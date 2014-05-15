require 'spec_helper'

describe Spree::InventoryUnit do
  let(:stock_location) { create(:stock_location_with_items) }
  let(:stock_item) { stock_location.stock_items.order(:id).first }

  context "#backordered_for_stock_item" do
    let(:order) do
      order = create(:order)
      order.state = 'complete'
      order.completed_at = Time.now
      order.tap(&:save!)
    end

    let(:shipment) do
      shipment = Spree::Shipment.new
      shipment.stock_location = stock_location
      shipment.shipping_methods << create(:shipping_method)
      shipment.order = order
      # We don't care about this in this test
      shipment.stub(:ensure_correct_adjustment)
      shipment.tap(&:save!)
    end

    let(:variant) do
      stock_item.variant
    end

    let(:line_item) do
      Spree::LineItem.create!(
        variant: variant,
        order: order
      )
    end

    let!(:unit) do
      shipment.inventory_units.create!(
        state: 'backordered',
        line_item: line_item,
        variant: variant
      )
    end

    # Regression for #3066
    it "returns modifiable objects" do
      units = Spree::InventoryUnit.backordered_for_stock_item(stock_item)
      expect { units.first.save! }.to_not raise_error
    end

    it "finds inventory units from its stock location when the unit's variant matches the stock item's variant" do
      Spree::InventoryUnit.backordered_for_stock_item(stock_item).should =~ [unit]
    end

    it "does not find inventory units that aren't backordered" do
      on_hand_unit = shipment.inventory_units.build
      on_hand_unit.state = 'on_hand'
      on_hand_unit.variant = variant
      on_hand_unit.line_item = line_item
      on_hand_unit.save!

      Spree::InventoryUnit.backordered_for_stock_item(stock_item).should_not include(on_hand_unit)
    end

    it "does not find inventory units that don't match the stock item's variant" do
      other_variant_unit = shipment.inventory_units.build
      other_variant_unit.state = 'backordered'
      other_variant_unit.variant = create(:variant)
      other_variant_unit.line_item = line_item
      other_variant_unit.save!

      Spree::InventoryUnit.backordered_for_stock_item(stock_item).should_not include(other_variant_unit)
    end

    context "other shipments" do
      let(:other_order) do
        order = create(:order)
        order.state = 'payment'
        order.completed_at = nil
        order.tap(&:save!)
      end

      let(:other_shipment) do
        shipment = Spree::Shipment.new
        shipment.stock_location = stock_location
        shipment.shipping_methods << create(:shipping_method)
        shipment.order = other_order
        # We don't care about this in this test
        shipment.stub(:ensure_correct_adjustment)
        shipment.tap(&:save!)
      end

      let(:other_shipment) do
        shipment = Spree::Shipment.new
        shipment.stock_location = stock_location
        shipment.shipping_methods << create(:shipping_method)
        shipment.order = other_order
        # We don't care about this in this test
        shipment.stub(:ensure_correct_adjustment)
        shipment.tap(&:save!)
      end

      let(:other_item) do
        Spree::LineItem.create!(
          variant: stock_item.variant,
          order: other_order
        )
      end

      let!(:other_unit) do
        unit = other_shipment.inventory_units.build
        unit.state = 'backordered'
        unit.variant_id = stock_item.variant.id
        unit.line_item = other_item
        unit.tap(&:save!)
      end

      it "does not find inventory units belonging to incomplete orders" do
        Spree::InventoryUnit.backordered_for_stock_item(stock_item).should_not include(other_unit)
      end

    end

  end

  context "variants deleted" do
    let!(:unit) do
      create :inventory_unit
    end

    it "can still fetch variant" do
      unit.variant.destroy
      expect(unit.reload.variant).to be_a Spree::Variant
    end

    it "can still fetch variants by eager loading (remove default_scope)" do
      pending "find a way to remove default scope when eager loading associations"
      unit.variant.destroy
      expect(Spree::InventoryUnit.joins(:variant).includes(:variant).first.variant).to be_a Spree::Variant
    end
  end

  context "#finalize_units!" do
    let!(:stock_location) { create(:stock_location) }
    let(:variant) { create(:variant) }
    let(:inventory_units) { [
      create(:inventory_unit, variant: variant),
      create(:inventory_unit, variant: variant)
    ] }

    it "should create a stock movement" do
      Spree::InventoryUnit.finalize_units!(inventory_units)
      inventory_units.any?(&:pending).should be_false
    end
  end
end

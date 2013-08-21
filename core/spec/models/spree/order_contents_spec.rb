require 'spec_helper'

describe Spree::OrderContents do
  let(:order) { Spree::Order.create }
  subject { described_class.new(order) }

  context "#add" do
    let(:variant) { create(:variant) }

    it 'should add line item if one does not exist' do
      line_item = subject.add(variant, 1)
      line_item.quantity.should == 1
      order.line_items.size.should == 1
    end

    it 'should update line item if one exists' do
      subject.add(variant, 1)
      line_item = subject.add(variant, 1)
      line_item.quantity.should == 2
      order.line_items.size.should == 1
    end

    it "should update order totals" do
      order.item_total.to_f.should == 0.00
      order.total.to_f.should == 0.00

      subject.add(variant, 1)

      order.item_total.to_f.should == 19.99
      order.total.to_f.should == 19.99
    end

    context "running promotions" do
      let(:promotion) { create(:promotion) }
      let(:calculator) { Spree::Calculator::FlatRate.new(:preferred_amount => 10) }

      context "one active order promotion" do
        let!(:action) { Spree::Promotion::Actions::CreateAdjustment.create(promotion: promotion, calculator: calculator) }

        it "creates valid discount on order" do
          subject.add(variant, 1)
          expect(subject.order.adjustments.to_a.sum(&:amount)).not_to eq 0
        end
      end

      context "one active line item promotion" do
        let!(:action) { Spree::Promotion::Actions::CreateItemAdjustment.create(promotion: promotion, calculator: calculator) }

        it "creates valid discount on order" do
          subject.add(variant, 1)
          expect(subject.order.line_item_adjustments.to_a.sum(&:amount)).not_to eq 0
        end
      end
    end
  end

  context "#remove" do
    let(:variant) { create(:variant) }

    context "given an invalid variant" do
      it "raises an exception" do
        expect {
          subject.remove(variant, 1)
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    it 'should reduce line_item quantity if quantity is less the line_item quantity' do
      line_item = subject.add(variant, 3)
      subject.remove(variant, 1)

      line_item.reload.quantity.should == 2
    end

    it 'should remove line_item if quantity matches line_item quantity' do
      subject.add(variant, 1)
      subject.remove(variant, 1)

      order.reload.find_line_item_by_variant(variant).should be_nil
    end

    it "should update order totals" do
      order.item_total.to_f.should == 0.00
      order.total.to_f.should == 0.00

      subject.add(variant,2)

      order.item_total.to_f.should == 39.98
      order.total.to_f.should == 39.98

      subject.remove(variant,1)
      order.item_total.to_f.should == 19.99
      order.total.to_f.should == 19.99
    end
  end
end

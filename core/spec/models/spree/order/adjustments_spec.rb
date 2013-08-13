require 'spec_helper'
describe Spree::Order do
  let(:order) { Spree::Order.new }

  context "clear_adjustments" do
    it "should destroy all previous tax adjustments" do
      adjustment = double
      adjustment.should_receive :destroy

      order.stub_chain :adjustments, :tax => [adjustment]
      order.clear_adjustments!
    end

    it "should destroy all price adjustments" do
      adjustment = double
      adjustment.should_receive :destroy

      order.stub :price_adjustments => [adjustment]
      order.clear_adjustments!
    end
  end

  context "totaling adjustments" do
    let(:adjustment1) { mock_model(Spree::Adjustment, :amount => 5) }
    let(:adjustment2) { mock_model(Spree::Adjustment, :amount => 10) }

    context "#ship_total" do
      it "should return the correct amount" do
        order.stub_chain :adjustments, :shipping => [adjustment1, adjustment2]
        order.ship_total.should == 15
      end
    end

    context "#tax_total" do
      it "should return the correct amount" do
        order.stub_chain :adjustments, :tax => [adjustment1, adjustment2]
        order.tax_total.should == 15
      end
    end
  end
end


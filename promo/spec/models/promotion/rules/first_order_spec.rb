require 'spec_helper'

describe Spree::Promotion::Rules::FirstOrder do
  let(:rule) { Spree::Promotion::Rules::FirstOrder.new }
  let(:order) { mock_model(Spree::Order, :user => nil) }
  let(:user) { mock_model(Spree::LegacyUser) }

  it "should not be eligible without a user" do
    rule.should_not be_eligible(order)
  end

  context "should be eligible if user does not have any other completed orders yet" do
    before(:each) do
      user.stub_chain(:orders, :complete => [])
    end

    it "for an order without a user, but with user in payload data" do
      rule.should be_eligible(order, :user => user)
    end

    it "for an order with a user, no user in payload data" do
      order.stub :user => user
      rule.should be_eligible(order)
    end
  end

  context "user already completed an order" do
    before(:each) do
      order.stub(:user => user)
    end

    it "any other order should not be eligible" do
      user.stub_chain(:orders, :complete => [mock_model(Spree::Order)])
      rule.should_not be_eligible(order)
    end

    it "should be eligible if checking against the same completed order" do
      user.stub_chain(:orders, :complete => [order])
      rule.should be_eligible(order)
    end
  end
end

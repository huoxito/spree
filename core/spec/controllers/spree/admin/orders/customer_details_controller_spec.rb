require 'spec_helper'

describe Spree::Admin::Orders::CustomerDetailsController do
  stub_authorization!

  let(:order) { mock_model(Spree::Order, :complete? => true, :total => 100) }

  before do
    Spree::Order.stub(:find_by_number! => order)
    request.env["HTTP_REFERER"] = "/"
  end

  context "#update" do
    it "should should not redirect the user" do
      order.stub(:update_attributes).and_return(true)
      spree_put :update
      response.should be_success
    end
  end
end

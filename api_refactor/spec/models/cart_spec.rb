require_relative '../../app/models/cart'

describe Cart do
  it "adds item to cart" do
    line_item = LineItem.new price: 5
    subject.add_item line_item

    expect(subject.line_items).to eq [line_item]
    expect(subject.item_total).to eq 5
  end

  it "adds item already in cart again" do
    line_item = LineItem.new price: 5
    subject.add_item line_item

    expect(subject.line_items).to eq [line_item]
    expect(subject.item_total).to eq 5
  end

  it "deletes item from cart" do
    line_item = LineItem.new price: 5

    subject.add_item line_item
    subject.remove_item line_item
    expect(subject.line_items).to eq []
  end

  it "holds a billing shipping address" do
    billing = Address.new
    subject.billing_address = billing
    expect(subject.billing_address).to eq billing

    shipping = Address.new
    subject.shipping_address = shipping
    expect(subject.shipping_address).to eq shipping
  end
end

require_relative '../../app/models/cart'

describe Cart do
  it "adds item to cart" do
    tshirt = Variant.new price: 5, sku: 'tshirt'
    subject.add_item tshirt

    expect(subject.line_items.count).to eq 1
    expect(subject.item_total).to eq 5
  end

  it "adds item already in cart again" do
    tshirt = Variant.new id: 1, price: 5, sku: 'tshirt'
    subject.add_item tshirt
    subject.add_item tshirt

    expect(subject.line_items.count).to eq 1
    expect(subject.item_total).to eq 10
  end

  it "empty" do
    tshirt = Variant.new id: 1, price: 5, sku: 'tshirt'
    subject.add_item tshirt

    subject.empty
    expect(subject.line_items.count).to eq 0
    expect(subject.item_total).to eq 0
  end

  it "deletes item from cart" do
    tshirt = Variant.new id: 1, price: 5, sku: 'tshirt'

    subject.add_item tshirt
    expect(subject.line_items.count).to eq 1

    subject.remove_item tshirt
    expect(subject.line_items.count).to eq 0
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

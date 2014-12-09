class Address
  attr_reader :firstname, :lastname, :address1, :city, :country
  attr_reader :zipcode, :phone
end

class Variant
  attr_reader :id, :sku, :price

  def initialize(attributes = {})
    @id = attributes[:id]
    @sku = attributes[:sku]
    @price = attributes[:price]
  end
end

def User
end

class LineItem
  attr_reader :price, :variant_id
  attr_accessor :quantity

  def initialize(attributes = {})
    @variant_id = attributes[:variant_id]
    @price = attributes[:price] || 1
    @quantity = attributes[:quantity] || 1
  end

  def amount
    price * quantity
  end
end

# Where line_items and addresses come from? How?
class Cart
  attr_reader :line_items, :item_total, :tax_total, :shipping_total

  attr_accessor :billing_address, :shipping_address

  def initialize(attributes = {})
    @line_items = []
    @item_total = @tax_total = @shipping_total = 0
  end

  # Perhaps some other object should take care of building / configuring
  # the line item (tried passing a LineItem here instead but didn't feel right
  # either)
  def add_item(variant, quantity = 1, options = {})
    if line_item = self.line_items.find { |l| l.variant_id == variant.id }
      line_item.quantity += quantity.to_i
    else
      line_item = LineItem.new(variant_id: variant.id, price: variant.price, quantity: quantity)
      self.line_items.push line_item
    end

    self.item_total = line_items.map(&:amount).reduce :+
    self.line_items
  end

  def remove_item(variant)
    line_item = self.line_items.find { |l| l.variant_id == variant.id }

    self.line_items.delete line_item
    self.line_items
  end

  def empty
    self.item_total = 0
    @line_items = []
  end

  private
    def item_total=(value)
      @item_total = value
    end
end

class Address
  attr_reader :firstname, :lastname, :address1, :city, :country
  attr_reader :zipcode, :phone
end

class LineItem
  attr_reader :price, :quantity

  def initialize(attributes = {})
    @price = attributes[:price] || 1
    @quantity = attributes[:quantity] || 1
  end

  def amount
    price * quantity
  end
end

class Cart
  attr_reader :line_items, :item_total, :tax_total, :shipping_total

  attr_accessor :billing_address, :shipping_address

  def initialize(attributes = {})
    @line_items = []
    @item_total = @tax_total = @shipping_total = 0
  end

  def add_item(line_item)
    self.line_items.push line_item
    self.item_total = line_items.map(&:amount).reduce :+
    self.line_items
  end

  def remove_item(line_item)
    self.line_items.delete line_item
    self.line_items
  end

  private
    def item_total=(value)
      @item_total = value
    end
end

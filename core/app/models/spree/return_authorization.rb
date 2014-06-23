module Spree
  class ReturnAuthorization < Spree::Base
    belongs_to :order, class_name: 'Spree::Order'

    has_many :inventory_units
    belongs_to :stock_location
    before_create :generate_number
    before_save :force_positive_amount

    validates :order, presence: true
    validates :amount, numericality: true
    validate :must_have_shipped_units

    state_machine initial: :authorized do
      after_transition to: :received, do: :process_return

      event :receive do
        transition to: :received, from: :authorized, if: :allow_receive?
      end
      event :cancel do
        transition to: :canceled, from: :authorized
      end
    end

    def currency
      order.nil? ? Spree::Config[:currency] : order.currency
    end

    def display_amount
      Spree::Money.new(amount, { currency: currency })
    end

    # add_variant is a bit of a misnomer. This method actually *sets* the
    # quantity of the variant we wish to return.
    def add_variant(variant_id, quantity)
      order_units = returnable_inventory.select{|unit| unit.variant_id == variant_id }
      returned_units = inventory_units.select{  |unit| unit.variant_id == variant_id }
      return false if order_units.empty?

      returned_count = returned_units.size

      if returned_count < quantity
        order_units.each do |unit|
          break if returned_count == quantity
          next if unit.return_authorization_id

          unit.split!(quantity - returned_count) do |new_unit|
            new_unit.return_authorization = self
            returned_count += new_unit.quantity
          end
        end
      elsif returned_count > quantity
        returned_units.each do |unit|
          break if returned_count == quantity

          unit.split!(returned_count - quantity) do |new_unit|
            new_unit.return_authorization = nil
            returned_count -= new_unit.quantity
          end
        end
      end

      order.authorize_return! if inventory_units.reload.size > 0 && !order.awaiting_return?
    end

    def returnable_inventory
      order.shipped_shipments.collect{|s| s.inventory_units.to_a}.flatten
    end

    # Used when Adjustment#update! wants to update the related adjustmenrt
    def compute_amount(*args)
      amount.abs * -1
    end

    private

      def must_have_shipped_units
        errors.add(:order, Spree.t(:has_no_shipped_units)) if order.nil? || !order.shipped_shipments.any?
      end

      def generate_number
        self.number ||= loop do
          random = "RMA#{Array.new(9){rand(9)}.join}"
          break random unless self.class.exists?(number: random)
        end
      end

      def process_return
        inventory_units(include: :variant).each do |iu|
          iu.return!

          if iu.variant.should_track_inventory?
            if stock_item = Spree::StockItem.find_by(variant_id: iu.variant_id, stock_location_id: stock_location_id)
              Spree::StockMovement.create!(stock_item_id: stock_item.id, quantity: 1)
            end
          end
        end

        Adjustment.create(adjustable: order, amount: compute_amount, label: Spree.t(:rma_credit), source: self)
        order.update!

        order.return if inventory_units.all?(&:returned?)
      end

      def allow_receive?
        !inventory_units.empty?
      end

      def force_positive_amount
        self.amount = amount.abs
      end
  end
end

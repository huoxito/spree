module Spree
  class OrderContents
    attr_accessor :order, :currency

    def initialize(order)
      @order = order
    end

    def add(variant, quantity, currency=nil, shipment=nil)
      line_item = add_to_line_item(variant, quantity, currency, shipment)
      order_updater.update_item_total
      PromotionItemHandlers.new(order, line_item).activate
      adjust_line_item line_item
      reload_totals

      line_item
    end

    def remove(variant, quantity, shipment=nil)
      line_item = remove_from_line_item(variant, quantity, shipment)
      adjust_line_item line_item
      reload_totals

      line_item
    end

    def update_cart(params)
      if order.update_attributes params
        order.line_items = order.line_items.select {|li| li.quantity > 0 }
        order.create_proposed_shipments if order.shipments.any?

        order.line_items.each { |item| adjust_line_item item }
        reload_totals
        true
      else
        false
      end
    end

    private
      def order_updater
        @updater ||= OrderUpdater.new(order)
      end

      def adjust_line_item(line_item)
        ItemAdjustments.new(line_item).update
        line_item
      end

      def reload_totals
        order_updater.update_item_total
        order_updater.update_adjustment_total
        order_updater.persist_totals

        order.reload
      end

      def add_to_line_item(variant, quantity, currency=nil, shipment=nil)
        line_item = grab_line_item_by_variant(variant)

        if line_item
          line_item.target_shipment = shipment
          line_item.quantity += quantity.to_i
          line_item.currency = currency unless currency.nil?
        else
          line_item = order.line_items.new(quantity: quantity, variant: variant)
          line_item.target_shipment = shipment
          if currency
            line_item.currency = currency unless currency.nil?
            line_item.price    = variant.price_in(currency).amount
          else
            line_item.price    = variant.price
          end
        end

        line_item.save
        line_item
      end

      def remove_from_line_item(variant, quantity, shipment=nil)
        line_item = grab_line_item_by_variant(variant, true)
        line_item.quantity += -quantity
        line_item.target_shipment= shipment

        if line_item.quantity == 0
          line_item.destroy
        else
          line_item.save!
        end

        line_item
      end

      def grab_line_item_by_variant(variant, raise_error = false)
        line_item = order.find_line_item_by_variant(variant)

        if !line_item.present? && raise_error
          raise ActiveRecord::RecordNotFound, "Line item not found for variant #{variant.sku}"
        end

        line_item
      end
  end
end

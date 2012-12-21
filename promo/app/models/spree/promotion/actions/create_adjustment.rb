module Spree
  class Promotion
    module Actions
      # Responsible for the creation and eligibility of an adjustment
      #
      # Only perform and eligible methods are called from outside this class
      # This differs from Spree core default mainly for the fact that it does
      # not delegates eligible? to the Promotion class. Instead it adds
      # more logic to give the flexibility of multiple promotions being applied
      # to the same order.
      #
      # All theses ajustments (discounts) might be eligible simultaneously
      #
      #   25% off for all Teflon Covers in the store
      #   15% off for all products associated with Food Equipment category
      #
      # However if there is more than one promotion set for Food Equipment products
      # only the most valuable adjustment will be eligible
      class CreateAdjustment < PromotionAction
        calculated_adjustments

        has_many :adjustments, :as => :originator, :dependent => :destroy

        before_validation :ensure_action_has_calculator

        # The first return call here is useless, The order input is already checked on the
        # Promotion class.
        #
        # Besides checking if the promotions is already associated with the order should be
        # a responsability of the Promotion and not the PromotionAction.
        # TODO Move this check to Spree::Promotion class
        # 
        # TODO Investigate why there is two calls for the order.update! in this method
        def perform(options = {})
          return unless order = options[:order]
          return if order.promotion_credit_exists?(promotion)

          order.adjustments.promotion.reload.clear
          order.update!
          create_adjustment("#{I18n.t(:promotion)} (#{promotion.name})", order, order)
          order.update!
        end

        # Override of CalculatedAdjustments#create_adjustment so promotional
        # adjustments are added all the time. They will get their eligability
        # set to false if the amount is 0
        #
        # TODO Does it make any sense at all to create adjustments with amount 0?
        # It probably indicates that the promotion should not even be eligible in
        # the first place
        #
        # TODO Why is it setting source here? It's not used anywhere I guess.
        # Orders are retrieved through :adjustable
        def create_adjustment(label, target, calculable, mandatory = false)
          amount = compute_amount(calculable)
          params = { :amount => amount,
                    :source => calculable,
                    :originator => self,
                    :label => label,
                    :mandatory => mandatory }
          target.adjustments.create(params, :without_protection => true)
        end

        # Decides whether or not the related adjustment will be eligible
        #
        # It goes through promotion#eligible? and promotion_rules#eligible?
        # first to avoid overwork.
        # In case the promotion is associated with products it tries to decide
        # whether it has the most valuable adjustment among the ones appliable
        # for the same products in the order.
        #
        # Should be called only after all promotion adjusments amount on the order
        # are saved. This gives the flexibility to manage discounts concurrently
        # among products in the order. Otherwise the logic described above would
        # not work properly
        #
        # TODO write a test for this scenario
        # Otherwise it leads to this issue:
        # A concurrent adjustment might be the best discount, although it shouldn't, because
        # all the other adjustments amounts were not updated yet
        def eligible?(order)
          return self.promotion.eligible?(order) if self.promotion.products.blank?
          self.promotion.eligible?(order) && self.best_than_concurrent_discounts?(order)
        end

        # Ensure a negative amount which does not exceed the sum of the order's item_total and ship_total
        def compute_amount(calculable)
          [(calculable.item_total + calculable.ship_total), super.to_f.abs].min * -1
        end

        def best_than_concurrent_discounts?(order)
          self.current_discount(order) < self.best_concurrent_discount(order)
        end

        def current_order_adjustment(order)
          self.adjustments.where("adjustable_id = ? AND adjustable_type = ?", order.id, "Spree::Order").first
        end

        def current_discount(order)
          current_order_adjustment(order).amount
        end

        def best_concurrent_discount(order)
          self.collect_discounts_sharing_products(order).min || 0
        end

        # TODO No idea yet why self.adjusment does not match orders adjustments when it should
        # so checking by id for now
        #   concurring_adjustments = order.adjustments - [self.adjustment]
        #
        # Collect concurrent discounts of products in other eligible promotions
        def collect_discounts_sharing_products(order)
          order.adjustments.inject([]) do |amount, adjustment|
            unless adjustment.id == self.current_order_adjustment(order).id
              adjustment_products = adjustment.originator.promotion.products

              if self.promotion.products.any? { |product| adjustment_products.include?(product) }
                amount << adjustment.amount if adjustment.originator.promotion.eligible?(order)
              end
            end
            amount
          end
        end

        private
          def ensure_action_has_calculator
            return if self.calculator
            self.calculator = Calculator::FlatPercentItemTotal.new
          end
      end
    end
  end
end

module Spree
  class Promotion
    module Actions
      # Manages the adjustment related to this action. Not only the creation of it
      # Responsible for the eligibility of the adjustment.
      # eligible? is called every time this adjusment is updated!
      class CreateAdjustment < PromotionAction
        calculated_adjustments

        has_one :adjustment, :as => :originator, :dependent => :destroy

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

        # override of CalculatedAdjustments#create_adjustment so promotional
        # adjustments are added all the time. They will get their eligability
        # set to false if the amount is 0
        #
        # TODO Does it make any sense at all to create adjustments with amount 0?
        # It probably indicates that the promotion should not even be eligible in
        # the first place
        #
        # TODO Why is it setting source here? It's not used anyhere. Orders are
        # retrieved through :adjustable
        #
        # TODO Since this class has_one :adjustment we might need to find a better way
        # to create adjustments. We're overriding Rails API create_association method for
        # has_one associations
        def create_adjustment(label, target, calculable, mandatory = false)
          amount = compute_amount(calculable)
          params = { :amount => amount,
                    :source => calculable,
                    :originator => self,
                    :label => label,
                    :mandatory => mandatory }
          target.adjustments.create(params, :without_protection => true)
        end

        # Ensure a negative amount which does not exceed the sum of the order's item_total and ship_total
        def compute_amount(calculable)
          [(calculable.item_total + calculable.ship_total), super.to_f.abs].min * -1
        end

        # TODO Shouldn't Spree Promotions have an eligible object?
        #
        # Should be called only after all promotion adjusments amount on the current order are saved.
        # This gives the flexibility to manage discount concurrently among products in the order
        #
        # Otherwise it leads to this issue:
        # A concurrent adjustment might be the best discount, although it shouldn't, because
        # all the other adjustments amounts were not updated yet
        def eligible?(order)
          return self.promotion.eligible?(order) if self.promotion.products.blank?
          self.promotion.eligible?(order) && self.best_then_concurrent_discounts?(order)
        end

        def best_then_concurrent_discounts?(order)
          self.current_discount < self.best_concurrent_discount(order)
        end

        def current_discount
          self.adjustment.amount
        end

        def best_concurrent_discount(order)
          self.collect_discounts_sharing_products(order).min || 0
        end

        # TODO No idea yet why self.adjusment does not match orders adjustments when it should
        # so checking by id for now
        #   concurring_adjustments = order.adjustments - [self.adjustment]
        def collect_discounts_sharing_products(order)
          order.adjustments.inject([]) do |amount, adjustment|
            unless adjustment.id == self.adjustment.id
              adjustment_products = adjustment.originator.promotion.products

              if self.promotion.products.any? { |product| adjustment_products.include?(product) }
                amount << adjustment.amount
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

module Spree
  class Promotion
    module Actions
      class CreateAdjustment < PromotionAction
        calculated_adjustments

        # delegate :eligible?, :to => :promotion
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

        # def eligible?(order)
        #   self.promotion.eligible? 
        # end

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

        def collect_discounts_sharing_products
          concurring_adjustments = order.adjustments - [self.adjustment]
          concurring_adjustments.inject([]) do |amount, adjustment|
            adjustment_products = adjustment.originator.promotion.products

            if self.promotion.products.any? { |product| adjustment_products.include?(product) }
              amount << adjustment.amount
            end
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

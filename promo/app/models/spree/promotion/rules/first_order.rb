module Spree
  class Promotion
    module Rules
      class FirstOrder < PromotionRule
        attr_reader :user

        def eligible?(order, options = {})
          @user = order.try(:user) || options[:user]

          if completed_orders.blank?
            !!(user && completed_orders.blank?)
          else
            completed_orders.first == order
          end 
        end

        private
          def completed_orders
            user ? user.orders.complete : []
          end
      end
    end
  end
end

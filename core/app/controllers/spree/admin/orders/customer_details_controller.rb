module Spree
  module Admin
    module Orders
      class CustomerDetailsController < Spree::Admin::BaseController
        before_filter :load_order

        def show
          edit
          render :action => :edit
        end

        def edit
          country_id = Address.default.country.id
          @order.build_bill_address(:country_id => country_id) if @order.bill_address.nil?
          @order.build_ship_address(:country_id => country_id) if @order.ship_address.nil?
        end

        def update
          if @order.update_attributes(params[:order])
            flash[:notice] = t('customer_details_updated')
          end
          render :action => :edit
        end

        private
          def load_order
            @order = Order.find_by_number!(params[:order_id], :include => :adjustments)
          end
      end
    end
  end
end

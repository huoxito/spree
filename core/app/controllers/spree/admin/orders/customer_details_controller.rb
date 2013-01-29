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

        # Updated without protection to set the order user_id if necessary
        def update
          if @order.update_attributes(params[:order], :without_protection => true)
            flash[:notice] = t('customer_details_updated')
            if @order.shipments.blank?
              redirect_to new_admin_order_shipment_path(@order)
            else
              redirect_to edit_admin_order_shipment_path(@order, @order.shipment)
            end
          else
            render :action => :edit
          end
        end

        private
          def load_order
            @order = Order.find_by_number!(params[:order_id], :include => :adjustments)
          end
      end
    end
  end
end

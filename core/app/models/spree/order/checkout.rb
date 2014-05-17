module Spree
  class Order < Spree::Base
    module Checkout
      def self.included(klass)
        klass.class_eval do
          class_attribute :next_event_transitions
          class_attribute :previous_states
          class_attribute :checkout_flow
          class_attribute :checkout_steps
          class_attribute :removed_transitions

          def self.checkout_flow(&block)
            if block_given?
              @checkout_flow = block
              define_state_machine!
            else
              @checkout_flow
            end
          end

          def self.define_state_machine!
            self.checkout_steps = {}
            self.next_event_transitions = []
            self.previous_states = [:cart]
            self.removed_transitions = []

            # Build the checkout flow using the checkout_flow defined either
            # within the Order class, or a decorator for that class.
            #
            # This method may be called multiple times depending on if the
            # checkout_flow is re-defined in a decorator or not.
            instance_eval(&checkout_flow)

            klass = self

            # To avoid a ton of warnings when the state machine is re-defined
            StateMachine::Machine.ignore_method_conflicts = true
            # To avoid multiple occurrences of the same transition being defined
            # On first definition, state_machines will not be defined
            state_machines.clear if respond_to?(:state_machines)
            state_machine :state, :initial => :cart, :use_transactions => false, :action => :save_state do
              klass.next_event_transitions.each { |t| transition(t.merge(:on => :next)) }

              # Persist the state on the order
              after_transition do |order, transition|
                order.state = order.state
                order.state_changes.create(
                  previous_state: transition.from,
                  next_state:     transition.to,
                  name:           'order',
                  user_id:        order.user_id
                )
                order.save
              end

              event :cancel do
                transition :to => :canceled, :if => :allow_cancel?
              end

              event :return do
                transition :to => :returned, :from => :awaiting_return, :unless => :awaiting_returns?
              end

              event :resume do
                transition :to => :resumed, :from => :canceled, :if => :canceled?
              end

              event :authorize_return do
                transition :to => :awaiting_return
              end

              if states[:payment]
                before_transition :to => :complete do |order|
                  order.process_payments! if order.payment_required?

                  if order.payment_required?
                    order.errors.add(:base, Spree.t(:no_payment_found))
                    false
                  end
                end
              end

              before_transition :from => :cart, :do => :ensure_line_items_present

              if states[:address]
                before_transition :from => :address, :do => :create_tax_charge!
              end

              if states[:payment]
                before_transition :to => :payment, :do => :set_shipments_cost
                before_transition :to => :payment, :do => :create_tax_charge!
              end

              if states[:delivery]
                before_transition :to => :delivery, :do => :create_proposed_shipments
                before_transition :to => :delivery, :do => :ensure_available_shipping_rates
                before_transition :from => :delivery, :do => :apply_free_shipping_promotions
              end

              after_transition :to => :complete, :do => :finalize!
              after_transition :to => :resumed,  :do => :after_resume
              after_transition :to => :canceled, :do => :after_cancel

              after_transition :from => any - :cart, :to => any - [:confirm, :complete] do |order|
                order.update_totals
                order.persist_totals
              end
            end

            alias_method :save_state, :save
          end

          def self.go_to_state(name, options={})
            self.checkout_steps[name] = options
            previous_states.each do |state|
              add_transition({:from => state, :to => name}.merge(options))
            end
            if options[:if]
              self.previous_states << name
            else
              self.previous_states = [name]
            end
          end

          def self.insert_checkout_step(name, options = {})
            before = options.delete(:before)
            after = options.delete(:after) unless before
            after = self.checkout_steps.keys.last unless before || after

            cloned_steps = self.checkout_steps.clone
            cloned_removed_transitions = self.removed_transitions.clone
            self.checkout_flow do
              cloned_steps.each_pair do |key, value|
                self.go_to_state(name, options) if key == before
                self.go_to_state(key, value)
                self.go_to_state(name, options) if key == after
              end
              cloned_removed_transitions.each do |transition|
                self.remove_transition(transition)
              end
            end
          end

          def self.remove_checkout_step(name)
            cloned_steps = self.checkout_steps.clone
            cloned_removed_transitions = self.removed_transitions.clone
            self.checkout_flow do
              cloned_steps.each_pair do |key, value|
                self.go_to_state(key, value) unless key == name
              end
              cloned_removed_transitions.each do |transition|
                self.remove_transition(transition)
              end
            end
          end

          def self.remove_transition(options={})
            self.removed_transitions << options
            self.next_event_transitions.delete(find_transition(options))
          end

          def self.find_transition(options={})
            return nil if options.nil? || !options.include?(:from) || !options.include?(:to)
            self.next_event_transitions.detect do |transition|
              transition[options[:from].to_sym] == options[:to].to_sym
            end
          end

          def self.next_event_transitions
            @next_event_transitions ||= []
          end

          def self.checkout_steps
            @checkout_steps ||= {}
          end

          def self.checkout_step_names
            self.checkout_steps.keys
          end

          def self.add_transition(options)
            self.next_event_transitions << { options.delete(:from) => options.delete(:to) }.merge(options)
          end

          def checkout_steps
            steps = self.class.checkout_steps.each_with_object([]) { |(step, options), checkout_steps|
              next if options.include?(:if) && !options[:if].call(self)
              checkout_steps << step
            }.map(&:to_s)
            # Ensure there is always a complete step
            steps << "complete" unless steps.include?("complete")
            steps
          end

          def has_checkout_step?(step)
            step.present? && self.checkout_steps.include?(step)
          end

          def checkout_step_index(step)
            self.checkout_steps.index(step)
          end

          def self.removed_transitions
            @removed_transitions ||= []
          end

          def can_go_to_state?(state)
            return false unless has_checkout_step?(self.state) && has_checkout_step?(state)
            checkout_step_index(state) > checkout_step_index(self.state)
          end

          define_callbacks :updating_from_params, terminator: ->(target, result) { result == false }

          set_callback :updating_from_params, :before, :update_params_payment_source

          def update_from_params(params, permitted_params, request_env = {})
            success = false
            @updating_params = params
            run_callbacks :updating_from_params do
              attributes = @updating_params[:order] ? @updating_params[:order].permit(permitted_params) : {}

              # Set existing card after setting permitted parameters because
              # rails would slice parameters containg ruby objects, apparently
              if @updating_params[:existing_card].present?
                credit_card = CreditCard.find(@updating_params[:existing_card])
                if credit_card.user_id != self.user_id || credit_card.user_id.blank?
                  raise Core::GatewayError.new Spree.t(:invalid_credit_card)
                end

                attributes[:payments_attributes].first[:source] = credit_card
                attributes[:payments_attributes].first[:payment_method_id] = credit_card.payment_method_id
                attributes[:payments_attributes].first.delete :source_attributes
              end

              if attributes[:payments_attributes]
                attributes[:payments_attributes].first[:request_env] = request_env
              end

              success = self.update_attributes(attributes)
            end

            @updating_params = nil
            success
          end

          private
          # For payment step, filter order parameters to produce the expected nested
          # attributes for a single payment and its source, discarding attributes
          # for payment methods other than the one selected
          def update_params_payment_source
            if has_checkout_step?("payment") && self.payment?
              if @updating_params[:payment_source].present?
                source_params = @updating_params.delete(:payment_source)[@updating_params[:order][:payments_attributes].first[:payment_method_id].underscore]

                if source_params
                  @updating_params[:order][:payments_attributes].first[:source_attributes] = source_params
                end
              end

              if (@updating_params[:order][:payments_attributes])
                @updating_params[:order][:payments_attributes].first[:amount] = self.total
              end
            end
          end
        end
      end
    end
  end
end

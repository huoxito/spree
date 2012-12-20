Spree::Order.class_eval do
  attr_accessible :coupon_code
  attr_accessor :coupon_code

  # Tells us if there if the specified promotion is already associated with the order
  # regardless of whether or not its currently eligible.  Useful because generally
  # you would only want a promotion to apply to order no more than once.
  def promotion_credit_exists?(promotion)
    !! adjustments.promotion.reload.detect { |credit| credit.originator.promotion.id == promotion.id }
  end

  # TODO This method would be better be implemented on the main app
  # Currently it can not be overriden if defined here
  #
  # A promotion adjustment eligibility depends on how the promotion rules
  # are set.
  # In case the promotion is associated with products it should check the
  # eligibilty of the action as well. Because we shouldn't apply more than
  # one adjustment associated with the same product to the order. Also this
  # rule probably only makes sense for adjustments being computed by the
  # PercentPerItem calculator
  #
  # unless self.method_defined?('update_adjustments_with_promotion_limiting')
  #   def update_adjustments_with_promotion_limiting
  #     update_adjustments_without_promotion_limiting
  #     return if adjustments.promotion.eligible.none?

  #     self.adjustments.each do |adjustment|
  #       if adjustment.originator.is_a?(Promotion::Actions::CreateAdjustment)
  #         adjustment.update_attribute_without_callbacks(:eligible, adjustment.originator.eligible?(self))
  #       end
  #     end

  #     most_valuable_adjustment = self.adjustments.promotion.eligible.max { |a,b| a.amount.abs <=> b.amount.abs }
  #     current_adjustments = (self.adjustments.promotion.eligible - [most_valuable_adjustment])
  #     current_adjustments.each do |adjustment|
  #       unless adjustment.originator.calculator.is_a?(Spree::Calculator::PercentPerItem)
  #         adjustment.update_attribute_without_callbacks(:eligible, false)
  #       end
  #     end
  #   end
  #   alias_method_chain :update_adjustments, :promotion_limiting
  # end
end

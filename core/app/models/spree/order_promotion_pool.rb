module Spree
  class OrderPromotionPool < ActiveRecord::Base
    belongs_to :order
    belongs_to :promotion

    scope :code, -> {
      includes(:promotion).where.not(Promotion.table_name => { code: nil })
        .references(:promotion)
    }
  end
end

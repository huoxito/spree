class CreateSpreeOrderPromotionPool < ActiveRecord::Migration
  def change
    create_table :spree_order_promotion_pools do |t|
      t.references :order, index: true
      t.references :promotion, index: true
      t.boolean :eligible
    end
  end
end

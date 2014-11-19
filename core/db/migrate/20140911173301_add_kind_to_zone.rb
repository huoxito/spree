class AddKindToZone < ActiveRecord::Migration
  def change
    add_column :spree_zones, :kind, :string
    add_index :spree_zones, :kind

    Spree::Zone.all.each do |zone|
      members = zone.members

      if members.any? && !members.any? { |member| member.try(:zoneable_type).nil? }
        zone.update_column :kind, members.last.zoneable_type.demodulize.underscore
      end
    end
  end
end

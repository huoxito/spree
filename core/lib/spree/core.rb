require 'rails/all'
require 'active_merchant'

ActiveSupport.on_load(:active_record) do
  require 'acts_as_list'
  require 'awesome_nested_set'
  require 'cancan'
  require 'paranoia'
  require 'ransack'
end

require 'mail'
require 'kaminari'
require 'paperclip'
require 'state_machine'

module Spree

  mattr_accessor :user_class

  def self.user_class
    if @@user_class.is_a?(Class)
      raise "Spree.user_class MUST be a String or Symbol object, not a Class object."
    elsif @@user_class.is_a?(String) || @@user_class.is_a?(Symbol)
      @@user_class.to_s.constantize
    end
  end

  # Used to configure Spree.
  #
  # Example:
  #
  #   Spree.config do |config|
  #     config.site_name = "An awesome Spree site"
  #   end
  #
  # This method is defined within the core gem on purpose.
  # Some people may only wish to use the Core part of Spree.
  def self.config(&block)
    ActiveSupport.on_load(:spree_config) do
      yield(Spree::Config)
    end
  end

  module Core
    autoload :ProductFilters, "spree/core/product_filters"

    class GatewayError < RuntimeError; end
  end
end

require 'spree/core/version'

require 'spree/core/mail_interceptor'
require 'spree/core/mail_method'
require 'spree/core/mail_settings'
require 'spree/core/environment_extension'
require 'spree/core/environment/calculators'
require 'spree/core/environment'
require 'spree/promo/environment'

require 'spree/core/engine'

require 'spree/i18n'
require 'spree/money'

require 'spree/permitted_attributes'
require 'spree/core/user_address'
require 'spree/core/s3_support'

ActiveSupport.on_load(:active_record) do
  require 'spree/core/delegate_belongs_to'
  require 'spree/core/permalinks'
  require 'spree/core/token_resource'

  ActiveRecord::Base.class_eval do
    include CollectiveIdea::Acts::NestedSet
  end
end

require 'spree/core/calculated_adjustments'
require 'spree/core/product_duplicator'
require 'spree/core/controller_helpers'
require 'spree/core/controller_helpers/strong_parameters'
require 'spree/core/controller_helpers/ssl'
require 'spree/core/controller_helpers/search'

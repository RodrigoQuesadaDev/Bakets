require 'bakets/version'

require 'bakets/internal/common/classes/class_metaprogramming_utils'
require 'bakets/bucket'
require 'bakets/bucket_config'
require 'bakets/bucket_config_manager'

module Bakets
  class << self
    attr_reader :default_root_bucket
  end

  @default_root_bucket = Bucket.new

  module ClassExtensions

    def new(*args)
      root = Bakets.default_root_bucket
      instance = root[self]
      if instance.nil?
        instance = super
        root[self] = instance
      end

      config = root.config_for(self)
      if config&.post_initialize&.enabled
        post_initialize_method = config.post_initialize.name
        if instance.respond_to?(post_initialize_method)
          instance.send(post_initialize_method)
        end
      end
      instance
    end

    def bakets(**attrs)
      raise 'This method should only be called within the context of a class.' unless is_a? Class

      Bakets.default_root_bucket.add_class self, BucketConfig.new(**attrs)
    end
  end
end

#region Bootstrapping
Class.prepend Bakets::ClassExtensions
#endregion
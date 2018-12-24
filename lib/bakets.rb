require 'bakets/version'

require 'bakets/internal/common/classes/class_refinements'
require 'bakets/internal/common/classes/class_metaprogramming_utils'
require 'bakets/bakets_exception'
require 'bakets/bucket'
require 'bakets/bucket_config'
require 'bakets/bucket_config_manager'

using Bakets::Internal::Common::ClassRefinements

module Bakets
  class << self
    attr_reader :_setup_config, :_default_root_bucket
  end

  @_setup_config = nil
  @_default_root_bucket = Bucket.new

  class << self

    def setup(**attrs)
      raise BaketsException, 'Setup should be performed a single time.' if @_setup_config

      @_setup_config = SetupConfig.new(**attrs)
    end

    def _third_party_class?(klass)
      !@_setup_config.root_modules.include? klass.root_module
    end
  end

  module ClassExtensions

    def new(*args)
      root = Bakets._default_root_bucket
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
      raise BaketsException, 'You need to setup Bakets first.' unless Bakets._setup_config
      raise 'This method should only be called with a class as receiver.' unless is_a? Class

      Bakets._default_root_bucket.add_class self, BucketConfig.new(self, **attrs)
    end
  end

  class SetupConfig
    attr_reader :root_modules

    def initialize(root_modules:)
      root_modules = [root_modules] unless root_modules.is_a? Array

      @root_modules = root_modules.map { |it|
        case it
        when Module then it
        when Symbol, String then Object.const_get it
        else raise BaketsException, "Each root module defined using 'root-modules' cannot only be of type Module, Symbol, or String."
        end
      }
    end
  end
end

#region Bootstrapping
Class.prepend Bakets::ClassExtensions
#endregion
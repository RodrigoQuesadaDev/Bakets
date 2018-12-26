require 'bakets/version'

require 'bakets/internal/common/classes/class_refinements'
require 'bakets/internal/common/classes/class_metaprogramming_utils'
require 'bakets/internal/common/thread/fiber_refinements'
require 'bakets/internal/common/thread/fiber_local/fiber_local_value'
require 'bakets/internal/common/thread/fiber_local/fiber_local_flag'
require 'bakets/internal/common/thread/fiber_local/fiber_local_accessors'
require 'bakets/bakets_exception'
require 'bakets/bucket'
require 'bakets/default_root_bucket'
require 'bakets/bucket_config'
require 'bakets/bucket_config_manager'
require 'bakets/internal/buckets_manager'

using Bakets::Internal::Common::ClassRefinements

module Bakets
  class << self
    attr_reader :_setup_config, :_buckets_manager
  end

  @_setup_config = nil
  @_root_bucket_specified = false
  @_buckets_manager = Internal::BucketsManager.new

  class << self

    def setup(**attrs)
      raise BaketsException, 'Setup should be performed a single time.' if @_setup_config

      @_setup_config = SetupConfig.new(**attrs)
    end

    def _third_party_class?(klass)
      !@_setup_config.root_modules.include? klass.root_module
    end

    def bucket(bucket_class = nil, root: false, &block)
      if root
        @_buckets_manager.scoping_root(bucket_class, &block)
      else
        @_buckets_manager.scoping(bucket_class, &block)
      end
    end

    #TODO check if this method should delegate to ::bucket
    def root_bucket(bucket_class = nil, &block)
      raise BaketsException, 'The root bucket should only be specified once within a given scope.' if @_root_bucket_specified

      begin
        @_root_bucket_specified = true

        bucket bucket_class, root: true, &block
      ensure
        @_root_bucket_specified = false
      end
    end
  end

  module ClassExtensions

    CREATING_OBJECT = Bakets::Internal::Common::FiberLocal::FiberLocalFlag.new

    def new(*args)
      return super if CREATING_OBJECT.value

      CREATING_OBJECT.setting do
        Bakets._buckets_manager.instance_for(self) do
          CREATING_OBJECT.unsetting { super }
        end
      end
    end

    def bakets(**attrs)
      raise BaketsException, 'You need to setup Bakets first.' unless Bakets._setup_config
      raise 'This method should only be called with a class as receiver.' unless is_a? Class

      bucket_class = attrs.delete(:bucket)
      Bakets._buckets_manager.add_class_to_bucket(self, BucketConfig.new(self, **attrs), bucket_class)
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
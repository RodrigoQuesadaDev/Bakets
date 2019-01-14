# frozen_string_literal: true

require 'ostruct'
require 'bakets/internal/common/hash/hash_refinements'
require 'bakets/internal/common/classes/core_types_refinements'
require 'bakets/internal/common/proc/proc_refinements'

using Bakets::Internal::Common::HashRefinements
using Bakets::Internal::Common::CoreTypesRefinements
using Bakets::Internal::Common::Procs::ProcRefinements

module Bakets

  class BucketConfig
    DEFAULT_CONFIG_OPTIONS = {
        post_initialize: {
            enabled: true,
            name: :post_initialize
        },
        on_bucket_destruction: {
            enabled: proc { @unique },
            name: :on_bucket_destruction
        }
    }.freeze
    DEFAULT_THIRD_PARTY_CONFIG_OPTIONS = DEFAULT_CONFIG_OPTIONS.deep_merge(
        post_initialize: {
            enabled: false
        },
        on_bucket_destruction: {
            enabled: false
        }
    ).freeze

    attr_reader :unique, :post_initialize, :on_bucket_destruction

    def initialize(klass, unique: false, post_initialize: {}, on_bucket_destruction: {})
      @unique = unique
      @default_config = _setup_default_config_for_instance klass
      @post_initialize = _get_lifecycle_config :post_initialize, post_initialize
      @on_bucket_destruction = _get_lifecycle_config :on_bucket_destruction, on_bucket_destruction

      raise ArgumentError, 'post_initialize.name should not be an empty String' if @post_initialize.name.empty?
      raise ArgumentError, 'on_bucket_destruction.name should not be an empty String' if @on_bucket_destruction.name.empty?
      raise BaketsException, "The 'on_bucket_destruction' lifecycle method cannot be enabled for non-unique objects." if @on_bucket_destruction.enabled && !@unique
    end

    private

    def _setup_default_config_for_instance(klass)
      replace_procs_with_values(Bakets._third_party_class?(klass) ? DEFAULT_THIRD_PARTY_CONFIG_OPTIONS : DEFAULT_CONFIG_OPTIONS)
    end

    def replace_procs_with_values(value)
      return value.transform_values(&method(:replace_procs_with_values)) if value.is_a?(Hash)
      return value.with_context(self).call if value.is_a?(Proc)

      value
    end

    def _get_lifecycle_config(lifecycle_symbol, user_lifecycle_config)
      lifecycle_config = _process_lifecycle_shortcuts user_lifecycle_config
      OpenStruct.new(@default_config[lifecycle_symbol].deep_merge(lifecycle_config)).freeze
    end

    def _process_lifecycle_shortcuts(user_lifecycle_config)
      case
      when user_lifecycle_config.is_boolean? then
        {enabled: user_lifecycle_config}
      when user_lifecycle_config.is_a?(String) || user_lifecycle_config.is_a?(Symbol) then
        {name: user_lifecycle_config}
      else
        user_lifecycle_config
      end
    end
  end
end
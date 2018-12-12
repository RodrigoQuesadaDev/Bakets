# frozen_string_literal: true

require 'ostruct'
require 'bakets/internal/common/hash/hash_refinements'
require 'bakets/internal/common/classes/core_types_refinements'

using Bakets::Internal::Common::HashRefinements
using Bakets::Internal::Common::CoreTypesRefinements

module Bakets

  class BucketConfig
    DEFAULT_POST_INITIALIZE_CONFIG = {
        enabled: true,
        name: :post_initialize
    }.freeze

    attr_reader :unique, :post_initialize

    def initialize(unique: false, post_initialize: {})
      post_initialize = process_post_initialize_shortcuts post_initialize

      @unique = unique
      @post_initialize = OpenStruct.new(DEFAULT_POST_INITIALIZE_CONFIG.deep_merge(post_initialize)).freeze

      raise ArgumentError, 'post_initialize.name should not be an empty String' if @post_initialize.name.empty?
    end

    private

    def process_post_initialize_shortcuts(post_initialize)
      case
      when post_initialize.is_boolean? then { enabled: post_initialize }
      when post_initialize.is_a?(String) || post_initialize.is_a?(Symbol) then { name: post_initialize }
      else post_initialize
      end
    end
  end
end
# frozen_string_literal: true

require 'ostruct'
require 'bakets/internal/common/hash/hash_refinements'

using Bakets::Internal::Common::HashRefinements

module Bakets

  class BucketConfig
    DEFAULT_POST_INITIALIZE_CONFIG = {
        enabled: true,
        name: :post_initialize
    }.freeze

    attr_reader :unique, :post_initialize

    def initialize(unique: false, post_initialize: {})
      @unique = unique
      @post_initialize = OpenStruct.new(DEFAULT_POST_INITIALIZE_CONFIG.deep_merge(post_initialize)).freeze

      raise ArgumentError, 'post_initialize.name should not be an empty String' if @post_initialize.name.empty?
    end
  end
end
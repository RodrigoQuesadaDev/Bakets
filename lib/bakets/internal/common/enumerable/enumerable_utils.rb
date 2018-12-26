# frozen_string_literal: true

require 'bakets/internal/common/delegator/dynamic_delegator'

module Bakets
  module Internal
    module Common

      class EnumerableReverseView < DynamicDelegator

        def initialize(source = nil, &block)
          super block || source
        end

        def each(*args)
          __getobj__.each(*args)
        end
      end
    end
  end
end
# frozen_string_literal: true

require 'bakets/internal/common/delegator/dynamic_delegator'

module Bakets
  module Internal
    module Common

      class EnumerableReverseView < DynamicDelegator

        def initialize(source = nil, &block)
          super block || source

          @__rodrigodev_find_method = __getobj__.method(:find).unbind.bind(self)
        end

        def each(*args, &block)
          __getobj__.reverse_each(*args, &block)
        end

        def find(*args, &block)
          @__rodrigodev_find_method.call(*args, &block)
        end
      end
    end
  end
end
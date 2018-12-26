# frozen_string_literal: true

require 'fiber'

module Bakets
  module Internal
    module Common

      module FiberRefinements

        ROOT = Fiber.current
        private_constant :ROOT

        refine Fiber.singleton_class do
          def root?
            Fiber.current.equal? ROOT
          end
        end
      end
    end
  end
end
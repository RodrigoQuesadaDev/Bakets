# frozen_string_literal: true

module Bakets
  module Internal
    module Common
      module Procs

        class AroundBlock

          def initialize(&block)
            @around = block
          end

          def run(&nested)
            was_call = false

            @around.call do
              nested.call

              was_call = true
            end
            assert_true was_call, 'The block passed to the AroundBlock should be called.'
          end
        end
      end
    end
  end
end
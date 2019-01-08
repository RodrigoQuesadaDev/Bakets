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
            was_called_or_error = false
            result = @around.call do
              nested.call.tap { was_called_or_error = true }
            rescue
              was_called_or_error = true
              raise
            end

            assert_true was_called_or_error, 'The block passed to the AroundBlock should be called.'
            result
          end
        end
      end
    end
  end
end
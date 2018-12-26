# frozen_string_literal: true

module Bakets
  module Internal
    module Common
      module FiberLocal

        class FiberLocalFlag

          def initialize(default_value = false)
            @flvalue = FiberLocalValue.new default_value
          end

          def value
            @flvalue.get
          end

          def set(value = true)
            @flvalue.set value
          end

          def unset
            @flvalue.set false
          end

          # region Public Utils
          def setting(value = true)
            temp = self.value
            set value
            yield
          ensure
            set temp
          end

          def unsetting(&block)
            setting false, &block
          end
          # endregion
        end
      end
    end
  end
end
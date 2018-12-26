# frozen_string_literal: true

require 'bakets/internal/common/hash/hash_refinements'

using Bakets::Internal::Common::FiberRefinements
using Bakets::Internal::Common::HashRefinements

module Bakets
  module Internal
    module Common
      module FiberLocal

        class FiberLocalValue

          def initialize(default_value = nil, &block)
            @default_value = block || proc { default_value }
          end

          def get
            _fiber_local_attribute_map.fetch!(object_id, &@default_value)
          end

          def set(val)
            _fiber_local_attribute_map[object_id] = val
          end

          private

          def _fiber_local_attribute_map
            (Fiber.root? ? Thread.current : Fiber.current).__rodrigodev_fiber_local_attribute_map
          end
        end

        #region extensions
        module ThreadFiberExtensions
          def __rodrigodev_fiber_local_attribute_map
            @__rodrigodev_fiber_local_attributes ||= {}
          end
        end
        #endregion
      end
    end
  end
end
#region Setup
Thread.include Bakets::Internal::Common::FiberLocal::ThreadFiberExtensions
Fiber.include Bakets::Internal::Common::FiberLocal::ThreadFiberExtensions
#endregion
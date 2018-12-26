# frozen_string_literal: true

module Bakets
  module Internal
    module Common

      class DynamicDelegator < Delegator
        def __getobj__
          unless defined?(@__rodrigodev_delegate_obj_proc)
            raise ::ArgumentError, 'not delegated' unless block_given?

            yield
          end

          @__rodrigodev_delegate_obj_proc.call
        end

        def __setobj__(obj)
          raise ::ArgumentError, 'cannot delegate to self' if equal?(obj)
          obj = proc { obj } unless obj.is_a? Proc

          @__rodrigodev_delegate_obj_proc = obj
        end
      end
    end
  end
end
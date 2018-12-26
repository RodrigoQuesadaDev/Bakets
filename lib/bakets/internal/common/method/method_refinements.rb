# frozen_string_literal: true

require 'bakets/internal/common/proc/proc_refinements'

module Bakets
  module Internal
    module Common
      module Methods

        module MethodRefinements

          refine Method do
            using Bakets::Internal::Common::Procs::ProcRefinements

            def curry_with_block(*args)
              to_proc.curry_with_block(*args)
            end
          end
        end
      end
    end
  end
end
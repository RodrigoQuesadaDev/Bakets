# frozen_string_literal: true

module Bakets
  module Internal
    module Common

      module CoreTypesRefinements

        refine Object do
          def is_boolean?
            self.class == TrueClass || self.class == FalseClass
          end
        end
      end
    end
  end
end
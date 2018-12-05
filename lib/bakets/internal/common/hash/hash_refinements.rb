# frozen_string_literal: true

module Bakets
  module Internal
    module Common

      module HashRefinements

        refine Hash do
          def deep_merge(second)
            merger = proc do |_, v1, v2|
              if v1.is_a?(Hash) && v1.is_a?(Hash)
                v1.merge(v2, &merger)
              else
                v2
              end
            end
            merge(second, &merger)
          end
        end
      end
    end
  end
end
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

          def fetch!(*args, &block)
            key = args[0]
            block = proc { args[1] } if !block_given? && args.length > 1

            new_block = if block_given? || args.length > 1 then proc {
                          value = block_given? ? block.call : args[1]
                          self[key] = value
                          value
                        }
                        else nil end

            fetch(key, &new_block)
          end
        end
      end
    end
  end
end
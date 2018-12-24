# frozen_string_literal: true

module Bakets
  module Internal
    module Common

      module ClassRefinements

        refine Class do
          def parent_module
            parent = name =~ /::[^:]+\Z/ ? $`.freeze : nil
            Object.module_eval("::#{parent}", __FILE__, __LINE__) unless parent.nil?
          end

          def root_module
            root = name =~ /::.+\Z/ ? $`.freeze : nil
            Object.module_eval("::#{root}", __FILE__, __LINE__) unless root.nil?
          end
        end
      end
    end
  end
end
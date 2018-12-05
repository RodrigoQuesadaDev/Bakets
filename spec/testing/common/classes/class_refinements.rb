# frozen_string_literal: true

module Bakets
  module Testing
    module Common

      module ClassRefinements

        refine Class do
          def parent_module
            parent = name =~ /::[^:]+\Z/ ? $`.freeze : nil
            Object.module_eval("::#{parent}", __FILE__, __LINE__) unless parent.nil?
          end
        end
      end
    end
  end
end
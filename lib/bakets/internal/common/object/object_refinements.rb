# frozen_string_literal: true

module Bakets
  module Internal
    module Common

      module ObjectRefinements

        refine Object do

          def send_if_possible(*args)
            if respond_to?(args.first)
              send(*args)
            end
          end
        end
      end
    end
  end
end
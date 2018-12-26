# frozen_string_literal: true

require 'bakets/internal/common/proc/proc_refinements'

using Bakets::Internal::Common::Procs::ProcRefinements

module Bakets
  module Internal
    module Common
      module FiberLocal

        module FiberLocalAccessors

          def flattr_accessor(*names, **options)

            names.each do |accessor_name|
              variable_sym = :"@__flattr_#{accessor_name}"

              class_exec(variable_sym, accessor_name.to_sym, options) do |variable_sym, accessor_sym, options|

                get_variable = proc {
                  unless instance_variable_defined? variable_sym
                    default_obj = options[:default]
                    default_value, default_proc = default_obj.is_a?(Proc) ? [nil, default_obj] : [default_obj, nil]

                    instance_variable_set variable_sym, FiberLocalValue.new(default_value, &default_proc&.with_context(self))
                  end

                  instance_variable_get variable_sym
                }

                define_method(accessor_sym) do
                  instance_exec(&get_variable).get
                end

                define_method("#{accessor_sym}=") do |value|
                  instance_exec(&get_variable).set value
                end
              end
            end
          end
        end
      end
    end
  end
end

# region setup
Class.include Bakets::Internal::Common::FiberLocal::FiberLocalAccessors
# endregion

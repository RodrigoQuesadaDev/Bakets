# frozen_string_literal: true

module Bakets
  module Internal
    module Common
      module Procs

        module ProcRefinements

          refine Proc do
            def with_context(context)
              proc { context.instance_exec(&self) }
            end

            def curry_with_block(*args)
              curry(*args).tap do |curried_proc|

                curried_proc.instance_exec do
                  @__rodrigodev_curry_args = []
                end

                def curried_proc.call(*args, **attrs, &block)
                  @__rodrigodev_curry_args.push(*args)
                  if block
                    if attrs.empty? then super(*@__rodrigodev_curry_args, &block)
                    else super(*@__rodrigodev_curry_args, **attrs, &block) end
                  else
                    self
                  end
                end
              end
            end
          end
        end
      end
    end
  end
end
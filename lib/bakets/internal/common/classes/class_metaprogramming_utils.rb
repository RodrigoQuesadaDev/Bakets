# frozen_string_literal: true

module Bakets
  module Internal
    module Common

      module Classes
        def self.redefine_method(klass, method_symbol, before = {}, after = proc { |it| it })
          klass.instance_eval do
            old_method = instance_method(method_symbol)

            define_method method_symbol do |*args, &block|

              instance_eval(&before)
              result = old_method.bind(self).call(*args, &block)
              instance_exec(result, &after)
            end
          end
        end
      end
    end
  end
end
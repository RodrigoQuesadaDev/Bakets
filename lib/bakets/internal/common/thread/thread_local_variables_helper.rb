# frozen_string_literal: true

module Bakets
  module Internal
    module Common

      class ThreadLocalVariablesHelper

        def initialize(namespace)
          @namespace = namespace
        end

        def key(symbol)
          ThreadLocalKey.new(@namespace, symbol)
        end

        def set_variable(key, value)
          raise 'key must be of type ThreadLocalKey' unless key.instance_of? ThreadLocalKey

          Thread.current[key.to_sym] = value
        end

        def get_variable(key)
          Thread.current[key.to_sym]
        end

        def set_flag(key, value = true)
          set_variable key, value
        end

        def unset_flag(key)
          set_flag key, false
        end

        def remove_variables(*keys)
          keys.each { |it| Thread.current[it.to_sym] = nil }
        end

        def clear
          Thread.current.thread_variables.each do |key|
            Thread.current[key.to_sym] = nil if key.class == ThreadLocalKey
          end
        end

        # region Public Utils
        def setting_flag(key, value = true)
          temp = get_variable key
          set_flag key, value
          yield
        ensure
          set_variable key, temp
        end

        def unsetting_flag(key, &block)
          setting_flag key, false, &block
        end

        # endregion

        # region Aliases
        alias []= set_variable

        alias [] get_variable
        # endregion
      end

      # region Other Classes
      class ThreadLocalKey
        def initialize(namespace, symbol)
          @symbol = :"#{namespace}_#{symbol}".to_sym
          freeze
        end

        def to_sym
          @symbol
        end
      end
      # endregion
    end
  end
end
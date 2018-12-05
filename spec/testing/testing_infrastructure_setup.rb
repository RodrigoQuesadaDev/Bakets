# frozen_string_literal: true

include Bakets::Internal::Common

using Bakets::Testing::Common::ClassRefinements

module Test
end

module Bakets
  module Testing
    module InfrastructureSetup
      class << self
        attr_reader :test_module
      end

      @test_module = Test

      module ClassExtensionOverrides

        def bakets(**attrs)
          test_module = InfrastructureSetup.test_module
          unless parent_module == test_module
            raise "Classes that use Bakets should be defined within the testing module '#{test_module}'."
          end
          unless Thread.current[:bakets_test_classes_was_called]
            raise "Classes that use Bakets should be defined using the 'test_classes' function."
          end

          super
        end
      end

      module RSpecExampleGroupOverrides

        def self.included(klass)
          klass.extend ClassMethods
        end

        module ClassMethods

          def test_classes(&block)
            test_module = InfrastructureSetup.test_module

            constants_created = nil
            before(:context) do
              ClassMethods.set_fiber_flag :bakets_test_classes_was_called
              constants_before = test_module.constants
              block.call
              constants_created = test_module.constants - constants_before
            end

            after(:context) do
              unless constants_created.empty?
                Bakets.remove_config_for(constants_created.map { |it| test_module.const_get it })
                constants_created.each { |it| test_module.send(:remove_const, it) }
              end
            end
          ensure
            ClassMethods.remove_fiber_variables :bakets_test_classes_was_called
          end

          #region Utils
          def self.set_fiber_variable symbol, value
            Thread.current[symbol] = value
          end

          def self.set_fiber_flag symbol
            set_fiber_variable symbol, true
          end

          def self.remove_fiber_variables(*symbols)
            symbols.each { |it| Thread.current[it] = nil }
          end
          #endregion
        end
      end
    end
  end

  def self.remove_config_for classes
    @default_root_bucket.remove_config_for classes
  end

  class Bucket
    def remove_config_for classes
      classes.each do |it|
        @classes_config.delete it
        @instances.delete it
      end
    end
  end
end

#region Setup
include Bakets::Testing::InfrastructureSetup.test_module
Class.prepend Bakets::Testing::InfrastructureSetup::ClassExtensionOverrides
RSpec::Core::ExampleGroup.include Bakets::Testing::InfrastructureSetup::RSpecExampleGroupOverrides
#endregion
# frozen_string_literal: true

include Bakets::Internal::Common

using Bakets::Internal::Common::ClassRefinements

module Test
end
module Test2
end
module Test3
end
module ThirdParty
end
module ThirdParty2
end
module ThirdParty3
end

module Bakets
  module Testing
    module InfrastructureSetup
      class << self
        attr_reader :test_modules
      end

      @test_modules = [Test, Test2, Test3, ThirdParty, ThirdParty2, ThirdParty3]

      module ClassExtensionOverrides

        def bakets(**attrs)
          test_modules = InfrastructureSetup.test_modules
          unless Thread.current[:bakets_allow_nont_test_classes]
            unless test_modules.include? parent_module
              raise "Classes that use Bakets should be defined within one of the testing modules '#{test_modules}'."
            end
            unless Thread.current[:bakets_test_classes_was_called]
              raise "Classes that use Bakets should be defined using the 'test_classes' function."
            end
          end

          super
        end
      end

      module RSpecExampleGroupOverrides

        module ClassMethods

          def test_classes(&block)
            test_modules = InfrastructureSetup.test_modules

            constants_created = {}
            before(:context) do
              ClassMethods.set_fiber_flag :bakets_test_classes_was_called
              constants_before = {}

              test_modules.each do |test_module|
                constants_before[test_module] = test_module.constants
              end

              block.call

              test_modules.each do |test_module|
                constants_created[test_module] = test_module.constants - constants_before[test_module]
              end
            end

            after(:context) do
              test_modules.each do |test_module|
                unless constants_created[test_module].empty?
                  Bakets.remove_config_for(constants_created[test_module].map { |it| test_module.const_get it })
                  constants_created[test_module].each { |it| test_module.send(:remove_const, it) }
                end
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

        def allow_non_test_classes
          ClassMethods.set_fiber_flag :bakets_allow_nont_test_classes
          yield
        ensure
          ClassMethods.remove_fiber_variables :bakets_allow_nont_test_classes
        end

        def simulate_no_setup
          Bakets.simulate_no_setup
          yield
        ensure
          Bakets.restore_setup_state
        end

        def self.included(klass)
          klass.extend ClassMethods
        end
      end
    end
  end

  def self.simulate_no_setup
    @_temp_backup_setup_config = @_setup_config
    @_setup_config = nil
  end

  def self.restore_setup_state
    @_setup_config = @_temp_backup_setup_config
  end

  def self.remove_config_for classes
    @_default_root_bucket.remove_config_for classes
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
Bakets::Testing::InfrastructureSetup.test_modules.each do |test_module|
  include test_module
end
Class.prepend Bakets::Testing::InfrastructureSetup::ClassExtensionOverrides
RSpec::Core::ExampleGroup.include Bakets::Testing::InfrastructureSetup::RSpecExampleGroupOverrides
#endregion
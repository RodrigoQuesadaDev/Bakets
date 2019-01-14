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
        attr_reader :managed_test_modules
      end

      @managed_test_modules = [Test, Test2, Test3, ThirdParty, ThirdParty2, ThirdParty3].freeze
      @unmanaged_test_modules = []

      def self.unmanaged_test_modules
        @unmanaged_test_modules.clone.freeze
      end

      def self.all_test_modules
        (@managed_test_modules + @unmanaged_test_modules).freeze
      end

      def self.add_unmanaged_test_module(mod)
        @unmanaged_test_modules << mod
      end

      module Flags
        ALLOW_NON_TEST_CLASSES = Internal::Common::FiberLocal::FiberLocalFlag.new
        TEST_CLASSES_WAS_CALLED = Internal::Common::FiberLocal::FiberLocalFlag.new
      end

      module ClassExtensionOverrides

        def bakets(**attrs)
          all_test_modules = InfrastructureSetup.all_test_modules
          unmanaged_test_modules = InfrastructureSetup.unmanaged_test_modules
          unless Flags::ALLOW_NON_TEST_CLASSES.value
            unless all_test_modules.include? parent_module
              raise "Classes that use Bakets should be defined within one of the testing modules '#{all_test_modules}'."
            end
            unless Flags::TEST_CLASSES_WAS_CALLED.value || unmanaged_test_modules.include?(parent_module)
              raise "Classes that use Bakets should be defined using the 'test_classes' function."
            end
          end

          super
        end
      end

      module RSpecExampleGroupOverrides

        module ClassMethods

          def test_classes(&block)
            test_modules = InfrastructureSetup.managed_test_modules

            constants_created = {}
            before(:context) do
              Flags::TEST_CLASSES_WAS_CALLED.set
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
                  constants_created[test_module].each { |it| test_module.__send__(:remove_const, it) }
                end
              end
            end
          ensure
            Flags::TEST_CLASSES_WAS_CALLED.unset
          end
        end

        def allowing_non_test_classes
          Flags::ALLOW_NON_TEST_CLASSES.setting { yield }
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

      module ObjectSpaceOverrides

        module ClassMethods

          def define_finalizer(obj, aProc = proc())
            if obj.is_a?(Bucket)
              aProc = ClassMethods.wrap_proc aProc
            end

            super obj, aProc
          end

          def self.wrap_proc(a_proc)
            proc {
              a_proc.call
              a_proc = nil # allow garbage collection to take place immediately afterwards for this proc
            }
          end
        end

        def self.prepended(klass)
          klass.singleton_class.prepend ClassMethods
        end
      end

      module GlobalFunctions

        def garbage_collect_bakets
          GC.start # collect normal objects
          GC.start # collect finalizer objects
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
    _buckets_manager.remove_config_for classes
  end

  module Internal
    class BucketsManager
      def remove_config_for classes
        classes.each { |it| @_configured_classes.delete it }
        destroy_root
      end
    end
  end
end

#region Setup
Bakets::Testing::InfrastructureSetup.managed_test_modules.each do |test_module|
  include test_module
end
Class.prepend Bakets::Testing::InfrastructureSetup::ClassExtensionOverrides
RSpec::Core::ExampleGroup.include Bakets::Testing::InfrastructureSetup::RSpecExampleGroupOverrides
ObjectSpace.prepend Bakets::Testing::InfrastructureSetup::ObjectSpaceOverrides
include Bakets::Testing::InfrastructureSetup::GlobalFunctions
#endregion
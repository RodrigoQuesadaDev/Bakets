# frozen_string_literal: true

require 'bakets/internal/common/proc/around_block'
require 'bakets/internal/common/method/method_refinements'
require 'weakref'

using Bakets::Testing::Assertions
using Bakets::Testing::AroundBlockRefinements
using Bakets::Internal::Common::Methods::MethodRefinements

RSpec.describe Bakets do

  AroundBlock = Bakets::Internal::Common::Procs::AroundBlock

  it 'has a version number' do
    expect(Bakets::VERSION).not_to be nil
  end

  describe 'API' do

    describe 'Setup' do

      context 'Bakets is not setup' do

        test_classes do
          module Test
            class Example
            end
          end
        end

        it "calling 'bakets' raises exception" do
          simulate_no_setup {

            expect { Example.bakets }.to raise_error BaketsException
          }
        end
      end

      it 'fails if called multiple times' do
        expect { Bakets.setup root_modules: [Test] }.to raise_error BaketsException
      end
    end

    describe 'Bucket' do

      def assert_new_objects_are_the_same(obj_class)
        obj1 = obj_class.new
        obj2 = obj_class.new
        obj3 = obj_class.new

        [obj1, obj2, obj3].each { |it| expect(it).to be_an_instance_of(obj_class) }
        assert_objects_are_the_same obj1, obj2, obj3
      end

      def assert_new_child_objects_are_the_same(parent_class)
        obj1 = parent_class.new.child
        obj2 = parent_class.new.child
        obj3 = parent_class.new.child

        assert_objects_are_the_same obj1, obj2, obj3
      end

      def assert_object_is_destroyed_after_getting_out_of_bucket_scope(around_scope, obj_class)
        assert_around_block around_scope

        obj_ref = nil
        around_scope.run do
          obj_ref = WeakRef.new(obj_class.new)
        end

        GC.start
        expect(obj_ref.weakref_alive?).to be_falsy
      end

      describe 'configuration' do

        describe 'unique: true' do

          test_classes do
            module Test
              class Unique
                bakets unique: true
              end
            end
          end

          it 'new objects are the same' do
            assert_new_objects_are_the_same Unique
          end
        end

        describe 'unique: false' do

          test_classes do
            module Test
              class NonUnique
                bakets unique: false
              end
            end
          end

          it 'new objects are different each time' do
            klass = NonUnique
            obj1 = klass.new
            obj2 = klass.new
            obj3 = klass.new

            expect(obj1).to_not equal(obj2)
            expect(obj1).to_not equal(obj3)
            expect(obj2).to_not equal(obj3)
          end
        end
      end

      describe 'usage' do

        context 'code is passed to it as a block' do

          test_classes do
            module Test
              class SampleBucket
                include Bakets::Bucket
              end
              class SampleBucket2
                include Bakets::Bucket
              end
              class SampleBucket3
                include Bakets::Bucket
              end
            end
          end

          def assert_it_runs_a_block(method)
            something = 123
            method.call {
              something = 234
            }
            expect(something).to eql 234
          end

          it 'it runs it at level 1' do
            assert_it_runs_a_block Bakets.method(:root_bucket)
            assert_it_runs_a_block Bakets.method(:bucket).curry_with_block.call(SampleBucket)
          end

          it 'it runs it at level 2' do
            assert_it_runs_a_block(proc do |&action|
              Bakets.bucket(SampleBucket2) do
                Bakets.bucket(SampleBucket3, &action)
              end
            end)
          end

          it 'it runs it at level 3' do
            assert_it_runs_a_block(proc do |&action|
              Bakets.bucket(SampleBucket) do
                Bakets.bucket(SampleBucket2) do
                  Bakets.bucket(SampleBucket3, &action)
                end
              end
            end)
          end
        end
      end

      describe 'scoping' do

        macros do
          def it_scopes_a_unique_obj(
              specific_context, get_obj_class, around_scope = Bakets::Internal::Common::Procs::AroundBlock.unscoped_block
          )
            assert_around_block around_scope

            it "scopes a unique object #{specific_context}" do

              around_scope.run do
                assert_new_objects_are_the_same(get_obj_class.call)
              end

              assert_object_is_destroyed_after_getting_out_of_bucket_scope(around_scope, get_obj_class.call) unless around_scope.is_unscoped_block?
            end
          end
        end

        describe 'all' do

          test_classes do
            module Test
              class SampleBucket
                include Bakets::Bucket
              end
              class SampleBucket2
                include Bakets::Bucket
              end
              class SampleBucket3
                include Bakets::Bucket
              end
            end
          end

          describe 'objects can be scoped to a specific bucket' do

            test_classes do
              module Test
                class BelongsToSample
                  bakets bucket: SampleBucket
                end
              end
            end

            it 'executing ::new fails when not called within the scope of a configured bucket' do
              expect { BelongsToSample.new }.to raise_error BaketsException
              expect { Bakets.bucket(SampleBucket2) { BelongsToSample.new } }.to raise_error BaketsException
            end

            test_classes do
              module Test
                class RootUnique
                  bakets unique: true
                end
                class SampleUnique
                  bakets unique: true, bucket: SampleBucket
                end
                class SampleUnique3
                  bakets unique: true, bucket: SampleBucket3
                end
              end
            end

            it_scopes_a_unique_obj(
                'at default root level',
                -> { RootUnique }
            )

            it_scopes_a_unique_obj(
                'at scoped default root level',
                -> { RootUnique },
                around_block(&Bakets.method(:root_bucket))
            )

            it_scopes_a_unique_obj(
                'at level 1',
                -> { SampleUnique },
                around_block do |&assertions|
                  Bakets.bucket(SampleBucket, &assertions)
                end
            )

            it_scopes_a_unique_obj(
                'at level 3',
                -> { SampleUnique3 },
                around_block do |&assertions|
                  Bakets.bucket(SampleBucket) {
                    Bakets.bucket(SampleBucket2) {
                      Bakets.bucket(SampleBucket3, &assertions)
                    }
                  }
                end
            )

            macros do
              def it_scopes_a_unique_obj_that_is_child_of(
                  parent_description, get_parent_obj_class, around_scope
              )
                assert_around_block around_scope

                it "scopes a unique object that's child of #{parent_description}" do
                  around_scope.run do
                    assert_new_child_objects_are_the_same(get_parent_obj_class.call)
                  end

                  assert_object_is_destroyed_after_getting_out_of_bucket_scope(around_scope, get_parent_obj_class.call)
                end
              end
            end

            test_classes do
              module Test
                class UniqueParent
                  attr_reader :child
                  bakets unique: true, bucket: SampleBucket2

                  def initialize
                    @child = UniqueChildOfUniqueParent
                  end
                end
                class UniqueChildOfUniqueParent
                  bakets unique: true, bucket: SampleBucket3
                end
              end
            end

            it_scopes_a_unique_obj_that_is_child_of(
                'another unique object',
                -> { UniqueParent },
                around_block do |&assertions|
                  Bakets.bucket(SampleBucket) {
                    Bakets.bucket(SampleBucket2) {
                      Bakets.bucket(SampleBucket3, &assertions)
                    }
                  }
                end
            )

            test_classes do
              module Test
                class NonUniqueParent
                  attr_reader :child

                  def initialize
                    @child = UniqueChildOfNonUniqueParent
                  end
                end
                class UniqueChildOfNonUniqueParent
                  bakets unique: true, bucket: SampleBucket3
                end
              end
            end

            it_scopes_a_unique_obj_that_is_child_of(
                'a non-unique object',
                -> { NonUniqueParent },
                around_block do |&assertions|
                  Bakets.bucket(SampleBucket) {
                    Bakets.bucket(SampleBucket2) {
                      Bakets.bucket(SampleBucket3, &assertions)
                    }
                  }
                end
            )

            it 'calling ::new for a unique object within the same bucket scope but in a different iteration will yield a different instance' do
              obj1 = Bakets.bucket(SampleBucket) { SampleUnique.new }
              obj2 = Bakets.bucket(SampleBucket) { SampleUnique.new }

              expect(obj1).to_not equal(obj2)
            end
          end

          describe 'objects can be scoped to multiple buckets' do

            test_classes do
              module Test
                class UniqueWithMultipleBuckets
                  bakets unique: true, bucket: SampleBucket2
                  bakets unique: true, bucket: SampleBucket3
                end
              end
            end

            it_scopes_a_unique_obj(
                'that belongs to multiple buckets - bucket 1',
                -> { UniqueWithMultipleBuckets },
                around_block do |&assertions|
                  Bakets.bucket(SampleBucket) {
                    Bakets.bucket(SampleBucket2, &assertions)
                  }
                end
            )

            it_scopes_a_unique_obj(
                'that belongs to multiple buckets - bucket 2',
                -> { UniqueWithMultipleBuckets },
                around_block do |&assertions|
                  Bakets.bucket(SampleBucket) {
                    Bakets.bucket(SampleBucket3, &assertions)
                  }
                end
            )

            describe 'calling ::new for a unique object within different configured bucket scopes will yield different instances for the same class' do

              it 'non-nested call' do
                obj1 = Bakets.bucket(SampleBucket2) { UniqueWithMultipleBuckets.new }
                obj2 = Bakets.bucket(SampleBucket3) { UniqueWithMultipleBuckets.new }

                expect(obj1).to_not equal(obj2)
              end

              it 'nested call' do
                obj1 = obj2 = nil
                Bakets.bucket(SampleBucket2) {
                  obj1 = UniqueWithMultipleBuckets.new
                  Bakets.bucket(SampleBucket3) {
                    obj2 = UniqueWithMultipleBuckets.new
                  }
                }

                expect(obj1).to_not be_nil
                expect(obj2).to_not be_nil
                expect(obj1).to_not equal(obj2)
              end
            end
          end
        end

        describe 'root' do

          group do
            macros do
              def it_fails_when_a_root_bucket_has_already_been_defined_within_the_scope(
                  specific_context, &around_action
              )
                it "fails_when_a_root_bucket_has_already_been_defined_within_the_scope #{specific_context}" do
                  expect {
                    around_action.call {

                      Bakets.root_bucket {
                        puts 'something'
                      }
                    }
                  }.to raise_error BaketsException
                end
              end
            end

            test_classes do
              module Test
                class SampleBucket
                  include Bakets::Bucket
                end
              end
            end

            it_fails_when_a_root_bucket_has_already_been_defined_within_the_scope(
                'immediately after defining the root bucket',
                &Bakets.method(:root_bucket)
            )

            it_fails_when_a_root_bucket_has_already_been_defined_within_the_scope(
                'inside a nested normal bucket'
            ) do |&action|
              Bakets.root_bucket {
                Bakets.bucket(SampleBucket, &action)
              }
            end
          end

          context 'an object belonging to it has already been created' do

            xit 'issues a warning when mode:warning or no mode is specified' do

            end

            xit 'it fails using mode:strict' do

            end

            xit 'does nothing when mode:ignore' do

            end
          end

          describe "objects that don't specify a bucket get mixed into the root bucket" do

            xit 'using a single bucket' do

            end
          end

          xit "allows for reusing after it's been destroyed" do

          end

          describe "allows for different buckets during the application's lifetime" do

            it "objects from specific buckets don't get mixed with objects from different ones" do

              fail
            end
          end

          describe 'destruction' do

            test_classes do
              module Test
                class SampleBucket
                  include Bakets::Bucket
                end

                class DefaultRootSample
                  bakets unique: true
                end
                class OwnRootSample
                  bakets unique: true, bucket: SampleBucket
                end
              end
            end

            it 'using #bucket with root:true option' do
              assert_object_is_destroyed_after_getting_out_of_bucket_scope(
                  around_block do |&assertions|
                    Bakets.bucket(root: true, &assertions)
                  end,
                  DefaultRootSample
              )
            end

            describe 'using #root_bucket' do

              it 'with default bucket' do
                assert_object_is_destroyed_after_getting_out_of_bucket_scope(
                    around_block(&Bakets.method(:root_bucket)),
                    DefaultRootSample
                )
              end

              it 'with own bucket' do
                assert_object_is_destroyed_after_getting_out_of_bucket_scope(
                    around_block do |&assertions|
                      Bakets.root_bucket(SampleBucket, &assertions)
                    end,
                    OwnRootSample
                )
              end

              it 'with own bucket and object configured with default bucket' do
                assert_object_is_destroyed_after_getting_out_of_bucket_scope(
                    around_block do |&assertions|
                      Bakets.root_bucket(SampleBucket, &assertions)
                    end,
                    DefaultRootSample
                )
              end
            end

            it 'using #destroy_root' do
              assert_object_is_destroyed_after_getting_out_of_bucket_scope(
                  around_block do |&assertions|
                    assertions.call
                    Bakets.destroy_root
                  end,
                  DefaultRootSample
              )
            end
          end

          describe 'default root bucket' do

            test_classes do
              module Test
                class DefaultRootSample
                  bakets unique: true
                end
              end
            end

            it_scopes_a_unique_obj(
                'using #root with no arguments',
                -> { DefaultRootSample },
                around_block(&Bakets.method(:root_bucket))
            )

            it_scopes_a_unique_obj(
                'using #bucket with root:true and no arguments',
                -> { DefaultRootSample },
                around_block do |&assertions|
                  Bakets.bucket(root: true, &assertions)
                end
            )
          end
        end
      end
    end

    describe 'Lifecycle hooks' do

      describe '#post_initialize' do

        describe 'main spec' do

          context 'simple class without inheritance' do
            test_classes do
              module Test
                class SimpleClass
                  bakets

                  attr_reader :events

                  def initialize
                    @events = []
                    @events << :initialize
                  end

                  def post_initialize
                    @events << :post_initialize
                  end
                end
              end
            end

            it '#post_initialize gets called after the initialization of the class' do
              obj = SimpleClass.new

              expect(obj.events).to eql [:initialize, :post_initialize]
            end
          end

          context 'superclass and subclass' do
            test_classes do
              module Test
                class SuperClass
                  attr_reader :events

                  def initialize
                    @events = []
                    @events << :initialize_super
                  end

                  def post_initialize
                    @events << :post_initialize_super
                  end
                end

                class SubClass < SuperClass
                  bakets

                  def initialize
                    super
                    @events << :initialize
                  end

                  def post_initialize
                    super
                    @events << :post_initialize
                  end
                end
              end
            end

            it '#post_initialize gets called after the initialize method of the superclass and the subclass has triggered' do
              obj = SubClass.new

              expect(obj.events).to eql [:initialize_super, :initialize, :post_initialize_super, :post_initialize]
            end
          end
        end

        describe 'configuration' do

          describe 'enabled' do

            test_classes do
              module Test
                class Enabled
                  bakets post_initialize: {enabled: true}

                  attr_reader :post_initialize_was_called

                  def post_initialize
                    @post_initialize_was_called = true
                  end
                end
              end
            end

            it "post_initialize gets called when 'enabled: true'" do
              obj = Enabled.new

              expect(obj.post_initialize_was_called).to be true
            end

            test_classes do
              module Test
                class Disabled
                  bakets post_initialize: {enabled: false}

                  attr_reader :post_initialize_was_called

                  def post_initialize
                    @post_initialize_was_called = true
                  end
                end
              end
            end

            it "post_initialize doesn't get called when 'enabled: false'" do
              obj = Disabled.new

              expect(obj.post_initialize_was_called).to be_falsy
            end

            test_classes do
              module Test
                class Default
                  bakets

                  attr_reader :post_initialize_was_called

                  def post_initialize
                    @post_initialize_was_called = true
                  end
                end
              end
            end

            it "default value is 'enabled: true' for own classes" do
              obj = Default.new

              expect(obj.post_initialize_was_called).to be true
            end

            test_classes do
              module ThirdParty
                class DefaultThirdParty
                  attr_reader :post_initialize_was_called

                  def post_initialize
                    @post_initialize_was_called = true
                  end
                end
              end
            end

            it "default value is 'enabled: false' for third-party classes" do
              allowing_non_test_classes {
                klass = ThirdParty::DefaultThirdParty
                klass.bakets
                obj = klass.new

                expect(obj.post_initialize_was_called).to be_falsy
              }
            end
          end

          describe 'name' do

            context 'illegal arguments' do

              it 'raises exception when name is empty' do

                expect {
                  module Test
                    class IllegalArgument
                      bakets post_initialize: {name: ''}
                    end
                  end
                }.to raise_error ArgumentError
              end
            end

            context 'using a String' do

              test_classes do
                module Test
                  class StringName
                    bakets post_initialize: {name: 'do_something_after_init'}

                    attr_reader :post_initialize_was_called, :do_something_after_init_was_called

                    def post_initialize
                      @post_initialize_was_called = true
                    end

                    def do_something_after_init
                      @do_something_after_init_was_called = true
                    end
                  end
                end
              end

              it "method named 'do_something_after_init' gets called instead of 'post_initialize'" do
                obj = StringName.new

                expect(obj.post_initialize_was_called).to be_falsy
                expect(obj.do_something_after_init_was_called).to be true
              end
            end

            context 'using a Symbol' do

              test_classes do
                module Test
                  class SymbolName
                    bakets post_initialize: {name: :do_something_after_init}

                    attr_reader :post_initialize_was_called, :do_something_after_init_was_called

                    def post_initialize
                      @post_initialize_was_called = true
                    end

                    def do_something_after_init
                      @do_something_after_init_was_called = true
                    end
                  end
                end
              end

              it 'method identified by symbol :do_something_after_init gets called instead of :post_initialize:' do
                obj = SymbolName.new

                expect(obj.post_initialize_was_called).to be_falsy
                expect(obj.do_something_after_init_was_called).to be true
              end
            end

            context 'default behavior' do

              test_classes do
                module Test
                  class Default
                    bakets

                    attr_reader :post_initialize_was_called

                    def post_initialize
                      @post_initialize_was_called = true
                    end
                  end
                end
              end

              it "default value is 'name: :post_initialize'" do
                obj = Default.new

                expect(obj.post_initialize_was_called).to be true
              end
            end
          end

          describe 'option shortcuts' do

            describe 'post_initialize: true/false' do

              test_classes do
                module Test
                  class EnabledTrueShortcut
                    bakets post_initialize: true

                    attr_reader :post_initialize_was_called

                    def post_initialize
                      @post_initialize_was_called = true
                    end
                  end
                end
              end

              it "'post_initialize: true' equals 'post_initialize.enable: true'" do
                obj = EnabledTrueShortcut.new

                expect(obj.post_initialize_was_called).to be true
              end

              test_classes do
                module Test
                  class EnabledFalseShortcut
                    bakets post_initialize: false

                    attr_reader :post_initialize_was_called

                    def post_initialize
                      @post_initialize_was_called = true
                    end
                  end
                end
              end

              it "'post_initialize: false' equals 'post_initialize.enable: false'" do
                obj = EnabledFalseShortcut.new

                expect(obj.post_initialize_was_called).to be_falsy
              end
            end

            describe 'post_initialize: String/Symbol' do

              test_classes do
                module Test
                  class NameStringShortcut
                    bakets post_initialize: 'do_something_after_init'

                    attr_reader :post_initialize_was_called, :do_something_after_init_was_called

                    def post_initialize
                      @post_initialize_was_called = true
                    end

                    def do_something_after_init
                      @do_something_after_init_was_called = true
                    end
                  end
                end
              end

              it "'post_initialize: String' equals 'post_initialize.name: String'" do
                obj = NameStringShortcut.new

                expect(obj.post_initialize_was_called).to be_falsy
                expect(obj.do_something_after_init_was_called).to be true
              end

              test_classes do
                module Test
                  class NameSymbolShortcut
                    bakets post_initialize: :do_something_after_init

                    attr_reader :post_initialize_was_called, :do_something_after_init_was_called

                    def post_initialize
                      @post_initialize_was_called = true
                    end

                    def do_something_after_init
                      @do_something_after_init_was_called = true
                    end
                  end
                end
              end

              it "'post_initialize: Symbol' equals 'post_initialize.name: Symbol'" do
                obj = NameSymbolShortcut.new

                expect(obj.post_initialize_was_called).to be_falsy
                expect(obj.do_something_after_init_was_called).to be true
              end
            end
          end
        end
      end

      # Only add before_bucket_destruction to unique objects...

      # by default it should only be called with own class definitions (or thrid party classes that use bakets with class reopening?)
      #   This means that 'bakets' called within a class definition is not the same as ClassName.bakets? NO, remove this
      #   I would say configured namespaces have a priority/different behavior for default values (such as post_initialize.enabled): NO, remove this
    end
  end

  describe 'Internal' do

    describe 'Own/Third-party classes detection' do

      test_classes do
        module Test
          class TestClass1
          end
        end

        module Test2
          class TestClass2
          end
        end

        module Test3
          class TestClass3
          end
        end
      end

      describe 'Own classes detection' do

        it 'detects 1 configured own class' do
          simulate_no_setup {
            Bakets.setup root_modules: [Test]

            expect(Bakets._third_party_class?(TestClass1)).to be false
            expect(Bakets._third_party_class?(TestClass2)).to be true
            expect(Bakets._third_party_class?(TestClass3)).to be true
          }
        end

        it 'detects 2 configured own classes' do
          simulate_no_setup {
            Bakets.setup root_modules: [Test, Test2]

            expect(Bakets._third_party_class?(TestClass1)).to be false
            expect(Bakets._third_party_class?(TestClass2)).to be false
            expect(Bakets._third_party_class?(TestClass3)).to be true
          }
        end

        it 'detects 3 configured own classes' do
          simulate_no_setup {
            Bakets.setup root_modules: [Test, Test2, Test3]

            expect(Bakets._third_party_class?(TestClass1)).to be false
            expect(Bakets._third_party_class?(TestClass2)).to be false
            expect(Bakets._third_party_class?(TestClass3)).to be false
          }
        end
      end

      it 'detects standard classes as third-party classes' do
        expect(Bakets._third_party_class?(String)).to be true
        expect(Bakets._third_party_class?(Hash)).to be true
      end

      describe 'configuration of root modules using various object types' do

        it 'allows configuration using Modules' do
          simulate_no_setup {
            Bakets.setup root_modules: [Test]

            expect(Bakets._third_party_class?(TestClass1)).to be false
            expect(Bakets._third_party_class?(TestClass2)).to be true
            expect(Bakets._third_party_class?(TestClass3)).to be true
          }
        end

        it 'allows configuration using Strings' do
          simulate_no_setup {
            Bakets.setup root_modules: ['Test']

            expect(Bakets._third_party_class?(TestClass1)).to be false
            expect(Bakets._third_party_class?(TestClass2)).to be true
            expect(Bakets._third_party_class?(TestClass3)).to be true
          }
        end

        it 'allows configuration using Symbols' do
          simulate_no_setup {
            Bakets.setup root_modules: [:Test]

            expect(Bakets._third_party_class?(TestClass1)).to be false
            expect(Bakets._third_party_class?(TestClass2)).to be true
            expect(Bakets._third_party_class?(TestClass3)).to be true
          }
        end

        it 'allows configuration using a single element instead of an array' do
          simulate_no_setup {
            Bakets.setup root_modules: Test

            expect(Bakets._third_party_class?(TestClass1)).to be false
            expect(Bakets._third_party_class?(TestClass2)).to be true
            expect(Bakets._third_party_class?(TestClass3)).to be true
          }
        end

        it 'fails when configured using an element of a non-supported type' do
          simulate_no_setup {
            expect { Bakets.setup root_modules: 123 }.to raise_error BaketsException
          }

          simulate_no_setup {
            expect { Bakets.setup root_modules: [123] }.to raise_error BaketsException
          }

          simulate_no_setup {
            expect { Bakets.setup root_modules: {value: 'something'} }.to raise_error BaketsException
          }
        end
      end
    end
  end
end

#TODO
# buckets should not be destroyed if pending thread still within its scope?
# multiple instances of buckets instead of single one? (think concurrency)
# manage buckets manually (therefore, allow to call Bakets.bucket(bucket))
# allow to specify multiple buckets simultaneously 'bakets unique: true, buckets: [SampleBucket1, SampleBucket1]'
# frozen_string_literal: true

require "bucket_scope_samples"
require 'bakets/internal/common/proc/around_block'
require 'bakets/internal/common/method/method_refinements'
require 'weakref'

using Bakets::Testing::Assertions
using Bakets::Testing::AroundBlockRefinements
using Bakets::Internal::Common::Methods::MethodRefinements

RSpec.describe Bakets do

  AroundBlock = Bakets::Internal::Common::Procs::AroundBlock
  BucketScopeSample = Bakets::Specs::BucketScopeSamples::BucketScopeSample
  SIMPLE_BUCKET_SCOPES = Bakets::Specs::BucketScopeSamples::SIMPLE_BUCKET_SCOPES
  UNIQUE_PARENT_UNIQUE_CHILD_BUCKET_SCOPES = Bakets::Specs::BucketScopeSamples::UNIQUE_PARENT_UNIQUE_CHILD_BUCKET_SCOPES
  NONUNIQUE_PARENT_UNIQUE_CHILD_BUCKET_SCOPES = Bakets::Specs::BucketScopeSamples::NONUNIQUE_PARENT_UNIQUE_CHILD_BUCKET_SCOPES

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

      def assert_new_objects_are_the_same(bucket_scope)
        obj1 = obj2 = obj3 = nil
        bucket_scope.scoping do
          obj1 = bucket_scope.new_obj
          obj2 = bucket_scope.new_obj
          obj3 = bucket_scope.new_obj
        end

        assert_objects_are_the_same obj1, obj2, obj3
      end

      def assert_object_is_destroyed_after_getting_out_of_bucket_scope(bucket_scope)

        obj_ref = nil
        bucket_scope.scoping do
          obj_ref = WeakRef.new(bucket_scope.new_obj)
        end

        GC.start
        expect(obj_ref.weakref_alive?).to be_falsy
      end

      def assert_objs_produced_in_two_given_scopes_are_not_the_same(bucket_scope1, bucket_scope2 = bucket_scope1)

        obj1 = obj2 = nil
        bucket_scope1.scoping { obj1 = bucket_scope1.new_obj }
        bucket_scope2.scoping { obj2 = bucket_scope2.new_obj }

        assert_objects_are_not_the_same obj1, obj2
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
            assert_new_objects_are_the_same(BucketScopeSample.new(obj_class: Unique))
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

            assert_objects_are_not_the_same obj1, obj2, obj3
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

          def assert_it_runs_a_block_and_returns_its_result(method)
            something = method.call {
              123
            }
            expect(something).to eql 123
          end

          it 'it runs it and returns its result at level 1' do
            assert_it_runs_a_block_and_returns_its_result Bakets.method(:root_bucket)
            assert_it_runs_a_block_and_returns_its_result Bakets.method(:bucket).curry_with_block.call(SampleBucket)
          end

          it 'it runs it and returns its result at level 2' do
            assert_it_runs_a_block_and_returns_its_result(proc do |&action|
              Bakets.bucket(SampleBucket2) do
                Bakets.bucket(SampleBucket3, &action)
              end
            end)
          end

          it 'it runs it and returns its result at level 3' do
            assert_it_runs_a_block_and_returns_its_result(proc do |&action|
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

        def assert_it_scopes_a_unique_obj(bucket_scope)
          assert_new_objects_are_the_same(bucket_scope)

          assert_object_is_destroyed_after_getting_out_of_bucket_scope(bucket_scope) unless bucket_scope.is_unscoped?
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

            it "scopes a unique object" do
              SIMPLE_BUCKET_SCOPES.all.each(&method(:assert_it_scopes_a_unique_obj))
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

            it 'it scopes a unique object that is child of another unique object' do
              UNIQUE_PARENT_UNIQUE_CHILD_BUCKET_SCOPES.all.each(&method(:assert_it_scopes_a_unique_obj))
            end

            it 'scopes a unique object that is child of a non-unique object' do
              NONUNIQUE_PARENT_UNIQUE_CHILD_BUCKET_SCOPES.all.each(&method(:assert_it_scopes_a_unique_obj))
            end

            describe 'calling ::new for a unique object within the same bucket scope but in a different scoping context will yield a different instance' do

              it 'immediately aftewards' do
                assert_objs_produced_in_two_given_scopes_are_not_the_same(
                    BucketScopeSample.new(
                        obj_class: SampleUnique,
                        around_scope: proc do |&actions|
                          Bakets.bucket(SampleBucket) { actions.call }
                        end
                    )
                )
              end

              it 'nested' do
                obj1 = obj2 = nil
                Bakets.bucket(SampleBucket) {
                  obj1 = SampleUnique.new
                  obj2 = Bakets.bucket(SampleBucket) { SampleUnique.new }
                }

                assert_objects_are_not_the_same obj1, obj2
              end
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

            it 'it scopes a unique object that belongs to multiple buckets - bucket 1' do
              assert_it_scopes_a_unique_obj(BucketScopeSample.new(
                  obj_class: UniqueWithMultipleBuckets,
                  around_scope: proc do |&actions|
                    Bakets.bucket(SampleBucket) {
                      Bakets.bucket(SampleBucket2, &actions)
                    }
                  end
              ))
            end

            it 'scopes a unique object that belongs to multiple buckets bucket 2' do
              assert_it_scopes_a_unique_obj(BucketScopeSample.new(
                  obj_class: UniqueWithMultipleBuckets,
                  around_scope: proc do |&actions|
                    Bakets.bucket(SampleBucket) {
                      Bakets.bucket(SampleBucket3, &actions)
                    }
                  end
              ))
            end

            describe 'calling ::new for a unique object within different configured bucket scopes will yield different instances for the same class' do

              it 'non-nested call' do
                assert_objs_produced_in_two_given_scopes_are_not_the_same(
                    BucketScopeSample.new(
                        obj_class: UniqueWithMultipleBuckets,
                        around_scope: proc do |&actions|
                          Bakets.bucket(SampleBucket2) { actions.call }
                        end
                    ),
                    BucketScopeSample.new(
                        obj_class: UniqueWithMultipleBuckets,
                        around_scope: proc do |&actions|
                          Bakets.bucket(SampleBucket3) { actions.call }
                        end
                    )
                )
              end

              it 'nested call' do
                obj1 = obj2 = nil
                Bakets.bucket(SampleBucket2) {
                  obj1 = UniqueWithMultipleBuckets.new
                  Bakets.bucket(SampleBucket3) {
                    obj2 = UniqueWithMultipleBuckets.new
                  }
                }

                assert_objects_are_not_the_same obj1, obj2
              end
            end
          end

          def assert_bucket_can_be_reused_after_being_destroyed(bucket_scope)
            obj1 = bucket_scope.scoping { bucket_scope.new_obj }
            obj2 = bucket_scope.scoping { bucket_scope.new_obj }

            assert_objects_are_not_the_same obj1, obj2
          end

          it "allows for reusing after it's been destroyed" do
            SIMPLE_BUCKET_SCOPES.scoped.each(&method(:assert_bucket_can_be_reused_after_being_destroyed))
          end
        end

        describe 'root' do

          test_classes do
            module Test
              class SampleBucket
                include Bakets::Bucket
              end
              class DefaultRootSample
                bakets unique: true
              end
            end
          end

          it 'fails when a root bucket has already been defined within the scope' do
            # immediately after root scope has been defined
            expect {
              Bakets.root_bucket {
                Bakets.root_bucket {
                  puts 'something'
                }
              }
            }.to raise_error BaketsException
            # nested
            expect {
              Bakets.root_bucket {
                Bakets.bucket(SampleBucket) {
                  Bakets.root_bucket {
                    puts 'something'
                  }
                }
              }
            }.to raise_error BaketsException
          end

          context 'a unique object belonging to it has already been created' do

            test_classes do
              module Test
                class AlreadyCreatedUnique
                  bakets unique: true
                end
              end
            end

            def assert_about_already_created_object(setup_options, assertions)
              assert_around_block assertions

              simulate_no_setup {
                Bakets.setup root_modules: [Test], **setup_options

                SIMPLE_BUCKET_SCOPES.root_scoped.each do |scope|

                  AlreadyCreatedUnique.new

                  assertions.run do
                    scope.scoping {}
                  end
                end
              }
            end

            def assert_it_issues_a_warning(**setup_options)
              assert_about_already_created_object(
                  setup_options,
                  around_block do |&scoped_block|
                    expect { scoped_block.call }.to output(/\balready\b.*\bcreated\b/i).to_stderr
                  end
              )
            end

            it 'issues a warning when mode:warning' do
              assert_it_issues_a_warning(before_root_scope_creation: :warning)
            end

            it 'it fails using mode:strict' do
              assert_about_already_created_object(
                  {before_root_scope_creation: :strict},
                  around_block do |&scoped_block|
                    expect { scoped_block.call }.to raise_error BaketsException
                  end
              )
            end

            it 'does nothing when mode:ignore' do
              assert_about_already_created_object(
                  {before_root_scope_creation: :ignore},
                  around_block do |&scoped_block|
                    expect { scoped_block.call }.to not_raise_error.and not_output.to_stderr
                  end
              )
            end

            it 'defaults to mode:warning' do
              assert_it_issues_a_warning
            end

            it 'a non-existent mode fails' do
              assert_about_already_created_object(
                  {before_root_scope_creation: :non_supported},
                  around_block do |&scoped_block|
                    expect { scoped_block.call }.to raise_error BaketsException
                  end
              )
            end
          end

          describe "objects that don't specify a bucket get mixed into the root bucket" do
            #TODO this one probably needs manual bucket handling functionality (as opposed to only bucket-class-based like right now)

            xit 'using a single bucket' do

            end
          end

          describe "allows for different root buckets during the application's lifetime" do

            test_classes do
              module Test
                class SampleRootBucket1
                  include Bakets::Bucket
                end
                class SampleRootBucket2
                  include Bakets::Bucket
                end

                class RootSample
                  bakets unique: true
                end
              end
            end

            it "objects from specific root buckets don't get mixed with objects from different ones" do
              assert_objs_produced_in_two_given_scopes_are_not_the_same(
                  BucketScopeSample.new(
                      obj_class: RootSample,
                      around_scope: proc do |&actions|
                        Bakets.root_bucket(SampleRootBucket1) { actions.call }
                      end
                  ),
                  BucketScopeSample.new(
                      obj_class: RootSample,
                      around_scope: proc do |&actions|
                        Bakets.root_bucket(SampleRootBucket2) { actions.call }
                      end
                  )
              )
            end
          end

          it 'destruction using #destroy_root' do
            assert_object_is_destroyed_after_getting_out_of_bucket_scope(BucketScopeSample.new(
                obj_class: DefaultRootSample,
                around_scope: proc do |&actions|
                  actions.call
                  Bakets.destroy_root
                end
            ))
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

      #TODO
      # Only add before_bucket_destruction to unique objects...

      # by default it should only be called with own class definitions (or thrid party classes that use bakets with class reopening?)
      #   This means that 'bakets' called within a class definition is not the same as ClassName.bakets? NO, remove this
      #   I would say configured namespaces have a priority/different behavior for default values (such as post_initialize.enabled): NO, remove this
      #   Actually, last one makes sense, keep it?
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
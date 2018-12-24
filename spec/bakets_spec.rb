# frozen_string_literal: true

RSpec.describe Bakets do

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

    describe 'Bucket configuration' do

      describe 'unique: true' do

        test_classes do
          module Test
            class Unique
              bakets unique: true
            end
          end
        end

        it 'new objects are the same' do
          klass = Unique
          obj1 = klass.new
          obj2 = klass.new
          obj3 = klass.new

          expect(obj1).to equal(obj2)
          expect(obj2).to equal(obj3)
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

              expect(obj.post_initialize_was_called).to be nil
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
              allow_non_test_classes {
                klass = ThirdParty::DefaultThirdParty
                klass.bakets
                obj = klass.new

                expect(obj.post_initialize_was_called).to be nil
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

                expect(obj.post_initialize_was_called).to be nil
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

                expect(obj.post_initialize_was_called).to be nil
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

                expect(obj.post_initialize_was_called).to be nil
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

                expect(obj.post_initialize_was_called).to be nil
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

                expect(obj.post_initialize_was_called).to be nil
                expect(obj.do_something_after_init_was_called).to be true
              end
            end
          end
        end
      end

      # Only add before_bucket_destruction to unique objects...

      # by default it should only be called with own class definitions (or thrid party classes that use bakets with class reopening?)
      #   This means that 'bakets' called within a class definition is not the same as ClassName.bakets?
      #   I would say configured namespaces have a priority/different behavior for default values (such as post_initialize.enabled).
      #   By default use/detect top/root namespace? (e.g. using Module.nested...)
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

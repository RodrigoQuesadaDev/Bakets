# frozen_string_literal: true

RSpec.describe Bakets do

  describe 'API' do

    describe 'Lifecycle hooks' do

      describe '#post_initialize' do

        class WithPostInitialize
          attr_reader :events

          def initialize
            @events = []
          end

          def post_initialize
            @events << :post_initialize
          end
        end

        module WithDoSomethingAfterInit

          def do_something_after_init
            @events << :do_something_after_init
          end
        end

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
                class Enabled < WithPostInitialize
                  bakets post_initialize: {enabled: true}
                end
              end
            end

            it "post_initialize gets called when 'enabled: true'" do
              obj = Enabled.new

              expect(obj.events).to eql [:post_initialize]
            end

            test_classes do
              module Test
                class Disabled < WithPostInitialize
                  bakets post_initialize: {enabled: false}
                end
              end
            end

            it "post_initialize doesn't get called when 'enabled: false'" do
              obj = Disabled.new

              expect(obj.events).to eql []
            end

            test_classes do
              module Test
                class Default < WithPostInitialize
                  bakets
                end
              end
            end

            it "default value is 'enabled: true' for own classes" do
              obj = Default.new

              expect(obj.events).to eql [:post_initialize]
            end

            test_classes do
              module ThirdParty
                class DefaultThirdParty < WithPostInitialize
                end
              end
            end

            it "default value is 'enabled: false' for third-party classes" do
              klass = ThirdParty::DefaultThirdParty
              klass.bakets
              obj = klass.new

              expect(obj.events).to eql []
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
                  class StringName < WithPostInitialize
                    include WithDoSomethingAfterInit

                    bakets post_initialize: {name: 'do_something_after_init'}
                  end
                end
              end

              it "method named 'do_something_after_init' gets called instead of 'post_initialize'" do
                obj = StringName.new

                expect(obj.events).to eql [:do_something_after_init]
              end
            end

            context 'using a Symbol' do

              test_classes do
                module Test
                  class SymbolName < WithPostInitialize
                    include WithDoSomethingAfterInit

                    bakets post_initialize: {name: :do_something_after_init}
                  end
                end
              end

              it 'method identified by symbol :do_something_after_init gets called instead of :post_initialize:' do
                obj = SymbolName.new

                expect(obj.events).to eql [:do_something_after_init]
              end
            end

            context 'default behavior' do

              test_classes do
                module Test
                  class Default < WithPostInitialize
                    bakets
                  end
                end
              end

              it "default value is 'name: :post_initialize'" do
                obj = Default.new

                expect(obj.events).to eql [:post_initialize]
              end
            end
          end

          describe 'option shortcuts' do

            describe 'post_initialize: true/false' do

              test_classes do
                module Test
                  class EnabledTrueShortcut < WithPostInitialize
                    bakets post_initialize: true
                  end
                end
              end

              it "'post_initialize: true' equals 'post_initialize.enable: true'" do
                obj = EnabledTrueShortcut.new

                expect(obj.events).to eql [:post_initialize]
              end

              test_classes do
                module Test
                  class EnabledFalseShortcut < WithPostInitialize
                    bakets post_initialize: false
                  end
                end
              end

              it "'post_initialize: false' equals 'post_initialize.enable: false'" do
                obj = EnabledFalseShortcut.new

                expect(obj.events).to eql []
              end
            end

            describe 'post_initialize: String/Symbol' do

              test_classes do
                module Test
                  class NameStringShortcut < WithPostInitialize
                    include WithDoSomethingAfterInit

                    bakets post_initialize: 'do_something_after_init'
                  end
                end
              end

              it "'post_initialize: String' equals 'post_initialize.name: String'" do
                obj = NameStringShortcut.new

                expect(obj.events).to eql [:do_something_after_init]
              end

              test_classes do
                module Test
                  class NameSymbolShortcut < WithPostInitialize
                    include WithDoSomethingAfterInit

                    bakets post_initialize: :do_something_after_init
                  end
                end
              end

              it "'post_initialize: Symbol' equals 'post_initialize.name: Symbol'" do
                obj = NameSymbolShortcut.new

                expect(obj.events).to eql [:do_something_after_init]
              end
            end
          end
        end
      end
    end
  end
end
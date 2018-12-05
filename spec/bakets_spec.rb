# frozen_string_literal: true

RSpec.describe Bakets do

  it 'has a version number' do
    expect(Bakets::VERSION).not_to be nil
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

# Add post_construct
# Only add before_bucket_destruction to unique objects...
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

          it "default value is 'enabled: true'" do
            obj = Default.new

            expect(obj.post_initialize_was_called).to be true
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

            it 'method identified by symbol :do_something_after_init gets called instead of :post_initialize:' do
              obj = StringName.new

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
      end
    end

    #by default it should only be called with own class definitions (or thrid party classes that use bakets with class reopening?)
    # test shortcuts for configuration (post_initialize = post_initialize.name; post_initialize = post_initialize.enabled...)
  end
end

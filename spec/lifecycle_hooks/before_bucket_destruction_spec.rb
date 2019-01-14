# frozen_string_literal: true

RSpec.describe Bakets do

  describe 'API' do

    describe 'Lifecycle hooks' do

      describe '#on_bucket_destruction' do

        class WithOnBucketDestruction
          attr_reader :events

          def initialize
            @events = []
          end

          def on_bucket_destruction
            @events << :on_bucket_destruction
          end
        end

        module WithDoSomethingAfterBucketDestruction

          def do_something_after_bucket_destruction
            @events << :do_something_after_bucket_destruction
          end
        end

        def assert_on_bucket_destruction(bucket_scope, &assertions)
          obj = nil
          bucket_scope.scoping do

            obj = bucket_scope.new_obj

            expect(obj.events.empty?).to be true
          end
          garbage_collect_bakets

          assertions.call obj
        end

        def assert_on_bucket_destruction_gets_called(bucket_scope)
          assert_on_bucket_destruction(bucket_scope) do |obj|
            expect(obj.events).to eql [:on_bucket_destruction]
          end
        end

        ROOT_BUCKET_SCOPED_BLOCK = proc do |&actions|
          Bakets.root_bucket { actions.call }
        end

        describe 'main spec' do

          it '#on_bucket_destruction gets called when the corresponding bucket is destroyed' do
            SIMPLE_BUCKET_SCOPES.scoped.each(&method(:assert_on_bucket_destruction_gets_called))
          end

          test_classes do
            module Test
              class NonUnique
              end
            end
          end

          it 'fails if configured for a non-unique class' do
            expect {
              NonUnique.bakets unique: false, on_bucket_destruction: {enabled: true}
            }.to raise_error BaketsException
          end
        end

        describe 'configuration' do

          describe 'enabled' do

            test_classes do
              module Test
                class Enabled < WithOnBucketDestruction
                  bakets unique: true, on_bucket_destruction: {enabled: true}
                end
              end
            end

            it "on_bucket_destruction gets called when 'enabled: true'" do
              assert_on_bucket_destruction(
                  BucketScopeSample.new(
                      obj_class: Enabled,
                      around_scope: ROOT_BUCKET_SCOPED_BLOCK
                  )
              ) do |obj|
                expect(obj.events).to eql [:on_bucket_destruction]
              end
            end

            test_classes do
              module Test
                class Disabled < WithOnBucketDestruction
                  bakets unique: true, on_bucket_destruction: {enabled: false}
                end
              end
            end

            it "on_bucket_destruction doesn't get called when 'enabled: false'" do
              assert_on_bucket_destruction(
                  BucketScopeSample.new(
                      obj_class: Disabled,
                      around_scope: ROOT_BUCKET_SCOPED_BLOCK
                  )
              ) do |obj|
                expect(obj.events).to eql []
              end
            end

            test_classes do
              module Test
                class Default < WithOnBucketDestruction
                  bakets unique: true
                end
              end
            end

            it "default value is 'enabled: true' for own classes" do
              assert_on_bucket_destruction(
                  BucketScopeSample.new(
                      obj_class: Default,
                      around_scope: ROOT_BUCKET_SCOPED_BLOCK
                  )
              ) do |obj|
                expect(obj.events).to eql [:on_bucket_destruction]
              end
            end

            test_classes do
              module ThirdParty
                class DefaultThirdParty < WithOnBucketDestruction
                end
              end
            end

            it "default value is 'enabled: false' for third-party classes" do
              assert_on_bucket_destruction(
                  BucketScopeSample.new(
                      obj_class: ThirdParty::DefaultThirdParty,
                      new_obj: proc {
                        klass = ThirdParty::DefaultThirdParty
                        klass.bakets unique: true
                        klass.new
                      },
                      around_scope: ROOT_BUCKET_SCOPED_BLOCK
                  )
              ) do |obj|
                expect(obj.events).to eql []
              end
            end
          end

          describe 'name' do

            context 'illegal arguments' do

              it 'raises exception when name is empty' do

                expect {
                  module Test
                    class IllegalArgument
                      bakets unique: true, on_bucket_destruction: {name: ''}
                    end
                  end
                }.to raise_error ArgumentError
              end
            end

            context 'using a String' do

              test_classes do
                module Test
                  class StringName < WithOnBucketDestruction
                    include WithDoSomethingAfterBucketDestruction

                    bakets unique: true, on_bucket_destruction: {name: 'do_something_after_bucket_destruction'}
                  end
                end
              end

              it "method named 'do_something_after_bucket_destruction' gets called instead of 'on_bucket_destruction'" do
                assert_on_bucket_destruction(
                    BucketScopeSample.new(
                        obj_class: StringName,
                        around_scope: ROOT_BUCKET_SCOPED_BLOCK
                    )
                ) do |obj|
                  expect(obj.events).to eql [:do_something_after_bucket_destruction]
                end
              end
            end

            context 'using a Symbol' do

              test_classes do
                module Test
                  class SymbolName < WithOnBucketDestruction
                    include WithDoSomethingAfterBucketDestruction

                    bakets unique: true, on_bucket_destruction: {name: :do_something_after_bucket_destruction}
                  end
                end
              end

              it 'method identified by symbol :do_something_after_bucket_destruction gets called instead of :on_bucket_destruction:' do
                assert_on_bucket_destruction(
                    BucketScopeSample.new(
                        obj_class: SymbolName,
                        around_scope: ROOT_BUCKET_SCOPED_BLOCK
                    )
                ) do |obj|
                  expect(obj.events).to eql [:do_something_after_bucket_destruction]
                end
              end
            end

            context 'default behavior' do

              test_classes do
                module Test
                  class Default < WithOnBucketDestruction
                    bakets unique: true
                  end
                end
              end

              it "default value is 'name: :on_bucket_destruction'" do
                assert_on_bucket_destruction(
                    BucketScopeSample.new(
                        obj_class: Default,
                        around_scope: ROOT_BUCKET_SCOPED_BLOCK
                    )
                ) do |obj|
                  expect(obj.events).to eql [:on_bucket_destruction]
                end
              end
            end
          end

          describe 'option shortcuts' do

            describe 'on_bucket_destruction: true/false' do

              test_classes do
                module Test
                  class EnabledTrueShortcut < WithOnBucketDestruction
                    bakets unique: true, on_bucket_destruction: true
                  end
                end
              end

              it "'on_bucket_destruction: true' equals 'on_bucket_destruction.enable: true'" do
                assert_on_bucket_destruction(
                    BucketScopeSample.new(
                        obj_class: EnabledTrueShortcut,
                        around_scope: ROOT_BUCKET_SCOPED_BLOCK
                    )
                ) do |obj|
                  expect(obj.events).to eql [:on_bucket_destruction]
                end
              end

              test_classes do
                module Test
                  class EnabledFalseShortcut < WithOnBucketDestruction
                    bakets unique: true, on_bucket_destruction: false
                  end
                end
              end

              it "'on_bucket_destruction: false' equals 'on_bucket_destruction.enable: false'" do
                assert_on_bucket_destruction(
                    BucketScopeSample.new(
                        obj_class: EnabledFalseShortcut,
                        around_scope: ROOT_BUCKET_SCOPED_BLOCK
                    )
                ) do |obj|
                  expect(obj.events).to eql []
                end
              end
            end

            describe 'on_bucket_destruction: String/Symbol' do

              test_classes do
                module Test
                  class NameStringShortcut < WithOnBucketDestruction
                    include WithDoSomethingAfterBucketDestruction

                    bakets unique: true, on_bucket_destruction: 'do_something_after_bucket_destruction'
                  end
                end
              end

              it "'on_bucket_destruction: String' equals 'on_bucket_destruction.name: String'" do
                assert_on_bucket_destruction(
                    BucketScopeSample.new(
                        obj_class: NameStringShortcut,
                        around_scope: ROOT_BUCKET_SCOPED_BLOCK
                    )
                ) do |obj|
                  expect(obj.events).to eql [:do_something_after_bucket_destruction]
                end
              end

              test_classes do
                module Test
                  class NameSymbolShortcut < WithOnBucketDestruction
                    include WithDoSomethingAfterBucketDestruction

                    bakets unique: true, on_bucket_destruction: :do_something_after_bucket_destruction
                  end
                end
              end

              it "'on_bucket_destruction: Symbol' equals 'on_bucket_destruction.name: Symbol'" do
                assert_on_bucket_destruction(
                    BucketScopeSample.new(
                        obj_class: NameSymbolShortcut,
                        around_scope: ROOT_BUCKET_SCOPED_BLOCK
                    )
                ) do |obj|
                  expect(obj.events).to eql [:do_something_after_bucket_destruction]
                end
              end
            end
          end
        end
      end
    end
  end
end
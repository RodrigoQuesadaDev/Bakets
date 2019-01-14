# frozen_string_literal: true

RSpec.describe Bakets do

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
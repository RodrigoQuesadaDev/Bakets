# frozen_string_literal: true

RSpec.describe Bakets do

  describe 'Sanity checks' do

    describe '::new' do

      test_classes do
        module Test
          class SanityCHeckNewArguments
            bakets unique: true
            attr_reader :value1, :value2, :value3, :other_values, :keyword1, :keyword2, :keyword3, :other_keywords, :block

            def initialize(value1, value2, value3, *other_values, keyword1:, keyword2:, keyword3:, **other_keywords, &block)
              @value1 = value1
              @value2 = value2
              @value3 = value3
              @other_values = other_values
              @keyword1 = keyword1
              @keyword2 = keyword2
              @keyword3 = keyword3
              @other_keywords = other_keywords
              @block = block
            end
          end
        end
      end

      it 'object can be initialize with keyword arguments, and blocks.' do
        obj = SanityCHeckNewArguments.new(
            123, 234, 345, 456, 567, 678,
            keyword1: 'abc', keyword2: 'bcd', keyword3: 'cde', def: 'efg', fgh: 'ghi', hij: 'ijk'
        ) do
          1234 + 2345
        end

        expect(obj.value1).to eq 123
        expect(obj.value2).to eq 234
        expect(obj.value3).to eq 345
        expect(obj.other_values).to eq [456, 567, 678]
        expect(obj.keyword1).to eq 'abc'
        expect(obj.keyword2).to eq 'bcd'
        expect(obj.keyword3).to eq 'cde'
        expect(obj.other_keywords).to eq({def: 'efg', fgh: 'ghi', hij: 'ijk'})
        expect(obj.block.call).to eq(3579)
      end
    end
  end
end
# frozen_string_literal: true

module Bakets
  module Testing
    module RSpec

      module RSpecExtensions
        def macros(&block)
          singleton_class.class_exec(&block)
        end

        def group(&block)
          context '---' do
            instance_exec(&block)
          end
        end

        def around_block(&block)
          Internal::Common::Procs::AroundBlock.new(&block)
        end

        def assert_around_block(block)
          assert_instance_of Internal::Common::Procs::AroundBlock, block
        end
      end
    end
  end
end
# region setup
include Bakets::Testing::RSpec::RSpecExtensions
# endregion
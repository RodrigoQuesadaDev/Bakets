# frozen_string_literal: true

require 'bakets/internal/common/proc/around_block'

module Bakets
  module Testing

    module AroundBlockRefinements

      UNSCOPED_BLOCK = Internal::Common::Procs::AroundBlock.new(&proc { |&nested| nested.call })
      private_constant :UNSCOPED_BLOCK

      refine Internal::Common::Procs::AroundBlock.singleton_class do
        def unscoped_block
          UNSCOPED_BLOCK
        end
      end

      refine Internal::Common::Procs::AroundBlock do

        def is_unscoped_block?
          equal? UNSCOPED_BLOCK
        end
      end
    end
  end
end
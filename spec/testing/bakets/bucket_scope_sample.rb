# frozen_string_literal: true

require 'bakets/internal/common/proc/around_block'

using Bakets::Testing::AroundBlockRefinements

module Bakets
  module Testing

    class BucketScopeSample
      attr_reader :obj_class

      AroundBlock = Internal::Common::Procs::AroundBlock

      def initialize(obj_class:, new_obj: -> { obj_class.new }, around_scope: nil)

        @around_scope = around_scope ? AroundBlock.new(&around_scope) : AroundBlock.unscoped_block
        @new_obj = new_obj
        @obj_class = obj_class
      end

      def scoping(&block)
        @around_scope.run do
          block.call
        end
      end

      def new_obj
        @new_obj.call.tap do |obj|
          assert_instance_of @obj_class, obj
        end
      end

      def is_unscoped?
        @around_scope.is_unscoped_block?
      end
    end
  end
end
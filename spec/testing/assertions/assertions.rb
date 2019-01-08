# frozen_string_literal: true

module Bakets
  module Testing

    module Assertions

      refine Object do
        def assert_objects_are_not_nil(*objs)
          assert(objs.all? { |it| !it.nil? })
        end

        def assert_objects_are_the_same(*objs)
          assert_objects_are_not_nil(*objs)
          objs.each_cons(2) { |a, b| expect(a).to equal(b) }
        end

        def assert_objects_are_not_the_same(*objs)
          assert_objects_are_not_nil(*objs)
          objs.combination(2) { |a, b| expect(a).to_not equal(b) }
        end
      end
    end
  end
end
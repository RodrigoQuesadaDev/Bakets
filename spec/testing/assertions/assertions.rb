# frozen_string_literal: true

module Bakets
  module Testing

    module Assertions

      refine Object do
        def assert_objects_are_the_same(*objs)
          objs.each_cons(2) { |a, b| expect(a).to equal(b) }
        end
      end
    end
  end
end
# frozen_string_literal: true

module Bakets
  module Testing

    class BucketScopeSampleSet

      protected

      attr_reader :scopes

      public

      def initialize(*scopes)
        @scopes = scopes.freeze
      end

      def each(&block)
        @scopes.each(&block)
      end

      def +(other)
        self.class.new(*(@scopes + other.scopes))
      end
    end
  end
end
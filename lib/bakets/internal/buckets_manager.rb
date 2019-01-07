# frozen_string_literal: true

require 'bakets/bucket'
require 'bakets/internal/common/object/object_refinements'
require 'bakets/internal/common/enumerable/enumerable_utils'

using Bakets::Internal::Common::ObjectRefinements

module Bakets
  module Internal

    class BucketsManager
      flattr_accessor :_scoped_buckets_stack, default: proc { self.class._scoped_buckets_stack_initial_value }

      DEFAULT_ROOT_BUCKET_CLASS = DefaultRootBucket

      def initialize
        @_configured_classes = {}
        @reverse_scoped_buckets_stack = Common::EnumerableReverseView.new(&method(:_scoped_buckets_stack))
      end

      def default_root_bucket
        _scoped_buckets_stack.first
      end

      def add_class_to_bucket(klass, config, bucket_class)
        self.class._bucket_class_or_default(bucket_class)._add_class klass, config
        @_configured_classes[klass] = true
      end

      def instance_for(klass, &new_instance)
        return new_instance.yield unless @_configured_classes[klass]

        bucket = @reverse_scoped_buckets_stack.find { |bucket| bucket._config_for klass }
        raise BaketsException, ':new must be called within the scope of a configured bucket.' unless bucket

        bucket[klass] ||= begin

          new_instance.yield.tap do |instance|
            config = bucket._config_for(klass)
            instance.send_if_possible config.post_initialize.name if config&.post_initialize&.enabled
          end
        end
      end

      def scoping_root(bucket_class, &block)
        raise BaketsException, 'scoped_buckets_stack.size must be 1' unless _scoped_buckets_stack.size == 1

        if bucket_class
          scoping(bucket_class, &block)
        else
          block.call
        end
      ensure
        destroy_root
      end

      def scoping(bucket_class)
        _scoped_buckets_stack.push self.class._new_bucket_for(bucket_class)
        yield
      ensure
        _scoped_buckets_stack.pop
      end

      def destroy_root
        _scoped_buckets_stack[0] = self.class._new_bucket_for(DEFAULT_ROOT_BUCKET_CLASS)
      end

      private

      def self._scoped_buckets_stack_initial_value
        [_new_bucket_for(DEFAULT_ROOT_BUCKET_CLASS)]
      end

      def self._bucket_class_or_default(bucket_klass)
        bucket_klass || DEFAULT_ROOT_BUCKET_CLASS
      end

      def self._new_bucket_for(bucket_klass)
        _bucket_class_or_default(bucket_klass).new
      end
    end
  end
end

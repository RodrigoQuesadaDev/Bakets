# frozen_string_literal: true

module Bakets

  module Bucket

    def initialize(*args)
      super
      @_bucket_instances = {}
    end

    def _instance_for(klass)
      @_bucket_instances[klass] if self.class._bucket_classes_config[klass]&.unique
    end

    def _config_for(klass)
      self.class._config_for klass
    end

    alias [] _instance_for

    def []=(klass, instance)
      @_bucket_instances[klass] = instance if self.class._bucket_classes_config[klass]&.unique
    end

    def empty?
      @_bucket_instances.empty?
    end

    module ClassMethods
      attr_reader :_bucket_classes_config

      def _add_class(klass, config)
        @_bucket_classes_config[klass] = config
      end

      def _config_for(klass)
        @_bucket_classes_config[klass]
      end
    end

    def self.included(klass)
      klass.instance_exec do
        @_bucket_classes_config = {}
      end
      klass.extend ClassMethods
    end
  end
end
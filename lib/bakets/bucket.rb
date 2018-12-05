# frozen_string_literal: true

module Bakets

  class Bucket
    class << self
      attr_reader :_classes_config
    end

    @_classes_config = {}

    def initialize
      @classes_config = Bucket._classes_config
      @instances = {}
    end

    def add_class klass, config
      @classes_config[klass] = config
    end

    def config_for(klass)
      @classes_config[klass]
    end

    def instance_for klass
      @instances[klass] if @classes_config[klass]&.unique
    end

    def [](klass)
      instance_for klass
    end

    def []=(klass, instance)
      @instances[klass] = instance if @classes_config[klass]&.unique
    end
  end
end
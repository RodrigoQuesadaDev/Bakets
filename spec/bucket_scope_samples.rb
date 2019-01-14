# frozen_string_literal: true

require 'testing/bakets/bucket_scope_sample'
require 'testing/bakets/bucket_scope_sample_set'
require 'testing/proc/around_block_refinements'
require 'bakets/internal/common/proc/around_block'

using Bakets::Testing::AroundBlockRefinements

module Bakets
  module Specs

    module BucketScopeSamples

      AroundBlock = Internal::Common::Procs::AroundBlock
      BucketScopeSample = Testing::BucketScopeSample
      BucketScopeSampleSet = Testing::BucketScopeSampleSet

      class BucketScopeSampleSets
        attr_reader :root_scoped, :scoped, :all

        def initialize(
            at_default_root_level:,
            root_scoped:,
            other_scopes:
        )
          @root_scoped = root_scoped.set
          @scoped = @root_scoped + other_scopes.set
          @all = BucketScopeSampleSet.new(at_default_root_level) + @scoped
          all
        end
      end

      class RootScopedBuckets
        attr_reader :set

        def initialize(
            at_scoped_default_root_level:,
            at_scoped_root_level_using_root_bucket_method:,
            at_scoped_root_level_using_root_bucket_method_and_object_configured_with_default_bucket:,
            at_scoped_root_level_using_bucket_method_and_no_bucket_specified:,
            at_scoped_root_level_using_bucket_method:,
            at_scoped_root_level_using_bucket_method_and_object_configured_with_default_bucket:
        )
          @set = BucketScopeSampleSet.new(
              at_scoped_default_root_level,
              at_scoped_root_level_using_root_bucket_method,
              at_scoped_root_level_using_root_bucket_method_and_object_configured_with_default_bucket,
              at_scoped_root_level_using_bucket_method_and_no_bucket_specified,
              at_scoped_root_level_using_bucket_method,
              at_scoped_root_level_using_bucket_method_and_object_configured_with_default_bucket
          )
        end
      end

      class OtherScopedBuckets
        attr_reader :set

        def initialize(at_level_1:, at_level_3:)
          @set = BucketScopeSampleSet.new(at_level_1, at_level_3)
        end
      end

      module Samples
        Testing::InfrastructureSetup.add_unmanaged_test_module self

        class RootBucket
          include Bakets::Bucket
        end
        class SampleBucket
          include Bakets::Bucket
        end
        class SampleBucket2
          include Bakets::Bucket
        end
        class SampleBucket3
          include Bakets::Bucket
        end

        class Base
          attr_reader :events

          def initialize
            @events = []
          end

          def on_bucket_destruction
            @events << :on_bucket_destruction
          end
        end

        class DefaultRootUnique < Base
          bakets unique: true, on_bucket_destruction: true
        end
        class RootUnique < Base
          bakets unique: true, bucket: RootBucket, on_bucket_destruction: true
        end
        class Unique < Base
          bakets unique: true, bucket: SampleBucket, on_bucket_destruction: true
        end
        class Unique3 < Base
          bakets unique: true, bucket: SampleBucket3, on_bucket_destruction: true
        end
      end
      include Samples

      SIMPLE_BUCKET_SCOPES = BucketScopeSampleSets.new(
          at_default_root_level: BucketScopeSample.new(
              obj_class: DefaultRootUnique
          ),
          root_scoped: RootScopedBuckets.new(
              at_scoped_default_root_level: BucketScopeSample.new(
                  obj_class: DefaultRootUnique,
                  around_scope: proc do |&actions|
                    Bakets.root_bucket { actions.call }
                  end
              ),
              at_scoped_root_level_using_root_bucket_method: BucketScopeSample.new(
                  obj_class: RootUnique,
                  around_scope: proc do |&actions|
                    Bakets.root_bucket(RootBucket) { actions.call }
                  end
              ),
              at_scoped_root_level_using_root_bucket_method_and_object_configured_with_default_bucket: BucketScopeSample.new(
                  obj_class: DefaultRootUnique,
                  around_scope: proc do |&actions|
                    Bakets.root_bucket(RootBucket) { actions.call }
                  end
              ),
              at_scoped_root_level_using_bucket_method_and_no_bucket_specified: BucketScopeSample.new(
                  obj_class: DefaultRootUnique,
                  around_scope: proc do |&actions|
                    Bakets.bucket(root: true) { actions.call }
                  end
              ),
              at_scoped_root_level_using_bucket_method: BucketScopeSample.new(
                  obj_class: RootUnique,
                  around_scope: proc do |&actions|
                    Bakets.bucket(RootBucket, root: true) { actions.call }
                  end
              ),
              at_scoped_root_level_using_bucket_method_and_object_configured_with_default_bucket: BucketScopeSample.new(
                  obj_class: DefaultRootUnique,
                  around_scope: proc do |&actions|
                    Bakets.bucket(RootBucket, root: true) { actions.call }
                  end
              )
          ),
          other_scopes: OtherScopedBuckets.new(
              at_level_1: BucketScopeSample.new(
                  obj_class: Unique,
                  around_scope: proc do |&actions|
                    Bakets.bucket(SampleBucket) { actions.call }
                  end
              ),
              at_level_3: BucketScopeSample.new(
                  obj_class: Unique3,
                  around_scope: proc do |&actions|
                    Bakets.bucket(SampleBucket) {
                      Bakets.bucket(SampleBucket2) {
                        Bakets.bucket(SampleBucket3) {
                          actions.call
                        }
                      }
                    }
                  end
              )
          )
      )

      class ParentChildBucketScope < BucketScopeSample

        def initialize(parent_class, obj_class, around_scope = nil)
          super obj_class: obj_class, new_obj: -> { parent_class.new.child }, around_scope: around_scope
        end
      end

      module Samples
        class DefaultRootUniqueParent
          attr_reader :child
          bakets unique: true

          def initialize
            @child = DefaultRootUniqueChild.new
          end
        end
        class RootUniqueParent
          attr_reader :child
          bakets unique: true

          def initialize
            @child = RootUniqueChild.new
          end
        end
        class UniqueParent
          attr_reader :child
          bakets unique: true, bucket: SampleBucket

          def initialize
            @child = UniqueChild.new
          end
        end
        class UniqueParent3
          attr_reader :child
          bakets unique: true, bucket: SampleBucket3

          def initialize
            @child = UniqueChild3.new
          end
        end

        class DefaultRootUniqueChild
          bakets unique: true
        end
        class RootUniqueChild
          bakets unique: true, bucket: RootBucket
        end
        class UniqueChild
          bakets unique: true, bucket: SampleBucket
        end
        class UniqueChild3
          bakets unique: true, bucket: SampleBucket3
        end
      end
      include Samples

      UNIQUE_PARENT_UNIQUE_CHILD_BUCKET_SCOPES = BucketScopeSampleSets.new(
          at_default_root_level: ParentChildBucketScope.new(
              DefaultRootUniqueParent,
              DefaultRootUniqueChild
          ),
          root_scoped: RootScopedBuckets.new(
              at_scoped_default_root_level: ParentChildBucketScope.new(
                  DefaultRootUniqueParent,
                  DefaultRootUniqueChild,
                  proc do |&actions|
                    Bakets.root_bucket { actions.call }
                  end
              ),
              at_scoped_root_level_using_root_bucket_method: ParentChildBucketScope.new(
                  RootUniqueParent,
                  RootUniqueChild,
                  proc do |&actions|
                    Bakets.root_bucket(RootBucket) { actions.call }
                  end
              ),
              at_scoped_root_level_using_root_bucket_method_and_object_configured_with_default_bucket: ParentChildBucketScope.new(
                  DefaultRootUniqueParent,
                  DefaultRootUniqueChild,
                  proc do |&actions|
                    Bakets.root_bucket(RootBucket) { actions.call }
                  end
              ),
              at_scoped_root_level_using_bucket_method_and_no_bucket_specified: ParentChildBucketScope.new(
                  DefaultRootUniqueParent,
                  DefaultRootUniqueChild,
                  proc do |&actions|
                    Bakets.bucket(root: true) { actions.call }
                  end
              ),
              at_scoped_root_level_using_bucket_method: ParentChildBucketScope.new(
                  RootUniqueParent,
                  RootUniqueChild,
                  proc do |&actions|
                    Bakets.bucket(RootBucket, root: true) { actions.call }
                  end
              ),
              at_scoped_root_level_using_bucket_method_and_object_configured_with_default_bucket: ParentChildBucketScope.new(
                  DefaultRootUniqueParent,
                  DefaultRootUniqueChild,
                  proc do |&actions|
                    Bakets.bucket(RootBucket, root: true) { actions.call }
                  end
              )
          ),
          other_scopes: OtherScopedBuckets.new(
              at_level_1: ParentChildBucketScope.new(
                  UniqueParent,
                  UniqueChild,
                  proc do |&actions|
                    Bakets.bucket(SampleBucket) { actions.call }
                  end
              ),
              at_level_3: ParentChildBucketScope.new(
                  UniqueParent3,
                  UniqueChild3,
                  proc do |&actions|
                    Bakets.bucket(SampleBucket) {
                      Bakets.bucket(SampleBucket2) {
                        Bakets.bucket(SampleBucket3) {
                          actions.call
                        }
                      }
                    }
                  end
              )
          )
      )

      module Samples
        class DefaultRootNonUniqueParent
          attr_reader :child
          bakets unique: false

          def initialize
            @child = DefaultRootUniqueChild.new
          end
        end
        class RootNonUniqueParent
          attr_reader :child
          bakets unique: false

          def initialize
            @child = RootUniqueChild.new
          end
        end
        class NonUniqueParent
          attr_reader :child
          bakets unique: false, bucket: SampleBucket

          def initialize
            @child = UniqueChild.new
          end
        end
        class NonUniqueParent3
          attr_reader :child
          bakets unique: false, bucket: SampleBucket3

          def initialize
            @child = UniqueChild3.new
          end
        end
      end
      include Samples

      NONUNIQUE_PARENT_UNIQUE_CHILD_BUCKET_SCOPES = BucketScopeSampleSets.new(
          at_default_root_level: ParentChildBucketScope.new(
              DefaultRootNonUniqueParent,
              DefaultRootUniqueChild
          ),
          root_scoped: RootScopedBuckets.new(
              at_scoped_default_root_level: ParentChildBucketScope.new(
                  DefaultRootNonUniqueParent,
                  DefaultRootUniqueChild,
                  proc do |&actions|
                    Bakets.root_bucket { actions.call }
                  end
              ),
              at_scoped_root_level_using_root_bucket_method: ParentChildBucketScope.new(
                  RootNonUniqueParent,
                  RootUniqueChild,
                  proc do |&actions|
                    Bakets.root_bucket(RootBucket) { actions.call }
                  end
              ),
              at_scoped_root_level_using_root_bucket_method_and_object_configured_with_default_bucket: ParentChildBucketScope.new(
                  DefaultRootNonUniqueParent,
                  DefaultRootUniqueChild,
                  proc do |&actions|
                    Bakets.root_bucket(RootBucket) { actions.call }
                  end
              ),
              at_scoped_root_level_using_bucket_method_and_no_bucket_specified: ParentChildBucketScope.new(
                  DefaultRootNonUniqueParent,
                  DefaultRootUniqueChild,
                  proc do |&actions|
                    Bakets.bucket(root: true) { actions.call }
                  end
              ),
              at_scoped_root_level_using_bucket_method: ParentChildBucketScope.new(
                  RootNonUniqueParent,
                  RootUniqueChild,
                  proc do |&actions|
                    Bakets.bucket(RootBucket, root: true) { actions.call }
                  end
              ),
              at_scoped_root_level_using_bucket_method_and_object_configured_with_default_bucket: ParentChildBucketScope.new(
                  DefaultRootNonUniqueParent,
                  DefaultRootUniqueChild,
                  proc do |&actions|
                    Bakets.bucket(RootBucket, root: true) { actions.call }
                  end
              )
          ),
          other_scopes: OtherScopedBuckets.new(
              at_level_1: ParentChildBucketScope.new(
                  NonUniqueParent,
                  UniqueChild,
                  proc do |&actions|
                    Bakets.bucket(SampleBucket) { actions.call }
                  end
              ),
              at_level_3: ParentChildBucketScope.new(
                  NonUniqueParent3,
                  UniqueChild3,
                  proc do |&actions|
                    Bakets.bucket(SampleBucket) {
                      Bakets.bucket(SampleBucket2) {
                        Bakets.bucket(SampleBucket3) {
                          actions.call
                        }
                      }
                    }
                  end
              )
          )
      )
    end
  end
end
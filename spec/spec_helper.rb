require 'test/unit'
require "bundler/setup"
require "bakets"
require "testing/rspec/rspec_extensions"
require "testing/proc/around_block_refinements"
require "testing/assertions/assertions"
require "testing/testing_infrastructure_setup"

include Test::Unit::Assertions

#Setup bakets
Bakets.setup root_modules: [Test, Test2, Test3]

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end

RSpec::Matchers.define_negated_matcher :not_output, :output
RSpec::Matchers.define_negated_matcher :not_raise_error, :raise_error

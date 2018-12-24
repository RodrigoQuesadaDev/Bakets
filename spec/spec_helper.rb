require "bundler/setup"
require "bakets"
require "testing/testing_infrastructure_setup"

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

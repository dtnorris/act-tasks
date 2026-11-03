# frozen_string_literal: true

require "minitest/autorun"
require_relative "../lib/act_tasks"

# Proves only the bootstrap import/version contract, without claiming task logic.
class PackageTest < Minitest::Test
  # Loads the package from its own checkout and verifies its initial version.
  # Accepts no arguments; assertion failures describe a broken scaffold identity.
  def test_independent_package_identity
    assert_equal "0.1.0", ActTasks::VERSION
    assert_equal "ActTasks", ActTasks.name
  end

  # Checks the distributable gem's identity, source inventory and dependency
  # independence. Missing/invalid metadata raises RubyGems validation errors.
  def test_installable_gem_specification
    specification = Gem::Specification.load(File.expand_path("../act-tasks.gemspec", __dir__))
    assert_equal "act-tasks", specification.name
    assert_equal ActTasks::VERSION, specification.version.to_s
    assert_empty specification.runtime_dependencies
    assert_equal Dir["lib/**/*.rb"].sort, specification.files.grep(/\Alib\//).sort
    assert specification.validate
  end
end

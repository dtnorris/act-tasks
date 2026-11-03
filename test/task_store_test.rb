# frozen_string_literal: true

require "minitest/autorun"
require "tmpdir"
require_relative "../lib/act_tasks"

# Transfers TaskStoreTest and the schema controls from PlanningGuidanceTest;
# policy, preparation, skill retrieval and lifecycle consumers stay in main.
class TaskStoreTest < Minitest::Test
  # Yields a real YAML directory, store and valid task; cleans up on any failure.
  def with_store
    Dir.mktmpdir("task-store-") do |root|
      task = { "id" => "T1", "title" => "Task", "repositories" => { "alpha" => { "access" => "write" } } }
      yield root, ActTasks::TaskStore.new(root), task
    end
  end

  # Loads actual files, sorted collections and missing paths while preserving
  # unrelated metadata and the main application's explicit checkpoint policy.
  def test_loading_collections_and_native_yaml_failures
    with_store do |root, store, task|
      assert_equal File.join(root, "T1.yml"), store.task_path("T1")
      error = assert_raises(ActTasks::InvalidTask) { store.load("T1") }
      assert_equal "task not found: T1", error.message
      assert_empty store.all
      task["author_metadata"] = { "custom" => [nil, false, "required"] }
      File.write(store.task_path("T1"), YAML.dump(task))
      File.write(File.join(root, "A.yml"), YAML.dump(task.merge("id" => "A")))
      assert_equal task, store.load("T1")
      assert_equal ["A", "T1"], store.all.map { |entry| entry.fetch("id") }
      File.write(store.task_path("T1"), "")
      assert_raises(ActTasks::InvalidTask) { store.load("T1") }
      File.write(store.task_path("T1"), "id: [\n")
      assert_raises(Psych::SyntaxError) { store.load("T1") }
      File.write(store.task_path("T1"), "id: &id T1\ntitle: *id\n")
      assert_raises(Psych::AliasesNotEnabled) { store.load("T1") }
      File.write(store.task_path("T1"), "--- 3\n")
      assert_raises(TypeError) { store.load("T1") }
      File.write(store.task_path("T1"), "")
      assert_raises(ActTasks::InvalidTask) { store.all }
    end
  end

  # Covers every migrated field refusal with compatible path/field diagnostics.
  def test_required_and_collection_metadata
    invalid = [["id", nil, "id is required"], ["id", "", "id is required"],
      ["title", nil, "title is required"], ["title", "", "title is required"],
      ["repositories", {}, "repositories must be a non-empty mapping"],
      ["repositories", [], "repositories must be a non-empty mapping"],
      ["repositories", { nil => {} }, "repository name must be a string"],
      ["repositories", { "" => {} }, "repository name must be a string"],
      ["repositories", { "alpha" => [] }, "alpha access must be write or read_only"],
      ["repositories", { "alpha" => { "access" => "other" } }, "alpha access must be write or read_only"],
      ["depends_on", nil, "depends_on must be an array"],
      ["constraints", nil, "constraints must be an array"],
      ["acceptance", nil, "acceptance must be an array"]]
    assert_invalid(invalid)
    with_store do |_root, store, task|
      task["repositories"]["alpha"]["access"] = "read_only"
      task.merge!("depends_on" => [], "constraints" => [], "acceptance" => [])
      File.write(store.task_path("T1"), YAML.dump(task))
      assert_equal task, store.load("T1")
    end
  end

  # Transfers all checkpoint schema negatives without importing checkpoint.rb.
  def test_checkpoint_metadata
    invalid = [nil, {}, { "mode" => "unknown" }, { "mode" => "required", "extra" => 1 }]
      .map { |value| ["checkpoint", value, "checkpoint mode must be required or exempt"] }
    [ { "mode" => "exempt" }, { "mode" => "exempt", "category" => "coding", "reason" => "No" },
      { "mode" => "exempt", "category" => "planning", "reason" => nil },
      { "mode" => "exempt", "category" => "planning", "reason" => " " } ].each do |value|
      invalid << ["checkpoint", value, "checkpoint exemption requires category and reason"]
    end
    invalid << ["checkpoint", { "mode" => "required", "reason" => "silent bypass" }, "required checkpoint takes only mode"]
    assert_invalid(invalid)
    with_store do |_root, store, task|
      [{ "mode" => "required" }, *%w[planning inspection no_code].map { |category|
        { "mode" => "exempt", "category" => category, "reason" => "No executable deliverable." }
      }].each do |policy|
        task["checkpoint"] = policy
        File.write(store.task_path("T1"), YAML.dump(task))
        assert_equal policy, store.load("T1").fetch("checkpoint")
      end
    end
  end

  # Transfers strict planning designation values and generic worker strings.
  def test_planning_and_worker_metadata
    values = [nil, true, false, "", " ", "Required", "optional", "required ", 1, [], ["required"], { "mode" => "required" }]
    invalid = values.map { |value| ["planning_guidance", value, "planning_guidance must be the scalar string required when present"] }
    invalid << ["worker_recommendation", [], "worker_recommendation must be a mapping"]
    invalid << ["worker_recommendation", { "thinking" => "High" }, "worker_recommendation model must be a non-empty string"]
    invalid << ["worker_recommendation", { "model" => "Any model" }, "worker_recommendation thinking must be a non-empty string"]
    %w[model thinking].each do |field|
      [nil, ""].each do |value|
        invalid << ["worker_recommendation", { "model" => "Any model", "thinking" => "Any effort" }.merge(field => value),
          "worker_recommendation #{field} must be a non-empty string"]
      end
    end
    assert_invalid(invalid)
    with_store do |_root, store, task|
      task.merge!("planning_guidance" => "required", "worker_recommendation" => {
        "model" => "Any human-authored model", "thinking" => "Custom effort" })
      File.write(store.task_path("T1"), YAML.dump(task))
      assert_equal task, store.load("T1")
    end
    refute defined?(AgentCodingTool), "package tests must not load main ACT"
  end

  # Checks table-driven negative cases through filesystem YAML, returning no
  # domain result. Assertion failures retain exact schema-message differences.
  def assert_invalid(cases)
    with_store do |_root, store, task|
      cases.each do |field, value, message|
        File.write(store.task_path("T1"), YAML.dump(task.merge(field => value)))
        error = assert_raises(ActTasks::InvalidTask) { store.load("T1") }
        assert_equal "#{store.task_path('T1')}: #{message}", error.message
      end
    end
  end
end

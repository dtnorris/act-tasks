# frozen_string_literal: true

require "minitest/autorun"
require_relative "../lib/act_tasks"

# Qualifies the supplied-fact journey without ACT stores, observers or processes.
class CompletionMetricsTest < Minitest::Test
  Metrics = ActTasks::CompletionMetrics

  # Builds a transient task with explicit edges; returns a Hash, raises nothing.
  def task(id, dependencies = [])
    { "id" => id, "depends_on" => dependencies }
  end

  # Returns a canonical write identity; no alias resolution or I/O occurs here.
  def authority(remote, branch = "main")
    ["git@github.com:example/#{remote}.git", branch]
  end

  # Composes selection, conditional width and dashboard metrics over explicit
  # facts. Empty state/authority facts are declared, never inferred by production.
  # Returns per-ID metric arrays; native input/assertion errors propagate.
  def journey(tasks, statuses, states: tasks.to_h { |item| [item.fetch("id"), {}] },
              reservations: {}, authorities: tasks.to_h { |item| [item.fetch("id"), []] },
              blocked: tasks.to_h { |item| [item.fetch("id"), false] })
    unlocks = statuses.filter_map do |status|
      next unless %w[READY CANDIDATE].include?(status.fetch("status"))

      id = status.fetch("id")
      [id, Metrics.completion_unlock_metrics(completed_id: id, tasks: tasks, states: states,
        reservations: reservations, writable_authorities: authorities, externally_blocked: blocked)]
    end.to_h
    Metrics.completion_dashboard_metrics(tasks: tasks, statuses: statuses, unlock_metrics: unlocks)
  end

  # Returns one effective status fact. No lifecycle or freshness is inferred.
  def status(id, label = "READY")
    { "id" => id, "status" => label }
  end

  # First continuous package proof: a diamond's join needs both parents and a
  # greedy bridge loses to two independent writers. Raises on changed answers.
  def test_diamond_final_prerequisite_and_non_greedy_width
    tasks = [task("ROOT"), task("A", ["ROOT"]), task("B", ["ROOT"]), task("JOIN", %w[A B]),
             task("BRIDGE", ["ROOT"]), task("TAIL", ["JOIN"])]
    authorities = { "A" => [authority("x")], "B" => [authority("y")],
                    "BRIDGE" => [authority("x"), authority("y")] }
    assert_equal({ "ROOT" => [3, 5, 3, 2] }, journey(tasks, [status("ROOT")], authorities: authorities))
    states = tasks.to_h { |item| [item.fetch("id"), {}] }
    states["A"] = { "result" => { "outcome" => "complete" } }
    assert_equal [task("JOIN", %w[A B])], Metrics.immediately_unlocked_tasks(completed_id: "B", tasks: tasks, states: states)
  end

  # Retains CLI chain/wide/diamond/distinct counts and finite self/cycle paths,
  # including duplicate edges and an absent depends_on field. Assertions fail.
  def test_graph_shapes_and_missing_dependency_field
    tasks = [task("ROOT"), task("A", %w[ROOT ROOT]), task("B", ["ROOT"]), task("D", %w[A B]),
             task("CHAIN"), task("C1", ["CHAIN"]), task("C2", ["C1"]), task("C3", ["C2"]), task("C4", ["C3"]),
             task("SELF", ["SELF"]), task("LOOP", ["CHILD"]), task("CHILD", ["LOOP"]), { "id" => "EMPTY" }]
    statuses = %w[ROOT CHAIN SELF LOOP EMPTY].map { |id| status(id) }
    assert_equal({ "ROOT" => [2, 3, 0, 0], "CHAIN" => [4, 4, 0, 0], "SELF" => [0, 0, 0, 0],
                   "LOOP" => [1, 1, 0, 0], "EMPTY" => [0, 0, 0, 0] },
                 Metrics.completion_dashboard_metrics(tasks: tasks, statuses: statuses))
  end

  # Empty inputs stay empty; only effective READY/CANDIDATE rows get metrics.
  # Missing optional unlock fields retain zero; malformed consumed fields raise.
  def test_empty_results_and_dashboard_status_selection
    assert_empty journey([], [])
    statuses = [status("R"), status("K", "CANDIDATE"), { "status" => "STALE_CANDIDATE" },
                { "status" => "ICEBOX" }, { "status" => "COMPLETE" }, { "status" => "IN_FLIGHT" }]
    assert_equal({ "R" => [0, 0, 0, 0], "K" => [0, 0, 2, 0] },
      Metrics.completion_dashboard_metrics(tasks: [], statuses: statuses, unlock_metrics: { "K" => { "unlock_count" => 2 } }))
    assert_raises(KeyError) { Metrics.completion_dashboard_metrics(tasks: [], statuses: [{}]) }
    assert_raises(KeyError) { Metrics.completion_dashboard_metrics(tasks: [], statuses: [{ "status" => "READY" }]) }
    assert_raises(NoMethodError) { Metrics.completion_dashboard_metrics(tasks: [{ "depends_on" => nil }], statuses: []) }
    assert_raises(NoMethodError) { Metrics.completion_dashboard_metrics(tasks: [], statuses: [status("R")], unlock_metrics: { "R" => nil }) }
  end

  # Immediate unlocks exclude all prepared/terminal/Icebox records, transitive
  # descendants and incomplete fan-in. Truthy empty snapshots still exclude.
  def test_final_missing_prerequisite_excludes_started_terminal_and_icebox
    excluded = %w[PREPARED IN-FLIGHT CANDIDATE complete failed blocked needs_judgment ICEBOX]
    tasks = [task("P"), task("OTHER"), task("ONE", ["P"]), task("LEVEL1", ["P"]),
             task("LEVEL2", ["LEVEL1"]), task("FANIN", %w[P OTHER])] + excluded.map { |id| task(id, ["P"]) }
    states = tasks.to_h { |item| [item.fetch("id"), {}] }
    %w[PREPARED IN-FLIGHT].each { |id| states[id] = { "snapshot" => {} } }
    %w[CANDIDATE complete failed blocked needs_judgment].each do |id|
      states[id] = { "result" => { "outcome" => id == "CANDIDATE" ? "candidate_complete" : id } }
    end
    states["ICEBOX"] = { "icebox" => nil }
    assert_equal [2, 2], journey(tasks, [status("P")], states: states).fetch("P").last(2)
    assert_equal %w[ONE LEVEL1], Metrics.immediately_unlocked_tasks(completed_id: "P", tasks: tasks, states: states).map { |item| item.fetch("id") }
    states["OTHER"] = { "result" => { "outcome" => "candidate_complete" } }
    refute_includes Metrics.immediately_unlocked_tasks(completed_id: "P", tasks: tasks, states: states).map { |item| item.fetch("id") }, "FANIN"
    states["OTHER"]["result"]["outcome"] = "complete"
    assert_equal 3, journey(tasks, [status("P")], states: states).fetch("P")[2]
  end

  # Canonical aliases conflict; different branches/remotes and read-only sets do
  # not. Main supplies resolved identities, never repository labels to compare.
  def test_exact_authority_aliases_branches_and_read_only_independence
    tasks = [task("P"), task("A", ["P"]), task("B", ["P"])]
    variants = [[{ "A" => [authority("shared")], "B" => [authority("shared")] }, 1],
                [{ "A" => [authority("shared")], "B" => [authority("shared", "release")] }, 2],
                [{ "A" => [authority("x")], "B" => [authority("y")] }, 2],
                [{ "A" => [], "B" => [authority("shared")] }, 2],
                [{ "A" => [], "B" => [] }, 2]]
    variants.each do |authorities, width|
      assert_equal [1, 2, 2, width], journey(tasks, [status("P")], authorities: authorities).fetch("P")
    end
  end

  # Effective fresh IN_FLIGHT/CANDIDATE writers occupy capacity. The hypothetical
  # candidate alone releases its reservation; other writers remain. Assertions fail.
  def test_candidate_own_reservation_exclusion_keeps_other_writers
    tasks = [task("P"), task("A", ["P"]), task("B", ["P"]), task("C", ["P"])]
    authorities = { "A" => [authority("x")], "B" => [authority("y")], "C" => [authority("z")] }
    states = tasks.to_h { |item| [item.fetch("id"), {}] }
    states["P"] = { "snapshot" => {}, "result" => { "outcome" => "candidate_complete" } }
    reservations = { "P" => [authority("z")], "IN-FLIGHT" => [authority("x")], "OTHER-CANDIDATE" => [authority("y")] }
    assert_equal [1, 3, 3, 1], journey(tasks, [status("P", "CANDIDATE")], states: states,
      reservations: reservations, authorities: authorities).fetch("P")
    assert_equal [1, 3, 3, 3], journey(tasks, [status("P", "CANDIDATE")], states: states,
      reservations: { "P" => [authority("z")] }, authorities: authorities).fetch("P")
    assert_empty Metrics.completion_dashboard_metrics(tasks: tasks, statuses: [status("P", "STALE_CANDIDATE")])
  end

  # Both READY and CANDIDATE width must beat the bridge-first greedy result of
  # one. Includes a fully conflicting set, catching over-counting as well.
  def test_exact_search_for_ready_and_candidate
    tasks = [task("P"), task("BRIDGE", ["P"]), task("LEFT", ["P"]), task("RIGHT", ["P"])]
    authorities = { "BRIDGE" => [authority("x"), authority("y")], "LEFT" => [authority("x")], "RIGHT" => [authority("y")] }
    %w[READY CANDIDATE].each do |label|
      assert_equal [1, 3, 3, 2], journey(tasks, [status("P", label)], authorities: authorities).fetch("P")
    end
    authorities["RIGHT"] = [authority("x")]
    assert_equal 1, journey(tasks, [status("P")], authorities: authorities).fetch("P")[3]
  end

  # External exclusion affects width, not unlock count, and precedes authority
  # consumption. Read-only independence is a main-supplied external decision.
  def test_external_conflicts_precede_authority_reads
    tasks = [task("P"), task("EXTERNAL", ["P"]), task("READER", ["P"]), task("FREE", ["P"])]
    blocked = { "EXTERNAL" => true, "READER" => false, "FREE" => false }
    authorities = { "READER" => [], "FREE" => [authority("free")] }
    assert_equal [1, 3, 3, 2], journey(tasks, [status("P")], blocked: blocked, authorities: authorities).fetch("P")
    blocked["READER"] = blocked["FREE"] = true
    assert_equal 0, journey(tasks, [status("P")], blocked: blocked, authorities: {}).fetch("P")[3]
  end

  # Missing consumed state/authority/external evidence refuses instead of claiming
  # empty success; malformed native task/state errors retain their classification.
  def test_missing_and_corrupt_consumed_facts_fail_closed
    tasks = [task("P"), task("A", ["P"])]
    assert_raises(KeyError) { journey(tasks, [status("P")], states: {}) }
    assert_raises(NoMethodError) { journey(tasks, [status("P")], states: { "P" => {}, "A" => nil }) }
    assert_raises(TypeError) { journey(tasks, [status("P")], states: { "P" => {}, "A" => { "result" => "bad" } }) }
    assert_raises(KeyError) { journey([task("A", ["MISSING"])], [status("MISSING")]) }
    assert_raises(KeyError) { journey(tasks, [status("P")], authorities: {}) }
    assert_raises(KeyError) { journey(tasks, [status("P")], blocked: {}) }
    [nil, "false", 0].each do |bad|
      assert_raises(ArgumentError) { journey(tasks, [status("P")], blocked: { "A" => bad }) }
    end
    [nil, "bad", [nil], [["remote"]], [["remote", nil]], [["remote", "branch", "extra"]]].each do |bad|
      assert_raises(ArgumentError) { journey(tasks, [status("P")], authorities: { "A" => bad }) }
      assert_raises(ArgumentError) { journey(tasks, [status("P")], reservations: { "OTHER" => bad }) }
    end
    assert_raises(KeyError) { Metrics.immediately_unlocked_tasks(completed_id: "P", tasks: [{}], states: {}) }
  end

  # Excluded malformed dependencies/authority facts stay unread; missing optional
  # state fields retain native truthiness. No eager global validation is added.
  def test_only_required_records_are_consumed
    tasks = [task("P"), { "id" => "EXCLUDED", "depends_on" => nil }]
    [{ "icebox" => false }, { "snapshot" => {} }, { "result" => { "outcome" => "" } }].each do |excluded|
      assert_equal [], Metrics.immediately_unlocked_tasks(completed_id: "P", tasks: tasks,
        states: { "P" => {}, "EXCLUDED" => excluded })
    end
    assert_equal [0, 0, 0, 0], journey([task("P")], [status("P")],
      reservations: { "P" => nil }, authorities: { "unused" => nil }, blocked: { "unused" => nil }).fetch("P")
    tasks = [task("P"), { "id" => "A", "depends_on" => ["P", "P"] }]
    assert_equal 1, journey(tasks, [status("P")]).fetch("P")[2]
  end

  # Deep-frozen facts survive repeated calls byte-for-byte; returned arrays are
  # detached. Mutation or an unwanted ACT import raises/asserts immediately.
  def test_repeated_calls_do_not_mutate_inputs_or_load_act
    tasks = [task("P"), task("A", ["P"])]
    statuses = [status("P", "CANDIDATE")]
    facts = { states: { "P" => {}, "A" => {} }, reservations: { "P" => [authority("x")] },
              authorities: { "A" => [authority("x")] }, blocked: { "A" => false } }
    before = Marshal.dump([tasks, statuses, facts])
    deep_freeze([tasks, statuses, facts])
    2.times { assert_equal({ "P" => [1, 1, 1, 1] }, journey(tasks, statuses, **facts)) }
    assert_equal before, Marshal.dump([tasks, statuses, facts])
    refute defined?(AgentCodingTool)
    assert_empty $LOADED_FEATURES.grep(%r{/(agent_coding_tool|act_lifecycle|act_observability)(/|\.rb)})
  end

  # The composed calculation must never open files, load dependencies or invoke
  # a process. Observes actual Ruby/C entries only during calculation; forbidden
  # calls raise immediately, without affecting the default runner's own I/O.
  def test_calculations_do_not_use_io_or_processes
    tasks = [task("P"), task("A", ["P"])]
    forbidden = %i[require require_relative load system exec spawn fork _fork daemon ` popen open
                   read binread readlines foreach write binwrite]
    observer = TracePoint.new(:call, :c_call) do |event|
      raise "calculation attempted #{event.method_id}" if forbidden.include?(event.method_id)
    end
    result = observer.enable { journey(tasks, [status("P")]) }
    assert_equal({ "P" => [1, 1, 1, 1] }, result)
  ensure
    observer&.disable
  end

  # Freezes only test-owned nested hashes/arrays and leaves; returns the value.
  # Unexpected object errors propagate and prevent a false immutability proof.
  def deep_freeze(value)
    value.each { |key, item| deep_freeze(key); deep_freeze(item) } if value.is_a?(Hash)
    value.each { |item| deep_freeze(item) } if value.is_a?(Array)
    value.freeze
  end
end

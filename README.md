# act-tasks

An independently installable Ruby package with the `ActTasks` namespace.
It supplies `ActTasks::TaskStore` YAML loading and explicit schema validation,
and `ActTasks::CompletionMetrics` calculations over transient caller facts;
policy and ACT orchestration remain in main under the authoritative
[breakup plan](https://github.com/dtnorris/agent-coding-tool-data/blob/4d297dcc6bd8574c2c103125abf453d8673aafec/plans/ab/AB-PLN-01A/plan.md).

```ruby
require "act_tasks"
ActTasks::VERSION # => "0.1.0"
ActTasks::TaskStore.new("/path/to/tasks").load("TASK-ID")
```

The gem has no runtime gem dependencies, imports no other ACT repository, and
does not read `.env`. Main ACT retains command and mode-selection authority.
`load`, filename-sorted `all` and `task_path` preserve the original main API.
`ActTasks::InvalidTask` identifies missing tasks and invalid metadata, with
unchanged messages. YAML alias refusal, parser errors, filesystem exceptions
and malformed top-level shape behavior remain native. Unrelated author metadata
is preserved. Main translates the package error to its own `InvalidTask` and
retains `CheckpointPolicy.required?`; the package validates only schema shape.
Publication, dependency pin updates and installed-ACT adoption remain operator
steps. Main owns the immutable split composition and compatibility qualification.

`CompletionMetrics.completion_dashboard_metrics(tasks:, statuses:, unlock_metrics: {})`
returns READY/CANDIDATE IDs mapped to `[downstream_depth, distinct_descendants,
immediate_unlock_count, parallel_width]`. Graph traversal tolerates cycles and
self-edges without counting the root as its own descendant. Missing `depends_on`
and missing dashboard unlock fields retain their existing empty/zero defaults.

`CompletionMetrics.immediately_unlocked_tasks(completed_id:, tasks:, states:)`
returns unstarted task records whose last missing prerequisite is `completed_id`.
The ID-keyed transient state hashes must explicitly include every consumed task
and dependency (`{}` means observed unstarted state). Icebox key presence, a
truthy snapshot or a truthy result outcome excludes a task. Only `complete`
satisfies prerequisites; `candidate_complete` does not.

`CompletionMetrics.completion_unlock_metrics(completed_id:, tasks:, states:,
reservations:, writable_authorities:, externally_blocked:)` returns String-keyed
`unlock_count` and `parallel_width` for one hypothetical READY/CANDIDATE completion.
Main supplies effective fresh IN_FLIGHT/CANDIDATE reservations as ID-to-authority
arrays, resolved writable authorities as ID-to-authority arrays, and external
conflicts as ID-to-boolean facts. Each authority is the exact `[remote_url, branch]`
pair; aliases must already be resolved by main, and read-only access contributes
no writable pair. Only the hypothetical ID's reservation is excluded. External
conflicts and other writers reduce width, while count still describes immediate
dependency unlocks. Width is the exact maximum compatible cardinality, independent
of ordering and the priority-first `next_start_set` policy retained in ACT.

These methods do no I/O, observation or live admission and never mutate inputs.
Main retains state parsing, freshness, authority resolution and their errors.
Use the separate immediate-selection step before collecting external/authority
facts: preserve main's read order and inspect authorities only for non-external
immediate unlocks. Do not eagerly read/validate excluded records. Required fact
lookups raise `KeyError`; native malformed task/state errors propagate. Consumed
authority sets and external booleans reject malformed shapes with `ArgumentError`.
Absent evidence must never be supplied as an empty authority set or `false`.
The source-bound cases, moved nodes and measured reference floors are recorded
in `test/completion_metrics_migration.json`. Package qualification and publication
remain David-owned; AB-TK-02B adopts the exact published revision/digests into ACT.

Install development dependencies with `bundle install` (separate from test
timing). Both `rake` and `bundle exec rake` run the **same entire default suite**,
with recursive `test/**/*_test.rb` discovery, genuine Minitest accounting, no
skips or selection flags, and fresh line/branch coverage of every production
file. Test-only helpers live under `test/support`; future `bin/` and `exe/`
production files join the coverage inventory. Unloaded files, unmeasured nodes,
missing/stale/corrupt results and unfinished descendants fail the gate. Coverage
hits never carry across runs. Each test file must define at least one case.

`test/coverage_floors.json` records the measured bootstrap executable nodes and
100% line/branch floors; files without branches report an empty branch inventory.
The TaskStore seed records its original source hash, numeric measured floors and
covered-node transfer in `test/task_store_migration.json`. Its new floor is 100%
for executable lines and branch arms. These schema tests run without main ACT;
main retains policy/prepare journeys and tests public split delegation separately.
Completion metrics likewise retain source-hashed method/node and assertion
transfers, with fresh measured 100% executable-line/branch floors in this package.

The initial timing contract targets David's Darwin arm64 Mac with Ruby 4.0.6
and this lockfile. The private watchdog supervises test startup through cleanup,
coverage verification and reporting. Native `proc_pid_rusage` and
`mach_absolute_time` debit Ruby/Bundler/Rake process startup from ten seconds;
0.25 seconds is reserved for process shutdown and launcher overhead. The
independent watchdog kills the parent and the test process group on exhaustion.
Unsupported clock APIs fail closed; package imports remain independent of the
test host. No environment variable changes the cap or disables coverage.

Kernel process age cannot observe time spent in a preceding shell/tool shim.
The operator must qualify the **outer launch-to-exit** time for both ordinary
commands on the named host, including those launchers, within ten seconds and
confirm the 0.25-second reserve covers their gap. A private runner measurement
alone is insufficient. Host checkpoint-gated measurements remain distinct from
focused worker checks; a new launcher/runtime/host requires requalification.
The successful final JSON reports remaining budget after temporary-file cleanup.
For an ordinary invocation, `10 - 0.25 - budget_remaining_seconds` is native
process age at that observation; compare outer elapsed time against it to
qualify the launcher/shutdown gap. Fixture deadlines are private fault controls
and do not supply host timing evidence.

Contributions follow the canonical
[coding](https://github.com/dtnorris/agent-skills/blob/8ac096dd81865ea9e30ef84c6a8127db68e159bb/skills/karpathy-manning-dtnorris-guidelines/SKILL.md)
and [planning](https://github.com/dtnorris/agent-skills/blob/8ac096dd81865ea9e30ef84c6a8127db68e159bb/skills/agentic-task-planning/SKILL.md)
guidance, subject to task-specific authority. This README describes the package
and its bootstrap developer contract; the cross-repository plan remains the
architectural authority.

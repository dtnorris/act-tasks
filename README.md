# act-tasks

An independently installable Ruby package with the `ActTasks` namespace.
It supplies `ActTasks::TaskStore` YAML loading and explicit schema validation;
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

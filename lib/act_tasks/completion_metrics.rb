# frozen_string_literal: true

module ActTasks
  # Read-only dependency and hypothetical completion calculations over transient
  # facts. ACT owns observation, canonical authority resolution and live admission.
  module CompletionMetrics
    # Returns READY/CANDIDATE IDs mapped to [depth, distinct descendants, immediate
    # unlocks, compatible width]. Tasks may omit depends_on; absent unlock metrics
    # retain the dashboard's zero defaults. Malformed consumed records raise native
    # KeyError/NoMethodError/TypeError; inputs are never modified.
    def self.completion_dashboard_metrics(tasks:, statuses:, unlock_metrics: {})
      downstream = Hash.new { |hash, id| hash[id] = [] }
      tasks.each do |task|
        task.fetch("depends_on", []).each { |dependency| downstream[dependency] << task.fetch("id") }
      end
      statuses.filter_map do |item|
        next unless %w[READY CANDIDATE].include?(item.fetch("status"))

        id = item.fetch("id")
        unlock = unlock_metrics.fetch(id, {})
        [id, [downstream_depth(id, downstream, { id => true }), downstream_count(id, downstream),
              unlock.fetch("unlock_count", 0), unlock.fetch("parallel_width", 0)]]
      end.to_h
    end

    # Returns task records whose only incomplete prerequisite is completed_id.
    # states must contain an observed Hash for each consumed task/dependency, with
    # {} explicitly meaning unstarted. Icebox key presence, snapshot truthiness and
    # any truthy outcome exclude work. Only outcome "complete" satisfies an edge.
    # Native missing/shape errors propagate; excluded records' dependencies are
    # not inspected. This separate step lets ACT defer authority/external reads.
    def self.immediately_unlocked_tasks(completed_id:, tasks:, states:)
      tasks.select do |task|
        state = states.fetch(task.fetch("id"))
        next false if state.key?("icebox") || state["snapshot"] || state.dig("result", "outcome")

        incomplete = task.fetch("depends_on", []).reject do |dependency|
          states.fetch(dependency).dig("result", "outcome") == "complete"
        end
        !incomplete.empty? && incomplete.all? { |dependency| dependency == completed_id }
      end
    end

    # Returns {unlock_count, parallel_width} with String keys for one hypothetical
    # READY/CANDIDATE completion. reservations maps effective fresh writer IDs to
    # canonical [remote, branch] pairs; main excludes stale/terminal reservations.
    # writable_authorities and externally_blocked are ID-keyed facts, required only
    # for immediate unlocks (authorities only when not externally blocked).
    # Missing facts raise KeyError; malformed authority sets/booleans raise
    # ArgumentError. Main must preserve observation failures before calling here.
    def self.completion_unlock_metrics(completed_id:, tasks:, states:, reservations:,
                                       writable_authorities:, externally_blocked:)
      reserved = reservations.reject { |id, _authorities| id == completed_id }.flat_map do |_id, authorities|
        authority_set!(authorities)
      end.uniq
      unlocked = immediately_unlocked_tasks(completed_id: completed_id, tasks: tasks, states: states)
      startable = unlocked.filter_map do |task|
        id = task.fetch("id")
        blocked = externally_blocked.fetch(id)
        raise ArgumentError, "external conflict fact must be true or false" unless blocked == true || blocked == false
        next if blocked

        authorities = authority_set!(writable_authorities.fetch(id))
        authorities unless (authorities & reserved).any?
      end
      { "unlock_count" => unlocked.length, "parallel_width" => maximum_compatible_count(startable) }
    end

    # Returns a finite longest simple downstream path, omitting IDs already in
    # path. Accepts adjacency/path hashes; malformed adjacency errors propagate.
    def self.downstream_depth(id, downstream, path)
      downstream.fetch(id, []).filter_map do |child|
        next if path[child]

        1 + downstream_depth(child, downstream, path.merge(child => true))
      end.max || 0
    end

    # Returns distinct reachable IDs excluding id, even for self/cyclic edges.
    # Accepts an adjacency hash; malformed adjacency errors propagate.
    def self.downstream_count(id, downstream)
      seen = { id => true }
      pending = downstream.fetch(id, []).dup
      until pending.empty?
        descendant = pending.shift
        next if seen[descendant]

        seen[descendant] = true
        pending.concat(downstream.fetch(descendant, []))
      end
      seen.length - 1
    end

    # Returns exact maximum cardinality over canonical authority arrays. Branch
    # and remote equality define conflicts; empty sets consume no write capacity.
    # Accepts validated sets; array operation errors propagate for invalid inputs.
    def self.maximum_compatible_count(authority_sets)
      best = 0
      search = lambda do |index, selected, count|
        return if count + authority_sets.length - index <= best

        if index == authority_sets.length
          best = count
          return
        end

        authorities = authority_sets.fetch(index)
        search.call(index + 1, selected + authorities, count + 1) if (selected & authorities).empty?
        search.call(index + 1, selected, count)
      end
      search.call(0, [], 0)
      best
    end

    # Returns supplied canonical pairs without normalization or mutation. Rejects
    # malformed consumed facts with ArgumentError rather than inventing capacity.
    def self.authority_set!(authorities)
      unless authorities.is_a?(Array) && authorities.all? { |pair|
        pair.is_a?(Array) && pair.length == 2 && pair.all? { |part| part.is_a?(String) }
      }
        raise ArgumentError, "writable authorities must be remote/branch pairs"
      end
      authorities
    end
    private_class_method :downstream_depth, :downstream_count, :maximum_compatible_count, :authority_set!
  end
end

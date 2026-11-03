# frozen_string_literal: true

module ActTasks
  # Invalid registered task metadata; filesystem and YAML exceptions stay native.
  class InvalidTask < StandardError; end
end

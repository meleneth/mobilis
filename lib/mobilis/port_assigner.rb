# frozen_string_literal: true

module Mobilis
  class PortAssigner
    include Singleton

    def initialize(starting_port_no: 10000, port_gap: 100)
      @assigned_ports = {}
      @starting_port_no = starting_port_no
      @port_gap = port_gap
      @offset = 0
    end

    def for_project(project)
      @assigned_ports[project.name] ||= next_port_number_to_assign :project
    end

    private

    def next_port_number_to_assign
      next_port_no = @starting_port_no + (@port_gap * @offset)
      @offset += 1
      next_port_no
    end
  end
end

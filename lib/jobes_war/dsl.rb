# frozen_string_literal: true

#
# JobesWar DSL entrypoint for building renderable layout trees.
# Example usage:
#
#   diagram = JobesWar.draw do
#     box "Outer", styles: [:green], label_styles: [:yellow] do
#       value "Hello World", styles: [:blue]
#       box "Inner", styles: [:red] do
#         value "Nested value"
#       end
#       tic_tac do
#         row do
#           cell "A", styles: [:blue]
#           cell "B", styles: [:green]
#         end
#       end
#     end
#   end
#   puts diagram.render
#

module JobesWar
  def self.draw(&block)
    diagram = Diagram.new
    result = block.arity.zero? ? DSL.new(diagram).instance_eval(&block) : block.call(diagram)
    diagram
  end

  class DSL
    def initialize(parent)
      @parent = parent
    end

    def box(label = nil, styles: [], label_styles: [], &block)
      node = Node::Box.new(label: label, styles: styles, label_styles: label_styles)
      @parent << node
      DSL.new(node).instance_eval(&block) if block_given?
    end

    def value(text, styles: [])
      @parent << Node::Value.new(text, styles: styles)
    end

    def tic_tac(&block)
      grid = Node::TicTac.new
      @parent << grid
      DSL.new(grid).instance_eval(&block)
    end

    def row(&block)
      row_node = []
      DSL.new(row_node).instance_eval(&block)
      @parent << row_node
    end
  end
end

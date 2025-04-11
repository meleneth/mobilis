# Diagram is the root container and rendering context for the layout tree
module JobesWar
  class Diagram < Base::Node
    attr_reader :children, :screen_width

    def initialize(screen_width: nil)
      super(parent: nil)
      @children = []
      @pastel = Pastel.new
      @screen_width = screen_width || default_terminal_width
    end

    def add(node)
      node.parent = self
      children << node
    end

    def render
      children.map(&:render).join("\n")
    end

    def available_width
      screen_width
    end

    def <<(child)
      @children << child
    end
  end
end

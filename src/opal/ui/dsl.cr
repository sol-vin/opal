require "./element"
require "./dsl_methods"

module Opal
  module UI
    # Declarative DSL builder for composing element trees.
    class Builder
      include DSL

      property root : Element?

      def initialize(@root : Element? = nil)
      end

      # Implements DSL contract
      def add_element(el : Element) : Element
        if r = @root
          if r.is_a?(VStack)
            r.add(el)
          else
            stack = VStack.new
            stack.add(r)
            stack.add(el)
            @root = stack
          end
        else
          @root = el
        end
        el
      end
    end

    # Builder for split view children
    class SplitBuilder
      getter first : Element?
      getter second : Element?

      def first(&) : Nil
        b = Builder.new
        with b yield b
        @first = b.root
      end

      def first(element : Element) : Nil
        @first = element
      end

      def second(&) : Nil
        b = Builder.new
        with b yield b
        @second = b.root
      end

      def second(element : Element) : Nil
        @second = element
      end
    end

    # Builder for stack children
    class StackBuilder
      include DSL

      getter elements : Array(Element)

      def initialize(elements : Enumerable(Element) = [] of Element)
        @elements = [] of Element
        elements.each { |e| @elements << e }
      end

      # Implements DSL contract
      def add_element(el : Element) : Element
        @elements << el
        el
      end
    end

    # Builder for table rows
    class TableBuilder
      def initialize(@table : Table)
      end

      def row(cells : Array(String)) : Nil
        @table.row(cells)
      end

      def row(*cells : String) : Nil
        @table.row(cells.to_a)
      end

      def <<(cells : Array(String)) : Nil
        @table.row(cells)
      end
    end

    # Builder for bar charts
    class BarChartBuilder
      def initialize(@chart : BarChart)
      end

      def bar(label : String, value : Float64 | Int32, color : Color | Symbol | String = :cyan, formatted : String? = nil) : Nil
        @chart.add(label, value.to_f, color, formatted)
      end

      def <<(item : NamedTuple(label: String, value: Float64 | Int32)) : Nil
        @chart.add(item[:label], item[:value].to_f)
      end
    end

    # Builder for pie charts
    class PieChartBuilder
      def initialize(@chart : PieChart)
      end

      def slice(label : String, value : Float64 | Int32, color : Color | Symbol | String = :cyan, formatted : String? = nil) : Nil
        @chart.add(label, value.to_f, color, formatted)
      end

      def <<(item : NamedTuple(label: String, value: Float64 | Int32)) : Nil
        @chart.add(item[:label], item[:value].to_f)
      end
    end

    # Builder for line graphs
    class LineGraphBuilder
      def initialize(@graph : LineGraph)
      end

      def series(name : String, data : Array(Float64), color : Color | Symbol | String = :cyan) : LineSeries
        @graph.add_series(name, data, color)
      end
    end

    # Builder for tree hierarchies
    class TreeBuilder
      def initialize(@tree : Tree)
      end

      def node(label : String, color : Color | Symbol | String = :white, icon : String? = nil, &) : TreeNode
        @tree.add(label, color, icon) { |sub_tree| with sub_tree yield sub_tree }
      end

      def node(label : String, color : Color | Symbol | String = :white, icon : String? = nil) : TreeNode
        n = TreeNode.new(label, color, icon)
        @tree.add(n)
        n
      end

      def <<(label : String) : TreeNode
        node(label)
      end
    end

    # Builds and renders an element tree to a string buffer.
    def self.render(width : Int32 = 80, height : Int32 = 24, &) : String
      builder = Builder.new
      with builder yield builder

      return "" unless root = builder.root

      w, h = root.preferred_size(width, height)
      buffer = Buffer.new(Math.max(1, w), Math.max(1, h))
      root.render(buffer, 0, 0, buffer.width, buffer.height)
      buffer.to_s
    end

    # Builds an element tree from a block.
    def self.build(&) : Element
      builder = Builder.new
      with builder yield builder
      builder.root || Text.new("")
    end

    # Creates and returns a DockContainer configured via DSL block
    def self.dock(&) : DockContainer
      dc = DockContainer.new
      with dc yield dc
      dc
    end

    # Creates and returns a GridContainer configured via DSL block
    def self.grid(
      columns : Array(GridTrack | Int32 | Float64 | String) = [GridTrack.fr(1.0)],
      rows : Array(GridTrack | Int32 | Float64 | String) = [GridTrack.fr(1.0)],
      gutter_x : Int32 = 1,
      gutter_y : Int32 = 0,
      &
    ) : GridContainer
      gc = GridContainer.new(columns: columns, rows: rows, gutter_x: gutter_x, gutter_y: gutter_y)
      with gc yield gc
      gc
    end

    # Creates a Screen with declarative root composed via Builder block
    def self.screen(name : String, title : String? = nil, &) : Screen
      root_el = build { |b| with b yield b }
      Screen.new(name: name, title: title, root: root_el)
    end

    # Creates a ModalScreen with declarative root composed via Builder block
    def self.modal_screen(name : String = "modal", title : String? = nil, &) : ModalScreen
      root_el = build { |b| with b yield b }
      ModalScreen.new(name: name, title: title, root: root_el)
    end
  end
end

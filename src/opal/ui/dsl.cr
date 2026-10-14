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

    # Builder for split view children and declarative split-pane configuration
    class SplitBuilder
      property first : Element?
      property second : Element?
      property direction_override : SplitDirection? = nil
      property ratio_override : Float64? = nil
      property first_size_override : Int32? = nil
      property second_size_override : Int32? = nil
      property min_first_size_override : Int32? = nil
      property max_first_size_override : Int32? = nil
      property separator_override : Char? = nil
      property separator_fg_override : Color? = nil
      property focused_pane_override : Symbol? = nil
      property show_separator_override : Bool? = nil

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

      # Horizontal split aliases
      def left(&) : Nil
        first { |b| with b yield b }
      end

      def left(element : Element) : Nil
        first(element)
      end

      def right(&) : Nil
        second { |b| with b yield b }
      end

      def right(element : Element) : Nil
        second(element)
      end

      # Vertical split aliases
      def top(&) : Nil
        first { |b| with b yield b }
      end

      def top(element : Element) : Nil
        first(element)
      end

      def bottom(&) : Nil
        second { |b| with b yield b }
      end

      def bottom(element : Element) : Nil
        second(element)
      end

      # Sequential pane builder: populates `first` then `second`, optionally wrapping in a bordered Box.
      def pane(
        title : String? = nil,
        border : Symbol | Border | Nil = nil,
        border_fg : Color | Symbol | String = Color.none,
        title_fg : Color | Symbol | String = :cyan,
        padding : Int32 = 0,
        bg : Color | Symbol | String = Color.none,
        &
      ) : Element?
        b = Builder.new
        with b yield b
        el = if title || border
               Box.new(
                 child: b.root,
                 border: border || :rounded,
                 border_fg: border_fg,
                 padding: padding,
                 title: title,
                 title_fg: title_fg,
                 bg: bg
               )
             else
               b.root
             end
        if @first.nil?
          @first = el
        else
          @second = el
        end
        el
      end

      def pane(element : Element) : Element
        if @first.nil?
          @first = element
        else
          @second = element
        end
        element
      end

      def direction(dir : SplitDirection | Symbol | String) : self
        @direction_override = SplitDirection.from(dir)
        self
      end

      def horizontal : self
        @direction_override = SplitDirection::Horizontal
        self
      end

      def vertical : self
        @direction_override = SplitDirection::Vertical
        self
      end

      def ratio(val : Float64) : self
        @ratio_override = val
        self
      end

      def first_size(sz : Int32) : self
        @first_size_override = sz
        self
      end

      def second_size(sz : Int32) : self
        @second_size_override = sz
        self
      end

      def min_first_size(sz : Int32) : self
        @min_first_size_override = sz
        self
      end

      def max_first_size(sz : Int32) : self
        @max_first_size_override = sz
        self
      end

      def separator(ch : Char, fg : Color | Symbol | String = Color.none) : self
        @separator_override = ch
        @separator_fg_override = Color.from(fg)
        @show_separator_override = true
        self
      end

      def hide_separator : self
        @show_separator_override = false
        self
      end

      def focus(pane : Symbol) : self
        @focused_pane_override = pane
        self
      end
    end

    class SplitView < Element
      def self.new(
        direction : SplitDirection | Symbol | String = SplitDirection::Horizontal,
        ratio : Float64? = 0.5,
        first_size : Int32? = nil,
        second_size : Int32? = nil,
        min_first_size : Int32? = nil,
        max_first_size : Int32? = nil,
        separator : Char? = nil,
        separator_fg : Color | Symbol | String = Color.none,
        focused_pane : Symbol = :first,
        show_separator : Bool = true,
        &
      ) : SplitView
        sb = SplitBuilder.new
        with sb yield sb
        new(
          first: sb.first,
          second: sb.second,
          direction: sb.direction_override || direction,
          ratio: sb.ratio_override || ratio,
          first_size: sb.first_size_override || first_size,
          second_size: sb.second_size_override || second_size,
          min_first_size: sb.min_first_size_override || min_first_size,
          max_first_size: sb.max_first_size_override || max_first_size,
          separator: sb.separator_override || separator,
          separator_fg: sb.separator_fg_override || separator_fg,
          focused_pane: sb.focused_pane_override || focused_pane,
          show_separator: sb.show_separator_override.nil? ? show_separator : sb.show_separator_override.not_nil!
        )
      end

      def self.horizontal(
        ratio : Float64? = 0.5,
        first_width : Int32? = nil,
        second_width : Int32? = nil,
        min_first_width : Int32? = nil,
        max_first_width : Int32? = nil,
        separator : Char? = nil,
        separator_fg : Color | Symbol | String = Color.none,
        focused_pane : Symbol = :first,
        show_separator : Bool = true,
        &
      ) : SplitView
        new(
          direction: SplitDirection::Horizontal,
          ratio: ratio,
          first_size: first_width,
          second_size: second_width,
          min_first_size: min_first_width,
          max_first_size: max_first_width,
          separator: separator,
          separator_fg: separator_fg,
          focused_pane: focused_pane,
          show_separator: show_separator
        ) { |sb| with sb yield sb }
      end

      def self.vertical(
        ratio : Float64? = 0.5,
        first_height : Int32? = nil,
        second_height : Int32? = nil,
        min_first_height : Int32? = nil,
        max_first_height : Int32? = nil,
        separator : Char? = nil,
        separator_fg : Color | Symbol | String = Color.none,
        focused_pane : Symbol = :first,
        show_separator : Bool = true,
        &
      ) : SplitView
        new(
          direction: SplitDirection::Vertical,
          ratio: ratio,
          first_size: first_height,
          second_size: second_height,
          min_first_size: min_first_height,
          max_first_size: max_first_height,
          separator: separator,
          separator_fg: separator_fg,
          focused_pane: focused_pane,
          show_separator: show_separator
        ) { |sb| with sb yield sb }
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
    def self.render(width : Int32 = 80, height : Int32 = 24, with_ansi : Bool = false, &) : String
      builder = Builder.new
      with builder yield builder

      return "" unless root = builder.root

      w, h = root.preferred_size(width, height)
      buffer = Buffer.new(Math.max(1, w), Math.max(1, h))
      root.render(buffer, 0, 0, buffer.width, buffer.height)
      with_ansi ? buffer.render_to_string(with_ansi: true) : buffer.to_s
    end

    # Builds and renders an element tree to an ANSI string (including colors and OSC 8 hyperlinks).
    def self.render_ansi(width : Int32 = 80, height : Int32 = 24, &) : String
      render(width, height, with_ansi: true) { |b| with b yield b }
    end

    # Builds an element tree from a block.
    def self.build(&) : Element
      builder = Builder.new
      with builder yield builder
      builder.root || Text.new("")
    end

    # Creates and returns a SplitView configured via DSL block
    def self.split_pane(
      direction : SplitDirection | Symbol | String = SplitDirection::Horizontal,
      ratio : Float64? = 0.5,
      first_size : Int32? = nil,
      second_size : Int32? = nil,
      min_first_size : Int32? = nil,
      max_first_size : Int32? = nil,
      separator : Char? = nil,
      separator_fg : Color | Symbol | String = Color.none,
      focused_pane : Symbol = :first,
      show_separator : Bool = true,
      &
    ) : SplitView
      SplitView.new(
        direction: direction,
        ratio: ratio,
        first_size: first_size,
        second_size: second_size,
        min_first_size: min_first_size,
        max_first_size: max_first_size,
        separator: separator,
        separator_fg: separator_fg,
        focused_pane: focused_pane,
        show_separator: show_separator
      ) { |sb| with sb yield sb }
    end

    # Creates and returns a horizontal SplitView configured via DSL block
    def self.hsplit(
      ratio : Float64? = 0.5,
      first_width : Int32? = nil,
      second_width : Int32? = nil,
      separator : Char? = nil,
      separator_fg : Color | Symbol | String = Color.none,
      show_separator : Bool = true,
      &
    ) : SplitView
      SplitView.horizontal(
        ratio: ratio,
        first_width: first_width,
        second_width: second_width,
        separator: separator,
        separator_fg: separator_fg,
        show_separator: show_separator
      ) { |sb| with sb yield sb }
    end

    # Creates and returns a vertical SplitView configured via DSL block
    def self.vsplit(
      ratio : Float64? = 0.5,
      first_height : Int32? = nil,
      second_height : Int32? = nil,
      separator : Char? = nil,
      separator_fg : Color | Symbol | String = Color.none,
      show_separator : Bool = true,
      &
    ) : SplitView
      SplitView.vertical(
        ratio: ratio,
        first_height: first_height,
        second_height: second_height,
        separator: separator,
        separator_fg: separator_fg,
        show_separator: show_separator
      ) { |sb| with sb yield sb }
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

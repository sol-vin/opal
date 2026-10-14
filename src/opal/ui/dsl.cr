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
      struct PaneEntry
        property element : Element?
        property id : String?
        property title : String?
        property flex : Float64?
        property fixed_size : Int32?
        property min_size : Int32?
        property max_size : Int32?
        property focusable : Bool
        property collapsed : Bool

        def initialize(
          @element : Element? = nil,
          @id : String? = nil,
          @title : String? = nil,
          @flex : Float64? = nil,
          @fixed_size : Int32? = nil,
          @min_size : Int32? = nil,
          @max_size : Int32? = nil,
          @focusable : Bool = true,
          @collapsed : Bool = false,
        )
        end
      end

      property first : Element?
      property second : Element?
      getter pane_entries : Array(PaneEntry) = [] of PaneEntry
      property first_entry : PaneEntry? = nil
      property second_entry : PaneEntry? = nil
      property direction_override : SplitDirection? = nil
      property ratio_override : Float64? = nil
      property ratios_override : Array(Float64)? = nil
      property first_size_override : Int32? = nil
      property second_size_override : Int32? = nil
      property min_first_size_override : Int32? = nil
      property max_first_size_override : Int32? = nil
      property min_second_size_override : Int32? = nil
      property max_second_size_override : Int32? = nil
      property separator_override : Char? = nil
      property separator_fg_override : Color? = nil
      property focused_pane_override : Symbol | Int32 | String | Nil = nil
      property show_separator_override : Bool? = nil
      property resize_step_override : Float64? = nil
      property highlight_focus_override : Bool? = nil
      property focus_border_fg_override : Color? = nil
      property unfocused_border_fg_override : Color? = nil

      def first(
        id : String? = nil,
        title : String? = nil,
        flex : Float64? = nil,
        size : Int32? = nil,
        min_size : Int32? = nil,
        max_size : Int32? = nil,
        focusable : Bool = true,
        collapsed : Bool = false,
        border : Symbol | Border | Nil = nil,
        border_fg : Color | Symbol | String = Color.none,
        title_fg : Color | Symbol | String = :cyan,
        padding : Int32 = 0,
        bg : Color | Symbol | String = Color.none,
        &
      ) : Nil
        b = Builder.new
        with b yield b
        el = wrap_pane_element(b.root, title, border, border_fg, title_fg, padding, bg)
        @first = el
        @first_entry = PaneEntry.new(el, id, title, flex, size, min_size, max_size, focusable, collapsed)
      end

      def first(
        element : Element,
        id : String? = nil,
        title : String? = nil,
        flex : Float64? = nil,
        size : Int32? = nil,
        min_size : Int32? = nil,
        max_size : Int32? = nil,
        focusable : Bool = true,
        collapsed : Bool = false,
      ) : Nil
        @first = element
        @first_entry = PaneEntry.new(element, id, title, flex, size, min_size, max_size, focusable, collapsed)
      end

      def second(
        id : String? = nil,
        title : String? = nil,
        flex : Float64? = nil,
        size : Int32? = nil,
        min_size : Int32? = nil,
        max_size : Int32? = nil,
        focusable : Bool = true,
        collapsed : Bool = false,
        border : Symbol | Border | Nil = nil,
        border_fg : Color | Symbol | String = Color.none,
        title_fg : Color | Symbol | String = :cyan,
        padding : Int32 = 0,
        bg : Color | Symbol | String = Color.none,
        &
      ) : Nil
        b = Builder.new
        with b yield b
        el = wrap_pane_element(b.root, title, border, border_fg, title_fg, padding, bg)
        @second = el
        @second_entry = PaneEntry.new(el, id, title, flex, size, min_size, max_size, focusable, collapsed)
      end

      def second(
        element : Element,
        id : String? = nil,
        title : String? = nil,
        flex : Float64? = nil,
        size : Int32? = nil,
        min_size : Int32? = nil,
        max_size : Int32? = nil,
        focusable : Bool = true,
        collapsed : Bool = false,
      ) : Nil
        @second = element
        @second_entry = PaneEntry.new(element, id, title, flex, size, min_size, max_size, focusable, collapsed)
      end

      # Horizontal split aliases
      def left(
        id : String? = nil,
        title : String? = nil,
        flex : Float64? = nil,
        size : Int32? = nil,
        min_size : Int32? = nil,
        max_size : Int32? = nil,
        focusable : Bool = true,
        collapsed : Bool = false,
        border : Symbol | Border | Nil = nil,
        border_fg : Color | Symbol | String = Color.none,
        title_fg : Color | Symbol | String = :cyan,
        padding : Int32 = 0,
        bg : Color | Symbol | String = Color.none,
        &
      ) : Nil
        first(
          id: id,
          title: title,
          flex: flex,
          size: size,
          min_size: min_size,
          max_size: max_size,
          focusable: focusable,
          collapsed: collapsed,
          border: border,
          border_fg: border_fg,
          title_fg: title_fg,
          padding: padding,
          bg: bg
        ) { |b| with b yield b }
      end

      def left(
        element : Element,
        id : String? = nil,
        title : String? = nil,
        flex : Float64? = nil,
        size : Int32? = nil,
        min_size : Int32? = nil,
        max_size : Int32? = nil,
        focusable : Bool = true,
        collapsed : Bool = false,
      ) : Nil
        first(element, id: id, title: title, flex: flex, size: size, min_size: min_size, max_size: max_size, focusable: focusable, collapsed: collapsed)
      end

      def right(
        id : String? = nil,
        title : String? = nil,
        flex : Float64? = nil,
        size : Int32? = nil,
        min_size : Int32? = nil,
        max_size : Int32? = nil,
        focusable : Bool = true,
        collapsed : Bool = false,
        border : Symbol | Border | Nil = nil,
        border_fg : Color | Symbol | String = Color.none,
        title_fg : Color | Symbol | String = :cyan,
        padding : Int32 = 0,
        bg : Color | Symbol | String = Color.none,
        &
      ) : Nil
        second(
          id: id,
          title: title,
          flex: flex,
          size: size,
          min_size: min_size,
          max_size: max_size,
          focusable: focusable,
          collapsed: collapsed,
          border: border,
          border_fg: border_fg,
          title_fg: title_fg,
          padding: padding,
          bg: bg
        ) { |b| with b yield b }
      end

      def right(
        element : Element,
        id : String? = nil,
        title : String? = nil,
        flex : Float64? = nil,
        size : Int32? = nil,
        min_size : Int32? = nil,
        max_size : Int32? = nil,
        focusable : Bool = true,
        collapsed : Bool = false,
      ) : Nil
        second(element, id: id, title: title, flex: flex, size: size, min_size: min_size, max_size: max_size, focusable: focusable, collapsed: collapsed)
      end

      # Vertical split aliases
      def top(
        id : String? = nil,
        title : String? = nil,
        flex : Float64? = nil,
        size : Int32? = nil,
        min_size : Int32? = nil,
        max_size : Int32? = nil,
        focusable : Bool = true,
        collapsed : Bool = false,
        border : Symbol | Border | Nil = nil,
        border_fg : Color | Symbol | String = Color.none,
        title_fg : Color | Symbol | String = :cyan,
        padding : Int32 = 0,
        bg : Color | Symbol | String = Color.none,
        &
      ) : Nil
        first(
          id: id,
          title: title,
          flex: flex,
          size: size,
          min_size: min_size,
          max_size: max_size,
          focusable: focusable,
          collapsed: collapsed,
          border: border,
          border_fg: border_fg,
          title_fg: title_fg,
          padding: padding,
          bg: bg
        ) { |b| with b yield b }
      end

      def top(
        element : Element,
        id : String? = nil,
        title : String? = nil,
        flex : Float64? = nil,
        size : Int32? = nil,
        min_size : Int32? = nil,
        max_size : Int32? = nil,
        focusable : Bool = true,
        collapsed : Bool = false,
      ) : Nil
        first(element, id: id, title: title, flex: flex, size: size, min_size: min_size, max_size: max_size, focusable: focusable, collapsed: collapsed)
      end

      def bottom(
        id : String? = nil,
        title : String? = nil,
        flex : Float64? = nil,
        size : Int32? = nil,
        min_size : Int32? = nil,
        max_size : Int32? = nil,
        focusable : Bool = true,
        collapsed : Bool = false,
        border : Symbol | Border | Nil = nil,
        border_fg : Color | Symbol | String = Color.none,
        title_fg : Color | Symbol | String = :cyan,
        padding : Int32 = 0,
        bg : Color | Symbol | String = Color.none,
        &
      ) : Nil
        second(
          id: id,
          title: title,
          flex: flex,
          size: size,
          min_size: min_size,
          max_size: max_size,
          focusable: focusable,
          collapsed: collapsed,
          border: border,
          border_fg: border_fg,
          title_fg: title_fg,
          padding: padding,
          bg: bg
        ) { |b| with b yield b }
      end

      def bottom(
        element : Element,
        id : String? = nil,
        title : String? = nil,
        flex : Float64? = nil,
        size : Int32? = nil,
        min_size : Int32? = nil,
        max_size : Int32? = nil,
        focusable : Bool = true,
        collapsed : Bool = false,
      ) : Nil
        second(element, id: id, title: title, flex: flex, size: size, min_size: min_size, max_size: max_size, focusable: focusable, collapsed: collapsed)
      end

      # Sequential pane builder: appends a pane with optional flex weight, min/max bounds, ID, and bordered Box wrapper.
      def pane(
        title : String? = nil,
        id : String? = nil,
        flex : Float64? = nil,
        ratio : Float64? = nil,
        size : Int32? = nil,
        fixed_size : Int32? = nil,
        min_size : Int32? = nil,
        max_size : Int32? = nil,
        focusable : Bool = true,
        collapsed : Bool = false,
        border : Symbol | Border | Nil = nil,
        border_fg : Color | Symbol | String = Color.none,
        title_fg : Color | Symbol | String = :cyan,
        padding : Int32 = 0,
        bg : Color | Symbol | String = Color.none,
        &
      ) : Element?
        b = Builder.new
        with b yield b
        el = wrap_pane_element(b.root, title, border, border_fg, title_fg, padding, bg)
        register_pane_entry(
          element: el,
          id: id,
          title: title,
          flex: flex || ratio,
          fixed_size: fixed_size || size,
          min_size: min_size,
          max_size: max_size,
          focusable: focusable,
          collapsed: collapsed
        )
        el
      end

      def pane(
        element : Element,
        title : String? = nil,
        id : String? = nil,
        flex : Float64? = nil,
        ratio : Float64? = nil,
        size : Int32? = nil,
        fixed_size : Int32? = nil,
        min_size : Int32? = nil,
        max_size : Int32? = nil,
        focusable : Bool = true,
        collapsed : Bool = false,
      ) : Element
        register_pane_entry(
          element: element,
          id: id,
          title: title,
          flex: flex || ratio,
          fixed_size: fixed_size || size,
          min_size: min_size,
          max_size: max_size,
          focusable: focusable,
          collapsed: collapsed
        )
        element
      end

      def direction(dir : SplitDirection | Core::SplitOrientation | Symbol | String) : self
        @direction_override = SplitDirection.from(dir)
        self
      end

      def orientation(dir : SplitDirection | Core::SplitOrientation | Symbol | String) : self
        direction(dir)
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

      def ratios(weights : Array(Float64)) : self
        @ratios_override = weights
        self
      end

      def ratios(*weights : Float64) : self
        @ratios_override = weights.to_a
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

      def min_second_size(sz : Int32) : self
        @min_second_size_override = sz
        self
      end

      def max_second_size(sz : Int32) : self
        @max_second_size_override = sz
        self
      end

      def resize_step(step : Float64) : self
        @resize_step_override = step
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

      def focus(pane : Symbol | Int32 | String) : self
        @focused_pane_override = pane
        self
      end

      def highlight_focus(
        enabled : Bool = true,
        focus_fg : Color | Symbol | String | Nil = nil,
        unfocused_fg : Color | Symbol | String | Nil = nil,
      ) : self
        @highlight_focus_override = enabled
        @focus_border_fg_override = Color.from(focus_fg) if focus_fg
        @unfocused_border_fg_override = Color.from(unfocused_fg) if unfocused_fg
        self
      end

      def build_split_view(
        direction : SplitDirection | Core::SplitOrientation | Symbol | String = SplitDirection::Horizontal,
        ratio : Float64? = 0.5,
        first_size : Int32? = nil,
        second_size : Int32? = nil,
        min_first_size : Int32? = nil,
        max_first_size : Int32? = nil,
        min_second_size : Int32? = nil,
        max_second_size : Int32? = nil,
        separator : Char? = nil,
        separator_fg : Color | Symbol | String = Color.none,
        focused_pane : Symbol | Int32 | String = :first,
        show_separator : Bool = true,
        resize_step : Float64 = 0.05,
      ) : SplitView
        eff_dir = @direction_override || SplitDirection.from(direction)
        eff_ratio = @ratio_override || ratio
        eff_first_size = @first_size_override || first_size
        eff_second_size = @second_size_override || second_size
        eff_min_first = @min_first_size_override || min_first_size
        eff_max_first = @max_first_size_override || max_first_size
        eff_min_second = @min_second_size_override || min_second_size
        eff_max_second = @max_second_size_override || max_second_size
        eff_sep = @separator_override || separator
        eff_sep_fg = @separator_fg_override || separator_fg
        eff_focus = @focused_pane_override || focused_pane
        eff_show_sep = @show_separator_override.nil? ? show_separator : @show_separator_override.not_nil!
        eff_step = @resize_step_override || resize_step

        entries = if !@pane_entries.empty?
                    @pane_entries
                  else
                    e1 = @first_entry || PaneEntry.new(@first)
                    e2 = @second_entry || PaneEntry.new(@second)
                    [e1, e2]
                  end

        elements = entries.map(&.element)
        constraints = [] of Core::PaneConstraint
        r_pair = (eff_ratio || 0.5).clamp(0.0, 1.0)
        use_pair_ratio = (entries.size == 2) && entries.all? { |e| e.flex.nil? } && @ratios_override.nil?

        entries.each_with_index do |entry, idx|
          default_id = case idx
                       when 0 then "first"
                       when 1 then "second"
                       else        "pane_#{idx}"
                       end
          flex_val = if ro = @ratios_override
                       ro[idx]? || 1.0
                     elsif ef = entry.flex
                       ef
                     elsif use_pair_ratio
                       idx == 0 ? r_pair : (1.0 - r_pair)
                     else
                       1.0
                     end

          f_size = entry.fixed_size
          f_size ||= eff_first_size if idx == 0
          f_size ||= eff_second_size if idx == 1

          min_s = entry.min_size
          min_s ||= eff_min_first if idx == 0
          min_s ||= eff_min_second if idx == 1

          max_s = entry.max_size
          max_s ||= eff_max_first if idx == 0
          max_s ||= eff_max_second if idx == 1

          constraints << Core::PaneConstraint.new(
            id: entry.id || default_id,
            title: entry.title,
            flex: flex_val,
            fixed_size: f_size,
            min_size: min_s || 0,
            max_size: max_s,
            focusable: entry.focusable,
            collapsed: entry.collapsed
          )
        end

        SplitView.new(
          first: elements[0]?,
          second: elements[1]?,
          direction: eff_dir,
          ratio: eff_ratio,
          first_size: eff_first_size,
          second_size: eff_second_size,
          min_first_size: eff_min_first,
          max_first_size: eff_max_first,
          min_second_size: eff_min_second,
          max_second_size: eff_max_second,
          separator: eff_sep,
          separator_fg: eff_sep_fg,
          focused_pane: eff_focus,
          show_separator: eff_show_sep,
          resize_step: eff_step,
          focus_border_fg: @focus_border_fg_override,
          unfocused_border_fg: @unfocused_border_fg_override,
          highlight_focus: @highlight_focus_override || false,
          panes: elements,
          constraints: constraints
        )
      end

      private def wrap_pane_element(
        root : Element?,
        title : String?,
        border : Symbol | Border | Nil,
        border_fg : Color | Symbol | String,
        title_fg : Color | Symbol | String,
        padding : Int32,
        bg : Color | Symbol | String,
      ) : Element?
        if title || border
          Box.new(
            child: root,
            border: border || :rounded,
            border_fg: border_fg,
            padding: padding,
            title: title,
            title_fg: title_fg,
            bg: bg
          )
        else
          root
        end
      end

      private def register_pane_entry(
        element : Element?,
        id : String?,
        title : String?,
        flex : Float64?,
        fixed_size : Int32?,
        min_size : Int32?,
        max_size : Int32?,
        focusable : Bool,
        collapsed : Bool,
      ) : Nil
        entry = PaneEntry.new(
          element: element,
          id: id,
          title: title,
          flex: flex,
          fixed_size: fixed_size,
          min_size: min_size,
          max_size: max_size,
          focusable: focusable,
          collapsed: collapsed
        )
        @pane_entries << entry
        if @pane_entries.size == 1
          @first = element
          @first_entry = entry
        elsif @pane_entries.size == 2
          @second = element
          @second_entry = entry
        end
      end
    end

    class SplitView < Control
      def self.new(
        direction : SplitDirection | Core::SplitOrientation | Symbol | String = SplitDirection::Horizontal,
        ratio : Float64? = 0.5,
        first_size : Int32? = nil,
        second_size : Int32? = nil,
        min_first_size : Int32? = nil,
        max_first_size : Int32? = nil,
        min_second_size : Int32? = nil,
        max_second_size : Int32? = nil,
        separator : Char? = nil,
        separator_fg : Color | Symbol | String = Color.none,
        focused_pane : Symbol | Int32 | String = :first,
        show_separator : Bool = true,
        resize_step : Float64 = 0.05,
        &
      ) : SplitView
        sb = SplitBuilder.new
        with sb yield sb
        sb.build_split_view(
          direction: direction,
          ratio: ratio,
          first_size: first_size,
          second_size: second_size,
          min_first_size: min_first_size,
          max_first_size: max_first_size,
          min_second_size: min_second_size,
          max_second_size: max_second_size,
          separator: separator,
          separator_fg: separator_fg,
          focused_pane: focused_pane,
          show_separator: show_separator,
          resize_step: resize_step
        )
      end

      def self.horizontal(
        ratio : Float64? = 0.5,
        first_width : Int32? = nil,
        second_width : Int32? = nil,
        min_first_width : Int32? = nil,
        max_first_width : Int32? = nil,
        min_second_width : Int32? = nil,
        max_second_width : Int32? = nil,
        separator : Char? = nil,
        separator_fg : Color | Symbol | String = Color.none,
        focused_pane : Symbol | Int32 | String = :first,
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
          min_second_size: min_second_width,
          max_second_size: max_second_width,
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
        min_second_height : Int32? = nil,
        max_second_height : Int32? = nil,
        separator : Char? = nil,
        separator_fg : Color | Symbol | String = Color.none,
        focused_pane : Symbol | Int32 | String = :first,
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
          min_second_size: min_second_height,
          max_second_size: max_second_height,
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
      direction : SplitDirection | Core::SplitOrientation | Symbol | String = SplitDirection::Horizontal,
      ratio : Float64? = 0.5,
      first_size : Int32? = nil,
      second_size : Int32? = nil,
      min_first_size : Int32? = nil,
      max_first_size : Int32? = nil,
      min_second_size : Int32? = nil,
      max_second_size : Int32? = nil,
      separator : Char? = nil,
      separator_fg : Color | Symbol | String = Color.none,
      focused_pane : Symbol | Int32 | String = :first,
      show_separator : Bool = true,
      resize_step : Float64 = 0.05,
      &
    ) : SplitView
      SplitView.new(
        direction: direction,
        ratio: ratio,
        first_size: first_size,
        second_size: second_size,
        min_first_size: min_first_size,
        max_first_size: max_first_size,
        min_second_size: min_second_size,
        max_second_size: max_second_size,
        separator: separator,
        separator_fg: separator_fg,
        focused_pane: focused_pane,
        show_separator: show_separator,
        resize_step: resize_step
      ) { |sb| with sb yield sb }
    end

    # Creates and returns a horizontal SplitView configured via DSL block
    def self.hsplit(
      ratio : Float64? = 0.5,
      first_width : Int32? = nil,
      second_width : Int32? = nil,
      min_first_width : Int32? = nil,
      max_first_width : Int32? = nil,
      min_second_width : Int32? = nil,
      max_second_width : Int32? = nil,
      separator : Char? = nil,
      separator_fg : Color | Symbol | String = Color.none,
      focused_pane : Symbol | Int32 | String = :first,
      show_separator : Bool = true,
      &
    ) : SplitView
      SplitView.horizontal(
        ratio: ratio,
        first_width: first_width,
        second_width: second_width,
        min_first_width: min_first_width,
        max_first_width: max_first_width,
        min_second_width: min_second_width,
        max_second_width: max_second_width,
        separator: separator,
        separator_fg: separator_fg,
        focused_pane: focused_pane,
        show_separator: show_separator
      ) { |sb| with sb yield sb }
    end

    # Creates and returns a vertical SplitView configured via DSL block
    def self.vsplit(
      ratio : Float64? = 0.5,
      first_height : Int32? = nil,
      second_height : Int32? = nil,
      min_first_height : Int32? = nil,
      max_first_height : Int32? = nil,
      min_second_height : Int32? = nil,
      max_second_height : Int32? = nil,
      separator : Char? = nil,
      separator_fg : Color | Symbol | String = Color.none,
      focused_pane : Symbol | Int32 | String = :first,
      show_separator : Bool = true,
      &
    ) : SplitView
      SplitView.vertical(
        ratio: ratio,
        first_height: first_height,
        second_height: second_height,
        min_first_height: min_first_height,
        max_first_height: max_first_height,
        min_second_height: min_second_height,
        max_second_height: max_second_height,
        separator: separator,
        separator_fg: separator_fg,
        focused_pane: focused_pane,
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

require "./element"
require "./components/text"
require "./components/badge"
require "./components/rule"
require "./components/stack"
require "./components/box"
require "./components/table"
require "./components/viewport"
require "./components/sparkline"
require "./components/barchart"
require "./components/gauge"
require "./components/tree"
require "./components/modal"
require "./components/toast"
require "./components/filter_list"
require "./markdown/renderer"
require "./components/command_palette"

module Opal
  module UI
    # Declarative DSL builder for composing element trees.
    class Builder
      getter root : Element?

      def text(
        content : String,
        fg : Color | Symbol | String = Color.none,
        bg : Color | Symbol | String = Color.none,
        bold : Bool = false,
        dim : Bool = false,
        italic : Bool = false,
        underline : Bool = false,
      ) : Text
        el = Text.new(content, fg: fg, bg: bg, bold: bold, dim: dim, italic: italic, underline: underline)
        set_root_or_child(el)
        el
      end

      def badge(
        label : String,
        bg : Color | Symbol | String = :blue,
        fg : Color | Symbol | String = :white,
        bold : Bool = true,
      ) : Badge
        el = Badge.new(label, bg: bg, fg: fg, bold: bold)
        set_root_or_child(el)
        el
      end

      def rule(char : Char = '─', fg : Color | Symbol | String = Color.none) : Rule
        el = Rule.new(char: char, fg: fg)
        set_root_or_child(el)
        el
      end

      def box(
        border : Symbol | Border = :rounded,
        border_fg : Color | Symbol | String = Color.none,
        padding : Int32 = 0,
        title : String? = nil,
        title_fg : Color | Symbol | String = :cyan,
        &block : Builder -> Nil
      ) : Box
        sub_builder = Builder.new
        block.call(sub_builder)
        el = Box.new(
          child: sub_builder.root,
          border: border,
          border_fg: border_fg,
          padding: padding,
          title: title,
          title_fg: title_fg
        )
        set_root_or_child(el)
        el
      end

      def vstack(spacing : Int32 = 0, &block : StackBuilder -> Nil) : VStack
        sb = StackBuilder.new
        block.call(sb)
        stack = VStack.new(spacing: spacing)
        sb.elements.each { |e| stack.add(e) }
        set_root_or_child(stack)
        stack
      end

      def hstack(spacing : Int32 = 0, &block : StackBuilder -> Nil) : HStack
        sb = StackBuilder.new
        block.call(sb)
        stack = HStack.new(spacing: spacing)
        sb.elements.each { |e| stack.add(e) }
        set_root_or_child(stack)
        stack
      end

      def table(
        headers : Array(String) = [] of String,
        header_fg : Color | Symbol | String = :cyan,
        border_fg : Color | Symbol | String = Color.none,
        &block : TableBuilder -> Nil
      ) : Table
        tbl = Table.new(headers: headers, header_fg: header_fg, border_fg: border_fg)
        tb = TableBuilder.new(tbl)
        block.call(tb)
        set_root_or_child(tbl)
        tbl
      end

      def viewport(
        content : String,
        offset_y : Int32 = 0,
        fg : Color | Symbol | String = Color.none,
        show_scrollbar : Bool = true,
      ) : Viewport
        el = Viewport.new(content: content, offset_y: offset_y, fg: fg, show_scrollbar: show_scrollbar)
        set_root_or_child(el)
        el
      end

      def sparkline(
        data : Array(Float64),
        color : Color | Symbol | String = :cyan,
        title : String? = nil,
        min : Float64? = nil,
        max : Float64? = nil,
      ) : Sparkline
        el = Sparkline.new(data: data, color: color, title: title, min: min, max: max)
        set_root_or_child(el)
        el
      end

      def barchart(
        title : String? = nil,
        bar_char : Char = '█',
        max_value : Float64? = nil,
        &block : BarChartBuilder -> Nil
      ) : BarChart
        chart = BarChart.new(title: title, bar_char: bar_char, max_value: max_value)
        bb = BarChartBuilder.new(chart)
        block.call(bb)
        set_root_or_child(chart)
        chart
      end

      def gauge(
        ratio : Float64,
        label : String? = nil,
        color : Color | Symbol | String | Nil = nil,
        filled_char : Char = '█',
        empty_char : Char = '░',
      ) : Gauge
        el = Gauge.new(ratio: ratio, label: label, color: color, filled_char: filled_char, empty_char: empty_char)
        set_root_or_child(el)
        el
      end

      def tree(title : String? = nil, &block : TreeBuilder -> Nil) : Tree
        tr = Tree.new(title: title)
        tb = TreeBuilder.new(tr)
        block.call(tb)
        set_root_or_child(tr)
        tr
      end

      def modal(
        title : String,
        message : String,
        buttons : Array(String) = ["OK"],
        selected_button : Int32 = 0,
        border_fg : Color | Symbol | String = :cyan,
        title_fg : Color | Symbol | String = :bright_white,
        button_fg : Color | Symbol | String = :white,
        selected_fg : Color | Symbol | String = :black,
        selected_bg : Color | Symbol | String = :cyan,
        dim_backdrop : Bool = true,
      ) : Modal
        el = Modal.new(
          title: title,
          message: message,
          buttons: buttons,
          selected_button: selected_button,
          border_fg: border_fg,
          title_fg: title_fg,
          button_fg: button_fg,
          selected_fg: selected_fg,
          selected_bg: selected_bg,
          dim_backdrop: dim_backdrop
        )
        set_root_or_child(el)
        el
      end

      def markdown(content : String, width : Int32 = 80) : MarkdownElement
        el = MarkdownElement.new(content, width)
        set_root_or_child(el)
        el
      end

      private def set_root_or_child(el : Element) : Nil
        @root ||= el
      end
    end

    # Builder for stack children
    class StackBuilder
      getter elements : Array(Element) = [] of Element

      def add(el : Element) : Nil
        @elements << el
      end

      def text(
        content : String,
        fg : Color | Symbol | String = Color.none,
        bg : Color | Symbol | String = Color.none,
        bold : Bool = false,
        dim : Bool = false,
        italic : Bool = false,
        underline : Bool = false,
      ) : Text
        el = Text.new(content, fg: fg, bg: bg, bold: bold, dim: dim, italic: italic, underline: underline)
        add(el)
        el
      end

      def badge(
        label : String,
        bg : Color | Symbol | String = :blue,
        fg : Color | Symbol | String = :white,
        bold : Bool = true,
      ) : Badge
        el = Badge.new(label, bg: bg, fg: fg, bold: bold)
        add(el)
        el
      end

      def rule(char : Char = '─', fg : Color | Symbol | String = Color.none) : Rule
        el = Rule.new(char: char, fg: fg)
        add(el)
        el
      end

      def box(
        border : Symbol | Border = :rounded,
        border_fg : Color | Symbol | String = Color.none,
        padding : Int32 = 0,
        title : String? = nil,
        title_fg : Color | Symbol | String = :cyan,
        &block : Builder -> Nil
      ) : Box
        b = Builder.new
        block.call(b)
        el = Box.new(
          child: b.root,
          border: border,
          border_fg: border_fg,
          padding: padding,
          title: title,
          title_fg: title_fg
        )
        add(el)
        el
      end

      def vstack(spacing : Int32 = 0, &block : StackBuilder -> Nil) : VStack
        sb = StackBuilder.new
        block.call(sb)
        stack = VStack.new(spacing: spacing)
        sb.elements.each { |e| stack.add(e) }
        add(stack)
        stack
      end

      def hstack(spacing : Int32 = 0, &block : StackBuilder -> Nil) : HStack
        sb = StackBuilder.new
        block.call(sb)
        stack = HStack.new(spacing: spacing)
        sb.elements.each { |e| stack.add(e) }
        add(stack)
        stack
      end

      def table(
        headers : Array(String) = [] of String,
        header_fg : Color | Symbol | String = :cyan,
        border_fg : Color | Symbol | String = Color.none,
        &block : TableBuilder -> Nil
      ) : Table
        tbl = Table.new(headers: headers, header_fg: header_fg, border_fg: border_fg)
        tb = TableBuilder.new(tbl)
        block.call(tb)
        add(tbl)
        tbl
      end

      def sparkline(
        data : Array(Float64),
        color : Color | Symbol | String = :cyan,
        title : String? = nil,
        min : Float64? = nil,
        max : Float64? = nil,
      ) : Sparkline
        el = Sparkline.new(data: data, color: color, title: title, min: min, max: max)
        add(el)
        el
      end

      def barchart(
        title : String? = nil,
        bar_char : Char = '█',
        max_value : Float64? = nil,
        &block : BarChartBuilder -> Nil
      ) : BarChart
        chart = BarChart.new(title: title, bar_char: bar_char, max_value: max_value)
        bb = BarChartBuilder.new(chart)
        block.call(bb)
        add(chart)
        chart
      end

      def gauge(
        ratio : Float64,
        label : String? = nil,
        color : Color | Symbol | String | Nil = nil,
        filled_char : Char = '█',
        empty_char : Char = '░',
      ) : Gauge
        el = Gauge.new(ratio: ratio, label: label, color: color, filled_char: filled_char, empty_char: empty_char)
        add(el)
        el
      end

      def tree(title : String? = nil, &block : TreeBuilder -> Nil) : Tree
        tr = Tree.new(title: title)
        tb = TreeBuilder.new(tr)
        block.call(tb)
        add(tr)
        tr
      end

      def markdown(content : String, width : Int32 = 80) : MarkdownElement
        el = MarkdownElement.new(content, width)
        add(el)
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
    end

    # Builder for bar charts
    class BarChartBuilder
      def initialize(@chart : BarChart)
      end

      def bar(label : String, value : Float64 | Int32, color : Color | Symbol | String = :cyan, formatted : String? = nil) : Nil
        @chart.add(label, value.to_f, color, formatted)
      end
    end

    # Builder for tree hierarchies
    class TreeBuilder
      def initialize(@tree : Tree)
      end

      def node(label : String, color : Color | Symbol | String = :white, icon : String? = nil, &block : TreeNode -> Nil) : TreeNode
        @tree.add(label, color, icon, &block)
      end

      def node(label : String, color : Color | Symbol | String = :white, icon : String? = nil) : TreeNode
        n = TreeNode.new(label, color, icon)
        @tree.add(n)
        n
      end
    end

    # Builds and renders an element tree to a string buffer.
    def self.render(width : Int32 = 80, height : Int32 = 24, &block : Builder -> Nil) : String
      builder = Builder.new
      block.call(builder)

      return "" unless root = builder.root

      w, h = root.preferred_size(width, height)
      buffer = Buffer.new(Math.max(1, w), Math.max(1, h))
      root.render(buffer, 0, 0, buffer.width, buffer.height)
      buffer.to_s
    end

    # Builds an element tree from a block.
    def self.build(&block : Builder -> Nil) : Element
      builder = Builder.new
      block.call(builder)
      builder.root || Text.new("")
    end
  end
end

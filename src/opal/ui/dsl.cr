require "./element"
require "./components/text"
require "./components/badge"
require "./components/rule"
require "./components/stack"
require "./components/box"
require "./components/table"
require "./components/viewport"

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
    end

    # Builder for table rows
    class TableBuilder
      def initialize(@table : Table)
      end

      def row(cells : Array(String)) : Nil
        @table.row(cells)
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

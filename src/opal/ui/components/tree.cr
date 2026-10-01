require "../control"
require "../buffer"
require "../../style/color"
require "../../style/visual_width"

module Opal
  module UI
    # Node in a hierarchical tree view.
    class TreeNode
      getter label : String
      getter children : Array(TreeNode) = [] of TreeNode
      getter color : Color
      getter icon : String?
      property? expanded : Bool = true

      def initialize(
        @label : String,
        color : Color | Symbol | String = :white,
        @icon : String? = nil,
        @expanded : Bool = true,
      )
        @color = Color.from(color)
      end

      def toggle_expand : Nil
        @expanded = !@expanded
      end

      def add(child : TreeNode) : TreeNode
        @children << child
        child
      end

      def add(label : String, color : Color | Symbol | String = :white, icon : String? = nil) : TreeNode
        child = TreeNode.new(label, color, icon)
        @children << child
        child
      end

      def add(label : String, color : Color | Symbol | String = :white, icon : String? = nil, &block : TreeNode -> Nil) : TreeNode
        child = TreeNode.new(label, color, icon)
        @children << child
        block.call(child)
        child
      end
    end

    # Renders an interactive hierarchical tree with branch connectors,
    # expand/collapse support, keyboard navigation, and mouse selection.
    class Tree < Control
      getter root_nodes : Array(TreeNode)
      getter title : String?
      property selected_node : TreeNode? = nil
      property on_select : Proc(TreeNode, Nil)? = nil
      property on_toggle : Proc(TreeNode, Nil)? = nil

      @visible_rows : Array(NamedTuple(node: TreeNode, y: Int32, x: Int32, w: Int32)) = [] of NamedTuple(node: TreeNode, y: Int32, x: Int32, w: Int32)

      def initialize(
        @root_nodes : Array(TreeNode) = [] of TreeNode,
        @title : String? = nil,
        @selected_node : TreeNode? = nil,
      )
        super()
      end

      def add(node : TreeNode) : TreeNode
        @root_nodes << node
        node
      end

      def add(label : String, color : Color | Symbol | String = :white, icon : String? = nil) : TreeNode
        node = TreeNode.new(label, color, icon)
        add(node)
        node
      end

      def add(label : String, color : Color | Symbol | String = :white, icon : String? = nil, &block : TreeNode -> Nil) : TreeNode
        node = TreeNode.new(label, color, icon)
        @root_nodes << node
        block.call(node)
        node
      end

      private def count_visible_lines(node : TreeNode) : Int32
        1 + (node.expanded? ? node.children.sum { |c| count_visible_lines(c) } : 0)
      end

      def preferred_size(available_w : Int32, available_h : Int32) : {Int32, Int32}
        total_lines = @root_nodes.sum { |n| count_visible_lines(n) } + (@title ? 2 : 0)
        {available_w, [total_lines, available_h].min}
      end

      def render(buffer : Buffer, x : Int32, y : Int32, width : Int32, height : Int32) : Nil
        return if @root_nodes.empty?
        @visible_rows.clear

        cur_y = y
        if t = @title
          buffer.put_string(x, cur_y, t, fg: Color.cyan, bold: true, max_width: width)
          cur_y += 1
          buffer.put_string(x, cur_y, "─" * Math.min(width, VisualWidth.width(t) + 4), fg: Color.bright_black)
          cur_y += 1
        end

        @root_nodes.each_with_index do |node, idx|
          is_last = (idx == @root_nodes.size - 1)
          cur_y = render_node(buffer, node, "", is_last, x, cur_y, width, y + height)
          break if cur_y >= y + height
        end
      end

      private def render_node(
        buffer : Buffer,
        node : TreeNode,
        prefix : String,
        is_last : Bool,
        x : Int32,
        y : Int32,
        w : Int32,
        max_y : Int32,
      ) : Int32
        return y if y >= max_y

        @visible_rows << {node: node, y: y, x: x, w: w}
        is_selected = (node == @selected_node)

        expand_symbol = if node.children.empty?
                          "  "
                        elsif node.expanded?
                          "v "
                        else
                          "> "
                        end

        connector = is_last ? "└── " : "├── "
        icon_str = node.icon ? "#{node.icon} " : ""
        conn_str = "#{prefix}#{connector}#{expand_symbol}"
        conn_w = VisualWidth.width(conn_str)

        bg_color = is_selected ? current_theme.surface : Color.none
        fg_color = is_selected ? current_theme.accent : node.color

        buffer.put_string(x, y, conn_str, fg: is_selected ? current_theme.accent : Color.bright_black, bg: bg_color, max_width: w)

        avail_label = Math.max(0, w - conn_w)
        if avail_label > 0
          buffer.put_string(x + conn_w, y, "#{icon_str}#{node.label}", fg: fg_color, bg: bg_color, bold: is_selected, max_width: avail_label)
        end

        next_y = y + 1
        return next_y unless node.expanded?

        new_prefix = prefix + (is_last ? "    " : "│   ")

        node.children.each_with_index do |child, idx|
          child_last = (idx == node.children.size - 1)
          next_y = render_node(buffer, child, new_prefix, child_last, x, next_y, w, max_y)
          break if next_y >= max_y
        end

        next_y
      end

      def handle_key(event : Terminal::KeyEvent) : Bool
        return false if @visible_rows.empty?

        current_idx = @visible_rows.index { |r| r[:node] == @selected_node } || 0

        case event.name
        when "up", "k"
          new_idx = Math.max(0, current_idx - 1)
          @selected_node = @visible_rows[new_idx][:node]
          @on_select.try(&.call(@selected_node.not_nil!))
          true
        when "down", "j"
          new_idx = Math.min(@visible_rows.size - 1, current_idx + 1)
          @selected_node = @visible_rows[new_idx][:node]
          @on_select.try(&.call(@selected_node.not_nil!))
          true
        when "enter", "return", "space", " "
          if sel = @selected_node
            sel.toggle_expand unless sel.children.empty?
            @on_toggle.try(&.call(sel))
            true
          else
            false
          end
        when "left", "h"
          if sel = @selected_node
            if sel.expanded? && !sel.children.empty?
              sel.toggle_expand
              @on_toggle.try(&.call(sel))
              true
            else
              false
            end
          else
            false
          end
        when "right", "l"
          if sel = @selected_node
            if !sel.expanded? && !sel.children.empty?
              sel.toggle_expand
              @on_toggle.try(&.call(sel))
              true
            else
              false
            end
          else
            false
          end
        else
          false
        end
      end

      def handle_mouse(event : Terminal::MouseEvent) : Bool
        return false if @visible_rows.empty?

        case event.button
        when Terminal::MouseButton::WheelUp
          current_idx = @visible_rows.index { |r| r[:node] == @selected_node } || 0
          new_idx = Math.max(0, current_idx - 1)
          @selected_node = @visible_rows[new_idx][:node]
          @on_select.try(&.call(@selected_node.not_nil!))
          return true
        when Terminal::MouseButton::WheelDown
          current_idx = @visible_rows.index { |r| r[:node] == @selected_node } || 0
          new_idx = Math.min(@visible_rows.size - 1, current_idx + 1)
          @selected_node = @visible_rows[new_idx][:node]
          @on_select.try(&.call(@selected_node.not_nil!))
          return true
        end

        if event.button == Terminal::MouseButton::Left && event.action == Terminal::MouseAction::Press
          if row = @visible_rows.find { |r| r[:y] == event.y && event.x >= r[:x] && event.x < r[:x] + r[:w] }
            node = row[:node]
            if @selected_node == node && !node.children.empty?
              node.toggle_expand
              @on_toggle.try(&.call(node))
            else
              @selected_node = node
              @on_select.try(&.call(node))
            end
            return true
          end
        end

        false
      end
    end
  end
end

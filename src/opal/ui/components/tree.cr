require "../element"
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

      def initialize(
        @label : String,
        color : Color | Symbol | String = :white,
        @icon : String? = nil,
      )
        @color = Color.from(color)
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

    # Renders a hierarchical tree with branch connectors.
    class Tree < Element
      getter root_nodes : Array(TreeNode)
      getter title : String?

      def initialize(@root_nodes : Array(TreeNode) = [] of TreeNode, @title : String? = nil)
      end

      def add(node : TreeNode) : Nil
        @root_nodes << node
      end

      def add(label : String, color : Color | Symbol | String = :white, icon : String? = nil, &block : TreeNode -> Nil) : TreeNode
        node = TreeNode.new(label, color, icon)
        @root_nodes << node
        block.call(node)
        node
      end

      private def count_visible_lines(node : TreeNode) : Int32
        1 + node.children.sum { |c| count_visible_lines(c) }
      end

      def preferred_size(available_w : Int32, available_h : Int32) : {Int32, Int32}
        total_lines = @root_nodes.sum { |n| count_visible_lines(n) } + (@title ? 2 : 0)
        {available_w, [total_lines, available_h].min}
      end

      def render(buffer : Buffer, x : Int32, y : Int32, width : Int32, height : Int32) : Nil
        return if @root_nodes.empty?

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

        connector = is_last ? "└── " : "├── "
        icon_str = node.icon ? "#{node.icon} " : ""
        line = "#{prefix}#{connector}#{icon_str}#{node.label}"

        # Draw connector in bright_black, then label in node color
        conn_w = VisualWidth.width("#{prefix}#{connector}")
        buffer.put_string(x, y, "#{prefix}#{connector}", fg: Color.bright_black)
        buffer.put_string(x + conn_w, y, "#{icon_str}#{node.label}", fg: node.color, max_width: w - conn_w)

        next_y = y + 1
        new_prefix = prefix + (is_last ? "    " : "│   ")

        node.children.each_with_index do |child, idx|
          child_last = (idx == node.children.size - 1)
          next_y = render_node(buffer, child, new_prefix, child_last, x, next_y, w, max_y)
          break if next_y >= max_y
        end

        next_y
      end
    end
  end
end

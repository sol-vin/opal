require "./ast"
require "../ui/buffer"
require "../style/color"
require "../style/glyphs"

module Opal
  module Mermaid
    # Unicode box-drawing diagram layout renderer for Mermaid ASTs
    class Renderer
      def self.render(diagram : Diagram, buffer : UI::Buffer, offset_x : Int32 = 0, offset_y : Int32 = 0, max_w : Int32 = 80, max_h : Int32 = 40) : Nil
        case diagram
        when FlowchartDiagram
          render_flowchart(diagram, buffer, offset_x, offset_y, max_w, max_h)
        when SequenceDiagramAST
          render_sequence(diagram, buffer, offset_x, offset_y, max_w, max_h)
        when StateDiagramAST
          render_state(diagram, buffer, offset_x, offset_y, max_w, max_h)
        when ClassDiagramAST
          render_class(diagram, buffer, offset_x, offset_y, max_w, max_h)
        end
      end

      private def self.render_flowchart(diag : FlowchartDiagram, buffer : UI::Buffer, ox : Int32, oy : Int32, mw : Int32, mh : Int32) : Nil
        # Top-down or Left-Right layout
        if diag.direction == Direction::LeftRight
          render_flowchart_lr(diag, buffer, ox, oy, mw, mh)
        else
          render_flowchart_td(diag, buffer, ox, oy, mw, mh)
        end
      end

      private def self.render_flowchart_td(diag : FlowchartDiagram, buffer : UI::Buffer, ox : Int32, oy : Int32, mw : Int32, mh : Int32) : Nil
        cur_y = oy + 1
        node_positions = Hash(String, Tuple(Int32, Int32, Int32)).new # id => {x, y, width}

        # Order nodes by edges (or key order)
        node_list = diag.nodes.values
        node_list.each do |node|
          w = node.label.size + 4
          cx = ox + Math.max(0, (mw // 2) - (w // 2))

          # Render node box
          render_node_box(node, buffer, cx, cur_y, w)
          node_positions[node.id] = {cx, cur_y, w}

          # Check if there is an edge leaving this node
          outgoing = diag.edges.select { |e| e.from_id == node.id }
          if !outgoing.empty?
            # Draw connector arrow down
            arrow_x = cx + (w // 2)
            edge = outgoing.first
            if lbl = edge.label
              buffer.put_string(arrow_x + 2, cur_y + 3, "|#{lbl}|", fg: Color.hex("#a0aec0"), dim: true)
            end
            buffer.put_char(arrow_x, cur_y + 3, '│', fg: Color.hex("#4facfe"))
            buffer.put_char(arrow_x, cur_y + 4, '▼', fg: Color.hex("#00f2fe"), bold: true)
            cur_y += 5
          else
            cur_y += 4
          end
          break if cur_y >= oy + mh - 2
        end
      end

      private def self.render_flowchart_lr(diag : FlowchartDiagram, buffer : UI::Buffer, ox : Int32, oy : Int32, mw : Int32, mh : Int32) : Nil
        cur_x = ox + 1
        center_y = oy + 2

        node_list = diag.nodes.values
        node_list.each_with_index do |node, idx|
          w = node.label.size + 4
          render_node_box(node, buffer, cur_x, center_y, w)
          cur_x += w

          if idx < node_list.size - 1
            # Draw connector arrow right
            edge = diag.edges.find { |e| e.from_id == node.id }
            if edge && (lbl = edge.label)
              buffer.put_string(cur_x + 1, center_y - 1, lbl, fg: Color.hex("#a0aec0"), dim: true)
            end
            buffer.put_string(cur_x + 1, center_y + 1, "──▶", fg: Color.hex("#00f2fe"), bold: true)
            cur_x += 5
          end
          break if cur_x >= ox + mw - 10
        end
      end

      private def self.render_node_box(node : Node, buffer : UI::Buffer, x : Int32, y : Int32, w : Int32) : Nil
        fg = case node.shape
             when NodeShape::Round    then Color.hex("#38ef7d")
             when NodeShape::Diamond  then Color.hex("#f6d365")
             when NodeShape::Database then Color.hex("#ff0844")
             when NodeShape::Pill     then Color.hex("#f093fb")
             else                          Color.hex("#4facfe")
             end

        # Top border
        tl, tr, bl, br = case node.shape
                         when NodeShape::Round, NodeShape::Pill
                           {'╭', '╮', '╰', '╯'}
                         when NodeShape::Database
                           {'⌠', '⌡', '⌡', '⌠'}
                         when NodeShape::Diamond
                           {'◇', '◇', '◇', '◇'}
                         else
                           {'┌', '┐', '└', '┘'}
                         end

        buffer.put_char(x, y, tl, fg: fg)
        (1...w - 1).each { |i| buffer.put_char(x + i, y, '─', fg: fg) }
        buffer.put_char(x + w - 1, y, tr, fg: fg)

        # Middle label
        buffer.put_char(x, y + 1, '│', fg: fg)
        buffer.put_string(x + 2, y + 1, node.label, fg: Color.white, bold: true)
        buffer.put_char(x + w - 1, y + 1, '│', fg: fg)

        # Bottom border
        buffer.put_char(x, y + 2, bl, fg: fg)
        (1...w - 1).each { |i| buffer.put_char(x + i, y + 2, '─', fg: fg) }
        buffer.put_char(x + w - 1, y + 2, br, fg: fg)
      end

      private def self.render_sequence(diag : SequenceDiagramAST, buffer : UI::Buffer, ox : Int32, oy : Int32, mw : Int32, mh : Int32) : Nil
        participants = diag.participants
        return if participants.empty?

        spacing = Math.max(12, (mw - 4) // participants.size)
        part_xs = Hash(String, Int32).new

        # Draw participant headers
        participants.each_with_index do |p, i|
          px = ox + 4 + (i * spacing)
          part_xs[p] = px
          label = "[ #{p} ]"
          buffer.put_string(px - (label.size // 2), oy + 1, label, fg: Color.hex("#38ef7d"), bold: true)
        end

        # Draw lifelines
        cur_y = oy + 3
        max_line_y = Math.min(oy + mh - 2, oy + 4 + (diag.messages.size * 3))
        (cur_y..max_line_y).each do |y|
          participants.each do |p|
            buffer.put_char(part_xs[p], y, '┆', fg: Color.ansi(240))
          end
        end

        # Draw messages
        diag.messages.each do |msg|
          from_x = part_xs[msg.from_name]? || (ox + 4)
          to_x = part_xs[msg.to_name]? || (ox + 20)

          cur_y += 2
          break if cur_y >= oy + mh - 2

          min_x = Math.min(from_x, to_x)
          max_x = Math.max(from_x, to_x)

          # Message line
          ch = msg.dashed? ? '┄' : '─'
          ((min_x + 1)...max_x).each do |x|
            buffer.put_char(x, cur_y, ch, fg: Color.hex("#00f2fe"))
          end

          # Arrowhead
          if from_x < to_x
            buffer.put_char(to_x, cur_y, '▶', fg: Color.hex("#00f2fe"), bold: true)
          else
            buffer.put_char(to_x, cur_y, '◀', fg: Color.hex("#00f2fe"), bold: true)
          end

          # Text label
          label_x = min_x + 2
          buffer.put_string(label_x, cur_y - 1, msg.message, fg: Color.white, dim: true)
        end
      end

      private def self.render_state(diag : StateDiagramAST, buffer : UI::Buffer, ox : Int32, oy : Int32, mw : Int32, mh : Int32) : Nil
        cur_y = oy + 1
        diag.transitions.each do |(from_s, to_s, desc)|
          buffer.put_string(ox + 2, cur_y, "(#{from_s})", fg: Color.hex("#4facfe"), bold: true)
          arrow_label = desc ? " ──[#{desc}]──▶ " : " ──────▶ "
          buffer.put_string(ox + 2 + from_s.size + 2, cur_y, arrow_label, fg: Color.hex("#00f2fe"))
          buffer.put_string(ox + 2 + from_s.size + 2 + arrow_label.size, cur_y, "(#{to_s})", fg: Color.hex("#38ef7d"), bold: true)
          cur_y += 3
          break if cur_y >= oy + mh - 2
        end
      end

      private def self.render_class(diag : ClassDiagramAST, buffer : UI::Buffer, ox : Int32, oy : Int32, mw : Int32, mh : Int32) : Nil
        cur_x = ox + 2
        diag.classes.each do |cname, members|
          w = Math.max(cname.size + 6, (members.map(&.size).max? || 0) + 4)
          h = members.size + 3

          # Class header box
          buffer.put_char(cur_x, oy + 1, '┌', fg: Color.hex("#f6d365"))
          (1...w - 1).each { |i| buffer.put_char(cur_x + i, oy + 1, '─', fg: Color.hex("#f6d365")) }
          buffer.put_char(cur_x + w - 1, oy + 1, '┐', fg: Color.hex("#f6d365"))

          buffer.put_char(cur_x, oy + 2, '│', fg: Color.hex("#f6d365"))
          buffer.put_string(cur_x + 2, oy + 2, cname, fg: Color.white, bold: true)
          buffer.put_char(cur_x + w - 1, oy + 2, '│', fg: Color.hex("#f6d365"))

          # Member separator
          buffer.put_char(cur_x, oy + 3, '├', fg: Color.hex("#f6d365"))
          (1...w - 1).each { |i| buffer.put_char(cur_x + i, oy + 3, '─', fg: Color.hex("#f6d365")) }
          buffer.put_char(cur_x + w - 1, oy + 3, '┤', fg: Color.hex("#f6d365"))

          # Member list
          members.each_with_index do |m, mi|
            my = oy + 4 + mi
            buffer.put_char(cur_x, my, '│', fg: Color.hex("#f6d365"))
            buffer.put_string(cur_x + 2, my, m, fg: Color.hex("#e2e8f0"))
            buffer.put_char(cur_x + w - 1, my, '│', fg: Color.hex("#f6d365"))
          end

          # Bottom
          by = oy + 4 + members.size
          buffer.put_char(cur_x, by, '└', fg: Color.hex("#f6d365"))
          (1...w - 1).each { |i| buffer.put_char(cur_x + i, by, '─', fg: Color.hex("#f6d365")) }
          buffer.put_char(cur_x + w - 1, by, '┘', fg: Color.hex("#f6d365"))

          cur_x += w + 4
          break if cur_x >= ox + mw - 10
        end
      end
    end
  end
end

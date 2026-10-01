require "./ast"

module Opal
  module Mermaid
    class Parser
      def self.parse(source : String) : Diagram
        lines = source.lines.map(&.strip).reject(&.empty?)
        return FlowchartDiagram.new if lines.empty?

        first_line = lines.first

        if first_line.starts_with?("sequenceDiagram")
          parse_sequence(lines)
        elsif first_line.starts_with?("stateDiagram")
          parse_state(lines)
        elsif first_line.starts_with?("classDiagram")
          parse_class(lines)
        else
          # Default to flowchart / graph
          parse_flowchart(lines)
        end
      end

      private def self.parse_flowchart(lines : Array(String)) : FlowchartDiagram
        dir = Direction::TopDown
        if header = lines.first?
          if header.includes?("LR") || header.includes?("right")
            dir = Direction::LeftRight
          elsif header.includes?("BT")
            dir = Direction::BottomUp
          elsif header.includes?("RL")
            dir = Direction::RightLeft
          end
        end

        diagram = FlowchartDiagram.new(dir)

        lines.each_with_index do |line, idx|
          next if idx == 0 && (line.starts_with?("graph") || line.starts_with?("flowchart"))
          next if line.starts_with?("%%") # Comment

          # Check for edge patterns: -->, ---, ==>, -.->
          # Optional label: -->|label| or -->|ok|
          if line.includes?("-->") || line.includes?("---") || line.includes?("==>") || line.includes?("-.->")
            parse_edge_line(line, diagram)
          else
            # Single node declaration
            if node = parse_node_token(line)
              diagram.nodes[node.id] = node
            end
          end
        end

        diagram
      end

      private def self.parse_edge_line(line : String, diagram : FlowchartDiagram) : Nil
        # Split by edge operator
        # Regex or string search
        op = if line.includes?("-->")
               "-->"
             elsif line.includes?("==>")
               "==>"
             elsif line.includes?("-.->")
               "-.->"
             else
               "---"
             end

        parts = line.split(op, 2)
        return if parts.size < 2

        left_raw = parts[0].strip
        right_raw = parts[1].strip

        edge_label = nil
        # Check if right_raw starts with |label|
        if right_raw.starts_with?("|")
          if end_idx = right_raw.index("|", 1)
            edge_label = right_raw[1...end_idx].strip
            right_raw = right_raw[(end_idx + 1)..-1].strip
          end
        end

        from_node = parse_node_token(left_raw) || Node.new(left_raw)
        to_node = parse_node_token(right_raw) || Node.new(right_raw)

        if existing = diagram.nodes[from_node.id]?
          if from_node.label != from_node.id || from_node.shape != NodeShape::Rect
            diagram.nodes[from_node.id] = from_node
          end
        else
          diagram.nodes[from_node.id] = from_node
        end

        if existing = diagram.nodes[to_node.id]?
          if to_node.label != to_node.id || to_node.shape != NodeShape::Rect
            diagram.nodes[to_node.id] = to_node
          end
        else
          diagram.nodes[to_node.id] = to_node
        end

        style = case op
                when "==>"  then EdgeStyle::Thick
                when "-.->" then EdgeStyle::Dotted
                when "---"  then EdgeStyle::Solid
                else             EdgeStyle::Arrow
                end

        diagram.edges << Edge.new(from_node.id, to_node.id, edge_label, style)
      end

      private def self.parse_node_token(token : String) : Node?
        t = token.strip
        return nil if t.empty?

        # Database: id[(label)]
        if db_match = t.match(/^([A-Za-z0-9_]+)\[\((.+?)\)\]$/)
          return Node.new(db_match[1], db_match[2], NodeShape::Database)
        end

        # Pill / Rounded: id([label])
        if pill_match = t.match(/^([A-Za-z0-9_]+)\(\[(.+?)\]\)$/)
          return Node.new(pill_match[1], pill_match[2], NodeShape::Pill)
        end

        # Circle: id((label))
        if circ_match = t.match(/^([A-Za-z0-9_]+)\(\((.+?)\)\)$/)
          return Node.new(circ_match[1], circ_match[2], NodeShape::Circle)
        end

        # Diamond: id{label}
        if dia_match = t.match(/^([A-Za-z0-9_]+)\{(.+?)\}$/)
          return Node.new(dia_match[1], dia_match[2], NodeShape::Diamond)
        end

        # Rounded: id(label)
        if rnd_match = t.match(/^([A-Za-z0-9_]+)\((.+?)\)$/)
          return Node.new(rnd_match[1], rnd_match[2], NodeShape::Round)
        end

        # Rect: id[label]
        if rect_match = t.match(/^([A-Za-z0-9_]+)\[(.+?)\]$/)
          return Node.new(rect_match[1], rect_match[2], NodeShape::Rect)
        end

        # Raw id
        if t.match(/^[A-Za-z0-9_]+$/)
          return Node.new(t, t, NodeShape::Rect)
        end

        nil
      end

      private def self.parse_sequence(lines : Array(String)) : SequenceDiagramAST
        diag = SequenceDiagramAST.new
        lines.each_with_index do |line, idx|
          next if idx == 0 # header
          next if line.starts_with?("%%")

          if line.starts_with?("participant") || line.starts_with?("actor")
            name = line.split.last
            diag.participants << name unless diag.participants.includes?(name)
          elsif line.includes?("->>") || line.includes?("-->>")
            dashed = line.includes?("-->>")
            sep = dashed ? "-->>" : "->>"
            parts = line.split(sep, 2)
            from_part = parts[0].strip
            rest = parts[1].strip
            msg_parts = rest.split(":", 2)
            to_part = msg_parts[0].strip
            msg = msg_parts.size > 1 ? msg_parts[1].strip : ""

            diag.participants << from_part unless diag.participants.includes?(from_part)
            diag.participants << to_part unless diag.participants.includes?(to_part)
            diag.messages << SequenceMessage.new(from_part, to_part, msg, dashed)
          end
        end
        diag
      end

      private def self.parse_state(lines : Array(String)) : StateDiagramAST
        diag = StateDiagramAST.new
        lines.each_with_index do |line, idx|
          next if idx == 0
          next if line.starts_with?("%%")
          if line.includes?("-->")
            parts = line.split("-->", 2)
            from_s = parts[0].strip
            rest = parts[1].strip
            desc = nil
            if rest.includes?(":")
              subparts = rest.split(":", 2)
              to_s = subparts[0].strip
              desc = subparts[1].strip
            else
              to_s = rest
            end
            diag.states << from_s unless diag.states.includes?(from_s)
            diag.states << to_s unless diag.states.includes?(to_s)
            diag.transitions << {from_s, to_s, desc}
          end
        end
        diag
      end

      private def self.parse_class(lines : Array(String)) : ClassDiagramAST
        diag = ClassDiagramAST.new
        current_class = nil
        lines.each_with_index do |line, idx|
          next if idx == 0
          next if line.starts_with?("%%")

          if line.starts_with?("class ")
            name = line.split[1].rstrip('{').strip
            current_class = name
            diag.classes[name] ||= [] of String
          elsif line == "}"
            current_class = nil
          elsif line.includes?("<|--")
            parts = line.split("<|--", 2)
            base_c = parts[0].strip
            child_c = parts[1].strip
            diag.relations << {base_c, child_c, "inherits"}
          elsif cc = current_class
            diag.classes[cc] << line
          end
        end
        diag
      end
    end
  end
end

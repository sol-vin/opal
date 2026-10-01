module Opal
  module HTML
    enum TagType
      H1
      H2
      H3
      H4
      H5
      H6
      Paragraph
      Link
      List
      OrderedList
      ListItem
      Table
      TableRow
      TableHeader
      TableCell
      Code
      Pre
      Blockquote
      Rule
      Image
      Text
    end

    class Node
      property type : TagType
      property content : String = ""
      property attributes : Hash(String, String) = Hash(String, String).new
      property children : Array(Node) = [] of Node

      def initialize(@type : TagType, @content : String = "")
      end

      def href : String?
        @attributes["href"]?
      end

      def src : String?
        @attributes["src"]?
      end

      def alt : String?
        @attributes["alt"]?
      end
    end

    class Parser
      def self.parse(html : String) : Node
        root = Node.new(TagType::Text)
        stack = [root]

        scanner = html
        pos = 0
        len = scanner.size

        while pos < len
          # Find next '<'
          tag_start = scanner.index('<', pos)
          if tag_start.nil?
            # Remaining plain text
            text_part = scanner[pos..-1].strip
            if !text_part.empty?
              stack.last.children << Node.new(TagType::Text, text_part)
            end
            break
          end

          # Add any text before the tag
          if tag_start > pos
            text_part = scanner[pos...tag_start].strip
            if !text_part.empty?
              stack.last.children << Node.new(TagType::Text, text_part)
            end
          end

          # Find closing '>'
          tag_end = scanner.index('>', tag_start)
          break if tag_end.nil?

          tag_content = scanner[(tag_start + 1)...tag_end].strip
          pos = tag_end + 1

          if tag_content.starts_with?("/")
            # Closing tag
            tag_name = tag_content[1..-1].strip.downcase
            # Pop stack if matching
            if stack.size > 1
              stack.pop
            end
          elsif tag_content.ends_with?("/") || tag_content.downcase.starts_with?("hr") || tag_content.downcase.starts_with?("br") || tag_content.downcase.starts_with?("img")
            # Self-closing tag
            tag_name, attrs = parse_tag_parts(tag_content.rstrip('/'))
            node = create_node_from_tag(tag_name, attrs)
            stack.last.children << node
          else
            # Opening tag
            tag_name, attrs = parse_tag_parts(tag_content)
            node = create_node_from_tag(tag_name, attrs)
            stack.last.children << node
            # Non-void elements get pushed onto stack
            unless {"img", "br", "hr", "input", "meta", "link"}.includes?(tag_name)
              stack << node
            end
          end
        end

        root
      end

      private def self.parse_tag_parts(content : String) : Tuple(String, Hash(String, String))
        parts = content.split(/\s+/, 2)
        tag_name = parts[0].downcase
        attrs = Hash(String, String).new

        if parts.size > 1
          # Simple attribute parser for key="val" or key='val'
          parts[1].scan(/([A-Za-z0-9_-]+)=(?:["']([^"']*)["']|([^\s>]+))/) do |m|
            key = m[1].downcase
            val = m[2]? || m[3]? || ""
            attrs[key] = val
          end
        end

        {tag_name, attrs}
      end

      private def self.create_node_from_tag(tag_name : String, attrs : Hash(String, String)) : Node
        type = case tag_name
               when "h1"               then TagType::H1
               when "h2"               then TagType::H2
               when "h3"               then TagType::H3
               when "h4"               then TagType::H4
               when "h5"               then TagType::H5
               when "h6"               then TagType::H6
               when "p"                then TagType::Paragraph
               when "a"                then TagType::Link
               when "ul"               then TagType::List
               when "ol"               then TagType::OrderedList
               when "li"               then TagType::ListItem
               when "table"            then TagType::Table
               when "tr"               then TagType::TableRow
               when "th"               then TagType::TableHeader
               when "td"               then TagType::TableCell
               when "code"             then TagType::Code
               when "pre"              then TagType::Pre
               when "blockquote"       then TagType::Blockquote
               when "hr"               then TagType::Rule
               when "img"              then TagType::Image
               else                         TagType::Text
               end

        node = Node.new(type)
        node.attributes = attrs
        node
      end
    end
  end
end

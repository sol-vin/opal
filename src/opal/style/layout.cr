require "./visual_width"

module Opal
  # Layout combinators for positioning multi-line string blocks horizontally and vertically.
  module Layout
    # Joins multi-line string blocks horizontally side-by-side.
    # Align can be :top, :center, or :bottom.
    def self.join_horizontal(align : Symbol = :top, blocks : Array(String) = [] of String, spacing : Int32 = 0) : String
      return "" if blocks.empty?
      return blocks.first if blocks.size == 1

      split_blocks = blocks.map { |b| b.split('\n') }
      block_widths = split_blocks.map { |lines| lines.map { |l| VisualWidth.width(l) }.max? || 0 }
      max_height = split_blocks.map(&.size).max? || 0

      # Normalize all blocks to have max_height lines
      normalized_blocks = split_blocks.map_with_index do |lines, idx|
        width = block_widths[idx]
        diff = max_height - lines.size

        case align
        when :bottom
          padded = Array.new(diff, " " * width) + lines
        when :center
          top_pad = diff // 2
          bot_pad = diff - top_pad
          padded = Array.new(top_pad, " " * width) + lines + Array.new(bot_pad, " " * width)
        else # :top
          padded = lines + Array.new(diff, " " * width)
        end

        # Ensure every individual line is padded to the full block width
        padded.map do |line|
          lw = VisualWidth.width(line)
          line + (" " * Math.max(0, width - lw))
        end
      end

      gap = " " * spacing
      result = (0...max_height).map do |row|
        normalized_blocks.map { |lines| lines[row] }.join(gap)
      end

      result.join('\n')
    end

    def self.join_horizontal(align : Symbol = :top, *blocks : String, spacing : Int32 = 0) : String
      join_horizontal(align, blocks.to_a, spacing: spacing)
    end

    # Stacks multi-line string blocks vertically.
    # Align can be :left, :center, or :right.
    def self.join_vertical(align : Symbol = :left, blocks : Array(String) = [] of String, spacing : Int32 = 0) : String
      return "" if blocks.empty?
      return blocks.first if blocks.size == 1

      all_lines = [] of String
      blocks.each_with_index do |block, i|
        all_lines.concat(block.split('\n'))
        if i < blocks.size - 1 && spacing > 0
          spacing.times { all_lines << "" }
        end
      end

      max_width = all_lines.map { |l| VisualWidth.width(l) }.max? || 0

      aligned_lines = all_lines.map do |line|
        w = VisualWidth.width(line)
        diff = Math.max(0, max_width - w)

        case align
        when :center
          left_pad = diff // 2
          right_pad = diff - left_pad
          (" " * left_pad) + line + (" " * right_pad)
        when :right
          (" " * diff) + line
        else # :left
          line
        end
      end

      aligned_lines.join('\n')
    end

    def self.join_vertical(align : Symbol = :left, *blocks : String, spacing : Int32 = 0) : String
      join_vertical(align, blocks.to_a, spacing: spacing)
    end
  end
end

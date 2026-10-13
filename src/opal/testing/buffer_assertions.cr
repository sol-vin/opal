require "../ui/buffer"
require "../terminal/mock"
require "../style/color"

module Opal
  module Testing
    # Ratatui-inspired 2D terminal buffer inspection and visual assertions.
    module BufferAssertions
      # Extracts the text lines from a buffer.
      def buffer_lines(buffer : UI::Buffer, trim_trailing : Bool = true) : Array(String)
        lines = [] of String
        (0...buffer.height).each do |y|
          line_io = String::Builder.new
          skip_next = false
          (0...buffer.width).each do |x|
            cell = buffer.get(x, y)
            if cell.continuation?
              next
            end
            line_io << cell.char
          end
          row = line_io.to_s
          row = row.rstrip if trim_trailing
          lines << row
        end
        lines
      end

      # Extracts the text lines from a mock driver by inspecting its stripped output or frame.
      def driver_lines(driver : Terminal::MockDriver, trim_trailing : Bool = true) : Array(String)
        lines = driver.stripped_output.split("\n")
        lines = lines.map(&.rstrip) if trim_trailing
        lines
      end

      # Asserts that the 2D buffer's rendered character grid matches the expected lines.
      # Upon mismatch, constructs a formatted, readable visual diff highlighting line numbers and discrepancies.
      def assert_buffer_lines(
        buffer : UI::Buffer,
        expected : Array(String),
        trim_trailing : Bool = true,
        file = __FILE__,
        line = __LINE__,
      ) : Nil
        actual = buffer_lines(buffer, trim_trailing: trim_trailing)
        max_rows = Math.max(actual.size, expected.size)
        mismatches = [] of Int32

        (0...max_rows).each do |row_idx|
          act_line = actual[row_idx]? || "<EOF>"
          raw_exp = expected[row_idx]?
          exp_line = if raw_exp
                       trim_trailing ? raw_exp.rstrip : raw_exp
                     else
                       "<EOF>"
                     end
          if act_line != exp_line
            mismatches << row_idx
          end
        end

        return if mismatches.empty?

        diff_msg = String::Builder.new
        diff_msg << "\nBuffer line mismatch detected at #{mismatches.size} row(s):\n"
        diff_msg << "┌─────┬─" + "─" * 40 + "─┬─" + "─" * 40 + "┐\n"
        diff_msg << "│ Row │ Expected" + " " * 32 + "│ Actual" + " " * 34 + "│\n"
        diff_msg << "├─────┼─" + "─" * 40 + "─┼─" + "─" * 40 + "┤\n"

        (0...max_rows).each do |row_idx|
          act_line = actual[row_idx]? || "<EOF>"
          exp_line = expected[row_idx]? || "<EOF>"
          is_mismatch = mismatches.includes?(row_idx)
          mark = is_mismatch ? ">" : " "

          padded_exp = sprintf("%-40.40s", exp_line)
          padded_act = sprintf("%-40.40s", act_line)
          diff_msg << sprintf("%s%3d │ %s │ %s │\n", mark, row_idx, padded_exp, padded_act)
        end

        diff_msg << "└─────┴─" + "─" * 40 + "─┴─" + "─" * 40 + "┘\n"

        raise Spec::AssertionFailed.new(diff_msg.to_s, file, line)
      end

      # Asserts a single cell's exact character and style properties at (x, y).
      def assert_cell(
        buffer : UI::Buffer,
        x : Int32,
        y : Int32,
        char : Char? = nil,
        fg : Color? = nil,
        bg : Color? = nil,
        bold : Bool? = nil,
        underline : Bool? = nil,
        dim : Bool? = nil,
        italic : Bool? = nil,
        file = __FILE__,
        line = __LINE__,
      ) : Nil
        unless buffer.in_bounds?(x, y)
          raise Spec::AssertionFailed.new(
            "Cell coordinates (#{x}, #{y}) out of buffer bounds (#{buffer.width}x#{buffer.height})",
            file,
            line
          )
        end

        cell = buffer.get(x, y)

        if char && cell.char != char
          raise Spec::AssertionFailed.new(
            "Cell at (#{x}, #{y}) character mismatch: expected '#{char}', got '#{cell.char}'",
            file,
            line
          )
        end

        if fg && cell.fg != fg
          raise Spec::AssertionFailed.new(
            "Cell at (#{x}, #{y}) foreground color mismatch: expected #{fg}, got #{cell.fg}",
            file,
            line
          )
        end

        if bg && cell.bg != bg
          raise Spec::AssertionFailed.new(
            "Cell at (#{x}, #{y}) background color mismatch: expected #{bg}, got #{cell.bg}",
            file,
            line
          )
        end

        if !bold.nil? && cell.bold? != bold
          raise Spec::AssertionFailed.new(
            "Cell at (#{x}, #{y}) bold mismatch: expected #{bold}, got #{cell.bold?}",
            file,
            line
          )
        end

        if !underline.nil? && cell.underline? != underline
          raise Spec::AssertionFailed.new(
            "Cell at (#{x}, #{y}) underline mismatch: expected #{underline}, got #{cell.underline?}",
            file,
            line
          )
        end

        if !dim.nil? && cell.dim? != dim
          raise Spec::AssertionFailed.new(
            "Cell at (#{x}, #{y}) dim mismatch: expected #{dim}, got #{cell.dim?}",
            file,
            line
          )
        end

        if !italic.nil? && cell.italic? != italic
          raise Spec::AssertionFailed.new(
            "Cell at (#{x}, #{y}) italic mismatch: expected #{italic}, got #{cell.italic?}",
            file,
            line
          )
        end
      end
    end
  end
end

require "../element"
require "../buffer"
require "./barchart"
require "../../style/color"
require "../../style/visual_width"

module Opal
  module UI
    struct BinarySection
      getter name : String
      getter size : UInt64
      getter percentage : Float64
      getter is_code : Bool
      getter is_data : Bool

      def initialize(@name : String, @size : UInt64, @percentage : Float64, @is_code : Bool = false, @is_data : Bool = false)
      end
    end

    struct BinaryFunction
      getter name : String
      getter size : UInt64
      getter complexity : Int32

      def initialize(@name : String, @size : UInt64, @complexity : Int32 = 1)
      end
    end

    struct HardeningFlag
      getter name : String
      getter enabled : Bool
      getter description : String

      def initialize(@name : String, @enabled : Bool, @description : String = "")
      end
    end

    # Generic visual dashboard for radare2 / binary static and dynamic analysis.
    # Displays section distribution, function size outliers, security hardening posture,
    # and code-to-data memory balance.
    class BinaryMetrics < Element
      property title : String?
      property target_name : String
      property total_size : UInt64
      property code_size : UInt64
      property sections : Array(BinarySection)
      property top_functions : Array(BinaryFunction)
      property hardening : Array(HardeningFlag)
      property bar_char : Char

      def initialize(
        @target_name : String = "binary",
        @total_size : UInt64 = 0_u64,
        @code_size : UInt64 = 0_u64,
        @sections = [] of BinarySection,
        @top_functions = [] of BinaryFunction,
        @hardening = [] of HardeningFlag,
        @title : String? = "RADARE2 BINARY ANALYSIS & HARDENING METRICS",
        @bar_char : Char = '|',
      )
      end

      def add_section(name : String, size : UInt64, percentage : Float64, is_code : Bool = false, is_data : Bool = false) : Nil
        @sections << BinarySection.new(name, size, percentage, is_code, is_data)
      end

      def add_function(name : String, size : UInt64, complexity : Int32 = 1) : Nil
        @top_functions << BinaryFunction.new(name, size, complexity)
      end

      def add_hardening(name : String, enabled : Bool, description : String = "") : Nil
        @hardening << HardeningFlag.new(name, enabled, description)
      end

      def preferred_size(available_w : Int32, available_h : Int32) : {Int32, Int32}
        {available_w, Math.min(available_h, 24)}
      end

      private def format_bytes(bytes : UInt64) : String
        if bytes >= 1024_u64 * 1024_u64
          sprintf("%.2f MB", bytes.to_f / (1024.0 * 1024.0))
        elsif bytes >= 1024_u64
          sprintf("%.1f KB", bytes.to_f / 1024.0)
        else
          "#{bytes} B"
        end
      end

      def render(buffer : Buffer, x : Int32, y : Int32, width : Int32, height : Int32) : Nil
        return if width < 40 || height < 8

        cur_y = y

        # 1. Header Banner
        if t = @title
          total_str = @total_size > 0 ? " (Total: #{format_bytes(@total_size)})" : ""
          buffer.put_string(x, cur_y, "#{t} â€” #{@target_name}#{total_str}", fg: Color.bright_cyan, bold: true, max_width: width)
          cur_y += 1
          buffer.put_string(x, cur_y, "â”€" * Math.min(width, width - 2), fg: Color.bright_black)
          cur_y += 1
        end

        # 2. Section Breakdown Table & Bar Chart
        if !@sections.empty? && cur_y < y + height - 6
          buffer.put_string(x, cur_y, "SECTION BREAKDOWN                 SIZE        RATIO    VISUAL DISTRIBUTION", fg: Color.bright_white, bold: true, max_width: width)
          cur_y += 1

          max_bar_w = Math.max(10, Math.min(width - 64, 35))
          @sections.each do |sec|
            break if cur_y >= y + height - 8

            sec_name_fmt = sprintf("%-18s", sec.name[0...18])
            size_fmt = sprintf("%10s", format_bytes(sec.size))
            ratio_fmt = sprintf("%6.1f%%", sec.percentage)

            num_bars = ((sec.percentage / 100.0) * max_bar_w).clamp(0.0, max_bar_w.to_f).round.to_i
            bars_str = @bar_char.to_s * Math.max(1, num_bars)

            bar_color = if sec.is_code
                          Color.green
                        elsif sec.name.includes?("rdata")
                          Color.cyan
                        elsif sec.is_data
                          Color.yellow
                        else
                          Color.bright_black
                        end

            buffer.put_string(x, cur_y, sec_name_fmt, fg: Color.white)
            buffer.put_string(x + 20, cur_y, size_fmt, fg: Color.bright_white)
            buffer.put_string(x + 33, cur_y, ratio_fmt, fg: Color.bright_yellow)
            buffer.put_string(x + 42, cur_y, "   ", fg: Color.bright_black)
            buffer.put_string(x + 45, cur_y, bars_str, fg: bar_color, bold: true)
            cur_y += 1
          end

          buffer.put_string(x, cur_y, "â”€" * Math.min(width, width - 2), fg: Color.bright_black)
          cur_y += 1
        end

        # 3. Top Function Size Outliers
        if !@top_functions.empty? && cur_y < y + height - 4
          buffer.put_string(x, cur_y, "TOP FUNCTION SIZE OUTLIERS        BYTES       CC       BLOAT INDICATOR", fg: Color.bright_white, bold: true, max_width: width)
          cur_y += 1

          max_fn_size = @top_functions.map(&.size).max? || 1_u64
          max_fn_size = 1_u64 if max_fn_size == 0
          max_fn_bar_w = Math.max(10, Math.min(width - 64, 35))

          @top_functions.first(4).each do |fn|
            break if cur_y >= y + height - 4

            fn_name_fmt = sprintf("%-28s", fn.name[0...28])
            size_fmt = sprintf("%10s", format_bytes(fn.size))
            cc_fmt = sprintf("%4d", fn.complexity)

            fn_ratio = (fn.size.to_f / max_fn_size.to_f).clamp(0.0, 1.0)
            num_bars = (fn_ratio * max_fn_bar_w).round.to_i
            bars_str = @bar_char.to_s * Math.max(1, num_bars)

            buffer.put_string(x, cur_y, fn_name_fmt, fg: Color.bright_cyan)
            buffer.put_string(x + 30, cur_y, size_fmt, fg: Color.white)
            buffer.put_string(x + 42, cur_y, cc_fmt, fg: Color.bright_yellow)
            buffer.put_string(x + 48, cur_y, "   ", fg: Color.bright_black)
            buffer.put_string(x + 51, cur_y, bars_str, fg: Color.magenta)
            cur_y += 1
          end

          buffer.put_string(x, cur_y, "â”€" * Math.min(width, width - 2), fg: Color.bright_black)
          cur_y += 1
        end

        # 4. Security Hardening Badges & Code/Data Split
        if cur_y < y + height
          if !@hardening.empty?
            badge_x = x
            buffer.put_string(badge_x, cur_y, "SECURITY: ", fg: Color.bright_white, bold: true)
            badge_x += 10
            @hardening.each do |h_flag|
              icon = h_flag.enabled ? "[OK]" : "[NO]"
              fg_color = h_flag.enabled ? Color.bright_green : Color.bright_red
              badge_str = "#{icon} #{h_flag.name}  "
              buffer.put_string(badge_x, cur_y, badge_str, fg: fg_color, bold: h_flag.enabled)
              badge_x += badge_str.size
            end
            cur_y += 1
          end

          # Code vs Data ratio gauge
          if @total_size > 0 && @code_size > 0 && cur_y < y + height
            code_pct = ((@code_size.to_f / @total_size.to_f) * 100.0).clamp(0.0, 100.0)
            data_pct = 100.0 - code_pct

            gauge_w = Math.max(10, Math.min(width - 45, 30))
            code_chars = ((code_pct / 100.0) * gauge_w).round.to_i
            data_chars = gauge_w - code_chars

            gauge_str = ("#" * code_chars) + ("." * data_chars)

            buffer.put_string(x, cur_y, "CODE/DATA: ", fg: Color.bright_white, bold: true)
            buffer.put_string(x + 11, cur_y, "[ CODE: #{sprintf("%.1f%%", code_pct)} ] ", fg: Color.green)
            buffer.put_string(x + 28, cur_y, gauge_str, fg: Color.cyan)
            buffer.put_string(x + 29 + gauge_w, cur_y, " [ DATA: #{sprintf("%.1f%%", data_pct)} ]", fg: Color.yellow)
          end
        end
      end
    end
  end
end

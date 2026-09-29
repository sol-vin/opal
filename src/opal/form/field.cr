require "../ui/buffer"
require "../style/color"
require "../style/visual_width"
require "../terminal/ansi_parser"

module Opal
  module FormModule
    # Abstract base class for all interactive fields in a multi-field Form.
    abstract class FormField
      getter name : String
      getter label : String
      property? focused : Bool = false
      property error : String? = nil

      def initialize(@name : String, @label : String)
      end

      abstract def render(buffer : UI::Buffer, x : Int32, y : Int32, width : Int32) : Int32
      abstract def handle_key(key : Terminal::Key) : Bool
      abstract def raw_value : String | Bool | Array(String)

      def value_as_s : String
        raw_value.to_s
      end
    end

    # Single-line text input field
    class TextField < FormField
      property value : String
      getter placeholder : String
      property cursor_pos : Int32

      def initialize(
        name : String,
        label : String,
        default : String = "",
        @placeholder : String = "",
      )
        super(name, label)
        @value = default
        @cursor_pos = @value.size
      end

      def raw_value : String | Bool | Array(String)
        @value
      end

      def handle_key(key : Terminal::Key) : Bool
        case key.name
        when "left"
          @cursor_pos = Math.max(0, @cursor_pos - 1)
          true
        when "right"
          @cursor_pos = Math.min(@value.size, @cursor_pos + 1)
          true
        when "home"
          @cursor_pos = 0
          true
        when "end"
          @cursor_pos = @value.size
          true
        when "backspace"
          if @cursor_pos > 0
            @value = @value[0...(@cursor_pos - 1)] + @value[@cursor_pos..]
            @cursor_pos -= 1
          end
          true
        when "delete"
          if @cursor_pos < @value.size
            @value = @value[0...@cursor_pos] + @value[(@cursor_pos + 1)..]
          end
          true
        else
          if key.name.size == 1 && key.name[0].ascii? && !key.name[0].control?
            @value = @value[0...@cursor_pos] + key.name + @value[@cursor_pos..]
            @cursor_pos += 1
            true
          else
            false
          end
        end
      end

      def render(buffer : UI::Buffer, x : Int32, y : Int32, width : Int32) : Int32
        lines = 1
        indicator = @focused ? "▶ " : "  "
        ind_color = @focused ? Color.cyan : Color.bright_black

        buffer.put_string(x, y, indicator, fg: ind_color, bold: @focused)
        buffer.put_string(x + 2, y, "#{@label} ", fg: @focused ? Color.white : Color.bright_black, bold: @focused)

        val_x = x + 2 + VisualWidth.width("#{@label} ")
        if @value.empty? && !@placeholder.empty? && !@focused
          buffer.put_string(val_x, y, @placeholder, fg: Color.bright_black, italic: true)
        else
          buffer.put_string(val_x, y, @value, fg: Color.bright_white)
        end

        if @focused
          cur_x = val_x + VisualWidth.width(@value[0...@cursor_pos])
          buffer.put_char(cur_x, y, '█', fg: Color.cyan)
        end

        if err = @error
          buffer.put_string(x + 4, y + 1, "⚠ #{err}", fg: Color.red, italic: true)
          lines += 1
        end

        lines
      end
    end

    # Password input field masked with bullet characters
    class PasswordField < TextField
      getter mask_char : Char

      def initialize(
        name : String,
        label : String,
        default : String = "",
        placeholder : String = "",
        @mask_char : Char = '•',
      )
        super(name, label, default, placeholder)
      end

      def render(buffer : UI::Buffer, x : Int32, y : Int32, width : Int32) : Int32
        lines = 1
        indicator = @focused ? "▶ " : "  "
        ind_color = @focused ? Color.cyan : Color.bright_black

        buffer.put_string(x, y, indicator, fg: ind_color, bold: @focused)
        buffer.put_string(x + 2, y, "#{@label} ", fg: @focused ? Color.white : Color.bright_black, bold: @focused)

        val_x = x + 2 + VisualWidth.width("#{@label} ")
        masked = @mask_char.to_s * @value.size
        buffer.put_string(val_x, y, masked, fg: Color.bright_white)

        if @focused
          cur_x = val_x + VisualWidth.width(masked[0...@cursor_pos])
          buffer.put_char(cur_x, y, '█', fg: Color.cyan)
        end

        if err = @error
          buffer.put_string(x + 4, y + 1, "⚠ #{err}", fg: Color.red, italic: true)
          lines += 1
        end

        lines
      end
    end

    # Single-select choice field with horizontal arrows
    class SelectField < FormField
      getter options : Array(String)
      property selected_idx : Int32

      def initialize(name : String, label : String, @options : Array(String), default_idx : Int32 = 0)
        super(name, label)
        @selected_idx = default_idx.clamp(0, Math.max(0, @options.size - 1))
      end

      def raw_value : String | Bool | Array(String)
        @options.empty? ? "" : @options[@selected_idx]
      end

      def handle_key(key : Terminal::Key) : Bool
        case key.name
        when "left", "h"
          @selected_idx = Math.max(0, @selected_idx - 1)
          true
        when "right", "l", "space"
          @selected_idx = Math.min(@options.size - 1, @selected_idx + 1)
          true
        else
          false
        end
      end

      def render(buffer : UI::Buffer, x : Int32, y : Int32, width : Int32) : Int32
        lines = 1
        indicator = @focused ? "▶ " : "  "
        ind_color = @focused ? Color.cyan : Color.bright_black

        buffer.put_string(x, y, indicator, fg: ind_color, bold: @focused)
        buffer.put_string(x + 2, y, "#{@label} ", fg: @focused ? Color.white : Color.bright_black, bold: @focused)

        val_x = x + 2 + VisualWidth.width("#{@label} ")
        current_opt = @options.empty? ? "none" : @options[@selected_idx]

        choice_display = "◀ #{current_opt} ▶"
        buffer.put_string(val_x, y, choice_display, fg: @focused ? Color.cyan : Color.bright_white, bold: @focused)

        if err = @error
          buffer.put_string(x + 4, y + 1, "⚠ #{err}", fg: Color.red, italic: true)
          lines += 1
        end

        lines
      end
    end

    # Multi-select toggle field with checkboxes
    class MultiSelectField < FormField
      getter options : Array(String)
      property selected : Set(String)
      property sub_cursor : Int32 = 0

      def initialize(name : String, label : String, @options : Array(String), initial_selected : Array(String) = [] of String)
        super(name, label)
        @selected = Set(String).new(initial_selected)
      end

      def raw_value : String | Bool | Array(String)
        @options.select { |o| @selected.includes?(o) }
      end

      def handle_key(key : Terminal::Key) : Bool
        case key.name
        when "left", "h"
          @sub_cursor = Math.max(0, @sub_cursor - 1)
          true
        when "right", "l"
          @sub_cursor = Math.min(@options.size - 1, @sub_cursor + 1)
          true
        when "space"
          if opt = @options[@sub_cursor]?
            if @selected.includes?(opt)
              @selected.delete(opt)
            else
              @selected.add(opt)
            end
          end
          true
        else
          false
        end
      end

      def render(buffer : UI::Buffer, x : Int32, y : Int32, width : Int32) : Int32
        lines = 1
        indicator = @focused ? "▶ " : "  "
        ind_color = @focused ? Color.cyan : Color.bright_black

        buffer.put_string(x, y, indicator, fg: ind_color, bold: @focused)
        buffer.put_string(x + 2, y, "#{@label} ", fg: @focused ? Color.white : Color.bright_black, bold: @focused)

        val_x = x + 2 + VisualWidth.width("#{@label} ")
        @options.each_with_index do |opt, idx|
          is_checked = @selected.includes?(opt)
          is_sub_focused = @focused && (idx == @sub_cursor)

          chk = is_checked ? "[✔]" : "[ ]"
          item_text = "#{chk} #{opt}  "

          fg_color = is_sub_focused ? Color.cyan : (is_checked ? Color.green : Color.bright_black)
          buffer.put_string(val_x, y, item_text, fg: fg_color, bold: is_sub_focused, underline: is_sub_focused)
          val_x += VisualWidth.width(item_text)
        end

        if err = @error
          buffer.put_string(x + 4, y + 1, "⚠ #{err}", fg: Color.red, italic: true)
          lines += 1
        end

        lines
      end
    end

    # Confirmation toggle (Yes / No)
    class ConfirmField < FormField
      property? value : Bool

      def initialize(name : String, label : String, default : Bool = false)
        super(name, label)
        @value = default
      end

      def raw_value : String | Bool | Array(String)
        @value
      end

      def handle_key(key : Terminal::Key) : Bool
        case key.name
        when "y", "t"
          @value = true
          true
        when "n", "f"
          @value = false
          true
        when "left", "right", "space"
          @value = !@value
          true
        else
          false
        end
      end

      def render(buffer : UI::Buffer, x : Int32, y : Int32, width : Int32) : Int32
        lines = 1
        indicator = @focused ? "▶ " : "  "
        ind_color = @focused ? Color.cyan : Color.bright_black

        buffer.put_string(x, y, indicator, fg: ind_color, bold: @focused)
        buffer.put_string(x + 2, y, "#{@label} ", fg: @focused ? Color.white : Color.bright_black, bold: @focused)

        val_x = x + 2 + VisualWidth.width("#{@label} ")

        yes_str = "[ Yes ]"
        no_str = "[ No ]"

        if @value
          buffer.put_string(val_x, y, yes_str, fg: Color.black, bg: Color.green, bold: true)
          buffer.put_string(val_x + VisualWidth.width(yes_str) + 1, y, no_str, fg: Color.bright_black)
        else
          buffer.put_string(val_x, y, yes_str, fg: Color.bright_black)
          buffer.put_string(val_x + VisualWidth.width(yes_str) + 1, y, no_str, fg: Color.black, bg: Color.red, bold: true)
        end

        if err = @error
          buffer.put_string(x + 4, y + 1, "⚠ #{err}", fg: Color.red, italic: true)
          lines += 1
        end

        lines
      end
    end
  end
end

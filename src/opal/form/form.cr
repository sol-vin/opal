require "./field"
require "./validator"
require "../ui/buffer"
require "../style/color"
require "../style/border"
require "../style/visual_width"
require "../terminal/driver"

module Opal
  alias FormValue = String | Bool | Array(String)

  module FormModule
    # Declarative multi-field form manager with real-time validation and keyboard navigation.
    class Form
      getter title : String
      getter fields : Array(FormField) = [] of FormField
      getter validators : Hash(String, Array(ValidatorFn)) = Hash(String, Array(ValidatorFn)).new
      property active_field_idx : Int32 = 0

      def initialize(@title : String = "Setup Wizard")
      end

      def text(name : String, label : String, default : String = "", placeholder : String = "", required : Bool = false) : TextField
        field = TextField.new(name, label, default, placeholder)
        @fields << field
        validate(name, Validator.required) if required
        update_focus
        field
      end

      def password(name : String, label : String, min_length : Int32 = 0, default : String = "", placeholder : String = "") : PasswordField
        field = PasswordField.new(name, label, default, placeholder)
        @fields << field
        validate(name, Validator.min_length(min_length)) if min_length > 0
        update_focus
        field
      end

      def select(name : String, label : String, options : Array(String), default_idx : Int32 = 0) : SelectField
        field = SelectField.new(name, label, options, default_idx)
        @fields << field
        update_focus
        field
      end

      def multi_select(name : String, label : String, options : Array(String), selected : Array(String) = [] of String) : MultiSelectField
        field = MultiSelectField.new(name, label, options, selected)
        @fields << field
        update_focus
        field
      end

      def confirm(name : String, label : String, default : Bool = false) : ConfirmField
        field = ConfirmField.new(name, label, default)
        @fields << field
        update_focus
        field
      end

      def validate(name : String, &validator : String -> String?) : Nil
        @validators[name] ||= [] of ValidatorFn
        @validators[name] << validator
      end

      def validate(name : String, validator : ValidatorFn) : Nil
        @validators[name] ||= [] of ValidatorFn
        @validators[name] << validator
      end

      def update_focus : Nil
        @fields.each_with_index do |f, idx|
          f.focused = (idx == @active_field_idx)
        end
      end

      def focus_next : Nil
        return if @fields.empty?
        @active_field_idx = (@active_field_idx + 1) % @fields.size
        update_focus
      end

      def focus_prev : Nil
        return if @fields.empty?
        @active_field_idx = (@active_field_idx - 1 + @fields.size) % @fields.size
        update_focus
      end

      def valid? : Bool
        all_ok = true
        first_error_idx : Int32? = nil

        @fields.each_with_index do |f, idx|
          f.error = nil
          if rules = @validators[f.name]?
            rules.each do |rule|
              if err = rule.call(f.value_as_s)
                f.error = err
                all_ok = false
                first_error_idx ||= idx
                break
              end
            end
          end
        end

        if err_idx = first_error_idx
          @active_field_idx = err_idx
          update_focus
        end

        all_ok
      end

      def values : Hash(String, FormValue)
        res = Hash(String, FormValue).new
        @fields.each do |f|
          res[f.name] = f.raw_value
        end
        res
      end

      def render(buffer : UI::Buffer, x : Int32, y : Int32, width : Int32, height : Int32) : Nil
        cur_y = y

        # Title Card Header
        buffer.put_string(x, cur_y, "┌─ #{@title} ", fg: Color.cyan, bold: true)
        head_len = VisualWidth.width("┌─ #{@title} ")
        if width > head_len
          buffer.put_string(x + head_len, cur_y, "─" * (width - head_len - 1) + "┐", fg: Color.cyan)
        end
        cur_y += 2

        # Render Fields
        @fields.each do |f|
          break if cur_y >= y + height - 3
          consumed = f.render(buffer, x + 2, cur_y, width - 4)
          cur_y += consumed + 1
        end

        # Footer Actions
        foot_y = Math.min(cur_y + 1, y + height - 2)
        buffer.put_string(x, foot_y, "└" + "─" * (width - 2) + "┘", fg: Color.cyan)
        instructions = " [Tab/Shift+Tab] Move   [Enter] Submit   [Esc] Cancel "
        buffer.put_string(x + 2, foot_y, instructions, fg: Color.bright_black)
      end

      # Interactively displays and executes the form
      def run(driver : Terminal::Driver? = nil) : Hash(String, FormValue)?
        drv = driver || Terminal.default_driver

        render_frame = -> {
          w, h = drv.size
          buf = UI::Buffer.new(w, h)
          render(buf, 1, 1, w - 2, h - 2)
          drv.write(Terminal::Screen::CLEAR_ALL)
          drv.write(Terminal::Screen.move_to(1, 1))
          drv.write(buf.to_s)
          drv.flush
        }

        submitted = false

        drv.raw_mode do
          drv.hide_cursor
          render_frame.call

          loop do
            event = drv.read_event
            next unless event
            should_redraw = false

            case event
            when Terminal::KeyEvent
              case event.name
              when "tab", "down"
                focus_next
                should_redraw = true
              when "shift+tab", "up"
                focus_prev
                should_redraw = true
              when "escape", "ctrl+c"
                break
              when "enter"
                if valid?
                  submitted = true
                  break
                else
                  should_redraw = true
                end
              else
                # Pass key to active field
                if active_f = @fields[@active_field_idx]?
                  if active_f.handle_key(event)
                    # Clear error on edit
                    active_f.error = nil
                    should_redraw = true
                  end
                end
              end
            end

            render_frame.call if should_redraw
          end
        ensure
          drv.show_cursor
        end

        submitted ? values : nil
      end
    end
  end

  # High-level entry point to declare and run an interactive form.
  def self.form(title : String = "Form", &block : FormModule::Form -> Nil) : Hash(String, FormValue)?
    f = FormModule::Form.new(title)
    block.call(f)
    f.run
  end
end

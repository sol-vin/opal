require "./autocomplete"
require "./key_map"
require "../terminal"
require "../style"

module Opal
  module Input
    # Interactive single-line text input field supporting Tab completion,
    # ghost text preview, cursor navigation, and history.
    class TextInput
      property prompt : String
      property value : String
      property cursor_pos : Int32
      property autocomplete : Autocomplete?
      property history : Array(String)
      @history_idx : Int32 = -1

      def initialize(
        @prompt : String = "> ",
        @value : String = "",
        @autocomplete : Autocomplete? = nil,
      )
        @cursor_pos = @value.size
        @history = [] of String
      end

      # Configures autocomplete using a block DSL
      def autocomplete(&block : Autocomplete -> Nil) : self
        ac = Autocomplete.new
        block.call(ac)
        @autocomplete = ac
        self
      end

      # Inserts a character at the current cursor position
      def insert(ch : Char) : Nil
        @value = @value[0...@cursor_pos] + ch.to_s + @value[@cursor_pos..]
        @cursor_pos += 1
      end

      # Deletes the character immediately preceding the cursor
      def delete_backward : Nil
        return if @cursor_pos <= 0
        @value = @value[0...(@cursor_pos - 1)] + @value[@cursor_pos..]
        @cursor_pos -= 1
      end

      # Deletes the character at the cursor
      def delete_forward : Nil
        return if @cursor_pos >= @value.size
        @value = @value[0...@cursor_pos] + @value[(@cursor_pos + 1)..]
      end

      # Moves cursor left
      def move_left : Nil
        @cursor_pos = Math.max(0, @cursor_pos - 1)
      end

      # Moves cursor right
      def move_right : Nil
        @cursor_pos = Math.min(@value.size, @cursor_pos + 1)
      end

      def move_start : Nil
        @cursor_pos = 0
      end

      def move_end : Nil
        @cursor_pos = @value.size
      end

      # Accepts the currently visible ghost text suggestion
      def accept_autocomplete : Bool
        if ac = @autocomplete
          if @cursor_pos == @value.size
            if ghost = ac.ghost_text(@value)
              @value += ghost
              @cursor_pos = @value.size
              return true
            end
          end
        end
        false
      end

      # Current ghost text preview suffix
      def current_ghost_text : String?
        if ac = @autocomplete
          if @cursor_pos == @value.size
            ac.ghost_text(@value)
          else
            nil
          end
        else
          nil
        end
      end

      # Handles a key event. Returns true if Enter was pressed (submission), false otherwise.
      def handle_key(event : Terminal::KeyEvent) : Bool
        case event.name.downcase
        when "enter"
          @history << @value unless @value.empty?
          @history_idx = -1
          return true
        when "tab"
          accept_autocomplete
        when "backspace"
          delete_backward
        when "delete"
          delete_forward
        when "left"
          move_left
        when "right"
          if @cursor_pos == @value.size
            accept_autocomplete || move_right
          else
            move_right
          end
        when "home"
          move_start
        when "end"
          move_end
        when "up"
          navigate_history(-1)
        when "down"
          navigate_history(1)
        when "w"
          if event.ctrl?
            delete_last_word
          elsif ch = event.char
            insert(ch)
          end
        else
          if ch = event.char
            insert(ch) if ch >= ' ' && !event.ctrl? && !event.alt?
          end
        end

        false
      end

      # Interactively reads user input until Enter is pressed, drawing in-place updates and ghost text.
      def read_line(driver : Terminal::Driver? = nil) : String
        term = driver || Terminal.default_driver
        prompt_style = Style.new.bold.fg(:cyan)
        dim_style = Style.new.faint

        term.raw_mode do
          loop do
            # Compute ghost text suffix
            ghost = current_ghost_text
            ghost_str = ghost ? dim_style.render(ghost) : ""

            # Render line
            term.write("\r\e[2K")
            term.write("#{prompt_style.render(@prompt)}#{@value}#{ghost_str}")

            # Position cursor at exact position
            prompt_w = VisualWidth.width(@prompt)
            cursor_col = prompt_w + @cursor_pos + 1
            term.write("\r\e[#{cursor_col}C") if cursor_col > 1
            term.flush

            event = term.read_event
            case event
            when Terminal::KeyEvent
              if event.name == "c" && event.ctrl?
                term.write("\n")
                term.flush
                exit 130
              end

              submitted = handle_key(event)
              if submitted
                term.write("\r\e[2K#{prompt_style.render(@prompt)}#{@value}\n")
                term.flush
                return @value
              end
            end
          end
        end

        @value
      end

      private def navigate_history(delta : Int32) : Nil
        return if @history.empty?

        if @history_idx == -1
          @history_idx = delta < 0 ? @history.size - 1 : 0
        else
          @history_idx = (@history_idx + delta).clamp(0, @history.size - 1)
        end

        @value = @history[@history_idx]
        @cursor_pos = @value.size
      end

      private def delete_last_word : Nil
        return if @cursor_pos <= 0
        idx = @cursor_pos - 1

        # Skip trailing spaces
        while idx >= 0 && @value[idx] == ' '
          idx -= 1
        end

        # Find word boundary
        while idx >= 0 && @value[idx] != ' '
          idx -= 1
        end

        new_pos = idx + 1
        @value = @value[0...new_pos] + @value[@cursor_pos..]
        @cursor_pos = new_pos
      end
    end
  end

  # Convenience DSL to prompt with tab autocomplete and ghost text
  def self.prompt_autocomplete(
    prompt : String = "> ",
    candidates : Array(String) = [] of String,
    driver : Terminal::Driver? = nil,
    &block : Input::Autocomplete -> Nil
  ) : String
    ti = Input::TextInput.new(prompt: prompt)
    ti.autocomplete(&block)
    ti.read_line(driver)
  end

  def self.prompt_autocomplete(
    prompt : String = "> ",
    candidates : Array(String) = [] of String,
    driver : Terminal::Driver? = nil,
  ) : String
    ti = Input::TextInput.new(prompt: prompt)
    ti.autocomplete { |ac| ac.candidates(candidates) }
    ti.read_line(driver)
  end
end

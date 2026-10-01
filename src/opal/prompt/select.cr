require "../style"
require "../terminal"

module Opal
  module Prompt
    # Interactive single-selection menu driven by arrow keys.
    class Select
      def self.run(
        question : String,
        options : Array(String),
        default_index : Int32 = 0,
        driver : Terminal::Driver? = nil,
      ) : String
        return "" if options.empty?

        term = driver || Terminal.default_driver
        q_style = Style.new.bold.fg(:cyan)
        check_style = Style.new.bold.fg(:green)
        selected_style = Style.new.bold.fg(:cyan)
        dim_style = Style.new.faint

        selected_idx = default_index.clamp(0, options.size - 1)
        first_render = true

        selected_val = term.raw_mode do
          term.hide_cursor
          loop do
            # Render menu
            lines = IO::Memory.new

            # If not first render, move cursor back up to overwrite
            unless first_render
              term.write(Terminal::Screen.move_up(options.size + 1))
            end
            first_render = false

            lines.puts "#{q_style.render("?")} #{question}: #{dim_style.render("(Use arrow keys or j/k)")}"
            options.each_with_index do |opt, idx|
              if idx == selected_idx
                lines.puts "  #{selected_style.render("> #{opt}")}"
              else
                lines.puts "    #{dim_style.render(opt)}"
              end
            end

            term.write(lines.to_s)
            term.flush

            event = term.read_event
            case event
            when Terminal::KeyEvent
              case event.name.downcase
              when "up", "k"
                selected_idx = (selected_idx - 1) % options.size
              when "down", "j"
                selected_idx = (selected_idx + 1) % options.size
              when "enter"
                break options[selected_idx]
              when "ctrl+c"
                term.show_cursor
                term.write("\n")
                term.flush
                exit 130
              end
            end
          end
        ensure
          term.show_cursor
        end

        # Overwrite with clean final result
        term.write(Terminal::Screen.move_up(options.size + 1))
        term.write(Terminal::Screen::CLEAR_LINE)
        term.write("#{check_style.render("[OK]")} #{question}: #{selected_style.render(selected_val)}\n")
        # Clear the old option lines below
        options.size.times do
          term.write(Terminal::Screen::CLEAR_LINE + "\n")
        end
        term.write(Terminal::Screen.move_up(options.size))
        term.flush

        selected_val
      end
    end
  end
end

require "../style"
require "../terminal"

module Opal
  module Prompt
    # Interactive multiple-selection menu with checkbox toggling.
    class MultiSelect
      def self.run(
        question : String,
        options : Array(String),
        default_indices : Array(Int32) = [] of Int32,
        driver : Terminal::Driver? = nil,
      ) : Array(String)
        return [] of String if options.empty?

        term = driver || Terminal.default_driver
        q_style = Style.new.bold.fg(:cyan)
        check_style = Style.new.bold.fg(:green)
        selected_style = Style.new.bold.fg(:cyan)
        dim_style = Style.new.faint

        selected_set = Set(Int32).new(default_indices)
        cursor_idx = 0
        first_render = true

        final_selected = term.raw_mode do
          term.hide_cursor
          loop do
            # Render menu
            lines = IO::Memory.new

            unless first_render
              term.write(Terminal::Screen.move_up(options.size + 1))
            end
            first_render = false

            lines.puts "#{q_style.render("?")} #{question}: #{dim_style.render("(Space to toggle, 'a' all, Enter to confirm)")}"

            options.each_with_index do |opt, idx|
              is_checked = selected_set.includes?(idx)
              box = is_checked ? check_style.render("[✓]") : dim_style.render("[ ]")
              cursor = (idx == cursor_idx) ? selected_style.render("❯") : " "

              line_text = if idx == cursor_idx
                            "  #{cursor} #{box} #{selected_style.render(opt)}"
                          else
                            "  #{cursor} #{box} #{opt}"
                          end
              lines.puts line_text
            end

            term.write(lines.to_s)
            term.flush

            event = term.read_event
            case event
            when Terminal::KeyEvent
              case event.name.downcase
              when "up", "k"
                cursor_idx = (cursor_idx - 1) % options.size
              when "down", "j"
                cursor_idx = (cursor_idx + 1) % options.size
              when "space", " "
                if selected_set.includes?(cursor_idx)
                  selected_set.delete(cursor_idx)
                else
                  selected_set.add(cursor_idx)
                end
              when "a"
                if selected_set.size == options.size
                  selected_set.clear
                else
                  options.size.times { |i| selected_set.add(i) }
                end
              when "i"
                options.size.times do |i|
                  if selected_set.includes?(i)
                    selected_set.delete(i)
                  else
                    selected_set.add(i)
                  end
                end
              when "enter"
                break selected_set.map { |i| options[i] }.to_a
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

        # Overwrite with clean final summary
        term.write(Terminal::Screen.move_up(options.size + 1))
        term.write(Terminal::Screen::CLEAR_LINE)
        term.write("#{check_style.render("✓")} #{question}: #{selected_style.render(final_selected.join(", "))}\n")
        options.size.times do
          term.write(Terminal::Screen::CLEAR_LINE + "\n")
        end
        term.write(Terminal::Screen.move_up(options.size))
        term.flush

        final_selected
      end
    end
  end
end

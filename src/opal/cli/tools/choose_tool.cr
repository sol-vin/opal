require "../../ui/buffer"
require "../../terminal/driver"
require "../command"

module Opal
  module CLI
    module Tools
      module ChooseTool
        def self.register(cmd : Command)
          cmd.summary "Choose an option from a list of choices and output selection to STDOUT"
          cmd.description "Interactive selection menu similar to 'gum choose' and 'fzf'. Displays on STDERR, emitting the chosen line strictly to STDOUT."

          cmd.arg :items, "List items to choose from (or pipe from STDIN)", required: false

          cmd.group "Appearance" do
            cmd.opt :header, "-H, --header=TEXT", "Header title above options list"
            cmd.opt :cursor, "-c, --cursor=GLYPH", "Cursor prefix glyph (default: '▶ ')", default: "▶ "
            cmd.opt :limit, "-l, --limit=N", "Maximum visible options", type: :int, default: 10
          end

          cmd.section "SHELL USAGE" do |s|
            s.example "BRANCH=$(git branch | opal choose --header 'Select branch')"
            s.example "CHOICE=$(opal choose apple banana cherry)"
            s.example "cat servers.txt | opal choose"
          end

          cmd.run do |ctx|
            options = Array(String).new

            # 1. Check positional args
            if !ctx.args.empty?
              options.concat(ctx.args.map(&.strip).reject(&.empty?))
            end

            # 2. Check STDIN if piped
            if options.empty? && !STDIN.tty?
              while line = STDIN.gets
                clean = line.strip
                options << clean unless clean.empty?
              end
            end

            if options.empty?
              STDERR.puts "\e[31mError:\e[0m No choices provided. Supply options as arguments or pipe lines to STDIN."
              next 1
            end

            header_text = ctx.string?(:header)
            cursor_glyph = ctx.string(:cursor)
            max_visible = ctx.int(:limit)

            selected_idx = 0
            confirmed = false
            drv = Terminal.default_driver(output: STDERR)

            render_frame = -> {
              w, h = drv.size
              buf = UI::Buffer.new(w, h)

              cur_y = 1
              if hdr = header_text
                buf.put_string(2, cur_y, hdr, fg: Color.cyan, bold: true)
                cur_y += 2
              end

              # Calculate scrolling window
              start_idx = 0
              if selected_idx >= max_visible
                start_idx = selected_idx - max_visible + 1
              end
              end_idx = Math.min(start_idx + max_visible, options.size)

              (start_idx...end_idx).each do |idx|
                is_sel = (idx == selected_idx)
                prefix = is_sel ? cursor_glyph : " " * cursor_glyph.size
                opt_str = "#{prefix}#{options[idx]}"
                fg_col = is_sel ? Color.bright_white : Color.white
                buf.put_string(2, cur_y, opt_str, fg: fg_col, bold: is_sel)
                cur_y += 1
              end

              cur_y += 1
              buf.put_string(2, cur_y, " [↑/↓, j/k] Navigate   [Enter] Select   [Esc] Cancel ", fg: Color.hex("#6272A4"))

              drv.write(Terminal::Screen::CLEAR_ALL)
              drv.write(Terminal::Screen.move_to(1, 1))
              drv.write(buf.to_s)
              drv.flush
            }

            drv.raw_mode do
              drv.hide_cursor
              render_frame.call

              loop do
                event = drv.read_event
                next unless event

                case event
                when Terminal::KeyEvent
                  if event.matches?("escape") || event.matches?("ctrl+c")
                    break
                  end

                  case event.name
                  when "up", "k"
                    selected_idx = (selected_idx - 1 + options.size) % options.size
                    render_frame.call
                  when "down", "j"
                    selected_idx = (selected_idx + 1) % options.size
                    render_frame.call
                  when "enter", "space"
                    confirmed = true
                    break
                  end
                end
              end
            ensure
              drv.show_cursor
            end

            if confirmed && selected_idx < options.size
              puts options[selected_idx]
              0
            else
              130
            end
          end
        end
      end
    end
  end
end

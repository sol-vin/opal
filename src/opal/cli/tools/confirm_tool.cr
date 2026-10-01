require "../../ui/buffer"
require "../../terminal/driver"
require "../command"

module Opal
  module CLI
    module Tools
      module ConfirmTool
        def self.register(cmd : Command)
          cmd.summary "Ask a confirmation prompt and exit 0 for Yes, 1 for No"
          cmd.description "Interactive Yes/No confirmation dialog similar to 'gum confirm'. Renders to STDERR, returning exit code 0 on confirmation and 1 on rejection."

          cmd.arg :prompt, "Confirmation question text", default: "Are you sure?"

          cmd.group "Options" do
            cmd.opt :affirmative, "-y, --affirmative=TEXT", "Affirmative label (default: 'Yes')", default: "Yes"
            cmd.opt :negative, "-n, --negative=TEXT", "Negative label (default: 'No')", default: "No"
            cmd.flag :default_no, "--default-no", description: "Default focus to No instead of Yes"
            cmd.flag :print, "-p, --print", description: "Print boolean true/false to STDOUT in addition to exit code"
          end

          cmd.section "SHELL USAGE" do |s|
            s.example "opal confirm 'Deploy to production?' && ./deploy.sh"
            s.example "if opal confirm 'Delete logs?'; then rm -rf /var/log/*.log; fi"
          end

          cmd.run do |ctx|
            prompt_text = ctx.arg(:prompt) || "Are you sure?"
            yes_lbl = ctx.string(:affirmative)
            no_lbl = ctx.string(:negative)
            selected_yes = !ctx.flag?(:default_no)
            confirmed = false
            completed = false

            drv = Terminal.default_driver(output: STDERR)

            render_frame = -> {
              w, h = drv.size
              buf = UI::Buffer.new(w, h)

              cur_y = 2
              buf.put_string(2, cur_y, prompt_text, fg: Color.bright_white, bold: true)
              cur_y += 2

              yes_btn = selected_yes ? "▶ [ #{yes_lbl} ]" : "  [ #{yes_lbl} ]"
              no_btn = !selected_yes ? "▶ [ #{no_lbl} ]" : "  [ #{no_lbl} ]"

              buf.put_string(2, cur_y, yes_btn, fg: selected_yes ? Color.hex("#50FA7B") : Color.white, bold: selected_yes)
              buf.put_string(4 + yes_btn.size, cur_y, no_btn, fg: !selected_yes ? Color.hex("#FF5555") : Color.white, bold: !selected_yes)

              cur_y += 2
              buf.put_string(2, cur_y, " [←/→, Tab] Switch   [Enter/Space] Confirm   [y/n] Direct choice   [Esc] Cancel ", fg: Color.hex("#6272A4"))

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
                    completed = true
                    confirmed = false
                    break
                  end

                  case event.name.downcase
                  when "left", "right", "tab", "h", "l"
                    selected_yes = !selected_yes
                    render_frame.call
                  when "y"
                    selected_yes = true
                    confirmed = true
                    completed = true
                    break
                  when "n"
                    selected_yes = false
                    confirmed = false
                    completed = true
                    break
                  when "enter", "space"
                    confirmed = selected_yes
                    completed = true
                    break
                  end
                end
              end
            ensure
              drv.show_cursor
            end

            if ctx.flag?(:print)
              puts confirmed ? "true" : "false"
            end

            confirmed ? 0 : 1
          end
        end
      end
    end
  end
end

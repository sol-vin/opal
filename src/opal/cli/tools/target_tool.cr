require "../../ui/components/target_selector_2d"
require "../../clipboard"
require "../command"

module Opal
  module CLI
    module Tools
      module TargetTool
        def self.register(cmd : Command)
          cmd.summary "Launch interactive 2D coordinate selector and output (x, y) to STDOUT"
          cmd.description "Interactive 2D Cartesian target pad with continuous domain mapping. Renders GUI to STDERR, outputting the confirmed coordinates strictly to STDOUT."

          cmd.group "Domain & Output" do
            cmd.opt :format, "-f, --format=FORMAT", "Output format (xy, json, csv, percent)", choices: ["xy", "json", "csv", "percent"], default: "xy"
            cmd.opt :min_x, "--min-x=VAL", "Minimum X boundary", type: :float, default: 0.0
            cmd.opt :max_x, "--max-x=VAL", "Maximum X boundary", type: :float, default: 1.0
            cmd.opt :min_y, "--min-y=VAL", "Minimum Y boundary", type: :float, default: 0.0
            cmd.opt :max_y, "--max-y=VAL", "Maximum Y boundary", type: :float, default: 1.0
          end

          cmd.group "Appearance" do
            cmd.opt :reticle, "-r, --reticle=CHAR", "Target reticle character (default: '⌖')", default: "⌖"
            cmd.flag :copy, "-c, --copy", description: "Copy selected coordinate to clipboard upon confirmation"
          end

          cmd.section "SHELL & PIPELINE USAGE" do |s|
            s.text "Capture 2D coordinates in bash/pwsh scripts:"
            s.example "COORDS=$(opal target --min-x -10 --max-x 10)"
            s.example "opal target -f json"
            s.example "read -r X Y <<< $(opal target)"
          end

          cmd.run do |ctx|
            x_min = ctx.float(:min_x)
            x_max = ctx.float(:max_x)
            y_min = ctx.float(:min_y)
            y_max = ctx.float(:max_y)
            reticle_str = ctx.string(:reticle)
            reticle_char = reticle_str.empty? ? '⌖' : reticle_str.chars.first

            drv = Terminal.default_driver(output: STDERR)
            selector = UI::TargetSelector2D.new(
              x_range: x_min..x_max,
              y_range: y_min..y_max,
              reticle_char: reticle_char,
              width: 36,
              height: 14
            )

            result : {Float64, Float64}? = nil

            render_frame = -> {
              w, h = drv.size
              buf = UI::Buffer.new(w, h)
              # Center selector in viewport
              sx = Math.max(0, (w - 36) // 2)
              sy = Math.max(0, (h - 14) // 2)
              selector.render(buf, sx, sy, 36, 14)

              # Hint bar
              buf.put_string(sx, sy + 14, " [Arrows/Drag] Move   [Shift] Fine   [Enter] Confirm   [Esc] Cancel ", fg: Color.hex("#6272A4"))

              drv.write(Terminal::Screen::CLEAR_ALL)
              drv.write(Terminal::Screen.move_to(1, 1))
              drv.write(buf.to_s)
              drv.flush
            }

            drv.raw_mode do
              drv.hide_cursor
              drv.enable_mouse
              render_frame.call

              loop do
                event = drv.read_event
                next unless event

                case event
                when Terminal::KeyEvent
                  if event.matches?("escape") || event.matches?("ctrl+c")
                    break
                  end

                  if selector.handle_key(event)
                    render_frame.call
                    if selector.confirmed?
                      result = {selector.x_val, selector.y_val}
                      break
                    end
                  end
                when Terminal::MouseEvent
                  if selector.handle_mouse(event)
                    render_frame.call
                    if selector.confirmed?
                      result = {selector.x_val, selector.y_val}
                      break
                    end
                  end
                end
              end
            ensure
              drv.disable_mouse
              drv.show_cursor
            end

            if result.nil?
              next 130
            end

            x_out, y_out = result.not_nil!
            formatted_output = case ctx.string(:format).downcase
                               when "json"
                                 sprintf("{\"x\": %.4f, \"y\": %.4f}", x_out, y_out)
                               when "csv"
                                 sprintf("%.4f,%.4f", x_out, y_out)
                               when "percent"
                                 u, v = selector.normalized_coords
                                 sprintf("%.1f%%, %.1f%%", u * 100, v * 100)
                               else
                                 sprintf("%.4f %.4f", x_out, y_out)
                               end

            if ctx.flag?(:copy)
              Opal.copy_to_clipboard(formatted_output, io: STDERR)
            end

            puts formatted_output
            0
          end
        end
      end
    end
  end
end

require "../../ui/components/color_picker"
require "../../clipboard"
require "../command"

module Opal
  module CLI
    module Tools
      module ColorPickerTool
        def self.register(cmd : Command)
          cmd.summary "Launch interactive TrueColor picker and output chosen color to STDOUT"
          cmd.description "Interactive terminal color picker supporting 8 color spaces (RGB, HSL, HSV, LAB, Oklab, XYZ, CMYK, Hex). Renders GUI to STDERR, outputting the confirmed color strictly to STDOUT for clean shell piping."

          cmd.group "Output & Mode" do
            cmd.opt :format, "-f, --format=FORMAT", "Output color format (hex, rgb, hsl, hsv, lab, oklab, cmyk, ansi, raw)", choices: ["hex", "rgb", "hsl", "hsv", "lab", "oklab", "cmyk", "ansi", "raw"], default: "hex"
            cmd.opt :mode, "-m, --mode=MODE", "Initial color space mode (rgb, hsl, hsv, lab, oklab, xyz, cmyk, hex)", choices: ["rgb", "hsl", "hsv", "lab", "oklab", "xyz", "cmyk", "hex"], default: "rgb"
            cmd.opt :initial, "-i, --initial=COLOR", "Initial color hex, e.g. '#89B4FA'", default: "#89B4FA"
          end

          cmd.group "Appearance & Integration" do
            cmd.opt :style, "-s, --style=LAYOUT", "Picker layout (studio, sliders, compact, palette)", choices: ["studio", "sliders", "compact", "palette"], default: "studio"
            cmd.flag :alpha, "-a, --alpha", description: "Enable alpha transparency channel slider"
            cmd.flag :copy, "-c, --copy", description: "Copy selected color to system clipboard upon confirmation"
            cmd.flag :no_harmonies, "--no-harmonies", description: "Hide complementary/analogous harmonies row"
          end

          cmd.section "SHELL & PIPELINE USAGE" do |s|
            s.text "Capture the selected color directly into an environment variable:"
            s.example "MY_COLOR=$(opal colorpicker)"
            s.example "MY_RGB=$(opal colorpicker -f rgb)"
            s.example "opal colorpicker -f hex --copy"
            s.example "opal colorpicker -m oklab -s compact"
          end

          cmd.run do |ctx|
            initial_hex = ctx.string(:initial)
            initial_color = Color.hex(initial_hex)
            initial_color = Color.hex("#89B4FA") if initial_color.none?

            mode_sym = case ctx.string(:mode).downcase
                       when "hsl"   then UI::ColorMode::HSL
                       when "hsv"   then UI::ColorMode::HSV
                       when "lab"   then UI::ColorMode::LAB
                       when "oklab" then UI::ColorMode::Oklab
                       when "xyz"   then UI::ColorMode::XYZ
                       when "cmyk"  then UI::ColorMode::CMYK
                       when "hex"   then UI::ColorMode::HEX
                       else              UI::ColorMode::RGB
                       end

            layout_sym = case ctx.string(:style).downcase
                         when "sliders" then UI::ColorPickerLayout::Sliders
                         when "compact" then UI::ColorPickerLayout::Compact
                         when "palette" then UI::ColorPickerLayout::PaletteOnly
                         else                UI::ColorPickerLayout::Studio
                         end

            show_harm = !ctx.flag?(:no_harmonies)
            show_alpha = ctx.flag?(:alpha)

            # Interactive driver renders on STDERR so STDOUT stays clean for variable capture
            picked_color = Opal.pick_color(
              initial: initial_color,
              mode: mode_sym,
              layout: layout_sym,
              show_harmonies: show_harm,
              show_select_button: true,
              output: STDERR
            )

            if picked_color.nil?
              # Cancelled / aborted by user
              next 130
            end

            c = picked_color.not_nil!
            formatted_output = format_color(c, ctx.string(:format))

            # Copy to clipboard if requested
            if ctx.flag?(:copy)
              Opal.copy_to_clipboard(formatted_output, io: STDERR)
            end

            # Output result strictly to STDOUT
            puts formatted_output
            0
          end
        end

        def self.format_color(color : Color, format : String) : String
          r, g, b = color.to_rgb
          case format.downcase
          when "hex"
            color.to_hex
          when "rgb"
            "rgb(#{r}, #{g}, #{b})"
          when "hsl"
            h, s, l = color.to_hsl
            sprintf("hsl(%.0f, %.0f%%, %.0f%%)", h, s * 100, l * 100)
          when "hsv"
            h, s, v = color.to_hsv
            sprintf("hsv(%.0f, %.0f%%, %.0f%%)", h, s * 100, v * 100)
          when "lab"
            l, a, b_val = color.to_lab
            sprintf("lab(%.1f, %.1f, %.1f)", l, a, b_val)
          when "oklab"
            l, a, b_val = color.to_oklab
            sprintf("oklab(%.2f, %.2f, %.2f)", l, a, b_val)
          when "cmyk"
            c, m, y, k = color.to_cmyk
            sprintf("cmyk(%.0f%%, %.0f%%, %.0f%%, %.0f%%)", c * 100, m * 100, y * 100, k * 100)
          when "ansi"
            "\e[38;2;#{r};#{g};#{b}m"
          when "raw"
            "#{r} #{g} #{b}"
          else
            color.to_hex
          end
        end
      end
    end
  end
end

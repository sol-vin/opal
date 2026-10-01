require "../../ui/components/palette"
require "../../clipboard"
require "../command"

module Opal
  module CLI
    module Tools
      module PaletteTool
        def self.register(cmd : Command)
          cmd.summary "Launch interactive color palette studio and export to STDOUT"
          cmd.description "Interactive terminal palette manager supporting Named and Indexed modes, color reordering via `[` and `]`, min/max constraints, embedded ColorPicker, and export to GPL, PAL, HEX, JSON, and CSS. Renders GUI to STDERR, outputting the confirmed palette strictly to STDOUT for clean shell piping."

          cmd.group "Mode & Format" do
            cmd.opt :mode, "-m, --mode=MODE", "Operating mode (indexed, named)", choices: ["indexed", "named"], default: "indexed"
            cmd.opt :format, "-f, --format=FORMAT", "Export palette format (hex, gpl, pal, json, css)", choices: ["hex", "gpl", "pal", "json", "css"], default: "hex"
            cmd.opt :input, "-i, --input=FILE", "Load initial palette from file (auto-detects format)"
            cmd.opt :output, "-o, --output=FILE", "Save exported palette to specified file destination"
            cmd.opt :name, "-n, --name=NAME", "Palette title/name metadata", default: "Opal Palette"
          end

          cmd.group "Restrictions & Permissions" do
            cmd.opt :min, "--min=COUNT", "Minimum allowed number of colors"
            cmd.opt :max, "--max=COUNT", "Maximum allowed number of colors"
            cmd.flag :no_add, "--no-add", description: "Disallow adding new colors or entries"
            cmd.flag :no_remove, "--no-remove", description: "Disallow deleting colors or entries"
            cmd.flag :no_reorder, "--no-reorder", description: "Disallow reordering colors"
          end

          cmd.group "Editor & Clipboard" do
            cmd.opt :picker_mode, "--picker-mode=MODE", "Initial color space for editor (rgb, hsl, hsv, lab, oklab, xyz, cmyk, hex)", choices: ["rgb", "hsl", "hsv", "lab", "oklab", "xyz", "cmyk", "hex"], default: "rgb"
            cmd.opt :picker_layout, "--picker-layout=LAYOUT", "ColorPicker layout (sliders, studio, compact)", choices: ["sliders", "studio", "compact"], default: "sliders"
            cmd.flag :copy, "-c, --copy", description: "Copy exported palette to system clipboard upon confirmation"
          end

          cmd.section "SHELL & PIPELINE USAGE" do |s|
            s.text "Capture exported palette directly into files or environment variables:"
            s.example "opal palette --format gpl > game_palette.gpl"
            s.example "opal palette --mode named --format json > theme.json"
            s.example "opal palette --min 4 --max 16 -f css"
            s.example "PAL_HEX=$(opal pal -f hex)"
          end

          cmd.run do |ctx|
            # Initialize or load model
            model = if input_file = ctx.string?(:input)
                      if File.exists?(input_file)
                        PaletteModel.from_file(input_file)
                      else
                        STDERR.puts "Error: Input file '#{input_file}' not found."
                        next 1
                      end
                    else
                      mode = ctx.string(:mode).downcase == "named" ? PaletteMode::Named : PaletteMode::Indexed
                      PaletteModel.new(mode: mode)
                    end

            # Apply restrictions
            if min_val = ctx.string?(:min).try(&.to_i?)
              model.min_colors = min_val
            end
            if max_val = ctx.string?(:max).try(&.to_i?)
              model.max_colors = max_val
            end

            model.allow_add = !ctx.flag?(:no_add)
            model.allow_remove = !ctx.flag?(:no_remove)
            model.allow_reorder = !ctx.flag?(:no_reorder)
            model.palette_name = ctx.string(:name)

            # Embedded picker configuration
            p_mode = case ctx.string(:picker_mode).downcase
                     when "hsl"   then UI::ColorMode::HSL
                     when "hsv"   then UI::ColorMode::HSV
                     when "lab"   then UI::ColorMode::LAB
                     when "oklab" then UI::ColorMode::Oklab
                     when "xyz"   then UI::ColorMode::XYZ
                     when "cmyk"  then UI::ColorMode::CMYK
                     when "hex"   then UI::ColorMode::HEX
                     else              UI::ColorMode::RGB
                     end

            p_layout = case ctx.string(:picker_layout).downcase
                       when "studio"  then UI::ColorPickerLayout::Studio
                       when "compact" then UI::ColorPickerLayout::Compact
                       else                UI::ColorPickerLayout::Sliders
                       end

            palette_ctrl = UI::Palette.new(
              model: model,
              picker_mode: p_mode,
              picker_layout: p_layout,
              title: ctx.string(:name)
            )

            # Interactive driver runs strictly on STDERR so STDOUT remains clean for pipes
            final_model = Opal.manage_palette(palette_ctrl, output: STDERR)

            if final_model.nil?
              # Cancelled by user
              next 130
            end

            # Export formatted string
            format_str = ctx.string(:format)
            export_content = final_model.export(format_str, name: ctx.string(:name))

            # Save to file if -o specified
            if out_path = ctx.string?(:output)
              File.write(out_path, export_content)
              STDERR.puts "Exported palette to #{out_path}"
            end

            # Copy to clipboard if requested
            if ctx.flag?(:copy)
              Opal.copy_to_clipboard(export_content, io: STDERR)
            end

            # Write clean result strictly to STDOUT
            puts export_content
            0
          end
        end
      end
    end
  end
end

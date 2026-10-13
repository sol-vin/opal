require "../../ui/components/input_remapper"
require "../../clipboard"
require "../command"

module Opal
  module CLI
    module Tools
      module RemapTool
        def self.register(cmd : Command)
          cmd.summary "Launch interactive input remapper studio or export binding profiles"
          cmd.description "Interactive terminal input remapping control for Opal TUIs, Lapis (Godot 4.8), and Citrine (PS2). Supports multi-slot bindings, conflict policies, gamepad glyph styles (DualShock, Xbox, Generic), and export to JSON, YAML, and Godot 4.8 [input] configuration."

          cmd.group "Profile & Format" do
            cmd.opt :format, "-f, --format=FORMAT", "Export format (json, yaml, lapis)", choices: ["json", "yaml", "lapis"], default: "json"
            cmd.opt :input, "-i, --input=FILE", "Load initial input profile from JSON/YAML file"
            cmd.opt :output, "-o, --output=FILE", "Save exported bindings to specified file destination"
            cmd.opt :name, "-n, --name=NAME", "Profile title/name metadata", default: "Default Controls"
            cmd.flag :print, "-p, --print", description: "Render static input table or export profile immediately without interactive TUI"
          end

          cmd.group "Gamepad & Conflict Policy" do
            cmd.opt :gamepad, "-g, --gamepad=STYLE", "Gamepad glyph convention (dualshock, xbox, generic)", choices: ["dualshock", "xbox", "generic"], default: "dualshock"
            cmd.opt :policy, "--policy=POLICY", "Duplicate binding conflict policy (allow, swap, replace, block)", choices: ["allow", "swap", "replace", "block"], default: "allow"
          end

          cmd.group "Clipboard" do
            cmd.flag :copy, "-c, --copy", description: "Copy exported profile to system clipboard upon confirmation"
          end

          cmd.section "SHELL & PIPELINE USAGE" do |s|
            s.text "Configure game or application bindings and pipe to JSON, YAML, or Lapis/Godot config:"
            s.example "opal remap --format json > controls.json"
            s.example "opal remap --gamepad dualshock --format lapis > input_map.cfg"
            s.example "opal remap --print --format yaml"
          end

          cmd.run do |ctx|
            model = if input_file = ctx.string?(:input)
                      if File.exists?(input_file)
                        Input::Core::InputRemapModel.from_file(input_file)
                      else
                        STDERR.puts "Error: Input file '#{input_file}' not found."
                        next 1
                      end
                    else
                      Input::Core::InputRemapModel.default_profile(ctx.string(:name))
                    end

            model.profile_name = ctx.string(:name)
            model.gamepad_style = Input::Core::GamepadStyle.parse_style(ctx.string(:gamepad))
            model.conflict_policy = Input::Core::ConflictPolicy.parse_policy(ctx.string(:policy))

            if ctx.flag?(:print)
              export_content = model.export(ctx.string(:format))
              if out_path = ctx.string?(:output)
                File.write(out_path, export_content)
              end
              puts export_content
              next 0
            end

            remapper = UI::InputRemapper.new(
              model: model,
              title: ctx.string(:name)
            )

            final_model = Opal.remap_inputs(remapper, output: STDERR)
            if final_model.nil?
              next 130
            end

            export_content = final_model.export(ctx.string(:format))

            if out_path = ctx.string?(:output)
              File.write(out_path, export_content)
              STDERR.puts "Exported input profile to #{out_path}"
            end

            if ctx.flag?(:copy)
              Opal.copy_to_clipboard(export_content, io: STDERR)
            end

            puts export_content
            0
          end
        end
      end
    end
  end
end

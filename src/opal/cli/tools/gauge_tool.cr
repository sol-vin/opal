require "../../ui/components/gauge"
require "../command"

module Opal
  module CLI
    module Tools
      module GaugeTool
        def self.register(cmd : Command)
          cmd.summary "Render a percentage progress bar gauge"
          cmd.description "Draws a responsive terminal progress bar with dynamic threshold colors (green/yellow/red) and custom labels."

          cmd.arg :value, "Value (e.g. '75%', '0.75', '45'), or '-' for stdin", required: false

          cmd.group "Appearance & Scaling" do
            cmd.opt :label, "-l, --label=LABEL", "Progress label prefix"
            cmd.opt :color, "-c, --color=COLOR", "Fill color override"
            cmd.opt :max, "--max=N", "Maximum value ceiling (for raw numbers)", type: :float
            cmd.opt :width, "-w, --width=N", "Gauge width in columns", type: :int
          end

          cmd.section "PIPELINE COMPOSITION" do |s|
            s.example "opal gauge 78% --label 'Uploading'"
            s.example "echo 0.42 | opal gauge -l 'Battery'"
            s.example "opal gauge 85 --max 100 -l 'Disk'"
          end

          cmd.run do |ctx|
            raw = ctx.read_input_or_arg(:value)
            if raw.nil? || raw.strip.empty?
              STDERR.puts "\e[31mError:\e[0m No value provided. Pass a value or percentage via argument or STDIN."
              next 1
            end

            trimmed = raw.strip
            ratio : Float64 = if trimmed.ends_with?('%')
              (trimmed[0...-1].to_f64? || 0.0) / 100.0
            elsif (num = trimmed.to_f64?)
              if max_val = ctx.float?(:max)
                num / max_val
              elsif num > 1.0
                num / 100.0
              else
                num
              end
            else
              0.0
            end

            label = ctx.string?(:label)
            color = ctx.string?(:color)
            width = ctx.int?(:width)

            UI::Gauge.print(
              ratio: ratio,
              label: label,
              color: color,
              width: width
            )
            0
          end
        end
      end
    end
  end
end

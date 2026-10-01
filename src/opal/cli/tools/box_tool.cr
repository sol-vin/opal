require "../../ui/components/box"
require "../command"

module Opal
  module CLI
    module Tools
      module BoxTool
        def self.register(cmd : Command)
          cmd.summary "Wrap text or piped data inside a styled terminal box"
          cmd.description "Surrounds arbitrary multi-line text or piped STDIN with Unicode border frames, padding, and titles."

          cmd.arg :text, "Text to frame, or '-' for stdin", required: false, multiple: true

          cmd.group "Appearance & Style" do
            cmd.opt :title, "-t, --title=TITLE", "Header title embedded in top border"
            cmd.opt :style, "-s, --style=STYLE", "Border style (rounded, single, double, thick, ascii)", choices: ["rounded", "single", "double", "thick", "ascii"], default: "rounded"
            cmd.opt :color, "-c, --color=COLOR", "Border color", default: "cyan"
            cmd.opt :padding, "-p, --padding=N", "Inner padding spaces", default: 1, type: :int
            cmd.opt :width, "-w, --width=N", "Explicit box width override", type: :int
            cmd.opt :theme, "--theme=NAME", "Apply Opal color palette"
          end

          cmd.section "PIPELINE COMPOSITION" do |s|
            s.example "echo 'Deployment Succeeded!' | opal box -t 'Status' -c green -s rounded"
            s.example "opal box 'Error: Database connection failed' -t 'FATAL' -c red -s thick"
          end

          cmd.run do |ctx|
            args_list = ctx.arg_list(:text)
            raw = if !args_list.empty? && args_list != ["-"]
                    args_list.join(' ')
                  else
                    ctx.read_input_or_arg
                  end

            if raw.nil? || raw.strip.empty?
              STDERR.puts "\e[31mError:\e[0m No text provided. Pass text as argument or pipe via STDIN."
              next 1
            end

            raw = InputReader.clean(raw)

            title = ctx.string?(:title)
            style_str = ctx.string(:style)
            b_style : Border | Symbol | String = case style_str
            when "ascii"  then :ascii
            when "single" then :single
            when "double" then :double
            when "thick"  then :thick
            else               :rounded
            end

            color = ctx.string(:color)
            padding = ctx.int(:padding)
            width = ctx.int?(:width)
            theme_name = ctx.string?(:theme)
            th = theme_name ? Theme.find(theme_name) : nil

            UI::Box.print(
              text: raw.strip,
              title: title,
              border: b_style,
              border_fg: Color.from(color),
              padding: padding,
              width: width,
              theme: th
            )
            0
          end
        end
      end
    end
  end
end

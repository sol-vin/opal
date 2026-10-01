require "../../ui/markdown/renderer"
require "../command"

module Opal
  module CLI
    module Tools
      module MarkdownTool
        def self.register(cmd : Command)
          cmd.summary "Render Markdown documents and text with rich terminal styling"
          cmd.description "Parses GitHub-flavored Markdown text and renders beautifully styled terminal ANSI output, including colored headers, bold/italic, code blocks, lists, and tables."
          cmd.alias_name "md"

          cmd.arg :file, "Markdown file path, string content, or '-' for stdin", required: false

          cmd.group "Formatting Options" do
            cmd.opt :width, "-w, --width=N", "Wrap width in columns (default: terminal width)", type: :int
          end

          cmd.section "PIPELINE COMPOSITION" do |s|
            s.example "opal markdown README.md"
            s.example "curl -s https://raw.githubusercontent.com/.../README.md | opal md"
            s.example "opal md '# Hello World\\nThis is **bold** text.'"
          end

          cmd.run do |ctx|
            raw = ctx.read_input_or_arg(:file)
            if raw.nil? || raw.strip.empty?
              STDERR.puts "\e[31mError:\e[0m No markdown content provided. Provide a file path or pipe via STDIN."
              next 1
            end

            width = ctx.int?(:width)
            UI::Markdown.print(raw, width: width)
            0
          end
        end
      end
    end
  end
end

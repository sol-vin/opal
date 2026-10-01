require "../../ui/components/badge"
require "../../ui/components/rule"
require "../../ui/components/code_view"
require "../command"

module Opal
  module CLI
    module Tools
      module MiscTools
        # Registers `opal badge`
        def self.register_badge(cmd : Command)
          cmd.summary "Render a highlighted tag badge or pill"
          cmd.description "Draws compact, high-contrast status tags with custom background and foreground colors."

          cmd.arg :label, "Badge text or label", required: true
          cmd.arg :sub_label, "Optional secondary status value", required: false

          cmd.group "Appearance" do
            cmd.opt :bg, "-b, --bg=COLOR", "Background color (green, red, yellow, blue, magenta, etc.)", default: "blue"
            cmd.opt :color, "-c, --color=COLOR", "Alias for background color"
            cmd.opt :fg, "--fg=COLOR", "Foreground text color", default: "white"
            cmd.flag :bold, "--bold", description: "Bold font style", default: true
          end

          cmd.run do |ctx|
            lbl = ctx.arg!(:label)
            bg_val = ctx.string?(:color) || ctx.string(:bg)
            if sub = ctx.arg(:sub_label)
              # Dual pill: [ LABEL | VALUE ]
              bg1 = Color.from(:bright_black)
              bg2 = Color.from(bg_val)
              fg1 = Color.white
              fg2 = Color.from(ctx.string(:fg))

              part1 = Opal.style.bg(bg1).fg(fg1).bold.render(" #{lbl} ")
              part2 = Opal.style.bg(bg2).fg(fg2).bold.render(" #{sub} ")
              puts "#{part1}#{part2}"
            else
              UI::Badge.print(
                label: lbl,
                bg: bg_val,
                fg: ctx.string(:fg),
                bold: ctx.flag?(:bold)
              )
              puts
            end
            0
          end
        end

        # Registers `opal rule`
        def self.register_rule(cmd : Command)
          cmd.summary "Print a terminal divider rule with optional centered text"
          cmd.description "Draws a horizontal rule across the terminal with customizable glyphs and alignment."

          cmd.arg :text, "Optional title text embedded in divider", required: false

          cmd.group "Appearance" do
            cmd.opt :char, "--char=CHAR", "Divider character (default: '─')", default: "─"
            cmd.opt :color, "-c, --color=COLOR", "Rule color", default: "cyan"
            cmd.opt :align, "-a, --align=ALIGN", "Text alignment (center, left, right)", choices: ["center", "left", "right"], default: "center"
            cmd.opt :width, "-w, --width=N", "Explicit rule width", type: :int
          end

          cmd.run do |ctx|
            text = ctx.arg(:text)
            char = ctx.string(:char).chars.first? || '─'
            color = ctx.string(:color)
            align = case ctx.string(:align)
                    when "left"  then :left
                    when "right" then :right
                    else              :center
                    end
            width = ctx.int?(:width)

            UI::Rule.print(
              text: text,
              char: char,
              fg: color,
              align: align,
              width: width
            )
            0
          end
        end

        # Registers `opal code`
        def self.register_code(cmd : Command)
          cmd.summary "Render syntax-highlighted source code with line numbers"
          cmd.description "Formats source code with keywords, strings, comments, and gutter numbers."

          cmd.arg :file, "Source file path or '-' for stdin", required: false

          cmd.group "Display Options" do
            cmd.opt :lang, "-l, --lang=LANG", "Syntax language (crystal, c, asm, plain)", choices: ["crystal", "c", "asm", "plain"], default: "plain"
            cmd.flag :no_numbers, "--no-numbers", description: "Hide line numbers"
            cmd.opt :start_line, "--start-line=N", "Starting line number offset", default: 1, type: :int
            cmd.opt :width, "-w, --width=N", "Code view width override", type: :int
          end

          cmd.run do |ctx|
            raw = ctx.read_input_or_arg(:file)
            if raw.nil? || raw.strip.empty?
              STDERR.puts "\e[31mError:\e[0m No code provided. Provide a file path or pipe via STDIN."
              next 1
            end

            lang_str = ctx.string(:lang)
            # Auto-detect language from extension if file argument provided
            if lang_str == "plain" && (file_arg = ctx.arg(:file))
              ext = File.extname(file_arg)
              lang_str = case ext
                         when ".cr"        then "crystal"
                         when ".c", ".h"   then "c"
                         when ".s", ".asm" then "asm"
                         else                   "plain"
                         end
            end

            lang_sym = case lang_str
                       when "crystal"  then :crystal
                       when "c"        then :c
                       when "asm", "s" then :asm
                       else                 :plain
                       end

            UI::CodeView.print(
              code: raw,
              language: lang_sym,
              show_line_numbers: !ctx.flag?(:no_numbers),
              start_line: ctx.int(:start_line),
              width: ctx.int?(:width)
            )
            0
          end
        end

        # Registers `opal diff`
        def self.register_diff(cmd : Command)
          cmd.summary "Compare two files with colored terminal diff formatting"
          cmd.description "Produces unified colored diff output highlighting additions in green and deletions in red."

          cmd.arg :file_a, "Original file path", required: true
          cmd.arg :file_b, "Modified file path", required: true

          cmd.run do |ctx|
            path_a = ctx.arg!(:file_a)
            path_b = ctx.arg!(:file_b)

            unless File.exists?(path_a)
              STDERR.puts "\e[31mError:\e[0m File not found: '#{path_a}'"
              next 1
            end

            unless File.exists?(path_b)
              STDERR.puts "\e[31mError:\e[0m File not found: '#{path_b}'"
              next 1
            end

            lines_a = File.read_lines(path_a)
            lines_b = File.read_lines(path_b)

            puts Opal.style.bold.fg(:cyan).render("--- #{path_a}")
            puts Opal.style.bold.fg(:cyan).render("+++ #{path_b}")

            max_len = Math.max(lines_a.size, lines_b.size)
            max_len.times do |i|
              line_a = lines_a[i]?
              line_b = lines_b[i]?

              if line_a == line_b
                puts Opal.style.faint.render("  #{line_a}")
              else
                puts Opal.style.fg(:red).render("- #{line_a}") if line_a
                puts Opal.style.fg(:green).render("+ #{line_b}") if line_b
              end
            end
            0
          end
        end
      end
    end
  end
end

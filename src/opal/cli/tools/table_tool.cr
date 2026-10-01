require "./input_reader"
require "../../ui/components/table"
require "../command"

module Opal
  module CLI
    module Tools
      module TableTool
        def self.register(cmd : Command)
          cmd.summary "Format CSV, TSV, JSON, Markdown, or space-delimited text into styled terminal tables"
          cmd.description "Reads structured data from a file, argument, or piped STDIN, auto-detects the format (CSV, TSV, JSON, Markdown, whitespace), and renders a responsive, aligned terminal table."

          cmd.arg :file, "Input data file, inline string, or '-' for stdin", required: false

          cmd.group "Data & Parsing" do
            cmd.opt :format, "-f, --format=FMT", "Data format (auto, csv, tsv, json, markdown, words)", choices: ["auto", "csv", "tsv", "json", "markdown", "words"], default: "auto"
            cmd.opt :delimiter, "-d, --delimiter=CHAR", "Field delimiter override (e.g. ',', '\t', '|', ':')"
            cmd.opt :headers, "-H, --headers=LIST", "Custom comma-separated header names"
            cmd.flag :no_headers, "--no-headers", description: "Treat all input lines as data (generate column headers)"
            cmd.opt :limit, "-n, --limit=N", "Maximum rows to render", type: :int
          end

          cmd.group "Appearance & Style" do
            cmd.opt :style, "-s, --style=STYLE", "Border style (rounded, ascii, markdown, double, thick, minimal, blank)", choices: ["rounded", "ascii", "markdown", "double", "thick", "minimal", "blank"], default: "rounded"
            cmd.flag :zebra, "-z, --zebra", description: "Enable alternating row shading"
            cmd.opt :theme, "--theme=NAME", "Apply Opal color palette (nord, dracula, catppuccin_mocha, etc.)"
            cmd.opt :width, "-w, --max-width=N", "Explicit table width override", type: :int
          end

          cmd.section "PIPELINE COMPOSITION" do |s|
            s.text "Pipe directly from other Unix command-line utilities:"
            s.example "ps aux | head -n 15 | opal table --zebra"
            s.example "cat metrics.csv | opal table -s rounded -z"
            s.example "curl -s https://api.github.com/repos/crystal-lang/crystal/releases | opal table -n 5"
          end

          cmd.run do |ctx|
            raw = ctx.read_input_or_arg(:file)
            if raw.nil? || raw.strip.empty?
              STDERR.puts "\e[31mError:\e[0m No input provided. Pipe data into STDIN or provide a file path."
              STDERR.puts "Run 'opal table --help' for usage and examples."
              next 1
            end

            fmt_str = ctx.string(:format)
            format_sym = case fmt_str
                         when "csv"      then :csv
                         when "tsv"      then :tsv
                         when "json"     then :json
                         when "markdown" then :markdown
                         when "words"    then :words
                         else                 :auto
                         end
            delimiter = ctx.string?(:delimiter)
            no_headers = ctx.flag?(:no_headers)

            custom_headers = ctx.string?(:headers).try(&.split(',').map(&.strip))

            headers, rows = InputReader.parse_table_data(
              content: raw,
              format: format_sym,
              delimiter: delimiter,
              custom_headers: custom_headers,
              no_headers: no_headers
            )

            if headers.empty? && rows.empty?
              STDERR.puts "\e[33mWarning:\e[0m No tabular data could be parsed from input."
              next 0
            end

            # Apply row limit if specified
            if limit = ctx.int?(:limit)
              rows = rows.first(limit) if limit > 0
            end

            # Border style
            style_str = ctx.string(:style)
            b_style : Border | Symbol | String = case style_str
            when "ascii"    then :ascii
            when "double"   then :double
            when "thick"    then :thick
            when "markdown" then :ascii
            when "minimal"  then :single
            when "blank"    then :hidden
            else                 :rounded
            end

            theme_name = ctx.string?(:theme)
            th = theme_name ? Theme.find(theme_name) : nil

            width_override = ctx.int?(:width)

            tbl = UI::Table.new(
              headers: headers,
              rows: rows,
              zebra: ctx.flag?(:zebra),
              border_style: b_style
            )

            tbl.print(width: width_override, theme: th)
            0
          end
        end
      end
    end
  end
end

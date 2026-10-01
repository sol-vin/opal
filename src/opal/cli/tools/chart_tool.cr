require "./input_reader"
require "../../ui/components/sparkline"
require "../../ui/components/barchart"
require "../../ui/components/line_graph"
require "../../ui/components/pie_chart"
require "../command"

module Opal
  module CLI
    module Tools
      module ChartTool
        # Registers the unified `opal chart` command with subcommands
        def self.register_chart(cmd : Command)
          cmd.summary "Visualize data with terminal sparklines, bar charts, line graphs, and pie charts"
          cmd.description "High-performance ASCII/Unicode data visualization suite for terminal dashboards and shell pipelines."

          cmd.command :sparkline, "Render inline Unicode block sparklines from numeric streams" do |sub|
            register_sparkline(sub)
          end

          cmd.command :bar, "Render horizontal bar charts from key-value pairs" do |sub|
            register_barchart(sub)
          end

          cmd.command :line, "Render 2D Cartesian line plots for numeric time series" do |sub|
            register_linegraph(sub)
          end

          cmd.command :pie, "Render circular or donut pie charts with TrueColor slice legends" do |sub|
            register_piechart(sub)
          end
        end

        # Registers `opal sparkline`
        def self.register_sparkline(cmd : Command)
          cmd.summary "Render Unicode block sparklines from numbers or piped data streams"
          cmd.description "Generates compact Unicode block sparklines ( ▂▃▄▅▆▇█) from arguments or piped numbers."

          cmd.arg :numbers, "Numeric data points, or '-' for stdin", required: false, multiple: true

          cmd.group "Appearance & Scaling" do
            cmd.opt :title, "-t, --title=TITLE", "Optional sparkline title"
            cmd.opt :color, "-c, --color=COLOR", "Sparkline color (cyan, green, yellow, magenta, etc.)", default: "cyan"
            cmd.opt :min, "--min=N", "Minimum scaling floor", type: :float
            cmd.opt :max, "--max=N", "Maximum scaling ceiling", type: :float
            cmd.opt :width, "-w, --width=N", "Max visible data points", type: :int
          end

          cmd.section "PIPELINE COMPOSITION" do |s|
            s.example "echo '1 5 22 13 53 12 60' | opal sparkline"
            s.example "seq 1 30 | opal sparkline -c green -t 'Trending Up'"
            s.example "opal sparkline 10 20 45 80 60 30 15 --title 'Memory Usage'"
          end

          cmd.run do |ctx|
            args_list = ctx.arg_list(:numbers)
            raw = if !args_list.empty? && args_list != ["-"]
                    args_list.join(' ')
                  else
                    ctx.read_input_or_arg
                  end

            if raw.nil? || raw.strip.empty?
              STDERR.puts "\e[31mError:\e[0m No numeric data provided. Pass numbers as arguments or pipe via STDIN."
              next 1
            end

            data = InputReader.parse_numeric_stream(raw)
            if data.empty?
              STDERR.puts "\e[31mError:\e[0m Could not extract numeric values from input."
              next 1
            end

            title = ctx.string?(:title)
            color = ctx.string(:color)
            min = ctx.float?(:min)
            max = ctx.float?(:max)
            width = ctx.int?(:width)

            UI::Sparkline.print(
              data: data,
              title: title,
              color: color,
              min: min,
              max: max,
              width: width
            )
            0
          end
        end

        # Registers `opal barchart`
        def self.register_barchart(cmd : Command)
          cmd.summary "Render horizontal bar charts with labels and percentage scaling"
          cmd.description "Draws horizontal Unicode bar charts from key:value arguments, TSV, CSV, or JSON streams."

          cmd.arg :pairs, "Key:value pairs (e.g. 'Apple:42' 'Banana:18'), or '-' for stdin", required: false, multiple: true

          cmd.group "Appearance & Formatting" do
            cmd.opt :title, "-t, --title=TITLE", "Chart title"
            cmd.opt :char, "--char=CHAR", "Bar glyph character (default: '█')", default: "█"
            cmd.opt :color, "-c, --color=COLOR", "Bar color (cyan, green, yellow, magenta, etc.)", default: "cyan"
            cmd.opt :max, "--max=N", "Maximum scale ceiling", type: :float
            cmd.opt :width, "-w, --width=N", "Total chart width override", type: :int
          end

          cmd.section "PIPELINE COMPOSITION" do |s|
            s.example "echo -e 'Apple\t42\nBanana\t18\nCherry\t65' | opal barchart --title 'Fruit Stock'"
            s.example "opal barchart 'CPU:45' 'RAM:78' 'Disk:22' -c yellow"
            s.example "cat stats.json | opal barchart"
          end

          cmd.run do |ctx|
            args_list = ctx.arg_list(:pairs)
            raw = if !args_list.empty? && args_list != ["-"]
                    args_list.join('\n')
                  else
                    ctx.read_input_or_arg
                  end

            if raw.nil? || raw.strip.empty?
              STDERR.puts "\e[31mError:\e[0m No data provided. Pass 'label:value' pairs or pipe via STDIN."
              next 1
            end

            parsed_pairs = InputReader.parse_key_value_pairs(raw)
            if parsed_pairs.empty?
              STDERR.puts "\e[31mError:\e[0m Could not parse any label:value pairs from input."
              next 1
            end

            title = ctx.string?(:title)
            bar_color = Color.from(ctx.string(:color))
            bar_char = ctx.string(:char).chars.first? || '█'
            max_val = ctx.float?(:max)
            width = ctx.int?(:width)

            items = parsed_pairs.map do |k, v|
              UI::BarItem.new(k, v, color: bar_color)
            end

            UI::BarChart.print(
              items: items,
              title: title,
              bar_char: bar_char,
              max_value: max_val,
              width: width
            )
            0
          end
        end

        # Registers `opal linegraph`
        def self.register_linegraph(cmd : Command)
          cmd.summary "Render 2D Cartesian line graphs for numeric series"
          cmd.description "Plots smooth connected curves with axes, ticks, and legend from CSV or space-delimited time series."

          cmd.arg :file, "Input data file or '-' for stdin", required: false

          cmd.group "Appearance & Dimensions" do
            cmd.opt :title, "-t, --title=TITLE", "Graph title"
            cmd.opt :height, "-H, --height=N", "Graph height in terminal lines", default: 14, type: :int
            cmd.opt :width, "-w, --width=N", "Graph width in terminal columns", type: :int
            cmd.opt :min_y, "--min-y=N", "Minimum Y axis value", type: :float
            cmd.opt :max_y, "--max-y=N", "Maximum Y axis value", type: :float
            cmd.flag :no_grid, "--no-grid", description: "Hide background grid"
            cmd.flag :no_legend, "--no-legend", description: "Hide series legend"
          end

          cmd.section "PIPELINE COMPOSITION" do |s|
            s.example "cat timeseries.csv | opal linegraph --title 'CPU Activity'"
            s.example "seq 1 40 | awk '{print sin($1/5)*20 + 25}' | opal linegraph"
          end

          cmd.run do |ctx|
            raw = ctx.read_input_or_arg(:file)
            if raw.nil? || raw.strip.empty?
              STDERR.puts "\e[31mError:\e[0m No data provided. Pipe numbers or CSV via STDIN."
              next 1
            end

            # Try parsing as table with series columns first
            headers, rows = InputReader.parse_table_data(raw)
            series_list = [] of UI::LineSeries
            palette = [Color.cyan, Color.green, Color.yellow, Color.magenta, Color.blue]

            if !headers.empty? && !rows.empty?
              # Multi-series from columns
              headers.each_with_index do |h, col_idx|
                data = rows.compact_map { |r| r[col_idx]?.try(&.to_f64?) }
                next if data.empty?
                c = palette[series_list.size % palette.size]
                series_list << UI::LineSeries.new(h, data, c)
              end
            end

            # Fallback to single numeric stream if no table columns found
            if series_list.empty?
              nums = InputReader.parse_numeric_stream(raw)
              if nums.empty?
                STDERR.puts "\e[31mError:\e[0m Could not parse any numeric series."
                next 1
              end
              series_list << UI::LineSeries.new(ctx.string?(:title) || "Series 1", nums, Color.cyan)
            end

            title = ctx.string?(:title)
            height = ctx.int(:height)
            width = ctx.int?(:width)
            min_y = ctx.float?(:min_y)
            max_y = ctx.float?(:max_y)

            UI::LineGraph.print(
              series: series_list,
              title: title,
              height: height,
              width: width,
              min_y: min_y,
              max_y: max_y,
              show_grid: !ctx.flag?(:no_grid),
              show_legend: !ctx.flag?(:no_legend)
            )
            0
          end
        end

        # Registers `opal piechart`
        def self.register_piechart(cmd : Command)
          cmd.summary "Render 2D circular or donut pie charts with percentage breakdowns"
          cmd.description "Visualizes categorical distributions using high-resolution circular terminal graphics."

          cmd.arg :pairs, "Key:value pairs (e.g. 'Used:65' 'Free:35'), or '-' for stdin", required: false, multiple: true

          cmd.group "Appearance & Options" do
            cmd.opt :title, "-t, --title=TITLE", "Chart title"
            cmd.flag :donut, "--donut", description: "Render as donut ring chart"
            cmd.opt :inner_ratio, "--inner-ratio=FLOAT", "Donut inner hole radius ratio (default: 0.42)", default: 0.42, type: :float
            cmd.opt :height, "-H, --height=N", "Chart height in lines", default: 12, type: :int
            cmd.opt :width, "-w, --width=N", "Chart width in columns", type: :int
          end

          cmd.section "PIPELINE COMPOSITION" do |s|
            s.example "df -h | awk 'NR>1 {print $1, $5}' | sed 's/%//' | opal piechart --title 'Disk Usage'"
            s.example "opal piechart 'Work:50' 'Sleep:30' 'Code:20' --donut"
          end

          cmd.run do |ctx|
            args_list = ctx.arg_list(:pairs)
            raw = if !args_list.empty? && args_list != ["-"]
                    args_list.join('\n')
                  else
                    ctx.read_input_or_arg
                  end

            if raw.nil? || raw.strip.empty?
              STDERR.puts "\e[31mError:\e[0m No data provided. Pass 'label:value' pairs or pipe via STDIN."
              next 1
            end

            parsed_pairs = InputReader.parse_key_value_pairs(raw)
            if parsed_pairs.empty?
              STDERR.puts "\e[31mError:\e[0m Could not parse any label:value pairs."
              next 1
            end

            palette = [Color.cyan, Color.green, Color.magenta, Color.yellow, Color.blue, Color.red]
            slices = parsed_pairs.map_with_index do |(k, v), idx|
              c = palette[idx % palette.size]
              UI::PieSlice.new(k, v, c)
            end

            title = ctx.string?(:title)
            donut = ctx.flag?(:donut)
            inner_ratio = ctx.float(:inner_ratio)
            height = ctx.int(:height)
            width = ctx.int?(:width)

            UI::PieChart.print(
              slices: slices,
              title: title,
              donut: donut,
              height: height,
              width: width,
              inner_radius_ratio: inner_ratio
            )
            0
          end
        end
      end
    end
  end
end

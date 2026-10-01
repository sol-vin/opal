require "../../opal"
require "./tools/table_tool"
require "./tools/chart_tool"
require "./tools/markdown_tool"
require "./tools/tree_tool"
require "./tools/box_tool"
require "./tools/gauge_tool"
require "./tools/misc_tools"

module Opal
  module CLI
    module Main
      def self.create_app : App
        app = App.new("opal", Opal::VERSION)
        app.title "OPAL: Linux CLI & Terminal UI Toolkit"
        app.header "  ✦ Opal CLI v#{Opal::VERSION} - Unix Terminal Formatting Utilities ✦"
        app.description "Unix-style command-line utilities for printing tables, charts, markdown, trees, boxes, and gauges in shell scripts and pipelines."

        # Register all command utilities
        app.command :table do |cmd|
          Tools::TableTool.register(cmd)
        end

        app.command :chart do |cmd|
          Tools::ChartTool.register_chart(cmd)
        end

        app.command :sparkline do |cmd|
          Tools::ChartTool.register_sparkline(cmd)
        end

        app.command :barchart do |cmd|
          Tools::ChartTool.register_barchart(cmd)
        end

        app.command :linegraph do |cmd|
          Tools::ChartTool.register_linegraph(cmd)
        end

        app.command :piechart do |cmd|
          Tools::ChartTool.register_piechart(cmd)
        end

        app.command :markdown do |cmd|
          Tools::MarkdownTool.register(cmd)
        end

        app.command :tree do |cmd|
          Tools::TreeTool.register(cmd)
        end

        app.command :box do |cmd|
          Tools::BoxTool.register(cmd)
        end

        app.command :gauge do |cmd|
          Tools::GaugeTool.register(cmd)
        end

        app.command :badge do |cmd|
          Tools::MiscTools.register_badge(cmd)
        end

        app.command :rule do |cmd|
          Tools::MiscTools.register_rule(cmd)
        end

        app.command :code do |cmd|
          Tools::MiscTools.register_code(cmd)
        end

        app.command :diff do |cmd|
          Tools::MiscTools.register_diff(cmd)
        end

        app
      end

      def self.run(args : Array(String) = ARGV) : Int32
        create_app.run(args)
      end
    end

    def self.create_app : App
      Main.create_app
    end

    module Tools
      def self.create_app : App
        Main.create_app
      end

      def self.build_app : App
        Main.create_app
      end
    end
  end
end

# Auto-execute when run as main program or crystal run
if !PROGRAM_NAME.includes?("spec") && (PROGRAM_NAME.ends_with?("opal") || PROGRAM_NAME.ends_with?("opal.exe") || PROGRAM_NAME.includes?("main") || PROGRAM_NAME.includes?("crystal-run"))
  exit Opal::CLI::Main.run(ARGV)
end

require "../spec_helper"
require "../../src/opal/cli/main"
require "../../src/opal/cli/tools/input_reader"

describe "Opal CLI Utilities & InputReader" do
  describe Opal::CLI::Tools::InputReader do
    it "cleans UTF-8 BOM and leading/trailing blank whitespace" do
      bom_str = "\uFEFF  hello world  \n"
      cleaned = Opal::CLI::Tools::InputReader.clean(bom_str)
      cleaned.should eq("hello world")
    end

    it "parses CSV tabular data" do
      csv = <<-CSV
      Name,Age,Role
      Alice,28,Developer
      Bob,34,Designer
      CSV

      headers, rows = Opal::CLI::Tools::InputReader.parse_table_data(csv, format: :csv)
      headers.should eq(["Name", "Age", "Role"])
      rows.size.should eq(2)
      rows[0].should eq(["Alice", "28", "Developer"])
      rows[1].should eq(["Bob", "34", "Designer"])
    end

    it "parses TSV tabular data" do
      tsv = "Host\tPort\tStatus\nweb-1\t80\tup\nweb-2\t443\tdown"
      headers, rows = Opal::CLI::Tools::InputReader.parse_table_data(tsv, format: :tsv)
      headers.should eq(["Host", "Port", "Status"])
      rows.size.should eq(2)
      rows[0].should eq(["web-1", "80", "up"])
      rows[1].should eq(["web-2", "443", "down"])
    end

    it "parses JSON array of objects" do
      json = <<-JSON
      [
        {"id": 1, "service": "auth", "healthy": true},
        {"id": 2, "service": "payment", "healthy": false}
      ]
      JSON

      headers, rows = Opal::CLI::Tools::InputReader.parse_table_data(json, format: :json)
      headers.should contain("id")
      headers.should contain("service")
      headers.should contain("healthy")
      rows.size.should eq(2)
      rows[0].should contain("auth")
      rows[1].should contain("payment")
    end

    it "parses Markdown pipe tables" do
      md = <<-MD
      | Item | Price | Stock |
      |:---|:---|:---|
      | Laptop | 1200 | 15 |
      | Mouse | 25 | 100 |
      MD

      headers, rows = Opal::CLI::Tools::InputReader.parse_table_data(md, format: :markdown)
      headers.should eq(["Item", "Price", "Stock"])
      rows.size.should eq(2)
      rows[0].should eq(["Laptop", "1200", "15"])
      rows[1].should eq(["Mouse", "25", "100"])
    end

    it "parses numeric series from CSV, whitespace, and JSON" do
      csv_nums = "10.5, 20.2, 35.0, 50.1"
      res1 = Opal::CLI::Tools::InputReader.parse_number_series(csv_nums)
      res1.should eq([10.5, 20.2, 35.0, 50.1])

      ws_nums = "1 4 9 16 25"
      res2 = Opal::CLI::Tools::InputReader.parse_number_series(ws_nums)
      res2.should eq([1.0, 4.0, 9.0, 16.0, 25.0])

      json_nums = "[100, 250, 375]"
      res3 = Opal::CLI::Tools::InputReader.parse_number_series(json_nums)
      res3.should eq([100.0, 250.0, 375.0])
    end

    it "parses labeled series from key-value, CSV, and JSON" do
      kv_text = <<-KV
      CPU: 75.5
      RAM: 42.0
      DISK: 88.2
      KV
      res1 = Opal::CLI::Tools::InputReader.parse_labeled_series(kv_text)
      res1.should eq([{"CPU", 75.5}, {"RAM", 42.0}, {"DISK", 88.2}])

      csv_text = "Chrome,65.2\nSafari,18.4\nFirefox,3.1"
      res2 = Opal::CLI::Tools::InputReader.parse_labeled_series(csv_text)
      res2.should eq([{"Chrome", 65.2}, {"Safari", 18.4}, {"Firefox", 3.1}])

      json_text = "{\"Alpha\": 10, \"Beta\": 20}"
      res3 = Opal::CLI::Tools::InputReader.parse_labeled_series(json_text)
      res3.should eq([{"Alpha", 10.0}, {"Beta", 20.0}])
    end

    it "parses hierarchical JSON trees" do
      json_tree = <<-JSON
      {
        "name": "project",
        "version": "1.0.0"
      }
      JSON

      root = Opal::CLI::Tools::TreeTool.json_to_tree_node("config", JSON.parse(json_tree))
      root.label.should contain("config")
      root.children.size.should eq(2)
    end
  end

  describe "CLI Argument & Help DSL" do
    it "parses unified spec strings in Option.from_spec" do
      opt = Opal::CLI::Option.from_spec(
        name: :delimiter,
        spec: "-d, --delimiter=CHAR",
        description: "Field delimiter override",
        group: "Data & Parsing",
        default: ","
      )
      opt.short_name.should eq("-d")
      opt.long_name.should eq("--delimiter")
      opt.value_name.should eq("CHAR")
      opt.group.should eq("Data & Parsing")
      opt.default.should eq(",")
    end

    it "supports variadic arguments with multiple: true" do
      arg = Opal::CLI::Argument.new(
        name: :files,
        description: "Source files",
        multiple: true
      )
      arg.multiple?.should be_true
      arg.formatted_name.should eq("[FILES...]")

      arg_req = Opal::CLI::Argument.new(
        name: :items,
        description: "Items",
        required: true,
        multiple: true
      )
      arg_req.formatted_name.should eq("<ITEMS...>")
    end

    it "parses variadic arguments in command run context" do
      captured_files = [] of String
      app = Opal.cli("test_variadic") do |cli|
        cli.command :archive do |cmd|
          cmd.arg :files, "Files to bundle", multiple: true
          cmd.run do |ctx|
            captured_files = ctx.arg_list
            0
          end
        end
      end

      status = app.run(["archive", "a.txt", "b.txt", "c.txt"])
      status.should eq(0)
      captured_files.should eq(["a.txt", "b.txt", "c.txt"])
    end

    it "renders command help screen with title, group headers, and custom sections" do
      app = Opal.cli("app") do |cli|
        cli.command :table do |cmd|
          cmd.summary "Format structured text into tables"
          cmd.description "Detailed description for the table formatter"
          cmd.group "Formatting Options" do
            cmd.opt :delimiter, "-d, --delimiter=CHAR", "Delimiter override"
          end
          cmd.section "PIPELINE EXAMPLES" do |s|
            s.example "cat data.csv | opal table"
          end
        end
      end

      cmd = app.commands["table"]
      help = Opal::CLI::Help.render_command("app table", cmd)
      help.should contain("Format structured text into tables")
      help.should contain("Detailed description for the table formatter")
      help.should contain("Formatting Options:")
      help.should contain("--delimiter=CHAR")
      help.should contain("PIPELINE EXAMPLES:")
      help.should contain("cat data.csv | opal table")
    end
  end

  describe "CLI Command Invocations" do
    app = Opal::CLI::Tools.build_app

    it "executes opal table with inline CSV string" do
      status = app.run(["table", "Name,Score\nAlice,95\nBob,88", "-s", "rounded"])
      status.should eq(0)
    end

    it "executes opal sparkline with inline numbers" do
      status = app.run(["sparkline", "1,5,22,13,53"])
      status.should eq(0)
    end

    it "executes opal barchart with inline labeled data" do
      status = app.run(["barchart", "CPU: 75\nRAM: 42"])
      status.should eq(0)
    end

    it "executes opal linegraph with inline series" do
      status = app.run(["linegraph", "10,25,18,30,22"])
      status.should eq(0)
    end

    it "executes opal piechart with inline slices" do
      status = app.run(["piechart", "Prod: 80\nStage: 20"])
      status.should eq(0)
    end

    it "executes opal markdown with inline markdown" do
      status = app.run(["markdown", "# Heading\n**bold text**"])
      status.should eq(0)
    end

    it "executes opal box with title and border" do
      status = app.run(["box", "Server online", "--title=STATUS", "-s", "rounded"])
      status.should eq(0)
    end

    it "executes opal gauge with numeric percentage" do
      status = app.run(["gauge", "75", "--label=Disk Usage"])
      status.should eq(0)
    end

    it "executes opal badge with label and color" do
      status = app.run(["badge", "ACTIVE", "-c", "green"])
      status.should eq(0)
    end

    it "executes opal rule with label and alignment" do
      status = app.run(["rule", "DEPLOYMENT", "-a", "center"])
      status.should eq(0)
    end

    it "executes opal code with language and line numbers" do
      status = app.run(["code", "puts 'hello'", "-l", "crystal"])
      status.should eq(0)
    end
  end
end

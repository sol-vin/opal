require "./spec_helper"

describe "Opal Expanded UI Components" do
  describe Opal::UI::SplitView do
    it "renders horizontal split with separator" do
      t1 = Opal::UI::Text.new("Left")
      t2 = Opal::UI::Text.new("Right")
      split = Opal::UI::SplitView.horizontal(first: t1, second: t2, ratio: 0.5, separator: '|')

      buf = Opal::UI::Buffer.new(11, 1)
      split.render(buf, 0, 0, 11, 1)
      res = buf.render_to_string(with_ansi: false)

      res.should contain("Left")
      res.should contain("|")
      res.should contain("Right")
    end

    it "renders vertical split with separator" do
      t1 = Opal::UI::Text.new("Top")
      t2 = Opal::UI::Text.new("Bottom")
      split = Opal::UI::SplitView.vertical(first: t1, second: t2, ratio: 0.5, separator: '-')

      buf = Opal::UI::Buffer.new(10, 3)
      split.render(buf, 0, 0, 10, 3)
      res = buf.render_to_string(with_ansi: false)

      lines = res.split('\n')
      lines[0].should contain("Top")
      lines[1].should contain("----------")
      lines[2].should contain("Bottom")
    end

    it "supports fixed pane sizing" do
      t1 = Opal::UI::Text.new("A")
      t2 = Opal::UI::Text.new("B")
      split = Opal::UI::SplitView.horizontal(first: t1, second: t2, first_width: 3, separator: '|')

      buf = Opal::UI::Buffer.new(10, 1)
      split.render(buf, 0, 0, 10, 1)
      buf.get(3, 0).char.should eq('|')
    end
  end

  describe Opal::UI::CodeView do
    it "renders line numbers and gutters" do
      code = "mov rax, 0x42\nret"
      cv = Opal::UI::CodeView.new(code: code, language: :asm, start_line: 1)

      buf = Opal::UI::Buffer.new(30, 2)
      cv.render(buf, 0, 0, 30, 2)
      res = buf.render_to_string(with_ansi: false)

      res.should contain("1 │ mov rax, 0x42")
      res.should contain("2 │ ret")
    end

    it "highlights active line cursor" do
      code = "int x = 1;\nreturn x;"
      cv = Opal::UI::CodeView.new(code: code, language: :c, highlighted_line: 2)

      buf = Opal::UI::Buffer.new(30, 2)
      cv.render(buf, 0, 0, 30, 2)
      res = buf.render_to_string(with_ansi: false)

      res.should contain("▶")
    end

    it "tokenizes Crystal code correctly" do
      code = "def hello : String\n  \"world\"\nend"
      cv = Opal::UI::CodeView.new(code: code, language: :crystal)

      buf = Opal::UI::Buffer.new(40, 3)
      cv.render(buf, 0, 0, 40, 3)
      res = buf.render_to_string(with_ansi: false)

      res.should contain("def hello")
      res.should contain("\"world\"")
    end
  end

  describe Opal::UI::Tabs do
    it "creates tabs from labels and tracks active selection" do
      tabs = Opal::UI::Tabs.from_labels(["Functions", "Sections", "Security"], active: 0)
      tabs.items.size.should eq(3)
      tabs.active_tab.try(&.label).should eq("Functions")

      tabs.next_tab
      tabs.active_tab.try(&.label).should eq("Sections")

      tabs.select_id("security")
      tabs.active_tab.try(&.label).should eq("Security")

      tabs.prev_tab
      tabs.active_tab.try(&.label).should eq("Sections")
    end

    it "renders tabs into buffer" do
      tabs = Opal::UI::Tabs.from_labels(["Code", "Data"], active: 1)
      buf = Opal::UI::Buffer.new(40, 1)
      tabs.render(buf, 0, 0, 40, 1)
      res = buf.render_to_string(with_ansi: false)

      res.should contain("[ 1: Code ]")
      res.should contain("[ 2: Data ]")
    end
  end

  describe Opal::UI::HexViewer do
    it "renders standard 16-byte hex dump with addresses and ascii" do
      bytes = Bytes[0x48, 0x89, 0x5c, 0x24, 0x08, 0x57, 0x48, 0x83, 0xec, 0x20, 0x48, 0x8b, 0xd9, 0x48, 0x8b, 0xfa]
      hex = Opal::UI::HexViewer.new(bytes: bytes, base_address: 0x140001000_u64)

      buf = Opal::UI::Buffer.new(80, 1)
      hex.render(buf, 0, 0, 80, 1)
      res = buf.render_to_string(with_ansi: false)

      res.should contain("0x140001000")
      res.should contain("48 89 5c 24 08 57 48 83  ec 20 48 8b d9 48 8b fa")
      res.should contain("│H.\\$.WH.. H..H..│")
    end

    it "computes total rows correctly" do
      bytes = Bytes.new(35, 0_u8)
      hex = Opal::UI::HexViewer.new(bytes: bytes, bytes_per_row: 16)
      hex.total_rows.should eq(3) # 16 + 16 + 3
    end
  end

  describe "Table Enhancements" do
    it "supports row selection cursor and truncation" do
      tbl = Opal::UI::Table.new(
        headers: ["Name", "Value"],
        rows: [
          ["Alpha", "100"],
          ["VeryLongStringToTruncate", "200"],
          ["Gamma", "300"]
        ],
        selected_index: 1,
        visible_rows: 2,
        truncate: true
      )

      tbl.selected_index.should eq(1)
      tbl.move_down
      tbl.selected_index.should eq(2)
      tbl.move_up
      tbl.selected_index.should eq(1)

      buf = Opal::UI::Buffer.new(30, 5)
      tbl.render(buf, 0, 0, 30, 5)
      res = buf.render_to_string(with_ansi: false)
      res.should contain("Name")
    end
  end

  describe "DSL Builder Integration" do
    it "constructs element tree with new components" do
      rendered = Opal.render_ui(width: 80, height: 10) do |ui|
        ui.split_view(ratio: 0.5) do |split|
          split.first do |left|
            left.tabs(["A", "B"])
          end
          split.second do |right|
            right.code_view("mov eax, 1", language: :asm)
          end
        end
      end

      rendered.should contain("[ 1: A ]")
      rendered.should contain("mov eax, 1")
    end
  end
end

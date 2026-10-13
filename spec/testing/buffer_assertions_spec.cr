require "../spec_helper"

describe Opal::Testing::BufferAssertions do
  describe "2D Buffer line assertions" do
    it "asserts exact line matching on a 2D buffer" do
      buf = Opal::UI::Buffer.new(12, 3)
      buf.put_string(0, 0, "┌──────────┐")
      buf.put_string(0, 1, "│Ratatui   │")
      buf.put_string(0, 2, "└──────────┘")

      assert_buffer_lines(buf, [
        "┌──────────┐",
        "│Ratatui   │",
        "└──────────┘",
      ])
    end

    it "handles multi-width unicode and emoji glyphs properly" do
      buf = Opal::UI::Buffer.new(14, 2)
      # 🚀 is width 2, 漢字 are width 2 each
      buf.put_string(0, 0, "🚀 Launch")
      buf.put_string(0, 1, "漢字 Text")

      lines = buffer_lines(buf)
      lines[0].should start_with("🚀 Launch")
      lines[1].should start_with("漢字 Text")

      assert_buffer_lines(buf, [
        "🚀 Launch",
        "漢字 Text",
      ])
    end

    it "raises Spec::AssertionFailed with formatted visual diff table upon mismatch" do
      buf = Opal::UI::Buffer.new(10, 2)
      buf.put_string(0, 0, "Hello A")
      buf.put_string(0, 1, "Hello B")

      expect_raises(Spec::AssertionFailed, /Buffer line mismatch detected/) do
        assert_buffer_lines(buf, [
          "Hello A",
          "Hello C", # Mismatch!
        ])
      end
    end
  end

  describe "Cell level assertions" do
    it "verifies exact styling and color attributes of individual cells" do
      buf = Opal::UI::Buffer.new(5, 5)
      buf.put_char(
        2, 3, 'X',
        fg: Opal::Color.bright_yellow,
        bg: Opal::Color.blue,
        bold: true,
        underline: true
      )

      assert_cell(
        buf, 2, 3,
        char: 'X',
        fg: Opal::Color.bright_yellow,
        bg: Opal::Color.blue,
        bold: true,
        underline: true
      )
    end

    it "raises when cell coordinates are out of bounds" do
      buf = Opal::UI::Buffer.new(5, 5)

      expect_raises(Spec::AssertionFailed, /out of buffer bounds/) do
        assert_cell(buf, 10, 10, char: 'Z')
      end
    end

    it "raises when cell attribute does not match" do
      buf = Opal::UI::Buffer.new(5, 5)
      buf.put_char(1, 1, 'M', bold: false)

      expect_raises(Spec::AssertionFailed, /bold mismatch/) do
        assert_cell(buf, 1, 1, bold: true)
      end
    end
  end
end

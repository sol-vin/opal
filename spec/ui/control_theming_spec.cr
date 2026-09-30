require "../spec_helper"

describe "UI Control Theming and Customization" do
  before_each do
    Opal::Theme.current = Opal::Theme.default
  end

  describe "Theme Inheritance and Dynamic Fallback" do
    it "renders controls with active theme colors by default" do
      Opal::Theme.current = Opal::Theme.dracula
      button = Opal::UI::Button.new("Submit")
      button.effective_fg.should eq(Opal::Theme.dracula.primary)
      button.effective_bg.should eq(Opal::Color.none)

      # Switch global theme
      Opal::Theme.current = Opal::Theme.nord
      button.effective_fg.should eq(Opal::Theme.nord.primary)
      button.effective_bg.should eq(Opal::Color.none)
    end

    it "supports local element-level theme overriding global theme" do
      Opal::Theme.current = Opal::Theme.default
      button = Opal::UI::Button.new("Scoped")
      button.theme = Opal::Theme.cyberpunk
      button.effective_fg.should eq(Opal::Theme.cyberpunk.primary)
      button.effective_bg.should eq(Opal::Color.none)
    end

    it "allows per-control property overrides that take precedence over theme" do
      button = Opal::UI::Button.new("Custom")
      button.fg = Opal::Color.red
      button.bg = Opal::Color.white

      button.effective_fg.should eq(Opal::Color.red)
      button.effective_bg.should eq(Opal::Color.white)
    end

    it "supports fluent .style configuration block on controls" do
      button = Opal::UI::Button.new("Styled").style do |b|
        b.fg = Opal::Color.cyan
        b.bg = Opal::Color.black
      end

      button.effective_fg.should eq(Opal::Color.cyan)
      button.effective_bg.should eq(Opal::Color.black)
    end
  end

  describe "Window Theme & Glyph Customization" do
    it "uses custom glyphs and pattern borders" do
      win = Opal::UI::Window.new(
        "",
        x: 0,
        y: 0,
        width: 20,
        height: 6,
        border: Opal::Border.pattern("-+"),
        close_glyph: "[X]",
        maximize_glyph: "[^]",
        minimize_glyph: "[-]",
        resize_glyph: '#'
      )

      win.close_glyph.should eq("[X]")
      win.maximize_glyph.should eq("[^]")
      win.minimize_glyph.should eq("[-]")
      win.resize_glyph.should eq('#')

      buf = Opal::UI::Buffer.new(20, 6)
      win.render(buf, 0, 0, 20, 6)

      # Check top border pattern rendered
      buf.get(1, 0).char.should eq('-')
      buf.get(2, 0).char.should eq('+')
      # Check custom close glyph rendered in titlebar
      rendered_row = (0...20).map { |col| buf.get(col, 0).char }.join
      rendered_row.should contain("[X]")
    end

    it "allows theme manipulation of window colors" do
      win = Opal::UI::Window.new("Win")
      win.title_fg = Opal::Color.magenta
      win.border_fg = Opal::Color.yellow
      win.active_border_fg = Opal::Color.cyan
      win.bg = Opal::Color.blue

      win.title_fg.should eq(Opal::Color.magenta)
      win.border_fg.should eq(Opal::Color.yellow)
      win.active_border_fg.should eq(Opal::Color.cyan)
      win.bg.should eq(Opal::Color.blue)
    end
  end

  describe "Table Theme & Divider Customization" do
    it "manipulates divider characters and theme colors" do
      table = Opal::UI::Table.new(["Name", "Role"])
      table.add_row(["Alice", "Dev"])

      table.horizontal_char = '='
      table.junction_char = '+'
      table.header_fg = Opal::Color.yellow
      table.border_fg = Opal::Color.blue

      table.horizontal_char.should eq('=')
      table.junction_char.should eq('+')

      buf = Opal::UI::Buffer.new(24, 5)
      table.render(buf, 0, 0, 24, 5)

      # Header divider row should have '=' characters
      divider_row = (0...24).map { |col| buf.get(col, 1).char }.join
      divider_row.should contain("===")
      divider_row.should contain("+")
    end
  end

  describe "ScrollBar Character & Color Swaps" do
    it "allows swapping thumb, track, and arrow characters" do
      sb = Opal::UI::ScrollBar.new(:vertical, min_value: 0, max_value: 100, page_size: 20)
      sb.thumb_char = '#'
      sb.track_char = '.'
      sb.arrow_up_char = '^'
      sb.arrow_down_char = 'v'
      sb.thumb_fg = Opal::Color.green
      sb.track_fg = Opal::Color.gray

      sb.thumb_char.should eq('#')
      sb.track_char.should eq('.')

      buf = Opal::UI::Buffer.new(1, 10)
      sb.render(buf, 0, 0, 1, 10)

      chars = (0...10).map { |row| buf.get(0, row).char }.join
      chars.should contain("^")
      chars.should contain("#")
      chars.should contain("v")
    end
  end

  describe "Dropdown Glyph & Border Customization" do
    it "allows swapping dropdown arrow glyph and pattern border" do
      dd = Opal::UI::Dropdown.new(["One", "Two", "Three"], expanded: true)
      dd.arrow_glyph = "v"
      dd.border = Opal::Border.pattern("-+")

      dd.arrow_glyph.should eq("v")
      dd.border.not_nil!.top.should eq("-+")

      buf = Opal::UI::Buffer.new(15, 6)
      dd.render(buf, 0, 0, 15, 6)

      # Check top pattern border on expanded popup box (rendered below header at y=1)
      buf.get(1, 1).char.should eq('-')
      buf.get(2, 1).char.should eq('+')

      # Check custom arrow glyph in collapsed header
      header_row = (0...15).map { |c| buf.get(c, 0).char }.join
      header_row.should contain("v")
    end
  end

  describe "CodeView Customization" do
    it "allows manipulating gutter fg, cursor fg, and cursor indicator" do
      cv = Opal::UI::CodeView.new("def foo\n  42\nend")
      cv.gutter_fg = Opal::Color.yellow
      cv.cursor_fg = Opal::Color.red
      cv.cursor_indicator = ">>"
      cv.highlighted_line = 2

      cv.gutter_fg.should eq(Opal::Color.yellow)
      cv.cursor_fg.should eq(Opal::Color.red)
      cv.cursor_indicator.should eq(">>")

      buf = Opal::UI::Buffer.new(20, 5)
      cv.render(buf, 0, 0, 20, 5)

      line2 = (0...20).map { |c| buf.get(c, 1).char }.join
      line2.should contain(">>")
      line2.should contain("│")
    end
  end
end

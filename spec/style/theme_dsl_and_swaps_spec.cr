require "../spec_helper"

describe "Theme DSL and Character Swaps" do
  describe "Border Patterns and Character Swapping" do
    it "creates repeating pattern borders" do
      border = Opal::Border.pattern("-+")
      border.top.should eq("-+")
      border.top_segment(6).should eq("-+-+-+")
      border.top_segment(5).should eq("-+-+-")
      border.bottom_segment(7).should eq("-+-+-+-")
    end

    it "supports vertical character patterns per row" do
      border = Opal::Border.new(
        top_left: "+", top: "-", top_right: "+",
        left: "|:", right: ":|",
        bottom_left: "+", bottom: "-", bottom_right: "+"
      )
      border.left_char(0).should eq('|')
      border.left_char(1).should eq(':')
      border.left_char(2).should eq('|')
      border.left_char(3).should eq(':')

      border.right_char(0).should eq(':')
      border.right_char(1).should eq('|')
    end

    it "swaps individual border characters non-destructively" do
      original = Opal::Border.single
      swapped = original.swap(top_left: "#", bottom_right: "#")
      swapped.top_left.should eq("#")
      swapped.bottom_right.should eq("#")
      swapped.top.should eq(original.top)
      swapped.bottom.should eq(original.bottom)
      # Original remains unchanged
      original.top_left.should eq("┌")
    end

    it "parses border patterns from string descriptors" do
      b1 = Opal::Border.from("pattern:-+")
      b1.top_segment(4).should eq("-+-+")

      b2 = Opal::Border.from("=-=")
      b2.top_segment(6).should eq("=-==-=")
    end
  end

  describe "GlyphSet" do
    it "provides Unicode and ASCII default glyph presets" do
      unicode_glyphs = Opal::GlyphSet.unicode
      unicode_glyphs.window_close.should eq("[x]")
      unicode_glyphs.window_maximize.should eq("[^]")
      unicode_glyphs.cursor.should eq("▶ ")

      ascii_glyphs = Opal::GlyphSet.ascii
      ascii_glyphs.window_close.should eq("[X]")
      ascii_glyphs.window_maximize.should eq("[+]")
      ascii_glyphs.cursor.should eq("> ")
      ascii_glyphs.scrollbar_thumb.should eq('#')
    end

    it "swaps UI control characters non-destructively" do
      base = Opal::GlyphSet.unicode
      swapped = base.swap(
        window_close: "x",
        cursor: ">>",
        scrollbar_thumb: 'O',
        dropdown_arrow: "v"
      )

      swapped.window_close.should eq("x")
      swapped.cursor.should eq(">>")
      swapped.scrollbar_thumb.should eq('O')
      swapped.dropdown_arrow.should eq("v")
      swapped.window_maximize.should eq("[^]")

      # Base remains untouched
      base.window_close.should eq("[x]")
      base.cursor.should eq("▶ ")
    end
  end

  describe "Declarative Opal.theme DSL" do
    it "builds and registers a custom theme using fluent chaining" do
      theme = Opal.theme "NeonCyberpunk" do |t|
        t.primary "#FF007F"
        t.secondary "#00F0FF"
        t.accent "#FFE600"
        t.background "#080811"
        t.surface "#121324"
        t.text "#FFFFFF"
        t.text_muted "#707590"
        t.border "#303550"
        t.window_border Opal::Border.pattern("-+")
        t.box_border Opal::Border.single
        t.glyphs do |g|
          g.swap(window_close: "[X]", cursor: "->")
        end
      end

      theme.name.should eq("NeonCyberpunk")
      theme.primary.should eq(Opal::Color.hex("#FF007F"))
      theme.window_border.top_segment(4).should eq("-+-+")
      theme.box_border.top_left.should eq("┌")
      theme.glyphs.window_close.should eq("[X]")
      theme.glyphs.cursor.should eq("->")

      # Should be queryable via Theme.find
      Opal::Theme.find("NeonCyberpunk").should_not be_nil
      Opal::Theme["NeonCyberpunk"].name.should eq("NeonCyberpunk")
    end

    it "supports nested colors block in DSL" do
      theme = Opal.theme "DSLPalette" do |t|
        t.colors do |c|
          c.primary "#00AAFF"
          c.secondary "#55FF55"
          c.background "#000000"
          c.text "#FFFFFF"
        end
        t.window_border :ascii
      end

      theme.primary.should eq(Opal::Color.hex("#00AAFF"))
      theme.secondary.should eq(Opal::Color.hex("#55FF55"))
      theme.window_border.top_left.should eq("+")
    end

    it "derives new themes with overrides" do
      base = Opal::Theme.nord
      derived = base.derive(
        name: "NordRetro",
        primary: "#A3BE8C",
        window_border: Opal::Border.ascii,
        glyphs: Opal::GlyphSet.ascii
      )

      derived.name.should eq("NordRetro")
      derived.primary.should eq(Opal::Color.hex("#A3BE8C"))
      derived.secondary.should eq(base.secondary)
      derived.window_border.top_left.should eq("+")
      derived.glyphs.window_close.should eq("[X]")
    end
  end

  describe "ThemeStore Serialization and Key-Value Format" do
    it "exports and imports themes to KV (.theme) format" do
      theme = Opal.theme "KVTheme" do |t|
        t.primary "#00AAFF"
        t.background "#000000"
        t.text "#FFFFFF"
        t.window_border Opal::Border.pattern("-+")
        t.glyphs do |g|
          g.swap(window_close: "[X]")
        end
      end

      kv = Opal::ThemeStore.export_kv(theme)
      kv.should contain("name = KVTheme")
      kv.should contain("primary = #00AAFF")
      kv.should contain("glyph_window_close = [X]")

      imported = Opal::ThemeStore.import_kv(kv)
      imported.name.should eq("KVTheme")
      imported.primary.should eq(Opal::Color.hex("#00AAFF"))
      imported.glyphs.window_close.should eq("[X]")
      imported.window_border.top_segment(4).should eq("-+-+")
    end

    it "exports and imports themes to JSON format" do
      theme = Opal::Theme.dracula
      json = Opal::ThemeStore.export_json(theme)
      json.should contain("\"name\":\"dracula\"")

      imported = Opal::ThemeStore.import_json(json)
      imported.name.should eq("dracula")
      imported.primary.should eq(theme.primary)
      imported.background.should eq(theme.background)
    end
  end
end

require "./spec_helper"
require "../src/opal/style/color"
require "../src/opal/style/palette_formats"

describe Opal::PaletteFormats do
  describe ".to_gpl and .from_gpl" do
    it "encodes and decodes GIMP Palette files accurately" do
      entries = [
        {"primary", Opal::Color.hex("#38EF7D")},
        {"accent", Opal::Color.hex("#BD93F9")},
        {"background", Opal::Color.hex("#1E1E2E")},
      ]

      gpl_str = Opal::PaletteFormats.to_gpl(entries, palette_name: "Test Theme")
      gpl_str.should contain("GIMP Palette")
      gpl_str.should contain("Name: Test Theme")
      gpl_str.should contain("56 239 125\tprimary")

      parsed = Opal::PaletteFormats.from_gpl(gpl_str)
      parsed.size.should eq(3)
      parsed[0][0].should eq("primary")
      parsed[0][1].to_hex.should eq("#38EF7D")
      parsed[1][0].should eq("accent")
      parsed[1][1].to_hex.should eq("#BD93F9")
    end
  end

  describe ".to_pal and .from_pal" do
    it "encodes and decodes JASC-PAL files" do
      colors = [
        Opal::Color.rgb(255, 0, 0),
        Opal::Color.rgb(0, 255, 0),
        Opal::Color.rgb(0, 0, 255),
      ]

      pal_str = Opal::PaletteFormats.to_pal(colors)
      pal_str.should contain("JASC-PAL")
      pal_str.should contain("0100")
      pal_str.should contain("3")
      pal_str.should contain("255 0 0")

      parsed = Opal::PaletteFormats.from_pal(pal_str)
      parsed.size.should eq(3)
      parsed[0].to_hex.should eq("#FF0000")
      parsed[1].to_hex.should eq("#00FF00")
      parsed[2].to_hex.should eq("#0000FF")
    end
  end

  describe ".to_hex and .from_hex" do
    it "encodes and decodes hex string lines" do
      colors = [
        Opal::Color.hex("#F38BA8"),
        Opal::Color.hex("#A6E3A1"),
      ]

      hex_str = Opal::PaletteFormats.to_hex(colors)
      hex_str.should contain("#F38BA8")
      hex_str.should contain("#A6E3A1")

      parsed = Opal::PaletteFormats.from_hex(hex_str)
      parsed.size.should eq(2)
      parsed[0].to_hex.should eq("#F38BA8")
      parsed[1].to_hex.should eq("#A6E3A1")
    end
  end

  describe ".to_json_named and .to_json_indexed" do
    it "formats JSON object for named palettes" do
      entries = [
        {"bg", Opal::Color.hex("#111111")},
        {"fg", Opal::Color.hex("#EEEEEE")},
      ]
      json_str = Opal::PaletteFormats.to_json_named(entries)
      json_str.should contain("\"bg\": \"#111111\"")
      json_str.should contain("\"fg\": \"#EEEEEE\"")
    end

    it "formats JSON array for indexed palettes" do
      colors = [Opal::Color.hex("#FF5555"), Opal::Color.hex("#50FA7B")]
      json_str = Opal::PaletteFormats.to_json_indexed(colors)
      json_str.should contain("\"#FF5555\"")
      json_str.should contain("\"#50FA7B\"")
    end
  end

  describe ".to_css" do
    it "formats CSS custom properties" do
      entries = [
        {"primary_color", Opal::Color.hex("#89B4FA")},
        {"surface", Opal::Color.hex("#181825")},
      ]
      css_str = Opal::PaletteFormats.to_css(entries, prefix: "app")
      css_str.should contain(":root {")
      css_str.should contain("--app-primary-color: #89B4FA;")
      css_str.should contain("--app-surface: #181825;")
    end
  end
end

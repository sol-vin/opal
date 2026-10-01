require "./spec_helper"
require "../src/opal/style/color"
require "../src/opal/style/palette_model"

describe Opal::PaletteModel do
  describe "Indexed Mode" do
    it "initializes with default colors if empty" do
      model = Opal::PaletteModel.new(mode: Opal::PaletteMode::Indexed)
      model.size.should be > 0
      model.mode.should eq(Opal::PaletteMode::Indexed)
    end

    it "respects min_colors and max_colors constraints" do
      initial_colors = [Opal::Color.hex("#111111"), Opal::Color.hex("#222222")]
      model = Opal::PaletteModel.new(
        mode: Opal::PaletteMode::Indexed,
        indexed_colors: initial_colors,
        min_colors: 2,
        max_colors: 3
      )

      model.can_remove?.should be_false
      model.remove_at(0).should be_false

      model.can_add?.should be_true
      model.add(Opal::Color.hex("#333333")).should be_true
      model.size.should eq(3)

      model.can_add?.should be_false
      model.add(Opal::Color.hex("#444444")).should be_false
      model.size.should eq(3)
    end

    it "swaps elements correctly using swap" do
      c1 = Opal::Color.hex("#111111")
      c2 = Opal::Color.hex("#222222")
      c3 = Opal::Color.hex("#333333")
      model = Opal::PaletteModel.new(
        mode: Opal::PaletteMode::Indexed,
        indexed_colors: [c1, c2, c3]
      )

      model.swap(0, 1).should be_true
      model.color_at(0).not_nil!.to_hex.should eq("#222222")
      model.color_at(1).not_nil!.to_hex.should eq("#111111")
      model.color_at(2).not_nil!.to_hex.should eq("#333333")
    end

    it "moves elements correctly" do
      c1 = Opal::Color.hex("#111111")
      c2 = Opal::Color.hex("#222222")
      c3 = Opal::Color.hex("#333333")
      model = Opal::PaletteModel.new(
        mode: Opal::PaletteMode::Indexed,
        indexed_colors: [c1, c2, c3]
      )

      model.move(0, 2).should be_true
      model.colors.map(&.to_hex).should eq(["#222222", "#333333", "#111111"])
    end
  end

  describe "Named Mode" do
    it "handles named dictionary entries with rename and update" do
      entries = {
        "primary" => Opal::Color.hex("#38EF7D"),
        "accent"  => Opal::Color.hex("#BD93F9"),
      }
      model = Opal::PaletteModel.new(
        mode: Opal::PaletteMode::Named,
        named_entries: entries,
        allow_rename: true
      )

      model.size.should eq(2)
      model.name_at(0).should eq("primary")
      model.color_at(0).not_nil!.to_hex.should eq("#38EF7D")

      # Rename
      model.rename(0, "brand_primary").should be_true
      model.name_at(0).should eq("brand_primary")

      # Update color
      model.update_color(0, Opal::Color.hex("#50FA7B")).should be_true
      model.color_at(0).not_nil!.to_hex.should eq("#50FA7B")
    end

    it "respects allow_rename and allow_remove flags" do
      entries = {
        "base" => Opal::Color.hex("#000000"),
        "alt"  => Opal::Color.hex("#FFFFFF"),
      }
      model = Opal::PaletteModel.new(
        mode: Opal::PaletteMode::Named,
        named_entries: entries,
        allow_rename: false,
        allow_remove: false
      )

      model.can_rename?.should be_false
      model.rename(0, "new_name").should be_false

      model.can_remove?.should be_false
      model.remove_at(0).should be_false
    end
  end

  describe "Export and Import" do
    it "exports across all formats and re-imports" do
      model = Opal::PaletteModel.new(
        mode: Opal::PaletteMode::Indexed,
        indexed_colors: [Opal::Color.hex("#123456"), Opal::Color.hex("#789ABC")]
      )

      # JSON
      json_out = model.export(:json)
      json_out.should contain("#123456")
      reimported_json = Opal::PaletteModel.from_content(json_out, Opal::PaletteFormat::JSON)
      reimported_json.size.should eq(2)
      reimported_json.color_at(0).not_nil!.to_hex.should eq("#123456")

      # PAL
      pal_out = model.export(:pal)
      reimported_pal = Opal::PaletteModel.from_content(pal_out, Opal::PaletteFormat::PAL)
      reimported_pal.size.should eq(2)
      reimported_pal.color_at(0).not_nil!.to_hex.should eq("#123456")

      # HEX
      hex_out = model.export(:hex)
      reimported_hex = Opal::PaletteModel.from_content(hex_out, Opal::PaletteFormat::HEX)
      reimported_hex.size.should eq(2)
      reimported_hex.color_at(0).not_nil!.to_hex.should eq("#123456")
    end
  end
end

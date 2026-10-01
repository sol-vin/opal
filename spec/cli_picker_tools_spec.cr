require "./spec_helper"
require "../src/opal/cli/main"

describe "Opal CLI Output & Picker Tools" do
  it "registers colorpicker, target, choose, confirm, palette, and pal commands in main app" do
    app = Opal::CLI::Main.create_app
    app.commands.has_key?("colorpicker").should be_true
    app.commands.has_key?("color").should be_true
    app.commands.has_key?("target").should be_true
    app.commands.has_key?("choose").should be_true
    app.commands.has_key?("confirm").should be_true
    app.commands.has_key?("palette").should be_true
    app.commands.has_key?("pal").should be_true
  end

  it "formats colors across all supported format strings" do
    col = Opal::Color.rgb(137, 180, 250)

    Opal::CLI::Tools::ColorPickerTool.format_color(col, "hex").should eq("#89B4FA")
    Opal::CLI::Tools::ColorPickerTool.format_color(col, "rgb").should eq("rgb(137, 180, 250)")
    Opal::CLI::Tools::ColorPickerTool.format_color(col, "raw").should eq("137 180 250")

    hsl_str = Opal::CLI::Tools::ColorPickerTool.format_color(col, "hsl")
    hsl_str.should start_with("hsl(")

    hsv_str = Opal::CLI::Tools::ColorPickerTool.format_color(col, "hsv")
    hsv_str.should start_with("hsv(")

    lab_str = Opal::CLI::Tools::ColorPickerTool.format_color(col, "lab")
    lab_str.should start_with("lab(")

    ok_str = Opal::CLI::Tools::ColorPickerTool.format_color(col, "oklab")
    ok_str.should start_with("oklab(")

    cmyk_str = Opal::CLI::Tools::ColorPickerTool.format_color(col, "cmyk")
    cmyk_str.should start_with("cmyk(")

    ansi_str = Opal::CLI::Tools::ColorPickerTool.format_color(col, "ansi")
    ansi_str.should eq("\e[38;2;137;180;250m")
  end

  it "renders help for colorpicker without errors" do
    app = Opal::CLI::Main.create_app
    app.commands["colorpicker"].summary.not_nil!.should contain("interactive TrueColor picker")
    app.commands["target"].summary.not_nil!.should contain("interactive 2D coordinate selector")
    app.commands["choose"].summary.not_nil!.should contain("list of choices")
    app.commands["confirm"].summary.not_nil!.should contain("confirmation prompt")
    app.commands["palette"].summary.not_nil!.should contain("color palette studio")
    app.commands["pal"].summary.not_nil!.should contain("color palette studio")
  end
end

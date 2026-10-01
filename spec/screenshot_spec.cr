require "./spec_helper"
require "../src/opal/asciicast"

describe "Opal Screenshot Utility" do
  it "generates clean plain text screenshot from buffer" do
    buf = Opal::UI::Buffer.new(20, 5)
    buf.put_string(2, 1, "Hello World", fg: Opal::Color.bright_cyan, bold: true)

    text = buf.screenshot(format: :text)
    text.should contain("Hello World")
    text.should_not contain("\e[")
  end

  it "generates styled ANSI screenshot from buffer" do
    buf = Opal::UI::Buffer.new(20, 5)
    buf.put_string(2, 1, "Hello ANSI", fg: Opal::Color.bright_green, bold: true)

    ansi = buf.screenshot(format: :ansi)
    ansi.should contain("Hello ANSI")
    ansi.should contain("\e[") # Has ANSI escapes
  end

  it "generates HTML screenshot with 24-bit CSS styles" do
    buf = Opal::UI::Buffer.new(20, 5)
    buf.put_string(2, 1, "HTML Test", fg: Opal::Color.rgb(56, 239, 125), bold: true)

    html = buf.screenshot(format: :html)
    html.should contain("<!DOCTYPE html>")
    html.should contain("<pre class=\"terminal-frame\">")
    html.should contain("HTML Test")
    html.should contain("#38EF7D") # Hex for rgb(56, 239, 125)
  end

  it "saves screenshot directly to file on disk" do
    buf = Opal::UI::Buffer.new(15, 3)
    buf.put_string(1, 1, "Disk Snapshot")

    tmp_path = "tmp/test_screenshot.txt"
    buf.screenshot(path: tmp_path, format: :text)

    File.exists?(tmp_path).should be_true
    File.read(tmp_path).should contain("Disk Snapshot")
    File.delete(tmp_path) if File.exists?(tmp_path)
  end

  it "takes screenshot via VCR singleton and instance" do
    buf = Opal::UI::Buffer.new(30, 4)
    buf.put_string(2, 1, "VCR Screenshot", fg: Opal::Color.bright_magenta)

    shot = Opal::VCR.screenshot(format: :ansi, buffer: buf)
    shot.should contain("VCR Screenshot")
    shot.should contain("\e[")

    text_shot = Opal::VCR.screenshot(format: :text, buffer: buf)
    text_shot.should contain("VCR Screenshot")
    text_shot.should_not contain("\e[")
  end

  it "supports screenshot_to_clipboard without raising" do
    buf = Opal::UI::Buffer.new(20, 3)
    buf.put_string(1, 1, "Clipboard Shot")

    res = buf.screenshot_to_clipboard(format: :text)
    res.should contain("Clipboard Shot")

    vcr_res = Opal::VCR.screenshot_to_clipboard(format: :text, buffer: buf)
    vcr_res.should contain("Clipboard Shot")
  end
end

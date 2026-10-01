require "../src/opal"
require "../src/opal/game"
require "../src/opal/gamepad"
require "../src/opal/mermaid"
require "../src/opal/html"
require "../src/opal/asciicast"
require "../examples/10_opal_tui_showcase"

width = 110
height = 32
output_cast = "demos/06_opal_tui_showcase.cast"

puts "Recording Opal TUI Showcase to #{output_cast}..."

app = ShowcaseAppModel.new
buffer = Opal::UI::Buffer.new(width, height)

Opal::VCR.record(output_cast, width: width, height: height, title: "Opal TUI Showcase Tour") do |vcr|
  capture = ->(advance : Float64) {
    app.render(buffer)
    vcr.capture(buffer, advance: advance)
  }

  puts "  -> Recording Slide 1: Check Slide"
  8.times do
    app.update(Opal::TEA::TickMsg.new)
    capture.call(0.08)
  end
  app.update(Opal::TEA::KeyMsg.new(key: "space"))
  capture.call(0.2)
  app.update(Opal::TEA::KeyMsg.new(key: "down"))
  capture.call(0.15)
  app.update(Opal::TEA::KeyMsg.new(key: "space"))
  capture.call(0.2)
  app.update(Opal::TEA::KeyMsg.new(key: "down"))
  app.update(Opal::TEA::KeyMsg.new(key: "down"))
  app.update(Opal::TEA::KeyMsg.new(key: "down"))
  app.update(Opal::TEA::KeyMsg.new(key: "enter"))
  capture.call(0.3)

  puts "  -> Recording Slide 2: Spotlight Masking"
  capture.call(0.3)
  ["d", "d", "d", "s", "s", "a", "w"].each do |k|
    app.update(Opal::TEA::KeyMsg.new(key: k))
    capture.call(0.1)
  end
  app.update(Opal::TEA::KeyMsg.new(key: "f"))
  capture.call(0.3)
  # Open Source Code modal
  app.update(Opal::TEA::KeyMsg.new(key: "c"))
  capture.call(0.4)
  app.update(Opal::TEA::KeyMsg.new(key: "down"))
  capture.call(0.15)
  app.update(Opal::TEA::KeyMsg.new(key: "escape"))
  capture.call(0.2)

  # Next slide
  app.update(Opal::TEA::KeyMsg.new(key: "tab"))
  capture.call(0.3)

  puts "  -> Recording Slide 3: Scissor & Buffer Region Ops"
  ["d", "d", "s", "s", "a"].each do |k|
    app.update(Opal::TEA::KeyMsg.new(key: k))
    capture.call(0.1)
  end
  app.update(Opal::TEA::KeyMsg.new(key: "b"))
  capture.call(0.2)
  app.update(Opal::TEA::KeyMsg.new(key: "i"))
  capture.call(0.3)
  # Open Guide modal
  app.update(Opal::TEA::KeyMsg.new(key: "?"))
  capture.call(0.4)
  app.update(Opal::TEA::KeyMsg.new(key: "escape"))
  capture.call(0.2)

  # Next slide
  app.update(Opal::TEA::KeyMsg.new(key: "tab"))
  capture.call(0.3)

  puts "  -> Recording Slide 4: OpalChat 2-Pane Split Mockup"
  app.update(Opal::TEA::KeyMsg.new(key: "down"))
  capture.call(0.2)
  app.update(Opal::TEA::KeyMsg.new(key: "down"))
  capture.call(0.2)
  " Zero overflow!".each_char do |ch|
    app.update(Opal::TEA::KeyMsg.new(key: ch.to_s, char: ch))
    app.update(Opal::TEA::TickMsg.new)
    capture.call(0.06)
  end

  # Next slide
  app.update(Opal::TEA::KeyMsg.new(key: "tab"))
  capture.call(0.3)

  puts "  -> Recording Slide 5: Playable Pong (60Hz Game Loop)"
  15.times do |step|
    if step % 3 == 0
      app.update(Opal::TEA::KeyMsg.new(key: step < 8 ? "s" : "w"))
    end
    app.update(Opal::TEA::TickMsg.new)
    capture.call(0.05)
  end

  # Next slide
  app.update(Opal::TEA::KeyMsg.new(key: "tab"))
  capture.call(0.3)

  puts "  -> Recording Slide 6: 3D Color Picker & Palette Studio"
  ["right", "right", "right", "down", "left", "left", "down", "right"].each do |k|
    app.update(Opal::TEA::KeyMsg.new(key: k))
    capture.call(0.1)
  end

  # Next slide
  app.update(Opal::TEA::KeyMsg.new(key: "tab"))
  capture.call(0.3)

  puts "  -> Recording Slide 7: Large Text, Big Digits & Clock"
  6.times do
    app.update(Opal::TEA::TickMsg.new)
    capture.call(0.08)
  end

  # Next slide
  app.update(Opal::TEA::KeyMsg.new(key: "tab"))
  capture.call(0.3)

  puts "  -> Recording Slide 8: Mermaid Diagram Viewer"
  ["2", "3", "4", "1"].each do |tab_key|
    app.update(Opal::TEA::KeyMsg.new(key: tab_key))
    capture.call(0.25)
  end
  app.update(Opal::TEA::KeyMsg.new(key: "a"))
  5.times do
    app.update(Opal::TEA::TickMsg.new)
    capture.call(0.08)
  end

  # Next slide
  app.update(Opal::TEA::KeyMsg.new(key: "tab"))
  capture.call(0.3)

  puts "  -> Recording Slide 9: TUI HTML Web Browser"
  app.update(Opal::TEA::KeyMsg.new(key: "down"))
  capture.call(0.2)
  app.update(Opal::TEA::KeyMsg.new(key: "down"))
  capture.call(0.2)

  # Next slide
  app.update(Opal::TEA::KeyMsg.new(key: "tab"))
  capture.call(0.3)

  puts "  -> Recording Slide 10: 6 Dropdown Styles & 1/8th Meters"
  ["1", "2", "3", "4", "5", "6"].each do |dd_key|
    app.update(Opal::TEA::KeyMsg.new(key: dd_key))
    capture.call(0.12)
  end
  ["+", "+", "+", "-", "-"].each do |m_key|
    app.update(Opal::TEA::KeyMsg.new(key: m_key))
    capture.call(0.1)
  end

  # Next slide
  app.update(Opal::TEA::KeyMsg.new(key: "tab"))
  capture.call(0.3)

  puts "  -> Recording Slide 11: Multi-Shader Compositing Pipeline"
  12.times do |step|
    if step == 3
      app.update(Opal::TEA::KeyMsg.new(key: "3")) # Glitch toggle
    elsif step == 8
      app.update(Opal::TEA::KeyMsg.new(key: "2")) # CRT toggle
    end
    app.update(Opal::TEA::TickMsg.new)
    capture.call(0.06)
  end

  # Next slide
  app.update(Opal::TEA::KeyMsg.new(key: "tab"))
  capture.call(0.3)

  puts "  -> Recording Slide 12: Tweens & 16 Easing Curves"
  ["down", "down", "down"].each do |k|
    app.update(Opal::TEA::KeyMsg.new(key: k))
    6.times do
      app.update(Opal::TEA::TickMsg.new)
      capture.call(0.05)
    end
  end

  # Next slide
  app.update(Opal::TEA::KeyMsg.new(key: "tab"))
  capture.call(0.3)

  puts "  -> Recording Slide 13: Gamepad Focus Navigation & Virtual Cursor"
  ["down", "down", "right", "right", "up", "space"].each do |k|
    app.update(Opal::TEA::KeyMsg.new(key: k))
    capture.call(0.15)
  end

  vcr.hold(1.0)
end

puts "[OK] Showcase recording complete: #{output_cast} (#{File.size(output_cast)} bytes)"

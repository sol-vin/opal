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

  puts "  -> Recording Slide 1: System Capability & Experience Checklist (sol.vin)"
  12.times do
    app.update(Opal::TEA::TickMsg.new)
    capture.call(0.1)
  end
  # Toggle first checklist item
  app.update(Opal::TEA::KeyMsg.new(key: "space"))
  capture.call(0.3)
  app.update(Opal::TEA::KeyMsg.new(key: "down"))
  capture.call(0.2)
  # Toggle second item
  app.update(Opal::TEA::KeyMsg.new(key: "space"))
  capture.call(0.3)
  # Navigate down to Launch button
  app.update(Opal::TEA::KeyMsg.new(key: "down"))
  capture.call(0.2)
  app.update(Opal::TEA::KeyMsg.new(key: "down"))
  capture.call(0.2)
  app.update(Opal::TEA::KeyMsg.new(key: "down"))
  capture.call(0.2)
  app.update(Opal::TEA::KeyMsg.new(key: "down"))
  capture.call(0.2)
  # Launch showcase!
  app.update(Opal::TEA::KeyMsg.new(key: "enter"))
  capture.call(0.4)

  puts "  -> Recording Slide 2: Spotlight Alpha Masking & Dithering"
  capture.call(0.8)
  # Smooth WASD movement of spotlight around the schematics
  ["d", "d", "d", "d", "s", "s", "s", "a", "a", "w", "w", "d"].each do |k|
    app.update(Opal::TEA::KeyMsg.new(key: k))
    capture.call(0.12)
  end
  # Toggle feathering
  app.update(Opal::TEA::KeyMsg.new(key: "f"))
  capture.call(0.4)
  # Cycle tint colors (uses remapped [t] key)
  app.update(Opal::TEA::KeyMsg.new(key: "t"))
  capture.call(0.35)
  app.update(Opal::TEA::KeyMsg.new(key: "t"))
  capture.call(0.35)
  app.update(Opal::TEA::KeyMsg.new(key: "t"))
  capture.call(0.35)
  # Open Source Code modal
  app.update(Opal::TEA::KeyMsg.new(key: "c"))
  capture.call(0.6)
  ["down", "down", "down", "down"].each do |k|
    app.update(Opal::TEA::KeyMsg.new(key: k))
    capture.call(0.18)
  end
  capture.call(0.4)
  app.update(Opal::TEA::KeyMsg.new(key: "escape"))
  capture.call(0.3)

  # Next slide
  app.update(Opal::TEA::KeyMsg.new(key: "tab"))
  capture.call(0.4)

  puts "  -> Recording Slide 3: Scissor Clipping & Buffer Region Operations"
  capture.call(0.8)
  ["d", "d", "d", "s", "s", "a"].each do |k|
    app.update(Opal::TEA::KeyMsg.new(key: k))
    capture.call(0.12)
  end
  # Cycle blit modes
  app.update(Opal::TEA::KeyMsg.new(key: "b"))
  capture.call(0.35)
  app.update(Opal::TEA::KeyMsg.new(key: "b"))
  capture.call(0.35)
  # Toggle sub-region inversion
  app.update(Opal::TEA::KeyMsg.new(key: "i"))
  capture.call(0.5)
  # Scroll rect
  app.update(Opal::TEA::KeyMsg.new(key: "r"))
  capture.call(0.35)
  # Open Guide modal
  app.update(Opal::TEA::KeyMsg.new(key: "?"))
  capture.call(0.6)
  ["down", "down", "down"].each do |k|
    app.update(Opal::TEA::KeyMsg.new(key: k))
    capture.call(0.18)
  end
  capture.call(0.4)
  app.update(Opal::TEA::KeyMsg.new(key: "escape"))
  capture.call(0.3)

  # Next slide
  app.update(Opal::TEA::KeyMsg.new(key: "tab"))
  capture.call(0.4)

  puts "  -> Recording Slide 4: Real-World App Mockup 1 — OpalChat (2-Pane Split)"
  capture.call(0.8)
  # Switch channels
  app.update(Opal::TEA::KeyMsg.new(key: "down"))
  capture.call(0.3)
  app.update(Opal::TEA::KeyMsg.new(key: "down"))
  capture.call(0.3)
  app.update(Opal::TEA::KeyMsg.new(key: "up"))
  capture.call(0.3)
  # Type interactive message into chat input
  " Testing zero overflow & real-time messaging!".each_char do |ch|
    app.update(Opal::TEA::KeyMsg.new(key: ch.to_s, char: ch))
    app.update(Opal::TEA::TickMsg.new)
    capture.call(0.045)
  end
  # Send message on Enter!
  app.update(Opal::TEA::KeyMsg.new(key: "enter"))
  capture.call(0.6)
  # Admire the posted message in history
  8.times do
    app.update(Opal::TEA::TickMsg.new)
    capture.call(0.1)
  end

  # Next slide
  app.update(Opal::TEA::KeyMsg.new(key: "tab"))
  capture.call(0.4)

  puts "  -> Recording Slide 5: Real-World App Mockup 2 — Playable Pong (60Hz Loop)"
  capture.call(0.8)
  # Play active Pong rally: move player paddle smoothly while ball bounces and AI tracks
  36.times do |step|
    if step % 4 == 0
      paddle_dir = (step // 8) % 2 == 0 ? "s" : "w"
      app.update(Opal::TEA::KeyMsg.new(key: paddle_dir))
    end
    app.update(Opal::TEA::TickMsg.new)
    capture.call(0.06)
  end
  # Pause game
  app.update(Opal::TEA::KeyMsg.new(key: "space"))
  capture.call(0.5)
  # Resume game
  app.update(Opal::TEA::KeyMsg.new(key: "space"))
  10.times do
    app.update(Opal::TEA::TickMsg.new)
    capture.call(0.06)
  end

  # Next slide
  app.update(Opal::TEA::KeyMsg.new(key: "tab"))
  capture.call(0.4)

  puts "  -> Recording Slide 6: 3D Color Picker & Palette Studio"
  capture.call(0.8)
  # Adjust Red channel
  ["right", "right", "right", "right"].each do |k|
    app.update(Opal::TEA::KeyMsg.new(key: k))
    capture.call(0.12)
  end
  # Switch to Green channel
  app.update(Opal::TEA::KeyMsg.new(key: "down"))
  capture.call(0.2)
  ["right", "right", "right", "right"].each do |k|
    app.update(Opal::TEA::KeyMsg.new(key: k))
    capture.call(0.12)
  end
  # Switch to Blue channel
  app.update(Opal::TEA::KeyMsg.new(key: "down"))
  capture.call(0.2)
  ["left", "left", "left"].each do |k|
    app.update(Opal::TEA::KeyMsg.new(key: k))
    capture.call(0.12)
  end
  # Randomize palette
  app.update(Opal::TEA::KeyMsg.new(key: "space"))
  capture.call(0.8)

  # Next slide
  app.update(Opal::TEA::KeyMsg.new(key: "tab"))
  capture.call(0.4)

  puts "  -> Recording Slide 7: Large Text, Big Digits & Telemetry Clock"
  # Watch the 3x5 block digits clock tick in real-time
  20.times do
    app.update(Opal::TEA::TickMsg.new)
    capture.call(0.12)
  end

  # Next slide
  app.update(Opal::TEA::KeyMsg.new(key: "tab"))
  capture.call(0.4)

  puts "  -> Recording Slide 8: Mermaid Diagram Viewer (Flowchart, Sequence, State, Class)"
  capture.call(0.8)
  # Step through all diagram tabs
  ["2", "3", "4", "1"].each do |tab_key|
    app.update(Opal::TEA::KeyMsg.new(key: tab_key))
    capture.call(0.9)
  end
  # Toggle auto-scroll and observe
  app.update(Opal::TEA::KeyMsg.new(key: "a"))
  12.times do
    app.update(Opal::TEA::TickMsg.new)
    capture.call(0.08)
  end

  # Next slide
  app.update(Opal::TEA::KeyMsg.new(key: "tab"))
  capture.call(0.4)

  puts "  -> Recording Slide 9: TUI HTML Web Browser with History & Hyperlinks"
  capture.call(0.8)
  # Navigate down and follow link
  app.update(Opal::TEA::KeyMsg.new(key: "down"))
  capture.call(0.3)
  app.update(Opal::TEA::KeyMsg.new(key: "down"))
  capture.call(0.3)
  app.update(Opal::TEA::KeyMsg.new(key: "enter"))
  capture.call(0.8)
  # History back and forward
  app.update(Opal::TEA::KeyMsg.new(key: "<"))
  capture.call(0.6)
  app.update(Opal::TEA::KeyMsg.new(key: ">"))
  capture.call(0.6)
  ["down", "down", "up"].each do |k|
    app.update(Opal::TEA::KeyMsg.new(key: k))
    capture.call(0.2)
  end

  # Next slide
  app.update(Opal::TEA::KeyMsg.new(key: "tab"))
  capture.call(0.4)

  puts "  -> Recording Slide 10: 6 Dropdown Styles & 1/8th Fractional Meters"
  capture.call(0.8)
  # Cycle through dropdown styles
  ["1", "2", "3", "4", "5", "6"].each do |dd_key|
    app.update(Opal::TEA::KeyMsg.new(key: dd_key))
    capture.call(0.25)
  end
  # Open active searchable dropdown
  app.update(Opal::TEA::KeyMsg.new(key: "space"))
  capture.call(0.5)
  app.update(Opal::TEA::KeyMsg.new(key: "down"))
  capture.call(0.25)
  app.update(Opal::TEA::KeyMsg.new(key: "enter"))
  capture.call(0.4)
  # Modulate heat, cool, and neon meters
  ["+", "+", "+", "+", "-", "-"].each do |m_key|
    app.update(Opal::TEA::KeyMsg.new(key: m_key))
    capture.call(0.18)
  end

  # Next slide
  app.update(Opal::TEA::KeyMsg.new(key: "tab"))
  capture.call(0.4)

  puts "  -> Recording Slide 11: Multi-Shader Compositing Pipeline (Matrix + CRT + Glitch)"
  capture.call(0.8)
  24.times do |step|
    if step == 4
      app.update(Opal::TEA::KeyMsg.new(key: "3")) # Glitch ON
    elsif step == 12
      app.update(Opal::TEA::KeyMsg.new(key: "1")) # Matrix toggle
    elsif step == 18
      app.update(Opal::TEA::KeyMsg.new(key: "2")) # CRT toggle
    end
    app.update(Opal::TEA::TickMsg.new)
    capture.call(0.08)
  end

  # Next slide
  app.update(Opal::TEA::KeyMsg.new(key: "tab"))
  capture.call(0.4)

  puts "  -> Recording Slide 12: Tweens & 16 Mathematical Easing Curves"
  capture.call(0.8)
  # Step through easing curves and watch animated track box
  ["down", "down", "down", "down"].each do |k|
    app.update(Opal::TEA::KeyMsg.new(key: k))
    10.times do
      app.update(Opal::TEA::TickMsg.new)
      capture.call(0.06)
    end
  end
  # Reset animation
  app.update(Opal::TEA::KeyMsg.new(key: "space"))
  8.times do
    app.update(Opal::TEA::TickMsg.new)
    capture.call(0.06)
  end

  # Next slide
  app.update(Opal::TEA::KeyMsg.new(key: "tab"))
  capture.call(0.4)

  puts "  -> Recording Slide 13: Gamepad Focus Navigation, Virtual Cursor & Screenshot"
  capture.call(0.8)
  # Traverse focus with D-Pad
  app.update(Opal::TEA::KeyMsg.new(key: "down"))
  capture.call(0.3)
  # Toggle Hardware Acceleration checkbox
  app.update(Opal::TEA::KeyMsg.new(key: "space"))
  capture.call(0.4)
  # Traverse to Telemetry slider
  app.update(Opal::TEA::KeyMsg.new(key: "down"))
  capture.call(0.3)
  ["right", "right", "right"].each do |k|
    app.update(Opal::TEA::KeyMsg.new(key: k))
    capture.call(0.15)
  end
  # Traverse to Reset button
  app.update(Opal::TEA::KeyMsg.new(key: "down"))
  capture.call(0.3)
  app.update(Opal::TEA::KeyMsg.new(key: "space"))
  capture.call(0.4)

  # TEST & SHOWCASE: Press Ctrl+S Screenshot hotkey!
  puts "  -> Capturing Screenshot via Ctrl+S and displaying toast notification..."
  app.update(Opal::TEA::KeyMsg.new(key: "s", ctrl: true))
  capture.call(0.2)
  # Hold on screen with floating toast notification badge visible
  18.times do
    app.update(Opal::TEA::TickMsg.new)
    capture.call(0.08)
  end

  vcr.hold(1.5)
end

puts "[OK] Showcase recording complete: #{output_cast} (#{File.size(output_cast)} bytes)"

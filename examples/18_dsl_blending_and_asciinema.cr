require "../src/opal"
require "../src/opal/asciicast/asciinema"

puts "\e[1;36m==========================================================\e[0m"
puts "\e[1;36m  Opal: DSL Blending & Asciinema VCR Tape Deck Showcase   \e[0m"
puts "\e[1;36m==========================================================\e[0m\n"

# -----------------------------------------------------------------------------
# Part 1: Dual-Mode Declarative DSL
# -----------------------------------------------------------------------------
puts "\e[1;33m[1/4] Rendering UI with Concise Implicit DSL Blocks...\e[0m"

concise_output = Opal.render_ui(width: 60, height: 10) do
  box(title: "Concise Implicit DSL", border: :rounded) do
    vstack(spacing: 1) do
      text "Zero boilerplate: methods resolve to current builder receiver", fg: :cyan
      hstack(spacing: 2) do
        badge "MODE: IMPLICIT", :green
        badge "BUILDER: ACTIVE", :blue
      end
      gauge ratio: 0.85, label: "Efficiency: 85%"
    end
  end
end
puts concise_output
puts ""

puts "\e[1;33m[2/4] Rendering UI with Explicit Receiver Blocks...\e[0m"

explicit_output = Opal.render_ui(width: 60, height: 8) do |ui|
  ui.box(title: "Explicit Receiver DSL", border: :double) do |b|
    b.vstack(spacing: 0) do |v|
      v.text "Explicit block parameter for nested scope clarity", fg: :yellow
      v.badge "MODE: EXPLICIT", :magenta
    end
  end
end
puts explicit_output
puts ""

# -----------------------------------------------------------------------------
# Part 2: Blending Traditional OOP Component Objects into Declarative DSL
# -----------------------------------------------------------------------------
puts "\e[1;33m[3/4] Blending Traditional OOP Instances into Declarative DSL...\e[0m"

# 1. Instantiate components traditionally with OOP syntax
my_chart = Opal::UI::LineGraph.new
my_chart.add_series("Throughput", [15.0, 32.0, 68.0, 94.0, 50.0], :cyan)

my_log = Opal::UI::RichLog.new(max_lines: 5)
my_log.log("Service cluster initialized")
my_log.log("Listening on 0.0.0.0:8080")

# 2. Embed pre-built instances directly into DSL using `add` and `<<`
blended_tree = Opal::UI.build do |b|
  b.vstack(spacing: 1) do |v|
    v.text "System Status: Healthy", fg: :green
    v.add my_chart # Embedded via add()
    v << my_log    # Embedded via shovel (<<)
  end
end

blended_buf = Opal::UI::Buffer.new(60, 12)
blended_tree.render(blended_buf, 0, 0, 60, 12)
puts blended_buf.to_s
puts ""

# -----------------------------------------------------------------------------
# Part 3: Tactile VCR Cassette Recording & Stepping Playback
# -----------------------------------------------------------------------------
puts "\e[1;33m[4/4] Tactile VCR Cassette Recording & Stepping Playback...\e[0m"

demo_cast_path = "vcr_showcase.cast"

# 1. Record session using VCR tape deck block syntax
Opal::VCR.record(demo_cast_path, width: 50, height: 8, title: "Tactile VCR Tape") do |vcr|
  puts "  -> VCR tape inserted. Recording started..."

  # Frame 1: Initial state
  buf1 = Opal::UI::Buffer.new(50, 8)
  buf1.put_string(2, 1, "[VCR Frame 1] System Booting...", fg: Opal::Color.cyan, bold: true)
  vcr.capture(buf1, advance: 0.1)

  # Frame pacing: simulate 3 frames of processing delay
  vcr.wait_frames(3, delay_per_frame: 0.08)

  # Pause recording temporarily (e.g. background database migration)
  vcr.pause
  puts "  -> VCR tape paused (internal setup invisible to recording)"
  vcr.resume
  puts "  -> VCR tape resumed"

  # Frame 2: Operational state
  buf2 = Opal::UI::Buffer.new(50, 8)
  buf2.put_string(2, 1, "[VCR Frame 2] Nodes Connected", fg: Opal::Color.green, bold: true)
  buf2.put_string(2, 3, "Traffic: 14,200 req/s", fg: Opal::Color.white)
  vcr.capture(buf2, advance: 0.2)

  # Hold final frame for 1 second in playback
  vcr.hold(1.0)
  puts "  -> VCR tape stopped. Session saved to #{demo_cast_path}"
end

# 2. Inspect and step through recorded frames with independent VCR instance
vcr_player = Opal::VCR.new
vcr_player.load(demo_cast_path)

puts "\n\e[1;32mVCR Playback Inspection:\e[0m"
puts "  Total frames: #{vcr_player.total_frames}"
puts "  Total duration: #{vcr_player.duration} seconds"

puts "\nStepping Frame-by-Frame:"
f0 = vcr_player.goto_frame(0)
puts "  Frame 0 [#{f0.time.round(2)}s]: \"#{f0.buffer.to_s.lines.first?.try(&.strip)}\""

f1 = vcr_player.next_frame
puts "  Frame 1 [#{f1.time.round(2)}s]: \"#{f1.buffer.to_s.lines.first?.try(&.strip)}\""

# Step back with prev_frame
prev = vcr_player.prev_frame
puts "  Stepped back to Frame #{prev.index} [#{prev.time.round(2)}s]"

# Rewind
vcr_player.rewind
puts "  Rewound to Start: Frame #{vcr_player.current_frame_index}"

# Clean up temp file
File.delete(demo_cast_path) if File.exists?(demo_cast_path)

puts "\n\e[1;32m[*] Showcase complete! All DSL blending and Asciinema VCR features verified.\e[0m"

require "../src/opal"
require "../src/opal/asciicast"

# [*] Opal Asciicast Recording Example
# Demonstrates how to use `require "opal/asciicast"` to programmatically
# record terminal sessions, render buffers, and drive headless TUI workflows
# into standard Asciinema v2 (.cast) files.

puts "[*] Opal Asciicast Recording Demo"
puts "================================"

output_dir = "tmp/example_casts"
Dir.mkdir_p(output_dir) unless Dir.exists?(output_dir)

# -----------------------------------------------------------------------------
# Part 1: Direct Recording with Opal::Asciicast.record
# -----------------------------------------------------------------------------
cast1_path = File.join(output_dir, "01_buffer_demo.cast")
puts "1. Recording Buffer Session to #{cast1_path}..."

Opal::Asciicast.record(
  output_path: cast1_path,
  width: 80,
  height: 20,
  title: "Opal Buffer Demo"
) do |writer|
  # Initial shell prompt with simulated human typing
  writer.write("\e[?25h\e[1;36muser@terminal\e[0m:\e[1;34m~/opal\e[0m$ ", advance: 0.0)
  writer.type_text("crystal run app.cr\r\n", cps: 20.0)
  writer.pause(0.4)

  # Clear screen and hide cursor
  writer.clear_screen(advance: 0.05)
  writer.write("\e[?25l", advance: 0.01)

  # Frame 1: Render a styled UI buffer
  buf = Opal::UI::Buffer.new(78, 16)
  buf.put_string(2, 1, ">> SYSTEM METRICS MONITOR", fg: Opal::Color.cyan, bold: true)
  buf.put_string(2, 2, "─" * 74, fg: Opal::Color.bright_black)

  # Render mock metrics
  sparkline = Opal::UI::Sparkline.new([10.0, 25.0, 45.0, 70.0, 85.0, 60.0, 95.0, 80.0, 50.0])
  sparkline.render(buf, 4, 4, 30, 1)
  buf.put_string(36, 4, "CPU Load: 82%", fg: Opal::Color.green, bold: true)

  gauge = Opal::UI::Gauge.new(ratio: 0.74, label: "Memory (74%)", color: :yellow)
  gauge.render(buf, 4, 6, 40, 1)

  writer.draw_buffer(buf, advance: 0.5)

  # Frame 2: Updated metric state
  gauge2 = Opal::UI::Gauge.new(ratio: 0.88, label: "Memory (88%)", color: :red)
  buf.fill(0, 0, 78, 16, ' ')
  buf.put_string(2, 1, ">> SYSTEM METRICS MONITOR", fg: Opal::Color.cyan, bold: true)
  buf.put_string(2, 2, "─" * 74, fg: Opal::Color.bright_black)
  sparkline.render(buf, 4, 4, 30, 1)
  buf.put_string(36, 4, "CPU Load: 94%", fg: Opal::Color.red, bold: true)
  gauge2.render(buf, 4, 6, 40, 1)

  writer.draw_buffer(buf, advance: 0.6)
  writer.pause(1.0)
end

puts "   [OK] Successfully generated #{cast1_path}!"

# -----------------------------------------------------------------------------
# Part 2: Headless TUI Recording via Opal::Asciicast::Driver
# -----------------------------------------------------------------------------
cast2_path = File.join(output_dir, "02_headless_table.cast")
puts "2. Recording Headless Table via Opal::Asciicast::Driver to #{cast2_path}..."

driver = Opal::Asciicast.create_driver(width: 70, height: 12, title: "Headless Table Tour")

table = Opal::UI::Table.new(
  headers: ["ID", "Service Name", "Status", "Latency"],
  rows: [
    ["#01", "Auth Gateway", "Active", "4ms"],
    ["#02", "Payment Broker", "Active", "12ms"],
    ["#03", "Order Dispatcher", "Pending", "8ms"],
    ["#04", "Telemetry Worker", "Active", "2ms"],
  ]
)

driver.raw_mode do
  driver.hide_cursor

  # Step 1: Initial Table Frame
  buf = Opal::UI::Buffer.new(68, 10)
  table.render(buf, 0, 0, 68, 10)
  driver.write(Opal::Terminal::Screen.move_to(1, 1))
  driver.write(buf.to_s)

  # Step 2: Inject synthetic keystrokes to navigate rows
  4.times do |step|
    driver.pause(0.4)
    table.move_down
    buf.fill(0, 0, 68, 10, ' ')
    table.render(buf, 0, 0, 68, 10)
    driver.write(Opal::Terminal::Screen.move_to(1, 1))
    driver.write(buf.to_s)
  end

  driver.pause(0.5)
  driver.save(cast2_path)
end

puts "   [OK] Successfully generated #{cast2_path}!"

# -----------------------------------------------------------------------------
# Part 3: Reading & Verifying Cast Recordings
# -----------------------------------------------------------------------------
puts "3. Parsing generated recordings with Opal::Asciicast.read..."

rec1 = Opal::Asciicast.read(cast1_path)
puts "   • Recording 1: #{rec1.header.title}"
puts "     Dimensions: #{rec1.header.width}x#{rec1.header.height}"
puts "     Duration:   #{rec1.duration.round(2)}s"
puts "     Events:     #{rec1.events.size} (#{rec1.outputs.size} output chunks)"

rec2 = Opal::Asciicast.read(cast2_path)
puts "   • Recording 2: #{rec2.header.title}"
puts "     Dimensions: #{rec2.header.width}x#{rec2.header.height}"
puts "     Duration:   #{rec2.duration.round(2)}s"
puts "     Events:     #{rec2.events.size}"

puts "\n[OK] Asciicast standardized recording demonstration complete!"

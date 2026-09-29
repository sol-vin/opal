require "../src/opal"

# Example 5: Autocomplete, Ghost Text, Keymaps, Mouse Input, and Terminal Info DSL
# Demonstrates Tab autocomplete with ghost text preview, declarative keymaps,
# mouse click & scroll handling, and terminal capability detection.

puts Opal.style.bold.fg(:cyan).render("\n=== Opal Terminal Inspection & Input Demo ===\n")

# 1. Query terminal capabilities using the Terminal Info DSL
Opal.terminal do |term|
  puts "Terminal Size:        #{term.columns} columns x #{term.rows} rows"
  puts "Color Capability:     #{term.color_profile}"
  puts "TrueColor Supported:  #{term.truecolor?}"
  puts "Terminal Program:     #{term.term_program || "Standard Console"}"
  puts "Mouse Tracking:       #{term.supports_mouse?}"
  puts "Alternate Buffer:     #{term.supports_alt_screen?}"
  puts "OS Environment:       #{term.windows? ? "Windows" : "POSIX"}"
end

puts
puts Opal.style.fg(:yellow).render("Interactive Autocomplete with Ghost Text:")
puts Opal.style.dim.render("(Type 'b' or 'c', watch the ghost text appear, then press <Tab> or <Right> to accept)")
puts

# 2. Tab completion with ghost text preview
input_value = Opal.prompt_autocomplete(
  prompt: "lapis > ",
  candidates: [
    "build --release",
    "bind engine",
    "bind project",
    "clean",
    "deps --target=bin",
    "dirs",
    "editor --attach-debugger",
    "package game --release",
    "scaffold new game",
    "test --project=all",
  ]
)

puts
puts Opal.style.bold.fg(:green).render("You entered: #{input_value}")

# 3. Demonstrating KeyMap DSL
keymap = Opal.on_key do |k|
  k.on "ctrl+c", "q" do
    puts "Exit command requested!"
  end
  k.on "enter" do
    puts "Enter key dispatched!"
  end
  k.on_char do |ch|
    puts "Received character: #{ch}"
  end
end

# 4. Demonstrating MouseMap DSL
mouse = Opal.on_mouse do |m|
  m.on_click(:left) do |ev|
    puts "Left clicked at (#{ev.x}, #{ev.y})"
  end
  m.on_scroll_up do |_ev|
    puts "Scrolled up!"
  end
  m.zone(x: 10..30, y: 5..10) do |_ev|
    puts "Clicked inside action button zone!"
  end
end

puts "\nDemo finished successfully!"

require "../src/opal"

# Example 2: Interactive CLI Setup Wizard
# Demonstrates interactive prompts, selection menus, multi-select checkboxes,
# animated background spinners, and smooth Unicode progress bars.

puts Opal.style.bold.fg(:cyan).render("\n=== Opal Project Setup Wizard ===\n")

# 1. Text input prompt
project_name = Opal.ask("Enter project name", default: "my_godot_game")

# 2. Single select radio menu
godot_version = Opal.select(
  question: "Select target Godot engine version",
  options: ["4.3-stable", "4.2.2-stable", "4.4-dev"]
)

# 3. Multiple select checkbox menu
features = Opal.multi_select(
  question: "Select features to enable",
  options: ["2D Physics", "3D Rendering", "Audio Effects", "Vulkan Shaders", "Steamworks SDK"],
  default_indices: [0, 1, 2]
)

# 4. Boolean confirmation
init_git = Opal.confirm("Initialize git repository?", default: true)

puts
puts Opal.style.bold.fg(:yellow).render("Starting installation...\n")

# 5. Background animated spinner
Opal.spinner("Downloading Godot template binaries...") do |sp|
  sleep 1.second
  sp.text = "Configuring GDExtension bindings..."
  sleep 1.second
  sp.success("Engine environment configured successfully!")
end

# 6. Smooth Unicode progress bar
Opal.progress(total: 50, title: "Unpacking game assets", color: :magenta) do |bar|
  50.times do
    sleep 30.milliseconds
    bar.advance
  end
end

# 7. Summary card rendered with declarative UI
summary_card = Opal.render_ui(width: 50, height: 10) do |ui|
  ui.box(border: :rounded, title: "Setup Complete", title_fg: :green, padding: 1) do |b|
    b.vstack(spacing: 1) do |v|
      v.hstack(spacing: 2) do
        v.badge "SUCCESS", bg: :green, fg: :white
        v.text "Project: #{project_name}", bold: true
      end
      v.rule
      v.text "Engine: Godot #{godot_version}"
      v.text "Features: #{features.join(", ")}"
      v.text "Git: #{init_git ? "Initialized" : "Skipped"}"
    end
  end
end

puts
puts summary_card

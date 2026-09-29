require "../src/opal"

# Showcases Opal's Markdown terminal rendering, Modal dialogs, and Toast notifications.

doc = <<-MD
# 💎 Opal Architecture Overview
Opal combines **The Elm Architecture**, **Lipgloss styling**, and **double-buffering**.

### Key Advantages
- **Zero C Dependencies**: Native Windows, macOS, and Linux support.
- **Fast Performance**: Delta renderer updates only changed cells.

```crystal
require "opal"

Opal.cli("demo", "Quick App") do
  command "serve" { puts "Listening on :3000" }
end
```

> "Good design is as little design as possible." — Dieter Rams

For more information, visit [Opal Documentation](https://github.com/sol-vin/opal).
MD

puts Opal.style.bold.foreground(Opal::Color.cyan).render("--- 1. Rendered Terminal Markdown Document ---")
puts Opal.render_markdown(doc, width: 70)

puts Opal.style.bold.foreground(Opal::Color.cyan).render("\n--- 2. Buffer Blit with Modal Dialog & Dimming ---")
base_buf = Opal::UI::Buffer.new(65, 12)
(0...12).each do |y|
  base_buf.put_string(0, y, "Dashboard row #{y} with metrics and live data feeds..." * 2, fg: Opal::Color.bright_black)
end

modal = Opal::UI::Modal.new(
  title: "Deploy Confirmation",
  message: "Are you sure you want to deploy build #1042\nto production cluster (us-east-1)?",
  buttons: ["Cancel", "Confirm Deploy"],
  selected_button: 1
)
modal.render(base_buf, 0, 0, 65, 12)
puts base_buf.to_s

puts Opal.style.bold.foreground(Opal::Color.cyan).render("\n--- 3. Toast Notifications Stack ---")
toast_buf = Opal::UI::Buffer.new(65, 8)
toast_mgr = Opal::UI::ToastManager.new
toast_mgr.add("Database Connected", "PostgreSQL pool healthy (5ms ping)", level: :success)
toast_mgr.add("Deploy In Progress", "Pushing image to container registry", level: :info)
toast_mgr.render_overlay(toast_buf, position: :top_right)
puts toast_buf.to_s

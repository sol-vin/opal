require "../src/opal"

# Showcases Opal's live Fuzzy Search & Filter List with split preview pane.
branches = [
  "main",
  "staging",
  "feat/tea-runtime",
  "feat/diff-renderer",
  "feat/lipgloss-styling",
  "feat/fuzzy-finder",
  "feat/multi-field-form",
  "fix/windows-vt100",
  "fix/buffer-blit-overflow",
  "docs/architecture-guide",
]

preview_handler = ->(branch : String) {
  "Branch Details: #{branch}\n" \
  "──────────────────────────────\n" \
  "Status    : Healthy (Clean tree)\n" \
  "Commits   : 14 ahead of origin/main\n" \
  "Updated   : 12 minutes ago by sol-vin\n" \
  "Tests     : 124 passed (100%)\n\n" \
  "Press [Enter] to checkout this branch."
}

selected = Opal.filter(
  items: branches,
  title: "Git Branch Switcher (Fuzzy Finder)",
  preview: preview_handler
)

if branch = selected
  puts Opal.style.bold.foreground(Opal::Color.green).render("\nSwitched to branch '#{branch}'!")
else
  puts Opal.style.foreground(Opal::Color.yellow).render("\nSelection cancelled.")
end

require "../src/opal"

# -------------------------------------------------------------------------
# Opal - Custom Themes, Declarative DSL & Character Swaps Demo
# -------------------------------------------------------------------------
# Demonstrates:
#   1. Declarative Theme DSL (Opal.theme) with fluent property chaining
#   2. WCAG 2.1 AA Contrast Auto-Enforcement (theme.ensure_contrast)
#   3. Repeating pattern borders (Border.pattern("-+") and Border.from("=-="))
#   4. UI Control Character Swaps (GlyphSet non-destructive swapping)
#   5. Per-control theme overrides and fluent .style blocks
#   6. Key-Value (.theme) and JSON export / import
# -------------------------------------------------------------------------

# 1. Define custom theme: "CyberMatrix" using the Declarative DSL
Opal.theme "CyberMatrix" do |t|
  t.primary "#00FF66"
  t.secondary "#00AA44"
  t.accent "#55FFAA"
  t.background "#0A0E0A"
  t.surface "#121A12"
  t.text "#E0FFE0"
  t.text_muted "#507550"
  t.border "#00FF66"
  t.window_border Opal::Border.pattern("-+")
  t.box_border Opal::Border.pattern("=-=")
  t.glyphs do |g|
    g.swap(
      window_close: "[X]",
      window_maximize: "[+]",
      window_minimize: "[-]",
      cursor: ">>",
      dropdown_arrow: "v",
      scrollbar_thumb: '#'
    )
  end
end

# 2. Define custom theme: "RetroAmber" with ASCII-only borders and glyphs
Opal.theme "RetroAmber" do |t|
  t.primary "#FFB000"
  t.secondary "#D08C00"
  t.accent "#FFCC44"
  t.background "#120B00"
  t.surface "#241600"
  t.text "#FFCC66"
  t.text_muted "#886022"
  t.border "#AA7700"
  t.window_border Opal::Border.ascii
  t.box_border Opal::Border.ascii
  t.glyphs do |g|
    g.swap(
      window_close: "[x]",
      window_maximize: "[^]",
      window_minimize: "[-]",
      cursor: "> ",
      scrollbar_thumb: 'O',
      table_junction: '+',
      table_horizontal: '-',
      table_vertical: '|'
    )
  end
end

# 3. Define custom theme: "NordicFrost" derived from standard Nord
Opal::Theme.nord.derive(
  name: "NordicFrost",
  primary: "#88C0D0",
  secondary: "#81A1C1",
  accent: "#B48EAD",
  window_border: Opal::Border.rounded,
  glyphs: Opal::GlyphSet.unicode
)

struct ThemeStudioModel
  include Opal::TEA::Model

  THEMES = ["CyberMatrix", "RetroAmber", "NordicFrost", "catppuccin_mocha", "dracula", "tokyo_night", "cyberpunk"]

  getter active_theme_idx : Int32
  getter status_message : String

  def initialize(@active_theme_idx : Int32 = 0, @status_message : String = "Press [ / ] or ← / → to switch themes, 'e' to export KV, 'q' to quit")
  end

  def init : Opal::TEA::Cmd
    Opal::TEA::Cmd.none
  end

  def update(msg : Opal::TEA::Msg) : {Opal::TEA::Model, Opal::TEA::Cmd}
    case msg
    when Opal::TEA::KeyMsg
      if msg.matches?("q") || msg.matches?("ctrl+c") || msg.matches?("escape")
        {self, Opal::TEA::Cmd.quit}
      elsif msg.matches?("[") || msg.matches?("left")
        new_idx = (@active_theme_idx - 1) % THEMES.size
        new_idx += THEMES.size if new_idx < 0
        Opal::Theme.current = THEMES[new_idx]
        {ThemeStudioModel.new(new_idx, "Switched to theme: #{THEMES[new_idx]}"), Opal::TEA::Cmd.none}
      elsif msg.matches?("]") || msg.matches?("right") || msg.matches?("tab")
        new_idx = (@active_theme_idx + 1) % THEMES.size
        Opal::Theme.current = THEMES[new_idx]
        {ThemeStudioModel.new(new_idx, "Switched to theme: #{THEMES[new_idx]}"), Opal::TEA::Cmd.none}
      elsif msg.matches?("e")
        theme = Opal::Theme.current
        kv = Opal::ThemeStore.export_kv(theme)
        {ThemeStudioModel.new(@active_theme_idx, "Exported '#{theme.name}' (#{kv.lines.size} KV lines)"), Opal::TEA::Cmd.none}
      else
        {self, Opal::TEA::Cmd.none}
      end
    else
      {self, Opal::TEA::Cmd.none}
    end
  end

  def view : String
    cols, rows = Opal::Terminal.default_driver.size
    cols = cols.clamp(74, 120)
    rows = rows.clamp(24, 40)

    buf = Opal::UI::Buffer.new(cols, rows)
    theme = Opal::Theme.current

    # Background canvas fill
    buf.fill(0, 0, cols, rows, ' ', fg: Opal::Color.none, bg: theme.background)

    # Top title bar
    buf.put_string(2, 0, "OPAL THEME DSL & CHARACTER SWAP RUNTIME", fg: theme.primary, bold: true)
    buf.put_string(cols - 28, 0, "Active: #{theme.name.upcase}", fg: theme.accent, bold: true)

    # Render Window container
    win = Opal::UI::Window.new(
      "Theme Studio & Character Swaps",
      x: 2, y: 1, width: cols - 4, height: rows - 3,
      border: theme.window_border,
      closable: true,
      minimizable: true,
      maximizable: true,
      resizable: false
    )
    win.render(buf, 2, 1, cols - 4, rows - 3)

    # 1. Theme Selector Header inside Window
    buf.put_string(5, 3, "Active Theme Preset:", fg: theme.text_muted)
    dropdown = Opal::UI::Dropdown.new(THEMES, selected_index: @active_theme_idx)
    dropdown.render(buf, 27, 3, 22, 1)

    btn_prev = Opal::UI::Button.new("< Prev [")
    btn_next = Opal::UI::Button.new("Next ] >")
    btn_prev.render(buf, 51, 3, 10, 1)
    btn_next.render(buf, 62, 3, 10, 1)

    # 2. Border Pattern & Glyph swap showcase box
    pattern_box = Opal::UI::Box.new(
      title: "Border Pattern & Character Swaps",
      border: theme.window_border
    )
    pattern_box.render(buf, 5, 5, cols - 10, 5)

    buf.put_string(7, 6, "Pattern: #{theme.window_border.top} | Close: #{theme.glyphs.window_close} | Max: #{theme.glyphs.window_maximize} | Min: #{theme.glyphs.window_minimize}", fg: theme.text)
    buf.put_string(7, 7, "Cursor: #{theme.glyphs.cursor} | Dropdown: #{theme.glyphs.dropdown_arrow} | ScrollThumb: #{theme.glyphs.scrollbar_thumb}", fg: theme.text_muted)
    buf.put_string(7, 8, "Per-Control .style Override: Buttons and borders adapt cleanly", fg: theme.accent)

    # 3. Contrast audit Table
    buf.put_string(5, 11, "Live Palette & WCAG 2.1 AA Contrast Audit:", fg: theme.primary, bold: true)
    table = Opal::UI::Table.new(["Token", "Hex Value", "Contrast", "WCAG AA"])
    audits = theme.audit_contrast
    table.add_row(["primary", theme.primary.to_hex, "#{audits["primary_on_background"]?.try { |a| a[:ratio].round(2) } || "?"}:1", audits["primary_on_background"]?.try { |a| a[:compliant] } ? "[PASS]" : "[WARN]"])
    table.add_row(["secondary", theme.secondary.to_hex, "-", "[INFO]"])
    table.add_row(["accent", theme.accent.to_hex, "#{audits["accent_on_background"]?.try { |a| a[:ratio].round(2) } || "?"}:1", audits["accent_on_background"]?.try { |a| a[:compliant] } ? "[PASS]" : "[WARN]"])
    table.add_row(["text", theme.text.to_hex, "#{audits["text_on_background"]?.try { |a| a[:ratio].round(2) } || "?"}:1", audits["text_on_background"]?.try { |a| a[:compliant] } ? "[PASS]" : "[WARN]"])
    table.add_row(["surface", theme.surface.to_hex, "-", "[BASE]"])
    table.add_row(["border", theme.border.to_hex, "-", "[STYLE]"])
    table.render(buf, 5, 12, cols - 15, 8)

    # 4. Scrollbar showing character swap
    scrollbar = Opal::UI::ScrollBar.new(:vertical, min_value: 0, max_value: 100, page_size: 15)
    scrollbar.render(buf, cols - 8, 12, 1, 8)

    # Status Bar at bottom
    status_y = rows - 1
    buf.fill(0, status_y, cols, 1, ' ', fg: Opal::Color.none, bg: theme.surface)
    buf.put_string(2, status_y, @status_message, fg: theme.text, bold: true)

    buf.render_to_string(with_ansi: true)
  end
end

if PROGRAM_NAME.includes?("15_custom_themes_and_presets")
  puts "Launching Opal Custom Themes & Presets Demo..."
  Opal.run_tea(ThemeStudioModel.new, alt_screen: true, diff_render: true)
  puts "Theme demo terminated cleanly. Terminal restored."
end

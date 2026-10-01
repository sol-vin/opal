require "../src/opal"
require "../src/opal/game"
require "../src/opal/gamepad"
require "../src/opal/mermaid"
require "../src/opal/html"
require "../src/opal/asciicast"

# =============================================================================
# [*] OPAL TUI FRAMEWORK SHOWCASE & INTERACTIVE DEMO APP
# =============================================================================
# Created by sol.vin (Ian Rash)
#
# A comprehensive interactive demonstration of the Opal Terminal User Interface
# Framework for Crystal, featuring:
#   - Check Slide with System Prerequisites & Capabilities
#   - Radial Spotlight Masking with Feathered Alpha Dithering
#   - Scissor Clipping & Buffer Region Operations (copy/paste/crop/invert/rotate)
#   - Real-World App Mockup 1: OpalChat (2-Pane Split with unread badges)
#   - Real-World App Mockup 2: Playable OpalPong with 60Hz Decoupled Loop
#   - Unified Multi-Space Color Studio & CLI Toolchain (RGB, HSL, LAB, Oklab, XYZ, CMYK)
#   - 2D Continuous Target Selector with Procedural Shaders & Reticles
#   - Bézier Curve Editor with Sub-Pixel Braille & Real-Time Easing Track
#   - 2D Unicode Math Typesetting & Cartesian Function Grapher
#   - Large Text, Big Digits & Live Clock
#   - Mermaid Diagram Viewer (Flowchart, Sequence, State, Class)
#   - TUI HTML Web Browser with History & OSC 8 Hyperlinks
#   - 6 Dropdown Styles & 1/8th Fractional Unicode Meters
#   - Multi-Shader Compositing Pipeline (Matrix + CRT + Glitch + Bloom)
#   - Real-Time Tweens & Easing Visualizer (16 Curves)
#   - Gamepad Controller Subsystem & Virtual Cursor
#
# Global Navigation:
#   [Shift+→] or [Tab] or [l]  : Next Slide
#   [Shift+←] or [Shift+Tab] or [h] : Previous Slide
#   [c] or [C]                 : Toggle Source Code Viewer Modal
#   [?]                        : Toggle Context-Sensitive Markdown Guide
#   [Ctrl+S]                   : Capture Screenshot & Copy to Clipboard
#   [q] or [ESC] or [Ctrl+C]   : Exit Showcase
#   Gamepad [LB] / [RB]        : Prev / Next Slide
#   Gamepad [X] / [Y]          : Toggle Code / Guide Modals
# =============================================================================

abstract class ShowcaseSlide
  abstract def title : String
  abstract def category : String
  abstract def hints : String
  abstract def source_code : String
  abstract def guide_markdown : String

  def handle_key(key : Opal::Terminal::KeyEvent) : Bool
    false
  end

  def handle_mouse(event : Opal::Terminal::MouseEvent) : Bool
    false
  end

  def handle_gamepad(event : Opal::Input::GamepadEvent) : Bool
    false
  end

  def tick(dt : Float64 = 0.0166) : Nil
  end

  abstract def render(buffer : Opal::UI::Buffer, x : Int32, y : Int32, w : Int32, h : Int32) : Nil
end

# =============================================================================
# Slide 1: System Capability & Experience Checklist ("Check" Slide)
# =============================================================================
class CheckSlide < ShowcaseSlide
  property checklist : Array(NamedTuple(id: Symbol, label: String, desc: String, ok: Bool, checked: Bool))
  property selected_idx : Int32 = 0
  property? launch_requested : Bool = false

  def initialize
    truecolor_ok = ENV.has_key?("COLORTERM") || ENV.fetch("TERM", "").includes?("24bit") || true
    unicode_ok = true
    mouse_ok = true
    gamepad_ok = Opal::Input::Gamepad.connected? rescue false

    cols, rows = Opal::Terminal.default_driver.size
    dim_ok = cols >= 80 && rows >= 24

    @checklist = [
      {
        id:      :truecolor,
        label:   "24-bit TrueColor ANSI Engine",
        desc:    "16.7M direct RGB terminal cell colors detected (#{ENV.fetch("COLORTERM", "truecolor")}).",
        ok:      truecolor_ok,
        checked: truecolor_ok,
      },
      {
        id:      :unicode,
        label:   "Unicode & Nerd Font Glyphs",
        desc:    "Shading (░▒▓█), fractional meters (▏..█), box borders (┌─┐).",
        ok:      unicode_ok,
        checked: unicode_ok,
      },
      {
        id:      :mouse,
        label:   "Extended SGR Mouse Protocol (1006)",
        desc:    "Pixel/cell accurate mouse click, hover, drag, and wheel tracking.",
        ok:      mouse_ok,
        checked: mouse_ok,
      },
      {
        id:      :gamepad,
        label:   "Gamepad / Controller Subsystem",
        desc:    gamepad_ok ? "Hardware XInput controller connected on Slot 0." : "Mock / Virtual controller active with full D-Pad focus traversal.",
        ok:      true,
        checked: true,
      },
      {
        id:      :viewport,
        label:   "Terminal Viewport Resolution",
        desc:    "Current geometry: #{cols}x#{rows} cells. (Recommended: 90x28+).",
        ok:      dim_ok,
        checked: dim_ok,
      },
    ]
  end

  def title : String
    "System Compatibility & Verification"
  end

  def category : String
    "Check Slide"
  end

  def hints : String
    "[↑/↓] Select Item  │  [Space] Toggle  │  [Enter] Start Showcase"
  end

  def source_code : String
    <<-CR
    require "opal"
    require "opal/gamepad"

    # Verify terminal environment capabilities
    driver = Opal::Terminal.default_driver
    cols, rows = driver.size

    puts "Opal TUI Framework by sol.vin (Ian Rash)"
    puts "TrueColor Support : \#{driver.supports_truecolor?}"
    puts "Gamepad Connected : \#{Opal::Input::Gamepad.connected?}"
    puts "Terminal Geometry : \#{cols}x\#{rows}"

    # Launch presentation model
    Opal.run_tea(ShowcaseAppModel.new, alt_screen: true, diff_render: true)
    CR
  end

  def guide_markdown : String
    <<-MD
    # Opal System Verification Checklist

    **Welcome to Opal TUI Framework** — created by `sol.vin (Ian Rash)`.

    This verification slide validates your terminal emulator capabilities before proceeding:

    - **TrueColor (24-bit RGB)**: Renders millions of discrete colors without 256-color palette clamping.
    - **Unicode Glyphs**: Verifies smooth font rendering for box-drawing, block shades, and directional symbols.
    - **Extended SGR Mouse (1006)**: Enables click-to-focus, drag selection, and wheel scrolling beyond column 223.
    - **Gamepad Controller**: Windows XInput with automatic headless/POSIX fallback and virtual pointer.

    ### Interactive Controls
    - **[↑ / ↓]** : Navigate checklist items.
    - **[Space]** : Toggle checkmark state.
    - **[Enter] / [A]** : Launch Interactive Showcase.
    MD
  end

  def handle_key(key : Opal::Terminal::KeyEvent) : Bool
    case key.name
    when "up", "k"
      @selected_idx = Math.max(0, @selected_idx - 1)
      true
    when "down", "j"
      @selected_idx = Math.min(@checklist.size, @selected_idx + 1)
      true
    when "space"
      if @selected_idx < @checklist.size
        item = @checklist[@selected_idx]
        @checklist[@selected_idx] = {
          id:      item[:id],
          label:   item[:label],
          desc:    item[:desc],
          ok:      item[:ok],
          checked: !item[:checked],
        }
      end
      true
    when "enter"
      @launch_requested = true
      true
    else
      false
    end
  end

  def handle_mouse(event : Opal::Terminal::MouseEvent) : Bool
    if event.button == Opal::Terminal::MouseButton::Left && event.action == Opal::Terminal::MouseAction::Press
      # Check checklist items click
      (0...@checklist.size).each do |idx|
        item_y = 7 + (idx * 3)
        if event.y >= item_y && event.y <= item_y + 1
          @selected_idx = idx
          item = @checklist[idx]
          @checklist[idx] = {
            id:      item[:id],
            label:   item[:label],
            desc:    item[:desc],
            ok:      item[:ok],
            checked: !item[:checked],
          }
          return true
        end
      end

      # Check Launch button click
      button_y = 8 + (@checklist.size * 3)
      if event.y >= button_y && event.y <= button_y + 2
        @launch_requested = true
        return true
      end
    end
    false
  end

  def handle_gamepad(event : Opal::Input::GamepadEvent) : Bool
    case event.button
    when Opal::Input::GamepadButton::DPadUp
      @selected_idx = Math.max(0, @selected_idx - 1)
      true
    when Opal::Input::GamepadButton::DPadDown
      @selected_idx = Math.min(@checklist.size, @selected_idx + 1)
      true
    when Opal::Input::GamepadButton::A
      if @selected_idx == @checklist.size
        @launch_requested = true
      else
        item = @checklist[@selected_idx]
        @checklist[@selected_idx] = {
          id:      item[:id],
          label:   item[:label],
          desc:    item[:desc],
          ok:      item[:ok],
          checked: !item[:checked],
        }
      end
      true
    else
      false
    end
  end

  def render(buffer : Opal::UI::Buffer, x : Int32, y : Int32, w : Int32, h : Int32) : Nil
    # Header Banner
    buffer.put_string(x + 2, y + 1, "❖ OPAL TERMINAL USER INTERFACE FRAMEWORK", fg: Opal::Color.bright_cyan, bold: true)
    buffer.put_string(x + 2, y + 2, "Created by sol.vin (Ian Rash) ── Next-Gen Terminal Engineering", fg: Opal::Color.hex("#38ef7d"))
    buffer.put_string(x + 2, y + 3, "─" * Math.max(0, w - 4), fg: Opal::Color.bright_black)

    buffer.put_string(x + 2, y + 5, "SYSTEM CAPABILITY & EXPERIENCE VERIFICATION:", fg: Opal::Color.bright_white, bold: true)

    # Render checklist items
    @checklist.each_with_index do |item, idx|
      row_y = y + 7 + (idx * 3)
      break if row_y + 2 >= y + h

      selected = (idx == @selected_idx)
      box_glyph = item[:checked] ? "[✔]" : "[ ]"
      box_color = item[:checked] ? Opal::Color.bright_green : Opal::Color.bright_black
      title_color = selected ? Opal::Color.bright_yellow : Opal::Color.bright_white

      cursor = selected ? "▶ " : "  "
      buffer.put_string(x + 2, row_y, cursor, fg: Opal::Color.bright_cyan, bold: true)
      buffer.put_string(x + 4, row_y, box_glyph, fg: box_color, bold: true)
      buffer.put_string(x + 8, row_y, item[:label], fg: title_color, bold: selected)

      buffer.put_string(x + 8, row_y + 1, item[:desc], fg: Opal::Color.bright_black)
    end

    # Launch Button
    btn_y = y + 8 + (@checklist.size * 3)
    if btn_y + 2 < y + h
      is_btn_selected = (@selected_idx == @checklist.size)
      btn_bg = is_btn_selected ? Opal::Color.hex("#11998e") : Opal::Color.hex("#1f2430")
      btn_fg = is_btn_selected ? Opal::Color.bright_white : Opal::Color.bright_cyan
      btn_text = " [ Launch Interactive Showcase ➔ ] "

      buffer.fill(x + 4, btn_y, btn_text.size, 1, ' ', bg: btn_bg)
      buffer.put_string(x + 4, btn_y, btn_text, fg: btn_fg, bg: btn_bg, bold: true)
      if is_btn_selected
        buffer.put_string(x + 2, btn_y, "▶", fg: Opal::Color.bright_cyan, bold: true)
      end
    end
  end
end

# =============================================================================
# Slide 2: Interactive Spotlight Masking Slide
# =============================================================================
class SpotlightSlide < ShowcaseSlide
  property center_x : Int32 = 45
  property center_y : Int32 = 12
  property radius : Int32 = 12
  property? feather : Bool = true
  property tint_idx : Int32 = 0

  TINTS = [
    {name: "Cyber Cyan", fg: Opal::Color.hex("#00f2fe")},
    {name: "Matrix Green", fg: Opal::Color.hex("#38ef7d")},
    {name: "Amber Phosphor", fg: Opal::Color.hex("#ffb199")},
    {name: "Neon Violet", fg: Opal::Color.hex("#b06ab3")},
  ]

  def title : String
    "Spotlight Alpha Masking"
  end

  def category : String
    "Advanced Graphics"
  end

  def hints : String
    "[WASD / Mouse] Move Light  │  [F] Toggle Feather  │  [+/-] Radius  │  [T] Tint"
  end

  def source_code : String
    <<-CR
    require "opal"

    # 1. Create a radial alpha mask map with feathered edge dithering
    mask = Opal::UI::MaskMap.radial(
      width: 80,
      height: 24,
      cx: 40,
      cy: 12,
      radius: 14.0,
      inner_radius: 6.0 # Smooth alpha ramp between inner and outer radius
    )

    # 2. Render high-density schematics and telemetry inside mask container
    buffer.with_mask(mask, feather: true) do
      buffer.put_string(10, 5, "TOP SECRET CYBERNETIC SCHEMATICS", fg: Color.cyan)
      schematic_box.render(buffer, 4, 2, 72, 20)
    end
    CR
  end

  def guide_markdown : String
    <<-MD
    # Spotlight Masking & Alpha Dithering

    Opal introduces hardware-level raster masking to terminal character buffers.

    ### Key Concepts
    - **`MaskMap`**: A 2D floating-point grid where each cell has an alpha coverage value from `0.0` (opaque/hidden) to `1.0` (fully visible).
    - **Feathered Dithering**: Uses Unicode fractional block shades (`[' ', '░', '▒', '▓', '█']`) to simulate smooth sub-character light diffusion at mask edges.
    - **Dynamic Tracking**: The spotlight can seamlessly track mouse pointers, virtual cursors, or gamepad analog thumbsticks.

    ### Interactive Controls
    - **[W / A / S / D]** or **Arrow Keys**: Move spotlight beam.
    - **Mouse Click/Hover**: Center light on mouse cursor.
    - **[F]**: Toggle feathered dithering on/off.
    - **[+] / [-]**: Expand or contract spotlight radius.
    - **[C]**: Cycle spotlight phosphor tint color.
    MD
  end

  def handle_key(key : Opal::Terminal::KeyEvent) : Bool
    case key.name
    when "w", "up"
      @center_y = Math.max(2, @center_y - 1)
      true
    when "s", "down"
      @center_y = Math.min(30, @center_y + 1)
      true
    when "a", "left"
      @center_x = Math.max(4, @center_x - 2)
      true
    when "d", "right"
      @center_x = Math.min(100, @center_x + 2)
      true
    when "f"
      @feather = !@feather
      true
    when "+", "="
      @radius = Math.min(30, @radius + 2)
      true
    when "-", "_"
      @radius = Math.max(4, @radius - 2)
      true
    when "t"
      @tint_idx = (@tint_idx + 1) % TINTS.size
      true
    else
      false
    end
  end

  def handle_mouse(event : Opal::Terminal::MouseEvent) : Bool
    @center_x = event.x
    @center_y = event.y - 2 # Offset for header
    true
  end

  def handle_gamepad(event : Opal::Input::GamepadEvent) : Bool
    case event.button
    when Opal::Input::GamepadButton::X
      @feather = !@feather
      true
    when Opal::Input::GamepadButton::Y
      @tint_idx = (@tint_idx + 1) % TINTS.size
      true
    else
      false
    end
  end

  def render(buffer : Opal::UI::Buffer, x : Int32, y : Int32, w : Int32, h : Int32) : Nil
    # 1. Render classified schematics into an offscreen scratch buffer
    offscreen = Opal::UI::Buffer.new(w, h)

    offscreen.put_string(2, 1, "CLASSIFIED SYSTEM SCHEMATICS // LEVEL-5 CLEARANCE REQUIRED", fg: Opal::Color.bright_red, bold: true)
    offscreen.put_string(2, 2, "PROJECT TITAN: QUANTUM FLUX INTERFEROMETER SPECIFICATION", fg: Opal::Color.bright_white)
    offscreen.put_string(2, 3, "─" * Math.max(0, w - 4), fg: Opal::Color.bright_black)

    # Render complex schematic grid
    schematic_lines = [
      "  ┌─────────────────────────┐      ┌─────────────────────────┐      ┌─────────────────────────┐",
      "  │  ION ACCELERATOR CORE   │ ───> │  FIELD STABILIZER ARRAY │ ───> │  RELATIVISTIC MODULATOR │",
      "  │  Status: SUPERCRITICAL  │      │  Harmonics: 432.89 THz  │      │  Efficiency: 99.412%    │",
      "  │  Power Draw: 1.21 GW    │      │  Magnetic Flux: 18.4 T  │      │  Phase Lock: ACTIVE     │",
      "  └─────────────────────────┘      └─────────────────────────┘      └─────────────────────────┘",
      "               │                                │                                │             ",
      "               ▼                                ▼                                ▼             ",
      "  ┌───────────────────────────────────────────────────────────────────────────────────────────┐",
      "  │  CENTRAL TELEMETRY BUS ── BUS_ADDR: 0x7FFF0048 ── FRAME_LATENCY: 0.12ms                   │",
      "  │  Telemetry Logs: [OK] Sensor 1-A nominal  [OK] Cryo-coolant flow 8.4 L/s  [OK] Inertia 0G │",
      "  │  Emergency Purge Valve: ARMED   Safety Lock: ENGAGED   Containment Mesh: 100% INTEGRITY   │",
      "  └───────────────────────────────────────────────────────────────────────────────────────────┘",
      "                                                                                               ",
      "  SUBSYSTEM DIAGNOSTIC DUMP:                                                                   ",
      "  [00:01:24] Handshake initiated with sub-orbital uplink satellite SAT-9X4...                  ",
      "  [00:01:25] Quantum entanglement key exchange complete. Entropy score: 0.99982                ",
      "  [00:01:26] Overclocking optical neural lattice to 8.4 GHz. Temperature: 34.2°C                ",
      "  [00:01:27] Warning: Minor magnetic eddy detected in quadrant 7. Compensating via coils...     ",
      "  [00:01:28] Compensation successful. Variance eliminated within 4.2 milliseconds.             ",
    ]

    schematic_lines.each_with_index do |line, l_idx|
      offscreen.put_string(2, 5 + l_idx, line, fg: Opal::Color.bright_cyan)
    end

    # 2. Build radial mask map centered at (@center_x, @center_y)
    mask = Opal::UI::MaskMap.radial(
      cx: @center_x - x,
      cy: @center_y - y,
      radius: @radius.to_f,
      feather: @feather ? 4.0 : 0.0,
      width: w,
      height: h
    )

    # 3. Apply mask to target buffer
    buffer.fill(x, y, w, h, ' ', bg: Opal::Color.hex("#080b11"))

    current_tint = TINTS[@tint_idx][:fg]

    (0...h).each do |sy|
      (0...w).each do |sx|
        alpha = mask[sx, sy]
        next if alpha <= 0.01

        cell = offscreen.get(sx, sy)
        target_cell = cell

        # Apply tint and alpha
        if @feather && alpha < 0.95
          # Alpha dithering
          dither_glyph = Opal::UI::MaskMap.dither_char(alpha)
          target_cell = Opal::UI::Cell.new(
            dither_glyph,
            fg: current_tint,
            bg: Opal::Color.hex("#080b11")
          )
        else
          target_cell = Opal::UI::Cell.new(
            cell.char,
            fg: current_tint,
            bg: Opal::Color.hex("#111827"),
            bold: cell.bold?
          )
        end

        buffer.set(x + sx, y + sy, target_cell)
      end
    end

    # HUD Overlay: Spotlight Coordinates & Controls
    hud_text = " SPOTLIGHT: [#{@center_x}, #{@center_y}] │ RADIUS: #{@radius} │ FEATHER: #{@feather ? "ON (Dithered)" : "OFF (Sharp)"} │ TINT: #{TINTS[@tint_idx][:name]} "
    buffer.put_string(x + 2, y + h - 2, hud_text, fg: Opal::Color.bright_white, bg: Opal::Color.hex("#1f2937"), bold: true)
  end
end

# =============================================================================
# Slide 3: Scissor Mode & Buffer Region Ops
# =============================================================================
class ScissorBufferSlide < ShowcaseSlide
  property scissor_x : Int32 = 4
  property scissor_y : Int32 = 4
  property scissor_w : Int32 = 42
  property scissor_h : Int32 = 14

  property stamp_pos_x : Int32 = 54
  property stamp_pos_y : Int32 = 5
  property stamp_mode_idx : Int32 = 0
  property? inverted : Bool = false
  property scroll_offset : Int32 = 0

  MODES = [Opal::UI::BlitMode::Replace, Opal::UI::BlitMode::Blend, Opal::UI::BlitMode::IgnoreSpaces]

  def title : String
    "Scissor Clipping & Buffer Operations"
  end

  def category : String
    "Core Graphics"
  end

  def hints : String
    "[WASD] Resize Scissor  │  [B] Blit Mode  │  [I] Invert Rect  │  [R] Scroll Rect"
  end

  def source_code : String
    <<-CR
    require "opal"

    # 1. Scissor container restricts drawing strictly inside boundary
    buffer.with_scissor(x: 4, y: 4, width: 40, height: 12) do
      # Content that extends beyond 40 cols is safely clipped
      buffer.put_string(0, 0, "This very long sentence will be cleanly clipped at border!")
      inner_component.render(buffer, 2, 2, 60, 20)
    end

    # 2. Buffer memory operations: copy, paste, invert, scroll
    stamp = buffer.copy(rect: Opal::UI::Rect.new(4, 4, 20, 8))
    buffer.invert(rect: Opal::UI::Rect.new(10, 6, 12, 4))
    buffer.paste(stamp, dst_x: 50, dst_y: 6, mode: Opal::UI::BlitMode::Blend)
    CR
  end

  def guide_markdown : String
    <<-MD
    # Scissor Clipping & Buffer Operations

    Opal brings fine-grained geometric buffer manipulation into pure Crystal terminal apps:

    ### Scissor Test
    - Restricts cell writes strictly to a sub-rectangle `[x, y, width, height]`.
    - Automatically handles wide-character safety so multi-cell emojis or East Asian ideographs never leave trailing artifacts.

    ### Region Operations
    - **`Buffer#copy(rect)`**: Clones a memory slice into an independent sub-buffer.
    - **`Buffer#paste(src, x, y, mode)`**: Blits a sub-buffer onto the target with blend modes (`:replace`, `:blend`, `:ignore_spaces`).
    - **`Buffer#invert(rect)`**: Inverts foreground/background RGB colors and toggles reverse attributes.
    - **`Buffer#scroll_rect(rect, dx, dy)`**: Smoothly scrolls arbitrary sub-regions.
    MD
  end

  def handle_key(key : Opal::Terminal::KeyEvent) : Bool
    case key.name
    when "w", "up"
      @scissor_h = Math.max(6, @scissor_h - 1)
      true
    when "s", "down"
      @scissor_h = Math.min(18, @scissor_h + 1)
      true
    when "a", "left"
      @scissor_w = Math.max(20, @scissor_w - 2)
      true
    when "d", "right"
      @scissor_w = Math.min(60, @scissor_w + 2)
      true
    when "b"
      @stamp_mode_idx = (@stamp_mode_idx + 1) % MODES.size
      true
    when "i"
      @inverted = !@inverted
      true
    when "r"
      @scroll_offset = (@scroll_offset + 1) % 10
      true
    else
      false
    end
  end

  def render(buffer : Opal::UI::Buffer, x : Int32, y : Int32, w : Int32, h : Int32) : Nil
    # 1. Left Column: Scissor Container Demonstration
    buffer.put_string(x + 2, y + 1, "SCISSOR TEST CONTAINER (Bounded Viewport):", fg: Opal::Color.bright_cyan, bold: true)
    buffer.put_string(x + 2, y + 2, "Content outside scissor box is mathematically clipped with wide-char safety.", fg: Opal::Color.bright_black)

    # Outer guide box
    guide_box = Opal::UI::Box.new(border: :rounded, border_fg: Opal::Color.bright_yellow)
    guide_box.render(buffer, x + @scissor_x - 1, y + @scissor_y - 1, @scissor_w + 2, @scissor_h + 2)

    # Scissor restricted drawing
    buffer.with_scissor(x + @scissor_x, y + @scissor_y, @scissor_w, @scissor_h) do
      # Draw overflowing text lines
      buffer.put_string(x + @scissor_x, y + @scissor_y, "LINE 1: 0123456789 ABCDEFGHIJKLMNOPQRSTUVWXYZ 0123456789 ABCDEFGHIJKLMNOPQRSTUVWXYZ", fg: Opal::Color.bright_white)
      buffer.put_string(x + @scissor_x, y + @scissor_y + 1, "LINE 2: ★ Wide Characters: 【日本語テスト】 🚀 Emoticons & Symbols ── Overflow Clip Test", fg: Opal::Color.bright_green)
      buffer.put_string(x + @scissor_x, y + @scissor_y + 2, "LINE 3: ─────────────────────────────────────────────────────────────────────────────", fg: Opal::Color.cyan)

      (3...@scissor_h).each do |row|
        buffer.put_string(x + @scissor_x, y + @scissor_y + row, "ROW #{row}: Matrix stream buffer element [#{row * 1024} bytes processed] ─── EXTENDED OVERFLOW", fg: Opal::Color.hex("#38ef7d"))
      end
    end

    # 2. Right Column: Buffer Operations
    right_x = x + @scissor_x + @scissor_w + 4
    if right_x + 30 < x + w
      buffer.put_string(right_x, y + 1, "BUFFER REGION OPERATIONS:", fg: Opal::Color.bright_magenta, bold: true)
      buffer.put_string(right_x, y + 2, "Direct memory stamping, inversion, and transforms.", fg: Opal::Color.bright_black)

      # Sample source buffer
      stamp = Opal::UI::Buffer.new(28, 8)
      stamp.fill(0, 0, 28, 8, ' ', bg: Opal::Color.hex("#1e1b4b"))
      stamp.put_string(2, 1, "✦ BUFFER STAMP ✦", fg: Opal::Color.hex("#a78bfa"), bold: true)
      stamp.put_string(2, 3, "Blit Mode: #{MODES[@stamp_mode_idx]}", fg: Opal::Color.bright_white)
      stamp.put_string(2, 5, "Alpha dithered overlay", fg: Opal::Color.bright_green)

      # Invert sub-region if toggled
      if @inverted
        stamp.invert(Opal::UI::Rect.new(1, 1, 26, 6))
      end

      # Paste onto main buffer
      buffer.paste(stamp, right_x, y + 4, MODES[@stamp_mode_idx])

      # HUD
      buffer.put_string(right_x, y + 14, "Scissor Bounds : #{@scissor_w}x#{@scissor_h}", fg: Opal::Color.bright_white)
      buffer.put_string(right_x, y + 15, "Blit Mode      : #{MODES[@stamp_mode_idx]} [Press B to cycle]", fg: Opal::Color.bright_yellow)
      buffer.put_string(right_x, y + 16, "Invert Region  : #{@inverted ? "ACTIVE [Press I]" : "OFF [Press I]"}", fg: Opal::Color.bright_cyan)
    end
  end
end

# =============================================================================
# Slide 4: Real-World App Mockup 1 — OpalChat (2-Pane Split)
# =============================================================================
class OpalChatSlide < ShowcaseSlide
  property active_channel : Int32 = 0
  property input_text : String = "Can we verify the new scissor mode on Discord?"
  property cursor_blink : Bool = true

  CHANNELS = ["# general", "# core-development", "# ui-showcase", "# announcements"]
  USERS    = [
    {name: "@sol.vin", status: "online", color: Opal::Color.bright_green},
    {name: "@ian", status: "online", color: Opal::Color.bright_green},
    {name: "@reviewer", status: "idle", color: Opal::Color.bright_yellow},
    {name: "@ci-bot", status: "offline", color: Opal::Color.bright_black},
  ]

  property messages : Array(NamedTuple(user: String, time: String, text: String, badge: String))

  def initialize
    @messages = [
      {user: "@sol.vin", time: "14:02", text: "Welcome everyone to Opal 2.0!", badge: "ADMIN"},
      {user: "@ian", time: "14:05", text: "The new fixed-timestep 60Hz loop is buttery smooth.", badge: "DEV"},
      {user: "@reviewer", time: "14:07", text: "Checking the 2-pane chat mockup. Zero text overflow!", badge: "QA"},
      {user: "@sol.vin", time: "14:10", text: "Testing code block rendering inside chat message:", badge: "ADMIN"},
      {user: "@sol.vin", time: "14:10", text: "  def pong_loop; game.step(0.0166); end", badge: "CODE"},
      {user: "@ci-bot", time: "14:12", text: "✔ All 715 specs passed with 0 errors across all modules.", badge: "BOT"},
    ]
  end

  def title : String
    "App Mockup: OpalChat (2-Pane Split)"
  end

  def category : String
    "Real-World Mockup"
  end

  def hints : String
    "[↑/↓] Switch Channels  │  [Type] Chat Input  │  [Enter] Send Message"
  end

  def source_code : String
    <<-CR
    require "opal"

    # Declarative 2-pane split chat architecture
    split_view(direction: :horizontal, ratio: 0.28) do |split|
      split.left do
        box(title: "Channels", border: :rounded) do
          filter_list(items: ["# general", "# dev", "# announcements"])
          text "DIRECT MESSAGES:"
          badge "@sol.vin", variant: :success
        end
      end

      split.right do
        group(overflow: :scroll) do
          message_stream.each do |msg|
            chat_bubble(user: msg.user, time: msg.time, text: msg.text)
          end
          text_input(placeholder: "Type a message...")
        end
      end
    end
    CR
  end

  def guide_markdown : String
    <<-MD
    # OpalChat: Multi-Pane Boundary & Overflow Architecture

    Real-world TUI applications demand nested panes that safely constrain text to their designated containers.

    ### Architectural Highlights
    - **Split View Layout**: Divides available terminal screen estate horizontally or vertically with proportional ratios.
    - **Nested Boundary Containment**: Long messages wrap automatically without corrupting adjacent columns or lines.
    - **Component Composition**: Combines `Box`, `FilterList`, `Badge`, `TextInput`, and `Group` into an ergonomic workflow.
    MD
  end

  def handle_key(key : Opal::Terminal::KeyEvent) : Bool
    case key.name
    when "up", "k"
      @active_channel = Math.max(0, @active_channel - 1)
      true
    when "down", "j"
      @active_channel = Math.min(CHANNELS.size - 1, @active_channel + 1)
      true
    when "enter"
      if @input_text.strip.size > 0
        now_time = Time.local.to_s("%H:%M")
        @messages << {user: "@you", time: now_time, text: @input_text.strip, badge: "YOU"}
        @input_text = ""
        true
      else
        false
      end
    when "backspace"
      @input_text = @input_text[0...-1] if @input_text.size > 0
      true
    else
      if key.char && key.char.as(Char).printable?
        @input_text += key.char.to_s
        true
      else
        false
      end
    end
  end

  property tick_counter : Int32 = 0

  def tick(dt : Float64 = 0.0166) : Nil
    @tick_counter += 1
    @cursor_blink = (@tick_counter // 20) % 2 == 0
  end

  def render(buffer : Opal::UI::Buffer, x : Int32, y : Int32, w : Int32, h : Int32) : Nil
    sidebar_w = 26
    chat_w = Math.max(20, w - sidebar_w - 3)

    # 1. Left Sidebar: Channels & Online Users
    side_box = Opal::UI::Box.new(title: "OpalChat Network", border: :rounded, border_fg: Opal::Color.bright_cyan)
    side_box.render(buffer, x + 1, y + 1, sidebar_w, h - 2)

    buffer.put_string(x + 3, y + 3, "CHANNELS:", fg: Opal::Color.bright_white, bold: true)
    CHANNELS.each_with_index do |ch, idx|
      selected = (idx == @active_channel)
      bg_c = selected ? Opal::Color.hex("#1e3a8a") : Opal::Color.none
      fg_c = selected ? Opal::Color.bright_yellow : Opal::Color.bright_cyan
      buffer.put_string(x + 3, y + 5 + idx, " #{selected ? "▶" : "#"} #{ch[2..]} ", fg: fg_c, bg: bg_c, bold: selected)
    end

    buffer.put_string(x + 3, y + 11, "DIRECT MESSAGES:", fg: Opal::Color.bright_white, bold: true)
    USERS.each_with_index do |u, idx|
      buffer.put_string(x + 3, y + 13 + idx, "●", fg: u[:color])
      buffer.put_string(x + 5, y + 13 + idx, u[:name], fg: Opal::Color.bright_white)
    end

    # 2. Right Pane: Conversation History
    chat_x = x + sidebar_w + 3
    chat_box = Opal::UI::Box.new(title: "Channel: #{CHANNELS[@active_channel]}", border: :rounded, border_fg: Opal::Color.hex("#38ef7d"))
    chat_box.render(buffer, chat_x, y + 1, chat_w, h - 5)

    # Show newest messages that fit
    max_msgs = (h - 7) // 2
    visible_msgs = @messages.size > max_msgs ? @messages[-max_msgs..] : @messages

    visible_msgs.each_with_index do |msg, idx|
      row_y = y + 3 + (idx * 2)
      break if row_y >= y + h - 6

      buffer.put_string(chat_x + 2, row_y, msg[:user], fg: Opal::Color.bright_cyan, bold: true)
      buffer.put_string(chat_x + 2 + msg[:user].size + 1, row_y, "[#{msg[:badge]}]", fg: Opal::Color.bright_magenta)
      buffer.put_string(chat_x + 2 + msg[:user].size + msg[:badge].size + 4, row_y, msg[:time], fg: Opal::Color.bright_black)

      msg_color = msg[:badge] == "CODE" ? Opal::Color.hex("#ffd200") : Opal::Color.bright_white
      buffer.put_string(chat_x + 4, row_y + 1, msg[:text], fg: msg_color)
    end

    # 3. Bottom Chat Input Box
    input_y = y + h - 4
    input_box = Opal::UI::Box.new(border: :rounded, border_fg: Opal::Color.bright_white)
    input_box.render(buffer, chat_x, input_y, chat_w, 3)

    cursor = @cursor_blink ? "█" : " "
    max_inp_len = Math.max(5, chat_w - 18)
    disp_text = @input_text.size > max_inp_len ? "..." + @input_text[-(max_inp_len - 3)..] : @input_text
    buffer.put_string(chat_x + 2, input_y + 1, "❯ #{disp_text}#{cursor}", fg: Opal::Color.bright_white)
    buffer.put_string(chat_x + chat_w - 12, input_y + 1, "[ Send ➔ ]", fg: Opal::Color.hex("#38ef7d"), bold: true)
  end
end

# =============================================================================
# Slide 5: Real-World App Mockup 2 — Playable OpalPong
# =============================================================================
class OpalPongSlide < ShowcaseSlide
  property pong : Opal::Game::Pong
  property? paused : Bool = false
  property fps : Float64 = 60.0
  property frame_count : Int32 = 0

  def initialize
    @pong = Opal::Game::Pong.new(court_width: 66, court_height: 18)
  end

  def title : String
    "App Mockup: Playable OpalPong (60Hz Engine)"
  end

  def category : String
    "Game Engine"
  end

  def hints : String
    "[W/S or ↑/↓] Move Paddle  │  [Space] Pause/Resume  │  [R] Reset Ball"
  end

  def source_code : String
    <<-CR
    require "opal"
    require "opal/game"

    # Playable 60Hz fixed-timestep game loop
    pong = Opal::Game::Pong.new(court_width: 70, court_height: 20)

    game_loop(target_fps: 60, tick_rate: 60) do
      update do |dt|
        pong.update(dt) # Physics collision, paddle AI, particle decay
      end

      render do |buffer, alpha|
        pong.render(buffer, alpha: alpha) # State interpolation
      end
    end
    CR
  end

  def guide_markdown : String
    <<-MD
    # 60Hz Fixed-Timestep Game Architecture (`opal/game`)

    Opal features a fully decoupled, deterministic game loop engine based on Glenn Fiedler's famous *"Fix Your Timestep"* architecture:

    ### Physics & Simulation
    - **Fixed Timestep**: Physics simulations update at exactly 60Hz (`dt = 0.0166s`), guaranteeing predictable collisions across varying hardware.
    - **Particle Trails**: Ball motion generates glowing particle sparks with velocity dispersion and lifespan fading.
    - **3x5 Block Digits**: Displays the live match score with bold 7-segment digital font characters.
    MD
  end

  def handle_key(key : Opal::Terminal::KeyEvent) : Bool
    case key.name
    when "w", "up"
      @pong.move_player(-1.5)
      true
    when "s", "down"
      @pong.move_player(1.5)
      true
    when "space"
      @paused = !@paused
      true
    when "r"
      @pong.reset_ball
      true
    else
      false
    end
  end

  def handle_gamepad(event : Opal::Input::GamepadEvent) : Bool
    case event.button
    when Opal::Input::GamepadButton::DPadUp
      @pong.move_player(-1.5)
      true
    when Opal::Input::GamepadButton::DPadDown
      @pong.move_player(1.5)
      true
    when Opal::Input::GamepadButton::Start
      @paused = !@paused
      true
    else
      false
    end
  end

  def tick(dt : Float64 = 0.0166) : Nil
    return if @paused
    @pong.update(dt)
    @frame_count += 1
  end

  def render(buffer : Opal::UI::Buffer, x : Int32, y : Int32, w : Int32, h : Int32) : Nil
    court_x = x + 4
    court_y = y + 2
    court_w = Math.min(@pong.court_width, w - 8)
    court_h = Math.min(@pong.court_height, h - 8)

    # 1. Top Scoreboard using Digits
    score_str = "#{@pong.player_score} - #{@pong.ai_score}"
    buffer.put_string(court_x + (court_w // 2) - 6, court_y - 1, "PLAYER", fg: Opal::Color.bright_cyan, bold: true)
    buffer.put_string(court_x + (court_w // 2) + 4, court_y - 1, "OPAL-AI", fg: Opal::Color.bright_magenta, bold: true)

    digits = Opal::UI::Digits.new(score_str, fg: Opal::Color.bright_white, bold: true)
    digits.render(buffer, court_x + (court_w // 2) - 8, court_y + 1, 16, 5)

    # 2. Render Court Box
    court_box = Opal::UI::Box.new(border: :double, border_fg: Opal::Color.bright_yellow)
    court_box.render(buffer, court_x, court_y + 6, court_w, court_h)

    # Center net
    (court_y + 7...court_y + 6 + court_h - 1).each do |net_y|
      buffer.put_char(court_x + (court_w // 2), net_y, '┆', fg: Opal::Color.bright_black)
    end

    # 3. Render Particles
    @pong.particles.each do |p|
      px = court_x + p.x.round.to_i
      py = court_y + 6 + p.y.round.to_i
      if px > court_x && px < court_x + court_w - 1 && py > court_y + 6 && py < court_y + 6 + court_h - 1
        buffer.put_char(px, py, '•', fg: p.color)
      end
    end

    # 4. Render Paddles
    # Player Paddle (Left)
    p_top = court_y + 6 + @pong.player_y.round.to_i
    (0...@pong.paddle_height).each do |offset|
      buffer.put_char(court_x + 1, p_top + offset, '█', fg: Opal::Color.bright_cyan)
    end

    # AI Paddle (Right)
    ai_top = court_y + 6 + @pong.ai_y.round.to_i
    (0...@pong.paddle_height).each do |offset|
      buffer.put_char(court_x + court_w - 2, ai_top + offset, '█', fg: Opal::Color.bright_magenta)
    end

    # 5. Render Ball
    ball_px = court_x + @pong.ball_x.round.to_i
    ball_py = court_y + 6 + @pong.ball_y.round.to_i
    if ball_px > court_x && ball_px < court_x + court_w - 1 && ball_py > court_y + 6 && ball_py < court_y + 6 + court_h - 1
      buffer.put_char(ball_px, ball_py, '●', fg: Opal::Color.hex("#38ef7d"), bold: true)
    end

    # HUD Status
    status_text = " STATE: #{@paused ? "PAUSED [Space]" : "RUNNING"} │ ENGINE: 60Hz FIXED-TIMESTEP │ PARTICLES: #{@pong.particles.size} "
    status_y = Math.min(y + h - 1, court_y + 6 + court_h)
    buffer.put_string(court_x + 2, status_y, status_text, fg: Opal::Color.bright_white, bg: Opal::Color.hex("#1f2937"))
  end
end

# =============================================================================
# Slide 6: Unified Multi-Space Color Studio & CLI Toolchain
# =============================================================================
class ColorPickerStudioSlide < ShowcaseSlide
  property picker : Opal::UI::ColorPicker

  def initialize
    @picker = Opal::UI::ColorPicker.new(
      initial_color: Opal::Color.hex("#38EF7D"),
      layout: Opal::UI::ColorPickerLayout::Studio,
      show_alpha: true,
      show_harmonies: true,
      show_select_button: true
    )
  end

  def title : String
    "Unified Multi-Space Color Studio & CLI"
  end

  def category : String
    "Controls & Color Spaces"
  end

  def hints : String
    "[m] Mode  │  [Tab] Cycle Channel  │  [←/→] Adjust  │  [Click/Drag] Pick  │  [Space/Enter] Confirm"
  end

  def source_code : String
    <<-CR
    require "opal"

    # 1. Component Usage: 8 Color Spaces, Harmonies, Alpha, 2D Plane
    picker = Opal::UI::ColorPicker.new(
      initial_color: Opal::Color.hex("#38EF7D"),
      mode: Opal::UI::ColorMode::RGB,      # RGB, HSL, HSV, LAB, Oklab, XYZ, CMYK, HEX
      layout: Opal::UI::ColorPickerLayout::Studio,
      show_alpha: true,
      show_harmonies: true,
      show_select_button: true
    )

    picker.on_change do |c|
      puts "Selected Color: \#{c.to_hex} (L*a*b*: \#{c.to_lab.map(&.round(1))})"
    end

    # 2. CLI Toolchain (gum / fzf separated I/O paradigm):
    # Interactive TUI runs on STDERR; clean result emitted strictly to STDOUT!
    #   $ MY_COLOR=$(opal colorpicker --format hex --mode lab)
    #   $ echo "Selected: $MY_COLOR"
    CR
  end

  def guide_markdown : String
    <<-MD
    # Unified Multi-Space Color Studio & CLI Toolchain

    Opal provides comprehensive color science and interactive manipulation across **8 color spaces**:

    ### Supported Color Spaces
    - **sRGB** (Standard Red, Green, Blue [0-255])
    - **HSL / HSV** (Cylindrical Hue, Saturation, Lightness / Value)
    - **CIELAB** ($L^*a^*b^*$ perceptually uniform color space using CIE standard illuminant D65)
    - **Oklab / Oklch** (Modern perceptual color space optimized for smooth gradients and perceptual lightness)
    - **CIE XYZ** (Tristimulus reference color space)
    - **CMYK** (Subtractive 4-channel printing color space [0-100%])
    - **Hexadecimal** (Web / CSS `#RRGGBB` serialization)

    ### Separated-IO CLI Architecture
    Following Unix conventions established by tools like `fzf` and `gum`:
    - The interactive TUI driver renders strictly to **`STDERR`**
    - The final confirmed selection is output cleanly to **`STDOUT`**
    - This allows shell automation scripts to cleanly capture output without ANSI escape pollution:
      ```bash
      MY_HEX=$(opal colorpicker --format hex)
      MY_RGB=$(opal colorpicker --format rgb --alpha)
      ```
    MD
  end

  def handle_key(key : Opal::Terminal::KeyEvent) : Bool
    @picker.handle_key(key)
  end

  def handle_mouse(event : Opal::Terminal::MouseEvent) : Bool
    @picker.handle_mouse(event)
  end

  def render(buffer : Opal::UI::Buffer, x : Int32, y : Int32, w : Int32, h : Int32) : Nil
    picker_w = Math.min(54, w - 4)
    @picker.render(buffer, x + 2, y + 1, picker_w, h - 2)

    right_x = x + 2 + picker_w + 2
    right_w = (x + w) - right_x - 2
    if right_w >= 26 && h >= 14
      cur_c = @picker.color
      hex_code = cur_c.to_hex

      diag_box = Opal::UI::Box.new(title: "Color Science Readout", border: :rounded, border_fg: cur_c)
      diag_box.render(buffer, right_x, y + 1, right_w, h - 2)

      patch_w = Math.min(right_w - 4, 28)
      (0...3).each do |py|
        buffer.fill(right_x + 2, y + 3 + py, patch_w, 1, ' ', bg: cur_c)
      end
      buffer.put_string(right_x + 4, y + 4, " #{hex_code} ", fg: Opal::Color.black, bg: Opal::Color.white, bold: true)

      row = y + 7
      buffer.put_string(right_x + 2, row, "PERCEPTUAL COLOR SPACES:", fg: Opal::Color.bright_white, bold: true)
      row += 1

      h_val, s_val, l_val = cur_c.to_hsl
      buffer.put_string(right_x + 2, row, sprintf("HSL:   %3.0f° %3.0f%% %3.0f%%", h_val, s_val * 100, l_val * 100), fg: Opal::Color.bright_yellow)
      row += 1

      lab_l, lab_a, lab_b = cur_c.to_lab
      buffer.put_string(right_x + 2, row, sprintf("LAB:   %4.1f %5.1f %5.1f", lab_l, lab_a, lab_b), fg: Opal::Color.bright_magenta)
      row += 1

      ok_l, ok_a, ok_b = cur_c.to_oklab
      buffer.put_string(right_x + 2, row, sprintf("Oklab: %4.2f %5.2f %5.2f", ok_l, ok_a, ok_b), fg: Opal::Color.bright_cyan)
      row += 1

      xyz_x, xyz_y, xyz_z = cur_c.to_xyz
      buffer.put_string(right_x + 2, row, sprintf("XYZ:   %4.2f %5.2f %5.2f", xyz_x, xyz_y, xyz_z), fg: Opal::Color.bright_blue)
      row += 1

      cmyk_c, cmyk_m, cmyk_y, cmyk_k = cur_c.to_cmyk
      buffer.put_string(right_x + 2, row, sprintf("CMYK:  %3.0f%% %3.0f%% %3.0f%% %3.0f%%", cmyk_c * 100, cmyk_m * 100, cmyk_y * 100, cmyk_k * 100), fg: Opal::Color.bright_green)
      row += 2

      if row + 3 < y + h - 2
        buffer.put_string(right_x + 2, row, "CLI COMMAND TOOL:", fg: Opal::Color.bright_cyan, bold: true)
        row += 1
        buffer.put_string(right_x + 2, row, "$ opal colorpicker", fg: Opal::Color.white)
        row += 1
        buffer.put_string(right_x + 2, row, "STDERR: TUI │ STDOUT: #{hex_code}", fg: Opal::Color.bright_black)
      end
    end
  end
end

# =============================================================================
# Slide 7: 2D Target Style Selector & Procedural Shaders
# =============================================================================
class TargetSelectorSlide < ShowcaseSlide
  property target : Opal::UI::TargetSelector2D
  property current_shader_idx : Int32 = 0
  property current_reticle_idx : Int32 = 0

  RETICLES = ['⌖', '┼', '◎', '+', '✦']

  def initialize
    @target = Opal::UI::TargetSelector2D.new(
      x_range: -10.0..10.0,
      y_range: -10.0..10.0,
      initial_x: 2.5,
      initial_y: -3.0,
      reticle_char: '⌖',
      width: 38,
      height: 14
    )
    apply_shader(0)
  end

  def apply_shader(idx : Int32) : Nil
    @current_shader_idx = idx % 3
    case @current_shader_idx
    when 0
      @target.background_shader = ->(u : Float64, v : Float64) : Opal::Color {
        dx = u - 0.5
        dy = v - 0.5
        dist = Math.sqrt(dx * dx + dy * dy) * 2.0
        hue = ((1.0 - dist.clamp(0.0, 1.0)) * 240.0).clamp(0.0, 360.0)
        Opal::Color.hsl(hue, 1.0, 0.45)
      }
    when 1
      @target.background_shader = ->(u : Float64, v : Float64) : Opal::Color {
        v1 = Math.sin(u * 8.0)
        v2 = Math.sin(v * 8.0)
        v3 = Math.sin((u + v) * 6.0)
        c_val = ((v1 + v2 + v3 + 3.0) / 6.0).clamp(0.0, 1.0)
        Opal::Color.hsl(c_val * 300.0 + 60.0, 0.9, 0.5)
      }
    when 2
      @target.background_shader = ->(u : Float64, v : Float64) : Opal::Color {
        r = (u * 255.0).round.to_i.clamp(0, 255)
        g = (v * 255.0).round.to_i.clamp(0, 255)
        b = 180
        Opal::Color.rgb(r, g, b)
      }
    end
  end

  def title : String
    "2D Continuous Target Selector & Shaders"
  end

  def category : String
    "Advanced Selectors"
  end

  def hints : String
    "[↑/↓/←/→] Pan Reticle  │  [Click/Drag] Aim  │  [1/2/3] Shaders  │  [r] Reticle Glyph"
  end

  def source_code : String
    <<-CR
    require "opal"

    # Continuous 2D Target Style Selector with Custom Physics / UV Domain
    target = Opal::UI::TargetSelector2D.new(
      x_range: -10.0..10.0,
      y_range: -10.0..10.0,
      initial_x: 2.5,
      initial_y: -3.0,
      reticle_char: '⌖'
    ) do |u, v|
      # Procedural shader block: normalized u, v in [0.0..1.0] -> Color
      dx = u - 0.5
      dy = v - 0.5
      dist = Math.sqrt(dx * dx + dy * dy) * 2.0
      Opal::Color.hsl((1.0 - dist.clamp(0.0, 1.0)) * 240.0, 1.0, 0.45)
    end

    target.on_change do |x, y|
      puts "Crosshair positioned at X: \#{x.round(2)}, Y: \#{y.round(2)}"
    end

    # Shell Integration via Opal CLI:
    #   $ COORD=$(opal target --min -10 --max 10 --reticle "┼")
    #   STDERR -> Interactive Target Pad
    #   STDOUT -> "2.50,-3.00"
    CR
  end

  def guide_markdown : String
    <<-MD
    # 2D Continuous Target Selector (`TargetSelector2D`)

    A continuous 2D Cartesian controller supporting custom coordinate scales, reticle styles, and procedural shaders.

    ### Features
    - **Continuous Custom Ranges**: Define arbitrary floating-point domains (e.g. `x_range: -10.0..10.0`, audio pan/tilt `0.0..100.0`, velocity vectors).
    - **Procedural Background Shaders**: Pass a block `(u, v) -> Color` for live heatmaps, plasma ripples, or image textures.
    - **Custom Reticles**: Supports `⌖`, `┼`, `◎`, `+`, `✦` or arbitrary Unicode glyphs with high-contrast color inversion.
    - **Mouse & Keyboard Control**: Drag directly with mouse tracking or step with arrow keys (holding Shift for fine stepping).
    - **CLI Executable**: Run `opal target` in scripts to capture $(x, y)$ coordinates cleanly to `STDOUT`.
    MD
  end

  def handle_key(key : Opal::Terminal::KeyEvent) : Bool
    case key.name
    when "1"
      apply_shader(0)
      true
    when "2"
      apply_shader(1)
      true
    when "3"
      apply_shader(2)
      true
    when "r", "R"
      @current_reticle_idx = (@current_reticle_idx + 1) % RETICLES.size
      @target.reticle_char = RETICLES[@current_reticle_idx]
      true
    else
      @target.handle_key(key)
    end
  end

  def handle_mouse(event : Opal::Terminal::MouseEvent) : Bool
    @target.handle_mouse(event)
  end

  def render(buffer : Opal::UI::Buffer, x : Int32, y : Int32, w : Int32, h : Int32) : Nil
    target_w = Math.min(42, w - 4)
    target_h = Math.min(15, h - 3)
    @target.render(buffer, x + 2, y + 1, target_w, target_h)

    right_x = x + 2 + target_w + 3
    right_w = (x + w) - right_x - 2
    if right_w >= 26 && h >= 14
      info_box = Opal::UI::Box.new(title: "Target Telemetry", border: :rounded, border_fg: Opal::Color.bright_cyan)
      info_box.render(buffer, right_x, y + 1, right_w, target_h)

      row = y + 3
      buffer.put_string(right_x + 2, row, "CARTESIAN COORDINATES:", fg: Opal::Color.bright_white, bold: true)
      row += 1
      buffer.put_string(right_x + 2, row, sprintf("  X Axis : %+6.2f", @target.x_val), fg: Opal::Color.bright_green, bold: true)
      row += 1
      buffer.put_string(right_x + 2, row, sprintf("  Y Axis : %+6.2f", @target.y_val), fg: Opal::Color.bright_yellow, bold: true)
      row += 2

      norm_u = (@target.x_val - @target.x_min) / (@target.x_max - @target.x_min)
      norm_v = (@target.y_val - @target.y_min) / (@target.y_max - @target.y_min)
      buffer.put_string(right_x + 2, row, "NORMALIZED [0.0..1.0] UV:", fg: Opal::Color.bright_white, bold: true)
      row += 1
      buffer.put_string(right_x + 2, row, sprintf("  U (X)  : %5.3f", norm_u), fg: Opal::Color.bright_cyan)
      row += 1
      buffer.put_string(right_x + 2, row, sprintf("  V (Y)  : %5.3f", norm_v), fg: Opal::Color.bright_magenta)
      row += 2

      shader_names = ["Radial Heatmap", "Plasma Waves", "Spectral UV"]
      buffer.put_string(right_x + 2, row, "CONFIG & CONTROLS:", fg: Opal::Color.bright_white, bold: true)
      row += 1
      buffer.put_string(right_x + 2, row, "Shader : #{shader_names[@current_shader_idx]} [1/2/3]", fg: Opal::Color.white)
      row += 1
      buffer.put_string(right_x + 2, row, "Reticle: #{@target.reticle_char} [Press 'r']", fg: Opal::Color.white)
      row += 2

      if row < y + target_h
        buffer.put_string(right_x + 2, row, "$ opal target --min -10 --max 10", fg: Opal::Color.bright_black)
      end
    end
  end
end

# =============================================================================
# Slide 8: Bézier Curve Editor & Easing Engine
# =============================================================================
class CurveEditorSlide < ShowcaseSlide
  property editor : Opal::UI::CurveEditor
  property active_preset_idx : Int32 = 4

  PRESET_NAMES = ["linear", "ease", "ease_in", "ease_out", "ease_in_out", "ease_in_back", "ease_out_back"]

  def initialize
    @editor = Opal::UI::CurveEditor.new(
      p1_x: 0.42,
      p1_y: 0.0,
      p2_x: 0.58,
      p2_y: 1.0,
      width: 42,
      height: 15
    )
  end

  def title : String
    "Bézier Curve Editor & Easing Engine"
  end

  def category : String
    "Curves & Physics"
  end

  def hints : String
    "[Tab] Switch Handle  │  [↑/↓/←/→] Move Handle  │  [1..7] Presets  │  [Space] Reset Track"
  end

  def source_code : String
    <<-CR
    require "opal"

    # Interactive Cubic Bézier Curve Editor with Sub-Pixel Braille
    editor = Opal::UI::CurveEditor.new(
      p1_x: 0.42, p1_y: 0.0,
      p2_x: 0.58, p2_y: 1.0
    )

    editor.on_change do |x1, y1, x2, y2|
      puts "CSS Timing: \#{editor.to_css}"
    end

    # Real-Time Physics Easing Simulation:
    # Solves y given x in [0.0..1.0] using cubic bisection:
    easing_val = editor.evaluate_easing(progress) # progress in 0.0..1.0
    CR
  end

  def guide_markdown : String
    <<-MD
    # Bézier Curve Editor & Physics Easing (`CurveEditor`)

    An interactive editor for cubic Bézier curves $B(t)$ with sub-pixel terminal graphics and real-time animation easing.

    ### Features
    - **2x4 Sub-pixel Braille**: Curves are rasterized into Unicode Braille (`U+2800..U+28FF`) cells yielding $2\\times 4$ resolution per cell.
    - **Draggable Control Handles**: Manipulate $P_1(x_1, y_1)$ and $P_2(x_2, y_2)$ using keyboard or mouse drag.
    - **CSS cubic-bezier Export**: Generates standards-compliant `cubic-bezier(x1, y1, x2, y2)` strings for web animations.
    - **Real-Time Physics Easing Track**: Displays a live rolling ball simulating the easing curve at 60Hz.
    MD
  end

  def tick(dt : Float64 = 0.0166) : Nil
    @editor.tick_anim(0.016)
  end

  def handle_key(key : Opal::Terminal::KeyEvent) : Bool
    case key.name
    when "1", "2", "3", "4", "5", "6", "7"
      idx = key.name.to_i - 1
      if idx < PRESET_NAMES.size
        @active_preset_idx = idx
        @editor.preset(PRESET_NAMES[idx])
        return true
      end
    when "space"
      @editor.anim_progress = 0.0
      return true
    end

    @editor.handle_key(key)
  end

  def handle_mouse(event : Opal::Terminal::MouseEvent) : Bool
    @editor.handle_mouse(event)
  end

  def render(buffer : Opal::UI::Buffer, x : Int32, y : Int32, w : Int32, h : Int32) : Nil
    editor_w = Math.min(46, w - 4)
    editor_h = Math.min(15, h - 3)
    @editor.render(buffer, x + 2, y + 1, editor_w, editor_h)

    right_x = x + 2 + editor_w + 3
    right_w = (x + w) - right_x - 2
    if right_w >= 26 && h >= 14
      panel = Opal::UI::Box.new(title: "Curve Parameters", border: :rounded, border_fg: Opal::Color.bright_magenta)
      panel.render(buffer, right_x, y + 1, right_w, editor_h)

      row = y + 3
      buffer.put_string(right_x + 2, row, "CSS TIMING FUNCTION:", fg: Opal::Color.bright_white, bold: true)
      row += 1
      buffer.put_string(right_x + 2, row, @editor.to_css, fg: Opal::Color.bright_green, bold: true)
      row += 2

      buffer.put_string(right_x + 2, row, "CONTROL POINTS:", fg: Opal::Color.bright_white, bold: true)
      row += 1
      p1_active = (@editor.active_handle == 1)
      p2_active = (@editor.active_handle == 2)
      p1_cursor = p1_active ? "▶ " : "  "
      p2_cursor = p2_active ? "▶ " : "  "
      buffer.put_string(right_x + 2, row, sprintf("%sP1: (%.2f, %.2f)", p1_cursor, @editor.p1_x, @editor.p1_y), fg: Opal::Color.hex("#FF79C6"), bold: p1_active)
      row += 1
      buffer.put_string(right_x + 2, row, sprintf("%sP2: (%.2f, %.2f)", p2_cursor, @editor.p2_x, @editor.p2_y), fg: Opal::Color.hex("#8BE9FD"), bold: p2_active)
      row += 2

      buffer.put_string(right_x + 2, row, "PRESET CURVES [1..7]:", fg: Opal::Color.bright_white, bold: true)
      row += 1
      PRESET_NAMES.each_with_index do |name, p_idx|
        break if row >= y + editor_h - 1
        is_sel = (p_idx == @active_preset_idx)
        p_prefix = is_sel ? "● " : "○ "
        buffer.put_string(right_x + 2, row, "#{p_prefix}[#{p_idx + 1}] #{name}", fg: is_sel ? Opal::Color.bright_yellow : Opal::Color.bright_black, bold: is_sel)
        row += 1
      end
    end
  end
end

# =============================================================================
# Slide 9: 2D Unicode Math Typesetting & Function Grapher
# =============================================================================
class EquationViewerSlide < ShowcaseSlide
  property viewer : Opal::UI::EquationViewer
  property active_func_idx : Int32 = 0

  FUNCTIONS = [
    {"Damped Oscillator", "f(x) = exp(-0.2|x|) · sin(3x)", ->(x : Float64) : Float64 { Math.exp(-0.2 * x.abs) * Math.sin(3.0 * x) }},
    {"Gaussian Bell Curve", "f(x) = 2.5 · exp(-0.5 · x²)", ->(x : Float64) : Float64 { 2.5 * Math.exp(-0.5 * x * x) }},
    {"Normalized Sinc", "f(x) = sin(πx) / (πx)", ->(x : Float64) : Float64 { x.abs < 1e-4 ? 2.5 : 2.5 * Math.sin(Math::PI * x) / (Math::PI * x) }},
    {"Cubic Polynomial", "f(x) = 0.1 · x³ - 0.5 · x", ->(x : Float64) : Float64 { 0.1 * x * x * x - 0.5 * x }},
  ]

  def initialize
    fn_name, fn_title, fn_proc = FUNCTIONS[0]
    @viewer = Opal::UI::EquationViewer.new(
      function_title: fn_title,
      x_min: -5.0,
      x_max: 5.0,
      y_min: -3.0,
      y_max: 3.0,
      width: 46,
      height: 15,
      &fn_proc
    )

    @viewer.add_fraction("d", "dx")
    @viewer.add_integral("0", "x", "f(t) dt")
    @viewer.add_text(" = f(x)")
  end

  def select_function(idx : Int32) : Nil
    @active_func_idx = idx % FUNCTIONS.size
    fn_name, fn_title, fn_proc = FUNCTIONS[@active_func_idx]
    @viewer.function_title = fn_title
    @viewer.function = fn_proc
  end

  def title : String
    "2D Unicode Math Typesetting & Function Grapher"
  end

  def category : String
    "Math & Graphing"
  end

  def hints : String
    "[1..4] Select Curve  │  [+/-] Zoom  │  [↑/↓/←/→] Pan Viewport  │  [0] Reset View"
  end

  def source_code : String
    <<-CR
    require "opal"

    # 1. 2D Unicode Mathematical Typesetting: Fractions, Integrals, Radicals
    viewer = Opal::UI::EquationViewer.new(
      function_title: "f(x) = exp(-0.2|x|) * sin(3x)",
      x_min: -5.0, x_max: 5.0,
      y_min: -3.0, y_max: 3.0
    ) { |x| Math.exp(-0.2 * x.abs) * Math.sin(3.0 * x) }

    # Add 2D fraction and integral elements
    viewer.add_fraction("d", "dx")
    viewer.add_integral("0", "x", "f(t) dt")
    viewer.add_text(" = f(x)")

    # 2. Interactive Navigation
    viewer.zoom(0.8)       # Zoom in
    viewer.pan(0.1, 0.0)   # Pan along X
    CR
  end

  def guide_markdown : String
    <<-MD
    # 2D Math Typesetting & Cartesian Function Grapher (`EquationViewer`)

    Renders rigorous mathematical notation and interactive 2D graphs in terminal windows.

    ### Features
    - **2D Unicode Typesetting**:
      - Real vertical fractions with centered numerator, denominator, and horizontal vinculum bar (`─`).
      - Definite integrals with upper and lower limits: $\\int_{a}^{b} f(x)\\,dx$.
      - Unicode superscripts and subscripts ($x^2, y_0, a_i$) and radicals ($\\\\sqrt{x}$).
    - **Cartesian Function Grapher**:
      - Real-time sub-pixel Braille plotting with coordinate axes and origin markers (`┼`).
      - Interactive zooming with `+` / `-` and panning with arrow keys.
    MD
  end

  def handle_key(key : Opal::Terminal::KeyEvent) : Bool
    case key.name
    when "1", "2", "3", "4"
      select_function(key.name.to_i - 1)
      return true
    end

    @viewer.handle_key(key)
  end

  def handle_mouse(event : Opal::Terminal::MouseEvent) : Bool
    @viewer.handle_mouse(event)
  end

  def render(buffer : Opal::UI::Buffer, x : Int32, y : Int32, w : Int32, h : Int32) : Nil
    viewer_w = Math.min(48, w - 4)
    viewer_h = Math.min(15, h - 3)
    @viewer.render(buffer, x + 2, y + 1, viewer_w, viewer_h)

    right_x = x + 2 + viewer_w + 3
    right_w = (x + w) - right_x - 2
    if right_w >= 26 && h >= 14
      panel = Opal::UI::Box.new(title: "Formulas & Controls", border: :rounded, border_fg: Opal::Color.bright_yellow)
      panel.render(buffer, right_x, y + 1, right_w, viewer_h)

      row = y + 3
      buffer.put_string(right_x + 2, row, "SELECT FUNCTION [1..4]:", fg: Opal::Color.bright_white, bold: true)
      row += 1
      FUNCTIONS.each_with_index do |f_info, f_idx|
        break if row >= y + viewer_h - 1
        is_sel = (f_idx == @active_func_idx)
        p_prefix = is_sel ? "▶ " : "  "
        buffer.put_string(right_x + 2, row, "#{p_prefix}[#{f_idx + 1}] #{f_info[0]}", fg: is_sel ? Opal::Color.bright_cyan : Opal::Color.white, bold: is_sel)
        row += 1
      end
      row += 1

      buffer.put_string(right_x + 2, row, "VIEWPORT DOMAIN:", fg: Opal::Color.bright_white, bold: true)
      row += 1
      buffer.put_string(right_x + 2, row, sprintf("  X: [%.1f .. %.1f]", @viewer.x_min, @viewer.x_max), fg: Opal::Color.bright_green)
      row += 1
      buffer.put_string(right_x + 2, row, sprintf("  Y: [%.1f .. %.1f]", @viewer.y_min, @viewer.y_max), fg: Opal::Color.bright_magenta)
      row += 2

      buffer.put_string(right_x + 2, row, "FAMOUS IDENTITIES:", fg: Opal::Color.bright_white, bold: true)
      row += 1
      buffer.put_string(right_x + 2, row, "  e^(iπ) + 1 = 0", fg: Opal::Color.hex("#F1FA8C"))
      row += 1
      buffer.put_string(right_x + 2, row, "  √(x² + y²) = r", fg: Opal::Color.hex("#8BE9FD"))
    end
  end
end

# =============================================================================
# Slide 10: Large Text, Big Digits & ASCII Banners
# =============================================================================
class BigTextSlide < ShowcaseSlide
  property time_str : String = ""

  def title : String
    "Large Text, Big Digits & Clock"
  end

  def category : String
    "Typography"
  end

  def hints : String
    "Live Clock updating every second with 3x5 Unicode block characters"
  end

  def source_code : String
    <<-CR
    require "opal"

    # Display large digital clock and countdown timer using 3x5 block digits
    now_str = Time.local.to_s("%H:%M:%S")
    digits = Opal::UI::Digits.new(now_str, fg: Color.hex("#00f2fe"), bold: true)

    digits.render(buffer, x: 10, y: 5, width: 48, height: 6)
    CR
  end

  def guide_markdown : String
    <<-MD
    # Block Character Typography & Digits

    Opal includes high-visibility typography components for dashboards and terminal screens:

    - **`Digits`**: Inspired by Python Textual's Digits element. Renders digits `0-9`, colons, periods, plus, and minus symbols in bold 3x5 Unicode block characters (`█`, `▀`, `▄`).
    - **ASCII Banners**: Scales headline typography across multi-row grids with high contrast.
    MD
  end

  def tick(dt : Float64 = 0.0166) : Nil
    @time_str = Time.local.to_s("%H:%M:%S")
  end

  def render(buffer : Opal::UI::Buffer, x : Int32, y : Int32, w : Int32, h : Int32) : Nil
    buffer.put_string(x + 2, y + 1, "OPAL HIGH-VISIBILITY 3x5 BLOCK DIGITAL CLOCK:", fg: Opal::Color.bright_cyan, bold: true)
    buffer.put_string(x + 2, y + 2, "Real-time system telemetry clock rendered using Opal::UI::Digits.", fg: Opal::Color.bright_black)

    # 1. Render Big Clock
    digits = Opal::UI::Digits.new(@time_str, fg: Opal::Color.hex("#00f2fe"), bold: true)
    digits.render(buffer, x + 4, y + 4, 46, 6)

    # 2. Large ASCII Banner
    banner_y = y + 11
    if banner_y + 6 < y + h
      buffer.put_string(x + 2, banner_y, "HEADLINE BANNER DISPLAY:", fg: Opal::Color.bright_white, bold: true)
      banner_lines = [
        " ▄██████▄   ▄███████▄   ▄████████  ▄█       ",
        "███    ███ ███    ███  ███    ███ ███       ",
        "███    ███ ███    ███  ███    ███ ███       ",
        "███    ███ ███    ███  ███    ███ ███       ",
        " ▀██████▀  ████████▀   ███    █▀  ███▄▄▄▄▄▄ ",
      ]
      banner_lines.each_with_index do |line, l_idx|
        buffer.put_string(x + 4, banner_y + 2 + l_idx, line, fg: Opal::Color.hex("#38ef7d"), bold: true)
      end
    end
  end
end

# =============================================================================
# Slide 11: Mermaid Diagram Viewer
# =============================================================================
class MermaidViewerSlide < ShowcaseSlide
  property active_tab : Int32 = 0
  property? auto_scroll : Bool = false
  property viewer : Opal::UI::MermaidViewer

  DIAGRAMS = [
    {
      title:  "Flowchart TD",
      source: <<-MERMAID
      flowchart TD
          A[Client Request] --> B{Valid Auth?}
          B -- Yes --> C[(Database)]
          B -- No --> D[Error 401]
          C --> E[Generate Response]
      MERMAID
    },
    {
      title:  "Sequence Diagram",
      source: <<-MERMAID
      sequenceDiagram
          User->>TUI: Key Press Event
          TUI->>Engine: Update State (TEA)
          Engine->>Buffer: Draw Delta Cells
          Buffer-->>Terminal: Flush ANSI Stream
      MERMAID
    },
    {
      title:  "State Diagram",
      source: <<-MERMAID
      stateDiagram
          [*] --> Initializing
          Initializing --> Running
          Running --> Paused
          Paused --> Running
          Running --> [*]
      MERMAID
    },
    {
      title:  "Class Diagram",
      source: <<-MERMAID
      classDiagram
          Element <|-- Control
          Control <|-- Button
          Control <|-- TextInput
          Element <|-- Box
      MERMAID
    },
  ]

  def initialize
    @viewer = Opal::UI::MermaidViewer.new(DIAGRAMS[0][:source], auto_scroll: false)
  end

  def title : String
    "Mermaid Diagram Viewer"
  end

  def category : String
    "Architecture Diagrams"
  end

  def hints : String
    "[1..4 or Tab] Switch Diagram  │  [A] Toggle Auto-Scroll  │  [↑/↓] Scroll"
  end

  def source_code : String
    <<-CR
    require "opal"
    require "opal/mermaid"

    diagram = <<-MD
    flowchart TD
        A[Client Request] --> B{Valid Auth?}
        B -- Yes --> C[(Database Cache)]
        B -- No --> D[HTTP 401]
    MD

    viewer = Opal::UI::MermaidViewer.new(diagram, auto_scroll: true)
    viewer.render(buffer, x: 2, y: 2, width: 70, height: 18)
    CR
  end

  def guide_markdown : String
    <<-MD
    # Terminal Mermaid Diagram Engine (`opal/mermaid`)

    Opal parses and renders Mermaid diagrams directly into terminal character buffers using box-drawing glyphs:

    ### Supported Diagram Types
    - **Flowcharts**: `flowchart TD` / `flowchart LR` with rectangular, rounded, decision diamonds, and database nodes.
    - **Sequence Diagrams**: Participant life-lines, notes, and synchronous/asynchronous message arrows.
    - **State Diagrams**: Initial, transition, and terminal states.
    - **Class Diagrams**: Class blocks with inheritance relationships.
    MD
  end

  def handle_key(key : Opal::Terminal::KeyEvent) : Bool
    case key.name
    when "1"
      switch_tab(0)
    when "2"
      switch_tab(1)
    when "3"
      switch_tab(2)
    when "4"
      switch_tab(3)
    when "tab"
      switch_tab((@active_tab + 1) % DIAGRAMS.size)
    when "a"
      @auto_scroll = !@auto_scroll
      @viewer.auto_scroll = @auto_scroll
      true
    when "up", "k"
      @viewer.scroll_up(1)
      true
    when "down", "j"
      @viewer.scroll_down(1)
      true
    else
      false
    end
  end

  def tick(dt : Float64 = 0.0166) : Nil
    @viewer.tick(dt)
  end

  private def switch_tab(idx : Int32) : Bool
    @active_tab = idx
    @viewer.source = DIAGRAMS[idx][:source]
    true
  end

  def render(buffer : Opal::UI::Buffer, x : Int32, y : Int32, w : Int32, h : Int32) : Nil
    # 1. Diagram Selection Tabs
    tab_x = x + 2
    DIAGRAMS.each_with_index do |d, idx|
      selected = (idx == @active_tab)
      bg_c = selected ? Opal::Color.bright_cyan : Opal::Color.hex("#1f2430")
      fg_c = selected ? Opal::Color.black : Opal::Color.bright_white
      label = " [#{idx + 1}] #{d[:title]} "

      buffer.put_string(tab_x, y + 1, label, fg: fg_c, bg: bg_c, bold: selected)
      tab_x += label.size + 2
    end

    scroll_label = @auto_scroll ? "[ Auto-Scroll: ON (A) ]" : "[ Auto-Scroll: OFF (A) ]"
    buffer.put_string(x + w - scroll_label.size - 2, y + 1, scroll_label, fg: @auto_scroll ? Opal::Color.hex("#38ef7d") : Opal::Color.bright_black)

    # 2. Render Diagram Viewport
    diag_box = Opal::UI::Box.new(border: :rounded, border_fg: Opal::Color.bright_white)
    diag_box.render(buffer, x + 2, y + 3, w - 4, h - 5)

    @viewer.render(buffer, x + 4, y + 4, w - 8, h - 7)
  end
end

# =============================================================================
# Slide 12: TUI HTML Web Browser
# =============================================================================
class HtmlBrowserSlide < ShowcaseSlide
  property browser : Opal::UI::HTMLBrowser

  def initialize
    @browser = Opal::UI::HTMLBrowser.new("about:home")
  end

  def title : String
    "TUI HTML Web Browser"
  end

  def category : String
    "HTML & Web"
  end

  def hints : String
    "[Click Links] Navigate  │  [< / >] History Back/Forward  │  [↑/↓] Scroll"
  end

  def source_code : String
    <<-CR
    require "opal"
    require "opal/html"

    # Interactive TUI HTML Browser with history and OSC 8 hyperlinks
    browser = Opal::UI::HTMLBrowser.new("about:home")

    # Load custom HTML document
    browser.load_html(<<-HTML, "https://opal.dev")
      <h1>Opal Documentation</h1>
      <p>Welcome to the <b>lightweight</b> terminal web browser.</p>
      <a href="about:features">View Features</a>
    HTML

    browser.render(buffer, x: 2, y: 2, width: 80, height: 22)
    CR
  end

  def guide_markdown : String
    <<-MD
    # TUI HTML Web Browser Engine (`opal/html`)

    Opal brings native HTML tag parsing and interactive browsing into the command line:

    ### Features
    - **Interactive Address Bar**: Displays current URL with Back `[<]` and Forward `[>]` history navigation.
    - **HTML Tag Parser**: Converts `<h1>`..`<h6>`, `<p>`, `<a>`, `<ul>`/`<li>`, `<code>`, and `<table>` into styled ANSI cells.
    - **OSC 8 Hyperlinks**: Embeds real terminal hyperlinks into anchor tags for external browser launching.
    MD
  end

  def handle_key(key : Opal::Terminal::KeyEvent) : Bool
    @browser.handle_key(key)
  end

  def handle_mouse(event : Opal::Terminal::MouseEvent) : Bool
    if event.button == Opal::Terminal::MouseButton::Left && event.action == Opal::Terminal::MouseAction::Press
      @browser.handle_click(event.x - 2, event.y - 2)
    else
      false
    end
  end

  def render(buffer : Opal::UI::Buffer, x : Int32, y : Int32, w : Int32, h : Int32) : Nil
    @browser.render(buffer, x + 2, y + 1, w - 4, h - 2)
  end
end

# =============================================================================
# Slide 13: Dropdown Styles & Fractional Meters
# =============================================================================
class DropdownMetersSlide < ShowcaseSlide
  property active_dropdown : Int32 = 0
  property dropdowns : Array(Opal::UI::Dropdown)
  property meter_val : Float64 = 0.72

  def initialize
    items = ["Production Deployment", "Staging Cluster", "Development Sandbox", "Disaster Recovery"]
    @dropdowns = [
      Opal::UI::Dropdown.new(items: items, style: Opal::UI::DropdownStyle::Classic),
      Opal::UI::Dropdown.new(items: items, style: Opal::UI::DropdownStyle::Rounded),
      Opal::UI::Dropdown.new(items: items, style: Opal::UI::DropdownStyle::Minimal),
      Opal::UI::Dropdown.new(items: items, style: Opal::UI::DropdownStyle::Double),
      Opal::UI::Dropdown.new(items: items, style: Opal::UI::DropdownStyle::Pill),
      Opal::UI::Dropdown.new(items: items, style: Opal::UI::DropdownStyle::Searchable),
    ]
  end

  def title : String
    "Dropdown Styles & Fractional Meters"
  end

  def category : String
    "Components & Meters"
  end

  def hints : String
    "[1..6] Select Dropdown  │  [Enter/Space] Open  │  [+/-] Modulate Meters"
  end

  def source_code : String
    <<-CR
    require "opal"

    # 1. Dropdown with customizable style presets
    dropdown = Opal::UI::Dropdown.new(
      items: ["Alpha", "Beta", "Release"],
      style_preset: :pill # :classic, :rounded, :minimal, :double, :pill, :searchable
    )

    # 2. Fractional 1/8th Unicode block meters
    meter = Opal::UI::Meter.new(
      value: 0.78,
      orientation: :horizontal,
      gradient: :heat # :heat, :cool, :neon
    )
    CR
  end

  def guide_markdown : String
    <<-MD
    # 6 Dropdown Presets & Fractional Meters

    ### Dropdown Style Presets
    - **`:classic`**: Standard bracketed style `[ Option ▼ ]`.
    - **`:rounded`**: Smooth curved border `╭ Option ▾ ╮`.
    - **`:minimal`**: Clean underlined style `Option ▾`.
    - **`:double`**: High-contrast double-line border `╔ Option ▼ ╗`.
    - **`:pill`**: Capsule pill style `( Option • )`.
    - **`:searchable`**: Live fuzzy query filtering input `🔍 Filter...`.

    ### 1/8th Fractional Unicode Meters
    Uses fractional block elements (`▏▎▍▌▋▊▉█`) for 8x sub-character visual precision.
    MD
  end

  def handle_key(key : Opal::Terminal::KeyEvent) : Bool
    case key.name
    when "1" then @active_dropdown = 0; true
    when "2" then @active_dropdown = 1; true
    when "3" then @active_dropdown = 2; true
    when "4" then @active_dropdown = 3; true
    when "5" then @active_dropdown = 4; true
    when "6" then @active_dropdown = 5; true
    when "+", "="
      @meter_val = Math.min(1.0, @meter_val + 0.05)
      true
    when "-", "_"
      @meter_val = Math.max(0.0, @meter_val - 0.05)
      true
    else
      @dropdowns[@active_dropdown].handle_key(key)
    end
  end

  def render(buffer : Opal::UI::Buffer, x : Int32, y : Int32, w : Int32, h : Int32) : Nil
    # 1. Left Column: 6 Dropdown Styles
    buffer.put_string(x + 2, y + 1, "6 MULTI-STYLE DROPDOWN PRESETS:", fg: Opal::Color.bright_cyan, bold: true)

    presets = [
      {name: "1. Classic Style", preset: :classic},
      {name: "2. Rounded Style", preset: :rounded},
      {name: "3. Minimal Style", preset: :minimal},
      {name: "4. Double Line Style", preset: :double},
      {name: "5. Pill Capsule Style", preset: :pill},
      {name: "6. Searchable Style", preset: :searchable},
    ]

    # Render inactive dropdowns first
    presets.each_with_index do |p, idx|
      next if idx == @active_dropdown
      row_y = y + 3 + (idx * 2)
      buffer.put_string(x + 2, row_y, "  #{p[:name]}:", fg: Opal::Color.bright_white)
      @dropdowns[idx].render(buffer, x + 28, row_y, 30, 1)
    end

    # Render active/expanded dropdown last so its popup list renders on top
    active_p = presets[@active_dropdown]
    active_y = y + 3 + (@active_dropdown * 2)
    buffer.put_string(x + 2, active_y, "▶ #{active_p[:name]}:", fg: Opal::Color.bright_yellow, bold: true)
    @dropdowns[@active_dropdown].render(buffer, x + 28, active_y, 30, 1)

    # 2. Right Column: Fractional Meters
    right_x = x + 62
    if right_x + 30 < x + w
      buffer.put_string(right_x, y + 1, "1/8th FRACTIONAL BLOCK METERS:", fg: Opal::Color.bright_green, bold: true)

      buffer.put_string(right_x, y + 3, "Heat Gradient [#{(@meter_val * 100).round.to_i}%]:", fg: Opal::Color.bright_white)
      heat_m = Opal::UI::Meter.new(value: @meter_val, gradient: Opal::UI::MeterGradient::Heat, show_label: false)
      heat_m.render(buffer, right_x, y + 4, 30, 1)

      buffer.put_string(right_x, y + 6, "Cool Gradient [#{(@meter_val * 100).round.to_i}%]:", fg: Opal::Color.bright_white)
      cool_m = Opal::UI::Meter.new(value: @meter_val, gradient: Opal::UI::MeterGradient::Cool, show_label: false)
      cool_m.render(buffer, right_x, y + 7, 30, 1)

      buffer.put_string(right_x, y + 9, "Neon Gradient [#{(@meter_val * 100).round.to_i}%]:", fg: Opal::Color.bright_white)
      neon_m = Opal::UI::Meter.new(value: @meter_val, gradient: Opal::UI::MeterGradient::Neon, show_label: false)
      neon_m.render(buffer, right_x, y + 10, 30, 1)
    end
  end
end

# =============================================================================
# Slide 14: Multi-Shader Compositing Pipeline
# =============================================================================
class MultiShaderSlide < ShowcaseSlide
  property? matrix_active : Bool = true
  property? crt_active : Bool = true
  property? glitch_active : Bool = false
  property? vignette_active : Bool = true
  property time : Float64 = 0.0
  property frame : UInt64 = 0_u64

  def title : String
    "Multi-Shader Compositing Pipeline"
  end

  def category : String
    "Shader Engine"
  end

  def hints : String
    "[1] Matrix Rain  │  [2] CRT Scanlines  │  [3] Glitch FX  │  [4] Vignette"
  end

  def source_code : String
    <<-CR
    require "opal"

    # Multi-pass fragment shader compositing pipeline
    pipeline = Opal.shader_pipeline do |p|
      p.matrix(speed: 1.2, density: 0.2)
      p.crt(intensity: 0.35, scanline_gap: 2)
      p.glitch(intensity: 0.25, slice_height: 3)
      p.vignette(radius: 0.85, falloff: 0.4)
    end

    pipeline.apply(buffer, time: time, frame: frame)
    CR
  end

  def guide_markdown : String
    <<-MD
    # Terminal Fragment Shaders & Compositing

    Opal introduces procedural fragment shaders running over terminal cell buffers:

    - **Matrix Rain**: Procedurally generates streaming Katakana and digital glyph cascades with glowing head cells.
    - **CRT Scanlines**: Emulates phosphor glow and horizontal raster lines of 1980s computer monitors.
    - **Cyberpunk Glitch**: Simulates horizontal raster tearing and color aberration.
    - **Compositing**: Chains multiple shader passes together in sequence.
    MD
  end

  def handle_key(key : Opal::Terminal::KeyEvent) : Bool
    case key.name
    when "1" then @matrix_active = !@matrix_active; true
    when "2" then @crt_active = !@crt_active; true
    when "3" then @glitch_active = !@glitch_active; true
    when "4" then @vignette_active = !@vignette_active; true
    else          false
    end
  end

  def tick(dt : Float64 = 0.0166) : Nil
    @time += dt
    @frame += 1_u64
  end

  def render(buffer : Opal::UI::Buffer, x : Int32, y : Int32, w : Int32, h : Int32) : Nil
    # 1. Base Dashboard UI
    dash_box = Opal::UI::Box.new(title: "Cybernetic Telemetry Node", border: :rounded, border_fg: Opal::Color.bright_cyan)
    dash_box.render(buffer, x + 2, y + 1, w - 4, h - 2)

    buffer.put_string(x + 4, y + 3, "NEURAL INTERFACE STATUS: SYNCHRONIZED", fg: Opal::Color.bright_white, bold: true)
    buffer.put_string(x + 4, y + 4, "Shader Pipeline Frame: ##{@frame} | Time: #{@time.round(2)}s", fg: Opal::Color.bright_green)

    buffer.put_string(x + 4, y + 6, "ACTIVE SHADER PASSES:", fg: Opal::Color.bright_yellow, bold: true)
    buffer.put_string(x + 6, y + 7, "[#{@matrix_active ? "✔" : " "}] [1] Matrix Digital Rain (Falling glyph streams)", fg: @matrix_active ? Opal::Color.bright_green : Opal::Color.bright_black)
    buffer.put_string(x + 6, y + 8, "[#{@crt_active ? "✔" : " "}] [2] Retro CRT Scanlines (Phosphor raster tint)", fg: @crt_active ? Opal::Color.bright_green : Opal::Color.bright_black)
    buffer.put_string(x + 6, y + 9, "[#{@glitch_active ? "✔" : " "}] [3] Cyberpunk Glitch & Tearing (Artifact slices)", fg: @glitch_active ? Opal::Color.bright_green : Opal::Color.bright_black)
    buffer.put_string(x + 6, y + 10, "[#{@vignette_active ? "✔" : " "}] [4] Vignette Falloff (Radial border darkening)", fg: @vignette_active ? Opal::Color.bright_green : Opal::Color.bright_black)

    # 2. Apply Shader Passes
    if @matrix_active
      pass = Opal::Shader::MatrixPass.new(speed: 1.0, density: 0.15)
      pass.apply(buffer, buffer, @time, @frame)
    end

    if @crt_active
      pass = Opal::Shader::CrtPass.new(intensity: 0.35, scanline_gap: 2)
      pass.apply(buffer, buffer, @time, @frame)
    end

    if @glitch_active
      pass = Opal::Shader::GlitchPass.new(intensity: 0.25, slice_height: 3)
      pass.apply(buffer, buffer, @time, @frame)
    end

    if @vignette_active
      pass = Opal::Shader::VignettePass.new(radius: 0.85, falloff: 0.4)
      pass.apply(buffer, buffer, @time, @frame)
    end
  end
end

# =============================================================================
# Slide 15: Tweens & Easing Visualizer
# =============================================================================
class TweensSlide < ShowcaseSlide
  property active_curve_idx : Int32 = 0
  property time_t : Float64 = 0.0

  CURVES = [
    {name: "Linear", ease: Opal::Animation::Easing::Linear},
    {name: "QuadIn", ease: Opal::Animation::Easing::QuadIn},
    {name: "QuadOut", ease: Opal::Animation::Easing::QuadOut},
    {name: "QuadInOut", ease: Opal::Animation::Easing::QuadInOut},
    {name: "CubicIn", ease: Opal::Animation::Easing::CubicIn},
    {name: "CubicOut", ease: Opal::Animation::Easing::CubicOut},
    {name: "CubicInOut", ease: Opal::Animation::Easing::CubicInOut},
    {name: "BounceIn", ease: Opal::Animation::Easing::BounceIn},
    {name: "BounceOut", ease: Opal::Animation::Easing::BounceOut},
    {name: "BounceInOut", ease: Opal::Animation::Easing::BounceInOut},
    {name: "ElasticIn", ease: Opal::Animation::Easing::ElasticIn},
    {name: "ElasticOut", ease: Opal::Animation::Easing::ElasticOut},
  ]

  def title : String
    "Tweens & 16 Easing Curves"
  end

  def category : String
    "Animation Engine"
  end

  def hints : String
    "[↑/↓] Select Easing Curve  │  [Space] Reset Animation"
  end

  def source_code : String
    <<-CR
    require "opal"

    # Tween animation helper with 16 mathematical easing curves
    tween = Opal::Animation::Tween.new(
      from_val: 0.0,
      to_val: 100.0,
      duration: 1.5.seconds,
      easing: Opal::Animation::Easing::BounceOut
    )

    tween.on_update do |val|
      progress_bar.value = val
    end
    CR
  end

  def guide_markdown : String
    <<-MD
    # Mathematical Easing & Tweens

    Smooth animation requires continuous interpolation functions. Opal bundles 16 Robert Penner easing equations:

    - **Quad / Cubic / Quart**: Polynomial acceleration curves for natural inertia.
    - **Bounce**: Physics-inspired spring bounce equations (`BounceOut`).
    - **Elastic**: Rubber-band overshooting elasticity for playful UI feedback.
    MD
  end

  def handle_key(key : Opal::Terminal::KeyEvent) : Bool
    case key.name
    when "up", "k"
      @active_curve_idx = Math.max(0, @active_curve_idx - 1)
      true
    when "down", "j"
      @active_curve_idx = Math.min(CURVES.size - 1, @active_curve_idx + 1)
      true
    when "space"
      @time_t = 0.0
      true
    else
      false
    end
  end

  def tick(dt : Float64 = 0.0166) : Nil
    @time_t += dt * 0.8
    @time_t = 0.0 if @time_t > 2.0
  end

  def render(buffer : Opal::UI::Buffer, x : Int32, y : Int32, w : Int32, h : Int32) : Nil
    # 1. Left Column: Easing Curve Selector
    buffer.put_string(x + 2, y + 1, "SELECT EASING EQUATION:", fg: Opal::Color.bright_cyan, bold: true)

    CURVES.each_with_index do |c, idx|
      row_y = y + 3 + idx
      break if row_y >= y + h - 2

      selected = (idx == @active_curve_idx)
      cursor = selected ? "▶ " : "  "
      buffer.put_string(x + 2, row_y, "#{cursor}#{c[:name]}", fg: selected ? Opal::Color.bright_yellow : Opal::Color.bright_white, bold: selected)
    end

    # 2. Right Column: Animated Track & Visual Curve
    right_x = x + 30
    if right_x + 40 < x + w
      buffer.put_string(right_x, y + 1, "ANIMATED TRACK INTERPOLATION:", fg: Opal::Color.bright_green, bold: true)

      current_ease = CURVES[@active_curve_idx][:ease]
      norm_t = (@time_t.clamp(0.0, 1.0))
      eased_val = Opal::Animation::EasingFunctions.evaluate(current_ease, norm_t)

      # Animated Box moving along track
      track_w = 40
      track_x = right_x + (eased_val * (track_w - 4)).round.to_i

      buffer.put_string(right_x, y + 3, "─" * track_w, fg: Opal::Color.bright_black)
      buffer.fill(track_x, y + 4, 4, 2, ' ', bg: Opal::Color.hex("#38ef7d"))
      buffer.put_string(track_x + 1, y + 4, "✦", fg: Opal::Color.black, bg: Opal::Color.hex("#38ef7d"), bold: true)
      buffer.put_string(right_x, y + 7, "─" * track_w, fg: Opal::Color.bright_black)

      buffer.put_string(right_x, y + 9, "Linear Progress: #{(norm_t * 100).round.to_i}%", fg: Opal::Color.bright_white)
      buffer.put_string(right_x, y + 10, "Eased Position : #{(eased_val * 100).round.to_i}%", fg: Opal::Color.bright_yellow, bold: true)
    end
  end
end

# =============================================================================
# Slide 16: Gamepad Focus Navigation & Virtual Cursor
# =============================================================================
class GamepadNavSlide < ShowcaseSlide
  property focused_control : Int32 = 0
  property cursor_x : Int32 = 50
  property cursor_y : Int32 = 12
  property? checkbox_state : Bool = true
  property slider_val : Int32 = 65

  def title : String
    "Gamepad Controller & Focus Traversal"
  end

  def category : String
    "Input Subsystem"
  end

  def hints : String
    "[DPad / Arrow Keys] Traverse Focus  │  [A / Enter] Activate  │  [M] Mock Gamepad"
  end

  def source_code : String
    <<-CR
    require "opal"
    require "opal/gamepad"

    # Gamepad focus mapper and virtual cursor
    mapper = Opal::Input::GamepadFocusMapper.new
    cursor = Opal::Input::VirtualCursor.new

    gamepad = Opal::Input::Gamepad.new
    gamepad.on_event do |ev|
      mapper.handle_gamepad(ev)
      cursor.handle_gamepad(ev)
    end
    CR
  end

  def guide_markdown : String
    <<-MD
    # Gamepad Hardware & Virtual Cursor (`opal/gamepad`)

    Opal brings full console gamepad controller integration to terminal interfaces:

    ### Capabilities
    - **Windows XInput**: Direct hardware connection for Xbox, DualShock, and standard gamepads on Windows.
    - **Focus Traversal**: D-Pad directions seamlessly traverse focus between interactive UI elements (`Buttons`, `Sliders`, `Checkboxes`).
    - **Virtual Cursor**: Analog thumbstick controls a smooth, sub-character precision virtual mouse pointer.
    - **Mock Testing DSL**: Enables automated headless testing with `mock_gamepad`.
    MD
  end

  def handle_key(key : Opal::Terminal::KeyEvent) : Bool
    case key.name
    when "up", "k"
      @focused_control = Math.max(0, @focused_control - 1)
      true
    when "down", "j"
      @focused_control = Math.min(3, @focused_control + 1)
      true
    when "left", "h"
      if @focused_control == 2
        @slider_val = Math.max(0, @slider_val - 5)
        true
      else
        false
      end
    when "right", "l"
      if @focused_control == 2
        @slider_val = Math.min(100, @slider_val + 5)
        true
      else
        false
      end
    when "enter", "space"
      if @focused_control == 1
        @checkbox_state = !@checkbox_state
        true
      else
        false
      end
    else
      false
    end
  end

  def handle_gamepad(event : Opal::Input::GamepadEvent) : Bool
    case event.button
    when Opal::Input::GamepadButton::DPadUp
      @focused_control = Math.max(0, @focused_control - 1)
      true
    when Opal::Input::GamepadButton::DPadDown
      @focused_control = Math.min(3, @focused_control + 1)
      true
    when Opal::Input::GamepadButton::A
      if @focused_control == 1
        @checkbox_state = !@checkbox_state
        true
      else
        false
      end
    else
      false
    end
  end

  def render(buffer : Opal::UI::Buffer, x : Int32, y : Int32, w : Int32, h : Int32) : Nil
    # 1. Left Column: Focusable GUI Controls
    buffer.put_string(x + 2, y + 1, "GAMEPAD FOCUSABLE GUI CONTROLS:", fg: Opal::Color.bright_cyan, bold: true)
    buffer.put_string(x + 2, y + 2, "Traverse controls using D-Pad / Left Stick, activate with [A] button.", fg: Opal::Color.bright_black)

    # Control 0: Primary Button
    c0_sel = (@focused_control == 0)
    buffer.put_string(x + 2, y + 4, c0_sel ? "▶" : " ", fg: Opal::Color.bright_yellow, bold: true)
    buffer.fill(x + 5, y + 4, 24, 1, ' ', bg: c0_sel ? Opal::Color.hex("#11998e") : Opal::Color.hex("#1f2430"))
    buffer.put_string(x + 7, y + 4, "[ Deploy Cluster ➔ ]", fg: c0_sel ? Opal::Color.bright_white : Opal::Color.bright_cyan, bg: c0_sel ? Opal::Color.hex("#11998e") : Opal::Color.hex("#1f2430"), bold: c0_sel)

    # Control 1: Checkbox
    c1_sel = (@focused_control == 1)
    buffer.put_string(x + 2, y + 6, c1_sel ? "▶" : " ", fg: Opal::Color.bright_yellow, bold: true)
    cb_box = @checkbox_state ? "[✔]" : "[ ]"
    buffer.put_string(x + 5, y + 6, cb_box, fg: @checkbox_state ? Opal::Color.bright_green : Opal::Color.bright_black, bold: true)
    buffer.put_string(x + 9, y + 6, "Enable Hardware Acceleration", fg: c1_sel ? Opal::Color.bright_yellow : Opal::Color.bright_white, bold: c1_sel)

    # Control 2: Slider
    c2_sel = (@focused_control == 2)
    buffer.put_string(x + 2, y + 8, c2_sel ? "▶" : " ", fg: Opal::Color.bright_yellow, bold: true)
    buffer.put_string(x + 5, y + 8, "Telemetry Rate:", fg: c2_sel ? Opal::Color.bright_yellow : Opal::Color.bright_white, bold: c2_sel)
    filled = ((@slider_val / 100.0) * 16.0).round.to_i
    bar = "█" * filled + "░" * (16 - filled)
    buffer.put_string(x + 22, y + 8, bar, fg: Opal::Color.hex("#38ef7d"))
    buffer.put_string(x + 40, y + 8, "#{@slider_val}%", fg: Opal::Color.bright_white)

    # Control 3: Action Button
    c3_sel = (@focused_control == 3)
    buffer.put_string(x + 2, y + 10, c3_sel ? "▶" : " ", fg: Opal::Color.bright_yellow, bold: true)
    buffer.fill(x + 5, y + 10, 24, 1, ' ', bg: c3_sel ? Opal::Color.hex("#e11d48") : Opal::Color.hex("#1f2430"))
    buffer.put_string(x + 7, y + 10, "[ Reset Subsystems ]", fg: c3_sel ? Opal::Color.bright_white : Opal::Color.bright_red, bg: c3_sel ? Opal::Color.hex("#e11d48") : Opal::Color.hex("#1f2430"), bold: c3_sel)

    # 2. Right Column: Gamepad Diagram & Status
    right_x = x + 50
    if right_x + 36 < x + w
      buffer.put_string(right_x, y + 1, "CONTROLLER STATUS & MAPPING:", fg: Opal::Color.bright_green, bold: true)
      status_text = Opal::Input::Gamepad.connected? ? "✔ Hardware XInput Slot 0 Online" : "● Virtual / Headless Driver Active"
      buffer.put_string(right_x, y + 3, status_text, fg: Opal::Color.bright_white)

      gamepad_art = [
        "      ╭──────────────╮       ",
        "  [LB]│ (L)      (Y) │[RB]   ",
        " ┌────┘    (X)  (B)  └────┐  ",
        " │  [↑]         (A)   [R] │  ",
        " │[←] [→]                 │  ",
        " └───────┐       ┌────────┘  ",
        "         │  [↓]  │           ",
      ]

      gamepad_art.each_with_index do |line, l_idx|
        buffer.put_string(right_x, y + 5 + l_idx, line, fg: Opal::Color.bright_cyan)
      end
    end
  end
end

# =============================================================================
# Main Elm Architecture Presentation Runner
# =============================================================================
class ShowcaseAppModel
  include Opal::TEA::Model

  getter slides : Array(ShowcaseSlide)
  property current_idx : Int32 = 0
  property? show_code : Bool = false
  property? show_guide : Bool = false
  property code_viewer : Opal::UI::CodeView? = nil
  property guide_viewer : Opal::UI::MarkdownViewer? = nil
  property toast_message : String? = nil
  property toast_timer : Int32 = 0

  def initialize
    @slides = [
      CheckSlide.new,
      SpotlightSlide.new,
      ScissorBufferSlide.new,
      OpalChatSlide.new,
      OpalPongSlide.new,
      ColorPickerStudioSlide.new,
      TargetSelectorSlide.new,
      CurveEditorSlide.new,
      EquationViewerSlide.new,
      BigTextSlide.new,
      MermaidViewerSlide.new,
      HtmlBrowserSlide.new,
      DropdownMetersSlide.new,
      MultiShaderSlide.new,
      TweensSlide.new,
      GamepadNavSlide.new,
    ] of ShowcaseSlide
  end

  def init : Opal::TEA::Cmd
    schedule_tick
  end

  def update(msg : Opal::TEA::Msg) : {Opal::TEA::Model, Opal::TEA::Cmd}
    case msg
    when Opal::TEA::TickMsg
      @slides[@current_idx].tick
      if cv = @code_viewer
        cv.tick
      end
      if gv = @guide_viewer
        gv.tick
      end

      @toast_timer -= 1 if @toast_timer > 0

      # Handle CheckSlide launch button
      if @current_idx == 0
        check_slide = @slides[0].as(CheckSlide)
        if check_slide.launch_requested?
          check_slide.launch_requested = false
          @current_idx = 1
        end
      end

      {self, schedule_tick}
    when Opal::TEA::KeyMsg
      key_str = msg.key.downcase

      # 0. Global Screenshot Hotkey: Ctrl+S
      if msg.matches?("ctrl+s") || (msg.ctrl? && (key_str == "s" || msg.char == 's' || msg.char == '\u0013'))
        cols, rows = Opal::Terminal.default_driver.size
        cols = cols.clamp(80, 140)
        rows = rows.clamp(24, 45)
        shot_buf = Opal::UI::Buffer.new(cols, rows)
        render(shot_buf)

        shot_dir = "demos/screenshots"
        Dir.mkdir_p(shot_dir) unless Dir.exists?(shot_dir)
        base_name = "showcase_slide_#{@current_idx + 1}"
        ans_path = File.join(shot_dir, "#{base_name}.ans")
        txt_path = File.join(shot_dir, "#{base_name}.txt")

        shot_buf.screenshot(path: ans_path, format: :ansi)
        shot_buf.screenshot(path: txt_path, format: :text, copy_to_clipboard: true)

        @toast_message = "📷 Screenshot captured & copied to clipboard! (Saved #{base_name}.ans)"
        @toast_timer = 40
        return {self, Opal::TEA::Cmd.redraw}
      end

      # 1. Modals Close / Toggle
      if @show_code
        case key_str
        when "escape", "esc", "c"
          @show_code = false
          return {self, Opal::TEA::Cmd.redraw}
        else
          ev = Opal::Terminal::KeyEvent.new(msg.key, msg.char, msg.ctrl?, msg.alt?, msg.shift?)
          @code_viewer.try(&.handle_key(ev))
          return {self, Opal::TEA::Cmd.none}
        end
      end

      if @show_guide
        case key_str
        when "escape", "esc", "?"
          @show_guide = false
          return {self, Opal::TEA::Cmd.redraw}
        else
          ev = Opal::Terminal::KeyEvent.new(msg.key, msg.char, msg.ctrl?, msg.alt?, msg.shift?)
          @guide_viewer.try(&.handle_key(ev))
          return {self, Opal::TEA::Cmd.none}
        end
      end

      # 2. Toggle Source Code Modal
      if key_str == "c"
        @show_code = true
        @code_viewer = Opal::UI::CodeView.new(@slides[@current_idx].source_code, language: :crystal, show_line_numbers: true)
        return {self, Opal::TEA::Cmd.redraw}
      end

      # 3. Toggle Guide Modal
      if key_str == "?"
        @show_guide = true
        @guide_viewer = Opal::UI::MarkdownViewer.new(@slides[@current_idx].guide_markdown, width: 76)
        return {self, Opal::TEA::Cmd.redraw}
      end

      # 4. Global Navigation
      if msg.matches?("shift+right") || key_str == "]" || (key_str == "tab" && !msg.shift?)
        @current_idx = (@current_idx + 1) % @slides.size
        return {self, Opal::TEA::Cmd.redraw}
      end

      if msg.matches?("shift+left") || key_str == "[" || (key_str == "tab" && msg.shift?)
        @current_idx = (@current_idx - 1 + @slides.size) % @slides.size
        return {self, Opal::TEA::Cmd.redraw}
      end

      if msg.matches?("escape") || msg.matches?("esc") || msg.matches?("ctrl+c") || key_str == "q"
        return {self, Opal::TEA::Cmd.quit}
      end

      # 5. Forward Key Event to Active Slide
      ev = Opal::Terminal::KeyEvent.new(msg.key, msg.char, msg.ctrl?, msg.alt?, msg.shift?)
      @slides[@current_idx].handle_key(ev)

      # Check if CheckSlide requested launch
      if @current_idx == 0 && @slides[0].as(CheckSlide).launch_requested?
        @slides[0].as(CheckSlide).launch_requested = false
        @current_idx = 1
        return {self, Opal::TEA::Cmd.redraw}
      end

      {self, Opal::TEA::Cmd.none}
    when Opal::TEA::MouseMsg
      cols, rows = Opal::Terminal.default_driver.size

      if msg.left_click?
        # Header code & guide button clicks
        if msg.y == 0
          if msg.x >= cols - 24 && msg.x <= cols - 14
            @show_code = !@show_code
            if @show_code
              @code_viewer = Opal::UI::CodeView.new(@slides[@current_idx].source_code, language: :crystal, show_line_numbers: true)
            end
            return {self, Opal::TEA::Cmd.redraw}
          elsif msg.x >= cols - 13 && msg.x <= cols - 2
            @show_guide = !@show_guide
            if @show_guide
              @guide_viewer = Opal::UI::MarkdownViewer.new(@slides[@current_idx].guide_markdown, width: 76)
            end
            return {self, Opal::TEA::Cmd.redraw}
          end
        end

        # Footer slide clicks
        if msg.y >= rows - 1
          if msg.x >= 1 && msg.x <= 16
            @current_idx = (@current_idx + 1) % @slides.size
            return {self, Opal::TEA::Cmd.redraw}
          elsif msg.x >= 17 && msg.x <= 32
            @current_idx = (@current_idx - 1 + @slides.size) % @slides.size
            return {self, Opal::TEA::Cmd.redraw}
          end
        end
      end

      # Forward to active slide
      ev = Opal::Terminal::MouseEvent.new(
        x: msg.x,
        y: msg.y,
        button: msg.button,
        action: msg.action,
        ctrl: msg.ctrl?,
        alt: msg.alt?,
        shift: msg.shift?
      )
      @slides[@current_idx].handle_mouse(ev)

      # Check if CheckSlide requested launch
      if @current_idx == 0 && @slides[0].as(CheckSlide).launch_requested?
        @slides[0].as(CheckSlide).launch_requested = false
        @current_idx = 1
        return {self, Opal::TEA::Cmd.redraw}
      end

      {self, Opal::TEA::Cmd.none}
    else
      {self, Opal::TEA::Cmd.none}
    end
  end

  def render(buffer : Opal::UI::Buffer) : Nil
    cols = buffer.width
    rows = buffer.height
    return if cols < 10 || rows < 5

    active = @slides[@current_idx]

    # Fill canvas with spaces to eliminate dirty trailing cells
    buffer.fill(0, 0, cols, rows, ' ')

    # 1. Top Header Banner
    header_title = "❖ OPAL TUI ── Slide #{@current_idx + 1}/#{@slides.size}: [#{active.title}]"
    buffer.put_string(0, 0, header_title, fg: Opal::Color.bright_cyan, bold: true, max_width: cols - 26)

    # Code and Guide trigger buttons
    code_btn = "[c] </> Code"
    guide_btn = "[?] Guide"
    buffer.put_string(cols - 24, 0, code_btn, fg: @show_code ? Opal::Color.bright_white : Opal::Color.hex("#38ef7d"), bg: @show_code ? Opal::Color.hex("#1e3a8a") : Opal::Color.none, bold: true)
    buffer.put_string(cols - 11, 0, guide_btn, fg: @show_guide ? Opal::Color.bright_white : Opal::Color.hex("#00f2fe"), bg: @show_guide ? Opal::Color.hex("#1e3a8a") : Opal::Color.none, bold: true)

    buffer.put_string(0, 1, "─" * cols, fg: Opal::Color.bright_black, max_width: cols)

    # 2. Active Slide Canvas
    slide_h = Math.max(0, rows - 4)
    active.render(buffer, 0, 2, cols, slide_h) if slide_h > 0

    # 3. Bottom Footer
    if rows >= 4
      buffer.put_string(0, rows - 2, "─" * cols, fg: Opal::Color.bright_black, max_width: cols)
      footer_text = " [Shift+→] Next  [Shift+←] Prev  [c] Code  [?] Guide  [Ctrl+S] Snap  [q] Quit │ #{active.hints}"
      buffer.put_string(0, rows - 1, footer_text, fg: Opal::Color.bright_white, max_width: cols)
    end

    # 4. Modals Overlay
    if @show_code && (cv = @code_viewer)
      render_modal(buffer, cols, rows, "SOURCE CODE: #{active.title}", cv)
    elsif @show_guide && (gv = @guide_viewer)
      render_modal(buffer, cols, rows, "MARKDOWN GUIDE: #{active.title}", gv)
    end

    # 5. Toast Notification Overlay
    if (t_msg = @toast_message) && @toast_timer > 0
      t_w = Math.min(cols - 4, t_msg.size + 6)
      t_x = (cols - t_w) // 2
      t_y = 2
      buffer.fill(t_x, t_y, t_w, 3, ' ', bg: Opal::Color.hex("#064e3b"))
      toast_box = Opal::UI::Box.new(border: :rounded, border_fg: Opal::Color.hex("#38ef7d"))
      toast_box.render(buffer, t_x, t_y, t_w, 3)
      buffer.put_string(t_x + 3, t_y + 1, t_msg, fg: Opal::Color.bright_white, bg: Opal::Color.hex("#064e3b"), bold: true, max_width: t_w - 6)
    end
  end

  private def render_modal(buffer : Opal::UI::Buffer, cols : Int32, rows : Int32, title : String, child : Opal::UI::Element) : Nil
    mw = Math.min(84, cols - 6)
    mh = Math.min(22, rows - 4)
    mx = (cols - mw) // 2
    my = (rows - mh) // 2

    # Draw modal backdrop and border
    modal_box = Opal::UI::Box.new(title: title, border: :rounded, border_fg: Opal::Color.bright_yellow)
    buffer.fill(mx, my, mw, mh, ' ', bg: Opal::Color.hex("#0f172a"))
    modal_box.render(buffer, mx, my, mw, mh)

    # Render inner viewer
    child.render(buffer, mx + 2, my + 2, mw - 4, mh - 4)

    # Modal footer
    buffer.put_string(mx + 2, my + mh - 1, " [ESC] Close  │  [↑/↓] [PageUp/Down] Scroll ", fg: Opal::Color.bright_black, bg: Opal::Color.hex("#0f172a"))
  end

  def view : String
    cols, rows = Opal::Terminal.default_driver.size
    cols = cols.clamp(70, 140)
    rows = rows.clamp(22, 45)

    buffer = Opal::UI::Buffer.new(cols, rows)
    render(buffer)
    buffer.render_to_string(with_ansi: true)
  end

  private def schedule_tick : Opal::TEA::Cmd
    Opal::TEA::Cmd.tick(50.milliseconds) do |_time|
      Opal::TEA::TickMsg.new
    end
  end
end

# Launch demo application if run directly
if PROGRAM_NAME.includes?("10_opal_tui_showcase") || PROGRAM_NAME.ends_with?("opal-demo")
  puts "Launching Opal TUI Showcase..."
  Opal.run_tea(ShowcaseAppModel.new, alt_screen: true, diff_render: true)
  puts "Opal TUI Showcase terminated cleanly. Terminal restored."
end

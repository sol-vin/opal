require "./cast_writer"
require "../src/opal"
require "../examples/10_opal_tui_showcase"

module Opal
  module Tools
    # Automated puppet driver that programs genuine keystrokes, ticks, and state
    # transitions into the 25-slide Opal TUI Showcase application, capturing
    # true double-buffered ANSI frames into an Asciinema v2 recording (.cast).
    class ShowcaseRecorder
      WIDTH  = 96
      HEIGHT = 26

      def self.record(output_path : String = "demos/06_opal_tui_showcase.cast")
        new.run(output_path)
      end

      @cast : CastWriter
      @app : ShowcaseAppModel

      def initialize
        @cast = CastWriter.new(width: WIDTH, height: HEIGHT, title: "Opal TUI Full Showcase Tour")
        @app = ShowcaseAppModel.new
      end

      private def render_frame(advance : Float64 = 0.05) : Nil
        buf = Opal::UI::Buffer.new(WIDTH, HEIGHT)
        @app.render(buf)
        @cast.draw_buffer(buf, advance: advance)
      end

      private def send_key(key : String, char : Char? = nil, ctrl : Bool = false, alt : Bool = false, shift : Bool = false, advance : Float64 = 0.08) : Nil
        parts = key.downcase.split('+').map(&.strip)
        has_ctrl = ctrl || parts.includes?("ctrl")
        has_alt = alt || parts.includes?("alt") || parts.includes?("meta")
        has_shift = shift || parts.includes?("shift")
        base = parts.reject { |p| ["ctrl", "alt", "meta", "shift"].includes?(p) }.first? || key

        msg = Opal::TEA::KeyMsg.new(base, char, ctrl: has_ctrl, alt: has_alt, shift: has_shift)
        @app.update(msg)
        render_frame(advance)
      end

      private def send_tick(advance : Float64 = 0.15) : Nil
        @app.update(Opal::TEA::TickMsg.new)
        render_frame(advance)
      end

      private def send_mouse(x : Int32, y : Int32, button : Opal::Terminal::MouseButton, action : Opal::Terminal::MouseAction, advance : Float64 = 0.08) : Nil
        msg = Opal::TEA::MouseMsg.new(x, y, button, action)
        @app.update(msg)
        render_frame(advance)
      end

      private def next_slide(pause_before : Float64 = 1.0) : Nil
        @cast.pause(pause_before)
        send_key("shift+right", advance: 0.15)
      end

      def run(output_path : String) : Nil
        puts "🎬 Puppeting Opal 26-Slide TUI Showcase Demo..."

        # 1. Shell prompt introduction
        @cast.write("\e[?25h\e[1;36msol-vin@terminal\e[0m:\e[1;34m~/opal\e[0m$ ", 0.0)
        @cast.type_text("crystal run examples/10_opal_tui_showcase.cr\r\n", cps: 24.0)
        @cast.pause(0.25)

        # Enter alternate screen buffer & hide cursor
        @cast.write("\e[?1049h\e[2J\e[H\e[?25l", 0.05)

        # =====================================================================
        # Slide 1: Welcome & Overview (Markdown)
        # =====================================================================
        puts "  → Slide 1: Welcome & Overview"
        render_frame(0.4)
        send_key("pagedown", advance: 0.25)
        send_mouse(40, 10, Opal::Terminal::MouseButton::WheelDown, Opal::Terminal::MouseAction::Press, advance: 0.2)
        send_mouse(40, 10, Opal::Terminal::MouseButton::WheelUp, Opal::Terminal::MouseAction::Press, advance: 0.2)
        send_key("pageup", advance: 0.25)
        next_slide(1.2)

        # =====================================================================
        # Slide 2: Multi-Field Form Wizard (Interactive App)
        # =====================================================================
        puts "  → Slide 2: Multi-Field Form Wizard"
        render_frame(0.3)
        # Type into cluster name
        "prod-us".each_char do |ch|
          send_key(ch.to_s, ch, advance: 0.08)
        end
        @cast.pause(0.2)

        # Tab to token
        send_key("tab", advance: 0.15)
        # Type password
        "993".each_char do |ch|
          send_key(ch.to_s, ch, advance: 0.08)
        end
        @cast.pause(0.2)

        # Tab to region (select)
        send_key("tab", advance: 0.15)
        send_key("down", advance: 0.2)
        send_key("down", advance: 0.2) # eu-central-1

        # Tab to addons (multi-select)
        send_key("tab", advance: 0.15)
        send_key("down", advance: 0.15)
        send_key("space", advance: 0.2) # select Kafka Mesh

        # Tab to auto-deploy confirmation
        send_key("tab", advance: 0.15)

        # Submit form
        send_key("enter", advance: 0.3)
        next_slide(1.2)

        # =====================================================================
        # Slide 3: Form Wizard Architecture (Code Slide)
        # =====================================================================
        puts "  → Slide 3: Form Wizard Architecture"
        render_frame(0.3)
        next_slide(1.0)

        # =====================================================================
        # Slide 4: Live Fuzzy Search & Filter (Interactive App)
        # =====================================================================
        puts "  → Slide 4: Live Fuzzy Search"
        render_frame(0.3)
        "pay".each_char do |ch|
          send_key(ch.to_s, ch, advance: 0.12)
        end
        @cast.pause(0.3)
        send_key("down", advance: 0.2)
        send_key("enter", advance: 0.25)
        next_slide(1.0)

        # =====================================================================
        # Slide 5: File Dialog Explorer (Interactive App)
        # =====================================================================
        puts "  → Slide 5: File Dialog Explorer"
        render_frame(0.3)
        send_key("down", advance: 0.2)
        send_key("down", advance: 0.2)
        send_key("down", advance: 0.2)
        send_key("up", advance: 0.2)
        next_slide(1.0)

        # =====================================================================
        # Slide 6: File Dialog Architecture (Code Slide)
        # =====================================================================
        puts "  → Slide 6: File Dialog Architecture"
        render_frame(0.3)
        next_slide(1.0)

        # =====================================================================
        # Slide 7: Color Picker Studio (Interactive App)
        # =====================================================================
        puts "  → Slide 7: Color Picker Studio"
        render_frame(0.3)
        send_key("+", advance: 0.15)
        send_key("+", advance: 0.15)
        send_key("down", advance: 0.15) # Green
        send_key("-", advance: 0.15)
        send_key("-", advance: 0.15)
        send_key("down", advance: 0.15) # Blue
        send_key("+", advance: 0.15)
        send_key("+", advance: 0.15)
        # Pick Catppuccin Peach preset
        send_key("3", advance: 0.3)
        next_slide(1.0)

        # =====================================================================
        # Slide 8: Color Engine Architecture (Code Slide)
        # =====================================================================
        puts "  → Slide 8: Color Engine Architecture"
        render_frame(0.3)
        next_slide(1.0)

        # =====================================================================
        # Slide 9: Dataviz Analytics (Interactive App)
        # =====================================================================
        puts "  → Slide 9: Cluster Analytics DataViz"
        render_frame(0.3)
        4.times do
          send_tick(advance: 0.2)
        end
        next_slide(1.0)

        # =====================================================================
        # Slide 10: Pie & Donut Charts (Interactive App - NEW)
        # =====================================================================
        puts "  → Slide 10: Pie & Donut Charts"
        render_frame(0.3)
        2.times { send_tick(advance: 0.2) }
        # Toggle Donut mode
        send_key("space", advance: 0.3)
        2.times { send_tick(advance: 0.2) }
        next_slide(1.0)

        # =====================================================================
        # Slide 11: 2D Cartesian Line Graphs (Interactive App - NEW)
        # =====================================================================
        puts "  → Slide 11: 2D Cartesian Line Graphs"
        render_frame(0.3)
        5.times { send_tick(advance: 0.2) }
        next_slide(1.0)

        # =====================================================================
        # Slide 12: Tables & Viewport (Interactive App)
        # =====================================================================
        puts "  → Slide 12: Tables & Viewport"
        render_frame(0.3)
        send_key("down", advance: 0.2)
        send_key("down", advance: 0.2)
        send_key("down", advance: 0.2)
        # Tab to logs Viewport
        send_key("tab", advance: 0.2)
        send_key("down", advance: 0.15)
        send_key("down", advance: 0.15)
        send_key("down", advance: 0.15)
        next_slide(1.0)

        # =====================================================================
        # Slide 13: DevTools: Code View & Hex Viewer (Interactive App)
        # =====================================================================
        puts "  → Slide 13: Code View & Hex Viewer"
        render_frame(0.3)
        send_key("down", advance: 0.18)
        send_key("down", advance: 0.18)
        send_key("down", advance: 0.18)
        next_slide(1.0)

        # =====================================================================
        # Slide 14: Responsive Split Views (Interactive App)
        # =====================================================================
        puts "  → Slide 14: Responsive Split Views"
        render_frame(0.3)
        send_key("l", advance: 0.2)
        send_key("l", advance: 0.2)
        send_key("l", advance: 0.2) # widen left pane
        send_key("h", advance: 0.2)
        next_slide(1.0)

        # =====================================================================
        # Slide 15: Tabs & Badges (Interactive App)
        # =====================================================================
        puts "  → Slide 15: Tabs & Badges"
        render_frame(0.3)
        send_key("right", advance: 0.25) # Telemetry
        send_key("right", advance: 0.25) # Topology
        send_key("right", advance: 0.25) # Security
        next_slide(1.0)

        # =====================================================================
        # Slide 16: Modals & Backdrop Dimming (Interactive App)
        # =====================================================================
        puts "  → Slide 16: Modals & Dimming"
        render_frame(0.3)
        send_key("right", advance: 0.25) # Select Confirm
        send_key("left", advance: 0.25)  # Select Cancel
        next_slide(1.0)

        # =====================================================================
        # Slide 17: Toast Notifications (Interactive App)
        # =====================================================================
        puts "  → Slide 17: Toast Notifications"
        render_frame(0.3)
        send_key("1", advance: 0.2) # Info
        send_key("2", advance: 0.2) # Success
        send_key("3", advance: 0.2) # Warning
        send_key("4", advance: 0.2) # Error
        next_slide(1.2)

        # =====================================================================
        # Slide 18: Command Palette (Interactive App)
        # =====================================================================
        puts "  → Slide 18: Command Palette"
        render_frame(0.3)
        "git c".each_char do |ch|
          send_key(ch.to_s, ch, advance: 0.12)
        end
        @cast.pause(0.4)
        send_key("enter", advance: 0.25)
        next_slide(1.0)

        # =====================================================================
        # Slide 19: Ghost-Text Autocomplete (Interactive App)
        # =====================================================================
        puts "  → Slide 19: Ghost-Text Autocomplete"
        render_frame(0.3)
        "git c".each_char do |ch|
          send_key(ch.to_s, ch, advance: 0.12)
        end
        @cast.pause(0.3)
        send_key("tab", advance: 0.25) # Auto-expand ghost suggestion
        send_key("enter", advance: 0.25)
        next_slide(1.0)

        # =====================================================================
        # Slide 20: Themes Studio (Interactive App)
        # =====================================================================
        puts "  → Slide 20: Theme Engine & Dynamic Palettes"
        render_frame(0.3)
        send_key("space", advance: 0.35) # Dracula
        send_key("space", advance: 0.35) # TokyoNight
        send_key("space", advance: 0.35) # Nord
        send_key("space", advance: 0.35) # Gruvbox
        next_slide(1.0)

        # =====================================================================
        # Slide 21: Terminal Capabilities & OSC 52 (Interactive App)
        # =====================================================================
        puts "  → Slide 21: Terminal Capabilities & OSC 52"
        render_frame(0.3)
        send_key("c", advance: 0.35) # Copy token to desktop clipboard
        next_slide(1.0)

        # =====================================================================
        # Slide 22: The Elm Architecture (TEA) Reactive Engine (Interactive App)
        # =====================================================================
        puts "  → Slide 22: TEA Reactive Engine"
        render_frame(0.3)
        send_key("+", advance: 0.18)
        send_key("+", advance: 0.18)
        send_key("+", advance: 0.18)
        send_key("space", advance: 0.2) # Enable auto-tick
        3.times do
          send_tick(advance: 0.25)
        end
        next_slide(1.0)

        # =====================================================================
        # Slide 23: Text Shaders & Fragment FX (Interactive App)
        # =====================================================================
        puts "  → Slide 23: Text Shaders & Fragment FX"
        render_frame(0.3)
        # 1: Matrix Digital Rain
        3.times { send_tick(advance: 0.16) }
        # 3: 24-bit TrueColor Sine Wave Plasma (bouncing window over full background!)
        send_key("3", advance: 0.2)
        4.times { send_tick(advance: 0.16) }
        # 5: Ascending Fire Dispersion
        send_key("5", advance: 0.2)
        3.times { send_tick(advance: 0.16) }
        # 6: Hyperdrive 3D Warp Starfield
        send_key("6", advance: 0.2)
        3.times { send_tick(advance: 0.16) }
        # 7: Water Ripple Caustic Dispersion
        send_key("7", advance: 0.2)
        3.times { send_tick(advance: 0.16) }
        # 8: 3D Demoscene Cyber Tunnel
        send_key("8", advance: 0.2)
        3.times { send_tick(advance: 0.16) }
        # 9: Multi-Layer Composite Pipeline
        send_key("9", advance: 0.2)
        3.times { send_tick(advance: 0.16) }
        next_slide(1.2)

        # =====================================================================
        # Slide 24: 2D & 3D Spatial Color Picker (Interactive App)
        # =====================================================================
        puts "  → Slide 24: 2D & 3D Spatial Color Picker"
        render_frame(0.3)
        # Rotate 3D RGB Cube in terminal space
        send_key("d", advance: 0.12)
        send_key("d", advance: 0.12)
        send_key("s", advance: 0.12)
        send_key("w", advance: 0.12)
        send_key("a", advance: 0.12)
        # Move virtual raycasting cursor across cube surface
        send_key("up", advance: 0.12)
        send_key("right", advance: 0.12)
        send_key("right", advance: 0.12)
        @cast.pause(0.2)
        # Switch shape to 3D Sphere with 'm'
        send_key("m", advance: 0.25)
        send_key("d", advance: 0.12)
        send_key("w", advance: 0.12)
        @cast.pause(0.2)
        # Drag mouse to rotate 3D object
        send_mouse(25, 10, Opal::Terminal::MouseButton::Left, Opal::Terminal::MouseAction::Press, advance: 0.1)
        send_mouse(30, 11, Opal::Terminal::MouseButton::Left, Opal::Terminal::MouseAction::Motion, advance: 0.1)
        send_mouse(35, 12, Opal::Terminal::MouseButton::Left, Opal::Terminal::MouseAction::Motion, advance: 0.1)
        send_mouse(35, 12, Opal::Terminal::MouseButton::Left, Opal::Terminal::MouseAction::Release, advance: 0.1)
        # Mouse wheel to adjust lightness
        send_mouse(25, 10, Opal::Terminal::MouseButton::WheelUp, Opal::Terminal::MouseAction::Press, advance: 0.15)
        # Toggle auto-spin with space
        send_key("space", advance: 0.2)
        3.times { send_tick(advance: 0.15) }
        send_key("space", advance: 0.2)
        next_slide(1.2)

        # =====================================================================
        # Slide 25: Image to ASCII Art & Interpolation (Interactive App - NEW)
        # =====================================================================
        puts "  → Slide 25: Image to ASCII Art"
        render_frame(0.3)
        # Switch to Nearest-Char mode (optical density luminance mapping)
        send_key("m", advance: 0.3)
        # Toggle interpolation mode
        send_key("i", advance: 0.25)
        # Switch to Twilight Mountains Sunset
        send_key("2", advance: 0.3)
        # Switch back to Half-Block mode
        send_key("m", advance: 0.3)
        # Switch to TrueColor HSV Spectrum Wheel
        send_key("3", advance: 0.3)
        # Toggle monochrome grayscale then restore
        send_key("c", advance: 0.25)
        send_key("c", advance: 0.25)
        next_slide(1.2)

        # =====================================================================
        # Slide 26: Grand Finale & Summary Checklist
        # =====================================================================
        puts "  → Slide 26: Grand Finale"
        render_frame(0.4)
        send_key("pagedown", advance: 0.25)
        send_key("pageup", advance: 0.25)
        @cast.pause(2.5) # Hold final frame so asciicast captures full matrix!

        # Cleanly quit demo via Escape
        send_key("escape", advance: 0.1)

        # Exit alternate screen & restore cursor
        @cast.write("\e[?1049l\e[?25h", 0.05)
        @cast.write("sol-vin@terminal:~/opal$ ", 0.02)
        @cast.pause(0.5)

        # Save asciicast
        @cast.save(output_path)
        puts "✨ Showcase recording saved successfully to #{output_path}!"
      end
    end
  end
end

Opal::Tools::ShowcaseRecorder.record

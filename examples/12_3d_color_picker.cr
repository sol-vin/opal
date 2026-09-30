require "../src/opal"

# =============================================================================
# [*] OPAL 2D/3D COLOR SPECTRUM & ROTATABLE CUBE STUDIO
# =============================================================================
# Demonstrates 3D RGB Cube rendering with 3D rotation, aspect ratio correction,
# Z-buffer depth sorting, 3D sphere, 2D polar circle wheel, and virtual raycast cursor.
#
# Controls:
#   [W/A/S/D]    : Turn / Rotate 3D Cube (Pitch & Yaw)
#   [↑/↓/←/→]    : Move Virtual Picker Cursor across the surface
#   [m]          : Switch Shape (3D Cube -> 3D Sphere -> 2D Wheel -> 2D Square)
#   [Space]      : Toggle Auto-Rotation
#   [+/-]        : Adjust Lightness
#   [Enter]      : Confirm & capture selected color
#   [q] / [Ctrl] : Exit
# =============================================================================

class ColorPicker3DAppModel
  include Opal::TEA::Model

  getter picker : Opal::UI::ColorPicker3D
  property? captured : Bool = false

  def initialize
    @picker = Opal::UI::ColorPicker3D.new(auto_rotate: false)
  end

  def init : Opal::TEA::Cmd
    schedule_tick
  end

  def update(msg : Opal::TEA::Msg) : {Opal::TEA::Model, Opal::TEA::Cmd}
    case msg
    when Opal::TEA::TickMsg
      @picker.tick(0.04)
      {self, schedule_tick}
    when Opal::TEA::KeyMsg
      if msg.matches?("q") || msg.matches?("ctrl+c")
        return {self, Opal::TEA::Cmd.quit}
      end

      ev = Opal::Terminal::KeyEvent.new(msg.key, msg.char, msg.ctrl?, msg.alt?, msg.shift?)
      @picker.handle_key(ev)

      if @picker.confirmed?
        @captured = true
      end

      {self, Opal::TEA::Cmd.none}
    else
      {self, Opal::TEA::Cmd.none}
    end
  end

  def view : String
    cols, rows = Opal::Terminal.default_driver.size
    cols = cols.clamp(70, 120)
    rows = rows.clamp(20, 35)

    buffer = Opal::UI::Buffer.new(cols, rows)
    @picker.render(buffer, 2, 1, cols - 4, rows - 2)

    if @captured
      buffer.put_string(
        cols - 35, 1,
        "[OK] Captured #{@picker.selected_color.to_hex}!",
        fg: Opal::Color.green,
        bold: true
      )
    end

    buffer.to_s
  end

  private def schedule_tick : Opal::TEA::Cmd
    Opal::TEA::Cmd.tick(33.milliseconds) do |_time|
      Opal::TEA::TickMsg.new
    end
  end
end

puts "Launching Opal 2D/3D Color Studio..."
Opal.run_tea(ColorPicker3DAppModel.new, alt_screen: true)
puts "Color studio terminated cleanly."

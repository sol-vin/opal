require "../src/opal"

# =============================================================================
# 🔮 OPAL TEXT SHADER ENGINE & COMPOSITING SHOWCASE
# =============================================================================
# Demonstrates procedural fragment shaders running over terminal screen buffers.
#
# Controls:
#   [1] : Matrix Digital Rain
#   [2] : Retro CRT Scanlines & Phosphor Tint
#   [3] : 24-bit TrueColor Sine Wave Plasma
#   [4] : Cyberpunk Glitch & Raster Tearing
#   [5] : Ascending Fire Heatmap
#   [6] : Multi-Layer Composited FX (Matrix + CRT + Vignette)
#   [Space] : Pause / Resume animation
#   [q] / [Ctrl+C] : Exit
# =============================================================================

enum ShaderMode
  Matrix
  Crt
  Plasma
  Glitch
  Fire
  Composite

  def title : String
    case self
    when Matrix    then "Matrix Digital Rain"
    when Crt       then "Retro CRT Scanlines & Phosphor Glow"
    when Plasma    then "24-bit TrueColor Sine Wave Plasma"
    when Glitch    then "Cyberpunk Glitch & Raster Tearing"
    when Fire      then "Ascending Fire Dispersion"
    when Composite then "Multi-Layer Composite (Matrix + CRT + Vignette)"
    else                "Shader"
    end
  end
end

class ShaderDemoModel
  include Opal::TEA::Model

  property mode : ShaderMode = ShaderMode::Matrix
  property time : Float64 = 0.0
  property frame : UInt64 = 0_u64
  property? animating : Bool = true

  def initialize
  end

  def init : Opal::TEA::Cmd
    schedule_tick
  end

  def update(msg : Opal::TEA::Msg) : {Opal::TEA::Model, Opal::TEA::Cmd}
    case msg
    when Opal::TEA::TickMsg
      if @animating
        @time += 0.05
        @frame += 1_u64
      end
      {self, schedule_tick}
    when Opal::TEA::KeyMsg
      case msg.key.downcase
      when "1"
        @mode = ShaderMode::Matrix
        {self, Opal::TEA::Cmd.none}
      when "2"
        @mode = ShaderMode::Crt
        {self, Opal::TEA::Cmd.none}
      when "3"
        @mode = ShaderMode::Plasma
        {self, Opal::TEA::Cmd.none}
      when "4"
        @mode = ShaderMode::Glitch
        {self, Opal::TEA::Cmd.none}
      when "5"
        @mode = ShaderMode::Fire
        {self, Opal::TEA::Cmd.none}
      when "6"
        @mode = ShaderMode::Composite
        {self, Opal::TEA::Cmd.none}
      when "space"
        @animating = !@animating
        {self, Opal::TEA::Cmd.none}
      when "q", "ctrl+c", "escape"
        {self, Opal::TEA::Cmd.quit}
      else
        {self, Opal::TEA::Cmd.none}
      end
    else
      {self, Opal::TEA::Cmd.none}
    end
  end

  def view : String
    cols, rows = Opal::Terminal.default_driver.size
    cols = cols.clamp(70, 120)
    rows = rows.clamp(20, 35)

    buffer = Opal::UI::Buffer.new(cols, rows)

    # 1. Base UI Render Pass
    buffer.put_string(2, 1, "🔮 Opal Text Shader Engine ── Mode: #{@mode.title}", fg: Opal::Color.bright_cyan, bold: true)
    buffer.put_string(2, 2, "─" * (cols - 4), fg: Opal::Color.bright_black)

    # Draw terminal dashboard content
    b = Opal::UI::Box.new(
      child: Opal::UI::Text.new(
        "CYBERNETIC TELEMETRY NODE // ONLINE\n\n" \
        "Neural Gateway : Synchronized (10 Gbps)\n" \
        "Core Flux      : 98.4% Nominal\n" \
        "Buffer Frame   : ##{@frame} | Time: #{@time.round(2)}s\n\n" \
        "Shader controls below:",
        fg: Opal::Color.bright_white
      ),
      border: :rounded,
      border_fg: Opal::Color.cyan,
      title: "Core System"
    )
    b.render(buffer, 4, 4, cols - 8, 10)

    # 2. Shader Post-Processing Pass
    case @mode
    when ShaderMode::Matrix
      pass = Opal::Shader::MatrixPass.new(speed: 1.2, density: 0.25)
      pass.apply(buffer, buffer, @time, @frame)
    when ShaderMode::Crt
      pass = Opal::Shader::CrtPass.new(intensity: 0.45, scanline_gap: 2, phosphor_tint: Opal::Color.green)
      pass.apply(buffer, buffer, @time, @frame)
    when ShaderMode::Plasma
      # Plasma scoped to the lower half
      plasma_region = Opal::Shader::Rect.new(4, 15, cols - 8, rows - 19)
      pass = Opal::Shader::PlasmaPass.new(region: plasma_region, scale: 0.18, speed: 1.6)
      pass.apply(buffer, buffer, @time, @frame)
    when ShaderMode::Glitch
      pass = Opal::Shader::GlitchPass.new(intensity: 0.28, slice_height: 3)
      pass.apply(buffer, buffer, @time, @frame)
    when ShaderMode::Fire
      fire_region = Opal::Shader::Rect.new(4, 15, cols - 8, rows - 19)
      pass = Opal::Shader::FirePass.new(region: fire_region, speed: 1.2)
      pass.apply(buffer, buffer, @time, @frame)
    when ShaderMode::Composite
      # Multi-pass pipeline compositing
      pipeline = Opal.shader_pipeline do |p|
        p.matrix(speed: 1.0, density: 0.15)
        p.crt(intensity: 0.35, scanline_gap: 2)
        p.vignette(radius: 0.85, falloff: 0.4)
      end
      pipeline.apply(buffer, @time, @frame)
    end

    # 3. Overlay Footer (Controls)
    foot_y = rows - 2
    buffer.put_string(2, foot_y - 1, "─" * (cols - 4), fg: Opal::Color.bright_black)
    hints = " [1] Matrix  [2] CRT  [3] Plasma  [4] Glitch  [5] Fire  [6] Composite  [Space] Pause  [q] Quit "
    buffer.put_string(2, foot_y, hints, fg: Opal::Color.bright_white, bold: true)

    buffer.to_s
  end

  private def schedule_tick : Opal::TEA::Cmd
    Opal::TEA::Cmd.tick(33.milliseconds) do |_time|
      Opal::TEA::TickMsg.new
    end
  end
end

puts "Launching Opal Text Shader Engine Showcase..."
Opal.run_tea(ShaderDemoModel.new, alt_screen: true)
puts "Shader showcase terminated cleanly."

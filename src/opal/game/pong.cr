require "../ui/buffer"
require "../style/color"

module Opal
  module Game
    struct Particle
      property x : Float64
      property y : Float64
      property vx : Float64
      property vy : Float64
      property life : Float64
      property max_life : Float64
      property color : Color

      def initialize(@x : Float64, @y : Float64, @vx : Float64, @vy : Float64, @life : Float64, @color : Color)
        @max_life = @life
      end
    end

    # Complete playable Pong physics simulation and renderer
    class Pong
      property court_width : Int32
      property court_height : Int32

      property paddle_height : Int32 = 4
      property player_y : Float64
      property ai_y : Float64

      property ball_x : Float64
      property ball_y : Float64
      property ball_vx : Float64 = 28.0
      property ball_vy : Float64 = 14.0

      property player_score : Int32 = 0
      property ai_score : Int32 = 0

      property particles : Array(Particle) = [] of Particle

      def initialize(@court_width : Int32 = 70, @court_height : Int32 = 20)
        @player_y = (@court_height / 2.0) - (@paddle_height / 2.0)
        @ai_y = (@court_height / 2.0) - (@paddle_height / 2.0)
        @ball_x = @court_width / 2.0
        @ball_y = @court_height / 2.0
      end

      def reset_ball(direction : Float64 = 1.0)
        @ball_x = @court_width / 2.0
        @ball_y = @court_height / 2.0
        @ball_vx = 28.0 * direction
        @ball_vy = (rand * 16.0) - 8.0
      end

      def move_player(delta : Float64)
        @player_y = (@player_y + delta).clamp(1.0, (@court_height - @paddle_height - 1).to_f)
      end

      def update(dt : Float64)
        # Update ball position
        @ball_x += @ball_vx * dt
        @ball_y += @ball_vy * dt

        # Spawn ball trail particle
        if rand < 0.6
          @particles << Particle.new(
            @ball_x, @ball_y,
            (rand - 0.5) * 4.0, (rand - 0.5) * 4.0,
            0.4,
            Color.hex("#38ef7d")
          )
        end

        # Top / bottom wall collision
        if @ball_y <= 1.0
          @ball_y = 1.0
          @ball_vy = -@ball_vy
        elsif @ball_y >= (@court_height - 2).to_f
          @ball_y = (@court_height - 2).to_f
          @ball_vy = -@ball_vy
        end

        # AI tracking (smooth lerp toward ball Y)
        ai_target = @ball_y - (@paddle_height / 2.0)
        ai_speed = 18.0 * dt
        if @ai_y < ai_target
          @ai_y = Math.min(@ai_y + ai_speed, ai_target)
        elsif @ai_y > ai_target
          @ai_y = Math.max(@ai_y - ai_speed, ai_target)
        end
        @ai_y = @ai_y.clamp(1.0, (@court_height - @paddle_height - 1).to_f)

        # Player paddle collision (x = 2)
        if @ball_x <= 3.0 && @ball_x >= 2.0
          if @ball_y >= @player_y && @ball_y <= (@player_y + @paddle_height)
            @ball_x = 3.0
            @ball_vx = @ball_vx.abs * 1.05 # Speed up slightly
            # Angle bounce based on hit position
            hit_offset = (@ball_y - (@player_y + @paddle_height / 2.0)) / (@paddle_height / 2.0)
            @ball_vy = hit_offset * 20.0
            spawn_collision_sparks(3.0, @ball_y, Color.hex("#11998e"))
          end
        end

        # AI paddle collision (x = court_width - 3)
        ai_paddle_x = (@court_width - 3).to_f
        if @ball_x >= ai_paddle_x - 1.0 && @ball_x <= ai_paddle_x
          if @ball_y >= @ai_y && @ball_y <= (@ai_y + @paddle_height)
            @ball_x = ai_paddle_x - 1.0
            @ball_vx = -(@ball_vx.abs * 1.05)
            hit_offset = (@ball_y - (@ai_y + @paddle_height / 2.0)) / (@paddle_height / 2.0)
            @ball_vy = hit_offset * 20.0
            spawn_collision_sparks(ai_paddle_x, @ball_y, Color.hex("#ff007f"))
          end
        end

        # Scoring
        if @ball_x < 0.0
          @ai_score += 1
          reset_ball(1.0)
        elsif @ball_x > @court_width.to_f
          @player_score += 1
          reset_ball(-1.0)
        end

        # Update particles
        @particles.each do |p|
          p.x += p.vx * dt
          p.y += p.vy * dt
          p.life -= dt
        end
        @particles.reject! { |p| p.life <= 0.0 }
      end

      private def spawn_collision_sparks(x : Float64, y : Float64, color : Color)
        8.times do
          angle = rand * Math::PI * 2.0
          speed = rand * 12.0 + 4.0
          @particles << Particle.new(
            x, y,
            Math.cos(angle) * speed, Math.sin(angle) * speed * 0.5,
            0.35,
            color
          )
        end
      end

      # Renders the Pong court, paddles, particles, ball, and score onto a buffer
      def draw(buffer : UI::Buffer, offset_x : Int32 = 0, offset_y : Int32 = 0, alpha : Float64 = 1.0) : Nil
        # Draw borders
        (0...@court_width).each do |x|
          buffer.put_char(offset_x + x, offset_y, '─', fg: Color.ansi(90))
          buffer.put_char(offset_x + x, offset_y + @court_height - 1, '─', fg: Color.ansi(90))
        end

        # Draw centerline
        (1...@court_height - 1).step(2).each do |y|
          buffer.put_char(offset_x + @court_width // 2, offset_y + y, '┊', fg: Color.ansi(240))
        end

        # Draw player paddle (cyan)
        py = @player_y.round.to_i
        (0...@paddle_height).each do |i|
          buffer.put_char(offset_x + 2, offset_y + py + i, '█', fg: Color.hex("#00f2fe"))
        end

        # Draw AI paddle (magenta)
        ay = @ai_y.round.to_i
        ai_x = @court_width - 3
        (0...@paddle_height).each do |i|
          buffer.put_char(offset_x + ai_x, offset_y + ay + i, '█', fg: Color.hex("#ff0844"))
        end

        # Draw particles
        @particles.each do |p|
          px = p.x.round.to_i
          py = p.y.round.to_i
          if px >= 0 && px < @court_width && py >= 1 && py < @court_height - 1
            glyph = p.life > 0.2 ? '•' : '·'
            buffer.put_char(offset_x + px, offset_y + py, glyph, fg: p.color, dim: p.life < 0.15)
          end
        end

        # Draw ball (yellow-green)
        bx = @ball_x.round.to_i
        by = @ball_y.round.to_i
        if bx >= 0 && bx < @court_width && by >= 0 && by < @court_height
          buffer.put_char(offset_x + bx, offset_y + by, '●', fg: Color.hex("#38ef7d"), bold: true)
        end
      end
    end
  end
end

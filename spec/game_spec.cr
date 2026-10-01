require "./spec_helper"
require "../src/opal/game"

describe "Opal::Game Subsystem" do
  it "initializes loop and performs single tick simulation" do
    updated = false
    loop = Opal::Game::Loop.new(target_fps: 60, tick_rate: 60)
    loop.on_update do |dt|
      updated = true
      dt.should be_close(0.016666, 0.001)
    end

    loop.tick_once
    updated.should be_true
  end

  it "simulates Pong physics and advances ball position" do
    pong = Opal::Game::Pong.new(60, 20)
    initial_x = pong.ball_x
    initial_y = pong.ball_y

    pong.update(0.1) # 100ms simulation step
    pong.ball_x.should_not eq(initial_x)

    # Render into buffer without errors
    buf = Opal::UI::Buffer.new(60, 20)
    pong.draw(buf)
    # Ensure ball glyph '●' is drawn somewhere
    found_ball = false
    (0...20).each do |y|
      (0...60).each do |x|
        if buf.get(x, y).char == '●'
          found_ball = true
          break
        end
      end
      break if found_ball
    end
    found_ball.should be_true
  end

  it "supports game_loop DSL inside UI builder" do
    builder = Opal::UI::Builder.new
    loop = builder.game_loop(target_fps: 30) do |gl|
      gl.pause
    end
    loop.paused?.should be_true
    loop.target_fps.should eq(30)
  end
end

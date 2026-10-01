require "./ui"
require "./game/loop"
require "./game/pong"

module Opal
  module Game
    # Helper to construct and run a game loop with DSL
    def self.loop(target_fps : Int32 = 60, tick_rate : Int32 = 60, &block : Loop -> Nil) : Loop
      l = Loop.new(target_fps, tick_rate)
      yield l
      l
    end
  end

  module UI
    module DSL
      # DSL extension for Game Loop
      def game_loop(target_fps : Int32 = 60, tick_rate : Int32 = 60, &block : Game::Loop -> Nil) : Game::Loop
        Opal::Game.loop(target_fps, tick_rate, &block)
      end
    end
  end
end

module Opal
  module Input
    module Gamepad
      enum Button
        A
        B
        X
        Y
        DPadUp
        DPadDown
        DPadLeft
        DPadRight
        LB
        RB
        Start
        Back
        Guide
        LThumb
        RThumb
      end

      enum Stick
        Left
        Right
      end

      enum Trigger
        Left
        Right
      end

      abstract struct Event
      end

      struct ButtonPress < Event
        getter button : Button

        def initialize(@button : Button)
        end
      end

      struct ButtonRelease < Event
        getter button : Button

        def initialize(@button : Button)
        end
      end

      struct StickMove < Event
        getter stick : Stick
        getter x : Float64 # Normalized -1.0 to 1.0
        getter y : Float64 # Normalized -1.0 to 1.0

        def initialize(@stick : Stick, @x : Float64, @y : Float64)
        end
      end

      struct TriggerMove < Event
        getter trigger : Trigger
        getter value : Float64 # Normalized 0.0 to 1.0

        def initialize(@trigger : Trigger, @value : Float64)
        end
      end
    end
  end
end

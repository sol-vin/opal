require "./types"

module Opal
  module Input
    module Gamepad
      {% if flag?(:win32) %}
        @[Link("xinput9_1_0")]
        lib LibXInput
          struct XINPUT_GAMEPAD
            w_buttons : UInt16
            b_left_trigger : UInt8
            b_right_trigger : UInt8
            s_thumb_lx : Int16
            s_thumb_ly : Int16
            s_thumb_rx : Int16
            s_thumb_ry : Int16
          end

          struct XINPUT_STATE
            dw_packet_number : UInt32
            gamepad : XINPUT_GAMEPAD
          end

          fun XInputGetState(dwUserIndex : UInt32, pState : XINPUT_STATE*) : UInt32
        end

        XINPUT_GAMEPAD_DPAD_UP        = 0x0001_u16
        XINPUT_GAMEPAD_DPAD_DOWN      = 0x0002_u16
        XINPUT_GAMEPAD_DPAD_LEFT      = 0x0004_u16
        XINPUT_GAMEPAD_DPAD_RIGHT     = 0x0008_u16
        XINPUT_GAMEPAD_START          = 0x0010_u16
        XINPUT_GAMEPAD_BACK           = 0x0020_u16
        XINPUT_GAMEPAD_LEFT_THUMB     = 0x0040_u16
        XINPUT_GAMEPAD_RIGHT_THUMB    = 0x0080_u16
        XINPUT_GAMEPAD_LEFT_SHOULDER  = 0x0100_u16
        XINPUT_GAMEPAD_RIGHT_SHOULDER = 0x0200_u16
        XINPUT_GAMEPAD_A              = 0x1000_u16
        XINPUT_GAMEPAD_B              = 0x2000_u16
        XINPUT_GAMEPAD_X              = 0x4000_u16
        XINPUT_GAMEPAD_Y              = 0x8000_u16
      {% end %}

      # Driver interface for polling physical or virtual gamepad states
      class Driver
        property user_index : Int32 = 0
        property deadzone : Float64 = 0.15
        property? connected : Bool = false

        @last_buttons : UInt16 = 0_u16
        @event_handlers : Array(Event -> Nil) = [] of Event -> Nil

        def on_event(&block : Event -> Nil) : self
          @event_handlers << block
          self
        end

        def dispatch(event : Event) : Nil
          @event_handlers.each(&.call(event))
        end

        def poll : Nil
          {% if flag?(:win32) %}
            state = uninitialized LibXInput::XINPUT_STATE
            res = LibXInput.XInputGetState(@user_index.to_u32, pointerof(state))
            if res == 0 # ERROR_SUCCESS
              @connected = true
              process_xinput_state(state.gamepad)
            else
              @connected = false
            end
          {% else %}
            # Headless / POSIX fallback: no hardware gamepad active
            @connected = false
          {% end %}
        end

        {% if flag?(:win32) %}
          private def process_xinput_state(gp : LibXInput::XINPUT_GAMEPAD) : Nil
            buttons = gp.w_buttons

            # Check button transitions
            check_button(buttons, XINPUT_GAMEPAD_A, Button::A)
            check_button(buttons, XINPUT_GAMEPAD_B, Button::B)
            check_button(buttons, XINPUT_GAMEPAD_X, Button::X)
            check_button(buttons, XINPUT_GAMEPAD_Y, Button::Y)
            check_button(buttons, XINPUT_GAMEPAD_DPAD_UP, Button::DPadUp)
            check_button(buttons, XINPUT_GAMEPAD_DPAD_DOWN, Button::DPadDown)
            check_button(buttons, XINPUT_GAMEPAD_DPAD_LEFT, Button::DPadLeft)
            check_button(buttons, XINPUT_GAMEPAD_DPAD_RIGHT, Button::DPadRight)
            check_button(buttons, XINPUT_GAMEPAD_LEFT_SHOULDER, Button::LB)
            check_button(buttons, XINPUT_GAMEPAD_RIGHT_SHOULDER, Button::RB)
            check_button(buttons, XINPUT_GAMEPAD_START, Button::Start)
            check_button(buttons, XINPUT_GAMEPAD_BACK, Button::Back)
            check_button(buttons, XINPUT_GAMEPAD_LEFT_THUMB, Button::LThumb)
            check_button(buttons, XINPUT_GAMEPAD_RIGHT_THUMB, Button::RThumb)

            @last_buttons = buttons

            # Left stick
            lx = normalize_axis(gp.s_thumb_lx)
            ly = normalize_axis(gp.s_thumb_ly)
            if lx.abs > @deadzone || ly.abs > @deadzone
              dispatch(StickMove.new(Stick::Left, lx, ly))
            end

            # Right stick
            rx = normalize_axis(gp.s_thumb_rx)
            ry = normalize_axis(gp.s_thumb_ry)
            if rx.abs > @deadzone || ry.abs > @deadzone
              dispatch(StickMove.new(Stick::Right, rx, ry))
            end

            # Triggers
            if gp.b_left_trigger > 30_u8
              dispatch(TriggerMove.new(Trigger::Left, gp.b_left_trigger.to_f / 255.0))
            end
            if gp.b_right_trigger > 30_u8
              dispatch(TriggerMove.new(Trigger::Right, gp.b_right_trigger.to_f / 255.0))
            end
          end

          private def check_button(current : UInt16, mask : UInt16, btn : Button) : Nil
            was_down = (@last_buttons & mask) != 0
            is_down = (current & mask) != 0

            if !was_down && is_down
              dispatch(ButtonPress.new(btn))
            elsif was_down && !is_down
              dispatch(ButtonRelease.new(btn))
            end
          end

          private def normalize_axis(raw : Int16) : Float64
            if raw >= 0
              raw.to_f / 32767.0
            else
              raw.to_f / 32768.0
            end
          end
        {% end %}
      end
    end
  end
end

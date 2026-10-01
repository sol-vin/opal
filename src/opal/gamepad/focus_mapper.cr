require "./types"

module Opal
  module Input
    module Gamepad
      # Translates gamepad events into standard UI focus traversal, activation,
      # and viewport scrolling actions.
      class FocusMapper
        property? enabled : Bool = true

        @on_next_focus : (-> Nil)?
        @on_prev_focus : (-> Nil)?
        @on_activate : (-> Nil)?
        @on_cancel : (-> Nil)?
        @on_prev_slide : (-> Nil)?
        @on_next_slide : (-> Nil)?
        @on_scroll : (Float64 -> Nil)?
        @button_hooks = Hash(Button, Array(Proc(Nil))).new { |h, k| h[k] = [] of Proc(Nil) }

        def on_next_focus(&block : -> Nil) : self
          @on_next_focus = block
          self
        end

        def on_prev_focus(&block : -> Nil) : self
          @on_prev_focus = block
          self
        end

        def on_activate(&block : -> Nil) : self
          @on_activate = block
          self
        end

        def on_cancel(&block : -> Nil) : self
          @on_cancel = block
          self
        end

        def on_prev_slide(&block : -> Nil) : self
          @on_prev_slide = block
          self
        end

        def on_next_slide(&block : -> Nil) : self
          @on_next_slide = block
          self
        end

        def on_scroll(&block : Float64 -> Nil) : self
          @on_scroll = block
          self
        end

        def hook(btn : Button, &block : -> Nil) : self
          @button_hooks[btn] << block
          self
        end

        # Dispatches a gamepad event through the mapper
        def handle(event : Event) : Nil
          return unless @enabled

          case event
          when ButtonPress
            # Custom button hooks
            @button_hooks[event.button]?.try(&.each(&.call))

            case event.button
            when Button::DPadDown, Button::DPadRight
              @on_next_focus.try(&.call)
            when Button::DPadUp, Button::DPadLeft
              @on_prev_focus.try(&.call)
            when Button::A
              @on_activate.try(&.call)
            when Button::B
              @on_cancel.try(&.call)
            when Button::LB
              @on_prev_slide.try(&.call)
            when Button::RB
              @on_next_slide.try(&.call)
            else
              # other buttons
            end
          when TriggerMove
            if event.trigger == Trigger::Left
              @on_scroll.try(&.call(-event.value))
            elsif event.trigger == Trigger::Right
              @on_scroll.try(&.call(event.value))
            end
          else
            # sticks handled by virtual cursor or direct mapping
          end
        end
      end
    end
  end
end

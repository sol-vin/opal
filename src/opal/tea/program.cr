require "../terminal"
require "../ui/diff_renderer"
require "../ui/buffer"
require "./model"
require "./msg"
require "./cmd"

module Opal
  module TEA
    # Event loop orchestrator for The Elm Architecture.
    class Program
      property model : Model
      property driver : Terminal::Driver
      property? alt_screen : Bool
      property? mouse_enabled : Bool
      property? diff_render : Bool
      @diff_renderer : UI::DiffRenderer? = nil
      @render_buffer : UI::Buffer? = nil

      def initialize(
        @model : Model,
        driver : Terminal::Driver? = nil,
        @alt_screen : Bool = true,
        @mouse_enabled : Bool = true,
        @diff_render : Bool = false,
      )
        @driver = driver || Terminal.default_driver
        @diff_renderer = UI::DiffRenderer.new(@driver) if @diff_render
      end

      # Runs the interactive application loop and returns the final Model state upon exit.
      def run : Model
        msg_channel = Channel(Msg).new(128)
        running = true

        @driver.raw_mode do
          begin
            if @alt_screen
              @driver.enter_alternate_screen
              @driver.write(Terminal::Screen::CLEAR_ALL)
              @driver.write(Terminal::Screen::CURSOR_HOME)
            end
            @driver.hide_cursor
            @driver.enable_mouse if @mouse_enabled

            # Dispatch initial commands
            dispatch_cmd(@model.init, msg_channel)

            # Initial render
            render_view

            # Background input reader fiber
            spawn do
              while running
                event = @driver.read_event
                if event
                  msg = case event
                        when Terminal::KeyEvent
                          KeyMsg.from_event(event)
                        when Terminal::MouseEvent
                          MouseMsg.from_event(event)
                        else
                          nil
                        end
                  msg_channel.send(msg) if msg
                else
                  Fiber.yield
                end
              end
            end

            # Main event loop
            while running
              msg = msg_channel.receive
              if msg.is_a?(QuitMsg)
                running = false
                break
              end

              new_model, cmd = @model.update(msg)
              @model = new_model

              if cmd.redraw?
                @diff_renderer.try(&.invalidate!)
              end

              render_view

              if cmd.quit?
                running = false
                break
              end

              dispatch_cmd(cmd, msg_channel)
            end
          ensure
            running = false
            @driver.show_cursor
            @driver.disable_mouse if @mouse_enabled
            @driver.exit_alternate_screen if @alt_screen
            @driver.flush
          end
        end

        @model
      end

      private def dispatch_cmd(cmd : Cmd, channel : Channel(Msg)) : Nil
        if cmd.quit?
          spawn { channel.send(QuitMsg.new) }
          return
        end

        cmd.actions.each do |action|
          spawn do
            if result_msg = action.call
              channel.send(result_msg)
            end
          end
        end
      end

      private def render_view : Nil
        if @diff_render && (dr = @diff_renderer)
          cols, rows = @driver.size
          rb = @render_buffer
          if rb.nil? || rb.width != cols || rb.height != rows
            rb = UI::Buffer.new(cols, rows)
            @render_buffer = rb
          else
            rb.clear
          end
          @model.render(rb)
          dr.render(rb)
        else
          @driver.write(Terminal::Screen::CURSOR_HOME)
          @driver.write(@model.view)
          @driver.flush
        end
      end
    end
  end
end

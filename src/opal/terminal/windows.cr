require "./driver"
require "./raw_mode"

{% if flag?(:windows) %}
  lib LibC
    struct COORD
      x : Int16
      y : Int16
    end

    struct SMALL_RECT
      left : Int16
      top : Int16
      right : Int16
      bottom : Int16
    end

    struct CONSOLE_SCREEN_BUFFER_INFO
      dwSize : COORD
      dwCursorPosition : COORD
      wAttributes : UInt16
      srWindow : SMALL_RECT
      dwMaximumWindowSize : COORD
    end

    fun GetConsoleScreenBufferInfo(hConsoleOutput : HANDLE, lpConsoleScreenBufferInfo : CONSOLE_SCREEN_BUFFER_INFO*) : Int32
    fun GetNumberOfConsoleInputEvents(hConsoleInput : HANDLE, lpcNumberOfEvents : UInt32*) : Int32
    fun WaitForSingleObject(hHandle : HANDLE, dwMilliseconds : UInt32) : UInt32

    KEY_EVENT                = 0x0001_u16
    MOUSE_EVENT              = 0x0002_u16
    WINDOW_BUFFER_SIZE_EVENT = 0x0004_u16
    MENU_EVENT               = 0x0008_u16
    FOCUS_EVENT              = 0x0010_u16

    struct KEY_EVENT_RECORD
      bKeyDown : Int32
      wRepeatCount : UInt16
      wVirtualKeyCode : UInt16
      wVirtualScanCode : UInt16
      uChar : UInt16
      dwControlKeyState : UInt32
    end

    struct INPUT_RECORD
      eventType : UInt16
      padding : UInt16
      keyEvent : KEY_EVENT_RECORD
    end

    fun FlushConsoleInputBuffer(hConsoleInput : HANDLE) : Int32
    fun PeekConsoleInputW(hConsoleInput : HANDLE, lpBuffer : INPUT_RECORD*, nLength : UInt32, lpNumberOfEventsRead : UInt32*) : Int32
    fun ReadConsoleInputW(hConsoleInput : HANDLE, lpBuffer : INPUT_RECORD*, nLength : UInt32, lpNumberOfEventsRead : UInt32*) : Int32
  end
{% end %}

module Opal
  module Terminal
    # Windows native terminal driver using Win32 Console API & VT100 sequences.
    class WindowsDriver < Driver
      ENABLE_MOUSE_INPUT     = 0x0010_u32
      ENABLE_WINDOW_INPUT    = 0x0008_u32
      ENABLE_QUICK_EDIT_MODE = 0x0040_u32
      ENABLE_EXTENDED_FLAGS  = 0x0080_u32

      @original_console_mode : UInt32? = nil

      def poll_event(timeout_ms : Int32 = 0) : KeyEvent | MouseEvent | ResizeEvent | Nil
        unless @buffered_events.empty?
          return @buffered_events.shift
        end

        if resize_ev = check_resize
          return resize_ev
        end

        {% if flag?(:windows) %}
          handle = LibC.GetStdHandle(LibC::STD_INPUT_HANDLE)

          # Drain non-keydown console input events (KEY_UP, FOCUS, MENU, WINDOW_BUFFER_SIZE)
          # so that ReadFile does not block when only non-character events are queued.
          loop do
            if LibC.GetNumberOfConsoleInputEvents(handle, out num_events) == 0 || num_events == 0
              break
            end

            rec = uninitialized LibC::INPUT_RECORD
            if LibC.PeekConsoleInputW(handle, pointerof(rec), 1_u32, out read_count) == 0 || read_count == 0
              break
            end

            if rec.eventType == LibC::KEY_EVENT
              if rec.keyEvent.bKeyDown != 0
                # Real keydown event, stop draining and proceed to read
                break
              else
                # Discard KEY_UP event
                LibC.ReadConsoleInputW(handle, pointerof(rec), 1_u32, out _)
              end
            elsif rec.eventType == LibC::WINDOW_BUFFER_SIZE_EVENT
              LibC.ReadConsoleInputW(handle, pointerof(rec), 1_u32, out _)
              if resize_ev = check_resize
                return resize_ev
              end
            elsif rec.eventType == LibC::FOCUS_EVENT || rec.eventType == LibC::MENU_EVENT
              # Discard focus/menu events
              LibC.ReadConsoleInputW(handle, pointerof(rec), 1_u32, out _)
            elsif rec.eventType == LibC::MOUSE_EVENT
              if @original_console_mode # mouse is enabled
                break
              else
                # Discard mouse events if mouse not enabled
                LibC.ReadConsoleInputW(handle, pointerof(rec), 1_u32, out _)
              end
            else
              break
            end
          end

          if LibC.GetNumberOfConsoleInputEvents(handle, out remaining_events) != 0
            if remaining_events == 0
              if timeout_ms > 0
                wait_res = LibC.WaitForSingleObject(handle, timeout_ms.to_u32)
                return check_resize if wait_res != 0_u32
              else
                return nil
              end
            end
          end
        {% end %}

        read_event
      end

      def flush_input : Nil
        super
        {% if flag?(:windows) %}
          handle = LibC.GetStdHandle(LibC::STD_INPUT_HANDLE)
          LibC.FlushConsoleInputBuffer(handle)
        {% end %}
      end

      def size : {Int32, Int32}
        {% if flag?(:windows) %}
          handle = LibC.GetStdHandle(LibC::STD_OUTPUT_HANDLE)
          if LibC.GetConsoleScreenBufferInfo(handle, out info) != 0
            cols = (info.srWindow.right - info.srWindow.left + 1).to_i
            rows = (info.srWindow.bottom - info.srWindow.top + 1).to_i
            return {cols > 0 ? cols : 80, rows > 0 ? rows : 24}
          end
        {% end %}

        cols = ENV["COLUMNS"]?.try(&.to_i?) || 80
        rows = ENV["LINES"]?.try(&.to_i?) || 24
        {cols, rows}
      end

      def initialize(output : IO = STDOUT, input : IO = STDIN)
        super(output, input)
      end

      def raw_mode(&)
        flush_input
        RawMode.run do
          flush_input
          yield
        end
      end

      def write(str : String) : Nil
        @output.print str
      rescue IO::Error
        # Handle broken pipes gracefully when output is piped to tools
      end

      def flush : Nil
        @output.flush
      rescue IO::Error
        # Handle broken pipes on flush
      end

      def enable_mouse : Nil
        super
        {% if flag?(:windows) %}
          handle = LibC.GetStdHandle(LibC::STD_INPUT_HANDLE)
          if LibC.GetConsoleMode(handle, out mode) != 0
            @original_console_mode ||= mode
            new_mode = (mode | ENABLE_EXTENDED_FLAGS | ENABLE_MOUSE_INPUT | ENABLE_WINDOW_INPUT | LibC::ENABLE_VIRTUAL_TERMINAL_INPUT) & ~ENABLE_QUICK_EDIT_MODE
            LibC.SetConsoleMode(handle, new_mode)
          end
        {% end %}
      end

      def disable_mouse : Nil
        super
        {% if flag?(:windows) %}
          if orig = @original_console_mode
            handle = LibC.GetStdHandle(LibC::STD_INPUT_HANDLE)
            LibC.SetConsoleMode(handle, orig | ENABLE_EXTENDED_FLAGS)
            @original_console_mode = nil
          end
        {% end %}
      end
    end
  end
end

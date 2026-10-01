require "./reader"
require "../ui/buffer"
require "../ui/cell"
require "../style/color"
require "../style/visual_width"

module Opal
  module Asciicast
    # A single visual frame in a recorded asciicast timeline.
    struct PlaybackFrame
      getter index : Int32
      getter timestamp : Float64
      getter buffer : UI::Buffer

      def time : Float64
        @timestamp
      end

      def initialize(@index : Int32, @timestamp : Float64, @buffer : UI::Buffer)
      end
    end

    # Playback and inspection engine for Asciinema v2 recordings.
    # Reconstructs terminal screens into `UI::Buffer` frames, supports
    # frame-by-frame stepping, seeking, speed multipliers, and overlay-respecting compositing.
    class PlaybackEngine
      getter recording : Reader::Recording
      getter frames : Array(PlaybackFrame)
      getter current_index : Int32 = 0
      property speed : Float64 = 1.0
      property? looping : Bool = false
      getter? playing : Bool = false
      getter? paused : Bool = false
      @overlays : Array(Tuple(UI::Element, Int32, Int32, Int32, Int32))

      def initialize(@recording : Reader::Recording)
        @frames = [] of PlaybackFrame
        @overlays = [] of Tuple(UI::Element, Int32, Int32, Int32, Int32)
        reconstruct_frames
      end

      # Factory constructor from file path
      def self.from_file(path : String) : self
        new(Reader.from_file(path))
      end

      # Factory constructor from raw asciicast string
      def self.from_string(content : String) : self
        new(Reader.from_string(content))
      end

      def width : Int32
        @recording.header.width
      end

      def height : Int32
        @recording.header.height
      end

      def duration : Float64
        @recording.duration
      end

      def total_frames : Int32
        @frames.size
      end

      def empty? : Bool
        @frames.empty?
      end

      def has_next? : Bool
        @current_index < @frames.size - 1
      end

      def has_prev? : Bool
        @current_index > 0
      end

      # Returns the current frame or a blank buffer if no frames exist
      def current_frame : PlaybackFrame
        if @frames.empty?
          PlaybackFrame.new(0, 0.0, UI::Buffer.new(Math.max(1, width), Math.max(1, height)))
        else
          @frames[@current_index.clamp(0, @frames.size - 1)]
        end
      end

      # Returns the current visual buffer
      def current_buffer : UI::Buffer
        current_frame.buffer
      end

      # Returns the current timestamp in seconds
      def current_timestamp : Float64
        current_frame.timestamp
      end

      # Advances to the next frame
      def next_frame : PlaybackFrame
        if @current_index < @frames.size - 1
          @current_index += 1
        elsif @looping && !@frames.empty?
          @current_index = 0
        end
        current_frame
      end

      # Steps back to the previous frame
      def prev_frame : PlaybackFrame
        if @current_index > 0
          @current_index -= 1
        end
        current_frame
      end

      # Seeks directly to a frame index
      def goto_frame(index : Int32) : PlaybackFrame
        return current_frame if @frames.empty?
        @current_index = index.clamp(0, @frames.size - 1)
        current_frame
      end

      # Seeks to the frame closest to the specified timestamp in seconds
      def seek(timestamp_seconds : Float64) : PlaybackFrame
        return current_frame if @frames.empty?
        target_t = Math.max(0.0, timestamp_seconds)
        closest_idx = 0
        min_diff = Float64::MAX

        @frames.each_with_index do |frame, idx|
          diff = (frame.timestamp - target_t).abs
          if diff < min_diff
            min_diff = diff
            closest_idx = idx
          end
        end

        @current_index = closest_idx
        current_frame
      end

      # Rewinds playback to frame 0
      def rewind : PlaybackFrame
        goto_frame(0)
      end

      # Attaches a persistent overlay element to be composited over playback
      def add_overlay(element : UI::Element, x : Int32, y : Int32, width : Int32, height : Int32) : self
        @overlays << {element, x, y, width, height}
        self
      end

      # Clears all persistent overlays
      def clear_overlays : self
        @overlays.clear
        self
      end

      # Composites the current playback frame into the target buffer.
      # If `respect_overlays` is true, does not overwrite non-space cells already in target.
      def render_frame(
        target : UI::Buffer,
        x : Int32 = 0,
        y : Int32 = 0,
        respect_overlays : Bool = false,
      ) : Nil
        src = current_buffer
        return if src.width <= 0 || src.height <= 0

        # Blit frame cells with clipping and overflow protection
        (0...src.height).each do |sy|
          ty = y + sy
          next if ty < 0 || ty >= target.height

          (0...src.width).each do |sx|
            tx = x + sx
            next if tx < 0 || tx >= target.width

            src_cell = src.get(sx, sy)
            next if src_cell.continuation?

            if respect_overlays
              # If source cell is empty/transparent, preserve existing target cell
              next if src_cell.char == ' ' && src_cell.bg == Color.none
            end

            target.set(tx, ty, src_cell)
          end
        end

        # Render attached persistent overlays
        @overlays.each do |(elem, ox, oy, ow, oh)|
          elem.render(target, ox, oy, ow, oh)
        end
      end

      # Automated playback loop yielding each frame buffer and frame index
      def play(speed : Float64 = 1.0, loop : Bool = false, &block : UI::Buffer, Int32 -> Nil) : Nil
        @speed = speed
        @looping = loop
        @playing = true
        @paused = false

        loop do
          break unless @playing
          frame = current_frame
          block.call(frame.buffer, frame.index)

          if has_next?
            next_t = @frames[@current_index + 1].timestamp
            cur_t = frame.timestamp
            delay = Math.max(0.005, (next_t - cur_t) / Math.max(0.1, @speed))
            sleep delay.seconds
            next_frame
          elsif @looping && !@frames.empty?
            sleep 0.5.seconds
            rewind
          else
            break
          end
        end

        @playing = false
      end

      def pause : self
        @paused = true
        self
      end

      def resume : self
        @paused = false
        self
      end

      def stop : self
        @playing = false
        @paused = false
        self
      end

      # Internal VT100 / ANSI terminal state machine to reconstruct sequential Buffer frames
      private def reconstruct_frames : Nil
        outputs = @recording.outputs
        w = Math.max(1, width)
        h = Math.max(1, height)

        if outputs.empty?
          @frames << PlaybackFrame.new(0, 0.0, UI::Buffer.new(w, h))
          return
        end

        sim_buffer = UI::Buffer.new(w, h)
        cur_x = 0
        cur_y = 0
        cur_fg = Color.none
        cur_bg = Color.none
        cur_bold = false
        cur_dim = false
        cur_italic = false
        cur_underline = false
        cur_reverse = false

        frame_idx = 0

        outputs.each do |ev|
          data = ev.data
          i = 0
          len = data.bytesize
          frame_modified = false

          while i < data.size
            ch = data[i]

            if ch == '\e' && i + 1 < data.size && data[i + 1] == '['
              # Parse CSI sequence: \e[ ... command
              i += 2
              param_start = i
              while i < data.size && !data[i].ascii_letter? && data[i] != '?'
                i += 1
              end
              cmd = data[i]? || ' '
              params = data[param_start...i]
              i += 1 # advance past command char

              case cmd
              when 'H', 'f' # Cursor Position \e[row;colH
                parts = params.split(';')
                row = parts[0]?.try(&.to_i?) || 1
                col = parts[1]?.try(&.to_i?) || 1
                cur_y = (row - 1).clamp(0, h - 1)
                cur_x = (col - 1).clamp(0, w - 1)
              when 'J' # Clear Screen
                case params
                when "2", ""
                  sim_buffer.fill(0, 0, w, h, ' ')
                  frame_modified = true
                end
              when 'K' # Clear Line
                sim_buffer.fill(cur_x, cur_y, Math.max(0, w - cur_x), 1, ' ')
                frame_modified = true
              when 'm' # SGR Formatting
                if params.empty? || params == "0"
                  cur_fg = Color.none
                  cur_bg = Color.none
                  cur_bold = false
                  cur_dim = false
                  cur_italic = false
                  cur_underline = false
                  cur_reverse = false
                else
                  codes = params.split(';').compact_map(&.to_i?)
                  idx = 0
                  while idx < codes.size
                    code = codes[idx]
                    case code
                    when 0
                      cur_fg = Color.none
                      cur_bg = Color.none
                      cur_bold = false
                      cur_dim = false
                      cur_italic = false
                      cur_underline = false
                      cur_reverse = false
                    when 1  then cur_bold = true
                    when 2  then cur_dim = true
                    when 3  then cur_italic = true
                    when 4  then cur_underline = true
                    when 7  then cur_reverse = true
                    when 22 then cur_bold = false; cur_dim = false
                    when 23 then cur_italic = false
                    when 24 then cur_underline = false
                    when 27 then cur_reverse = false
                    when 30..37, 90..97
                      cur_fg = Color.ansi(code)
                    when 39
                      cur_fg = Color.none
                    when 40..47, 100..107
                      cur_bg = Color.ansi(code - 10)
                    when 49
                      cur_bg = Color.none
                    when 38 # Extended FG
                      if idx + 4 < codes.size && codes[idx + 1] == 2
                        cur_fg = Color.rgb(codes[idx + 2].clamp(0, 255), codes[idx + 3].clamp(0, 255), codes[idx + 4].clamp(0, 255))
                        idx += 4
                      elsif idx + 2 < codes.size && codes[idx + 1] == 5
                        cur_fg = Color.index(codes[idx + 2].clamp(0, 255))
                        idx += 2
                      end
                    when 48 # Extended BG
                      if idx + 4 < codes.size && codes[idx + 1] == 2
                        cur_bg = Color.rgb(codes[idx + 2].clamp(0, 255), codes[idx + 3].clamp(0, 255), codes[idx + 4].clamp(0, 255))
                        idx += 4
                      elsif idx + 2 < codes.size && codes[idx + 1] == 5
                        cur_bg = Color.index(codes[idx + 2].clamp(0, 255))
                        idx += 2
                      end
                    end
                    idx += 1
                  end
                end
              end
            elsif ch == '\r'
              cur_x = 0
              i += 1
            elsif ch == '\n'
              cur_y = Math.min(cur_y + 1, h - 1)
              i += 1
            elsif ch == '\b'
              cur_x = Math.max(0, cur_x - 1)
              i += 1
            elsif ch == '\t'
              cur_x = Math.min(w - 1, ((cur_x // 8) + 1) * 8)
              i += 1
            else
              if cur_x < w && cur_y < h
                cell = UI::Cell.new(
                  char: ch,
                  fg: cur_fg,
                  bg: cur_bg,
                  bold: cur_bold,
                  dim: cur_dim,
                  italic: cur_italic,
                  underline: cur_underline,
                  reverse: cur_reverse
                )
                sim_buffer.set(cur_x, cur_y, cell)
                frame_modified = true
                cw = VisualWidth.char_width(ch)
                cur_x += (cw > 0 ? cw : 1)
              end
              i += 1
            end
          end

          # Each output event snapshot is saved as a distinct frame
          if frame_modified || @frames.empty?
            @frames << PlaybackFrame.new(frame_idx, ev.time, sim_buffer.clone)
            frame_idx += 1
          end
        end

        if @frames.empty?
          @frames << PlaybackFrame.new(0, 0.0, sim_buffer.clone)
        end
      end
    end
  end
end

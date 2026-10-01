require "../opal"
require "json"
require "./asciicast/header"
require "./asciicast/event"
require "./asciicast/writer"
require "./asciicast/reader"
require "./asciicast/driver"
require "./asciicast/uploader"
require "./asciicast/screen_recorder"
require "./asciicast/playback_engine"
require "./asciicast/vcr"

module Opal
  # Asciinema v2 terminal session recording, playback, and parsing.
  # Available via optional require:
  #   require "opal/asciicast"
  #   require "opal/asciicast/asciinema"
  module Asciicast
    # Records a programmatic terminal session directly to an Asciinema v2 (.cast) file.
    def self.record(
      output_path : String,
      width : Int32 = 80,
      height : Int32 = 24,
      title : String = "Opal Session",
      term : String = "xterm-256color",
      &block : Writer -> Nil
    ) : Writer
      writer = Writer.new(width: width, height: height, title: title, term: term)
      block.call(writer)
      writer.save(output_path)
      writer
    end

    # Creates a headless recording driver that can be passed into any Opal TUI component or TEA program.
    def self.create_driver(
      width : Int32 = 80,
      height : Int32 = 24,
      title : String = "Opal Session",
      time_advance : Float64 = 0.05,
    ) : Driver
      Driver.new(width: width, height: height, title: title, time_advance: time_advance)
    end

    # Reads and parses an Asciinema v2 recording from a file path or raw string content.
    def self.read(path_or_content : String) : Reader::Recording
      if File.exists?(path_or_content)
        Reader.from_file(path_or_content)
      else
        Reader.from_string(path_or_content)
      end
    end
  end

  # Top-level alias for VCR
  alias VCR = Asciicast::VCR

  # Reopen TEA::Program to enable direct screen buffer recording
  module TEA
    class Program
      property recorder : Asciicast::ScreenRecorder? = nil

      # Enables asciicast recording of this program's screen buffer
      def record_cast(
        output_path : String,
        title : String = "Opal Session",
        width : Int32? = nil,
        height : Int32? = nil,
      ) : self
        cols, rows = @driver.size
        w = width || cols
        h = height || rows
        rec = Asciicast::ScreenRecorder.new(output_path, width: w, height: h, title: title)
        rec.start
        @recorder = rec
        self
      end

      # Hook into render_view to automatically capture buffer frames
      private def render_view : Nil
        begin
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
            @recorder.try(&.capture_frame(rb))
            dr.render(rb)
          else
            # When recording without diff_render, ensure screen buffer is still captured
            if rec = @recorder
              cols, rows = @driver.size
              rb = @render_buffer ||= UI::Buffer.new(cols, rows)
              rb.clear
              @model.render(rb)
              rec.capture_frame(rb)
            end
            @driver.write(Terminal::Screen::CURSOR_HOME)
            @driver.write(@model.view)
            @driver.flush
          end
        rescue IO::Error
          # Suppress crash if pipe has been closed / broken
        end
      end
    end
  end

  # Overload run_tea with record_cast support
  def self.run_tea(
    model : TEA::Model,
    driver : Terminal::Driver? = nil,
    alt_screen : Bool = true,
    diff_render : Bool = true,
    mouse_enabled : Bool = true,
    record_cast : String? = nil,
    cast_title : String = "Opal Session",
  ) : TEA::Model
    prog = TEA::Program.new(
      model,
      driver: driver,
      alt_screen: alt_screen,
      diff_render: diff_render,
      mouse_enabled: mouse_enabled,
    )
    if cast_path = record_cast
      prog.record_cast(cast_path, title: cast_title)
    end
    res = prog.run
    prog.recorder.try(&.stop)
    res
  end

  # Reopen ScreenStack to enable direct screen buffer recording
  module UI
    class ScreenStack
      def record_cast(
        output_path : String,
        width : Int32 = 80,
        height : Int32 = 24,
        title : String = "Opal Session",
        &block : Asciicast::ScreenRecorder -> Nil
      ) : Nil
        recorder = Asciicast::ScreenRecorder.new(output_path, width: width, height: height, title: title)
        buf = Buffer.new(width, height)
        recorder.start
        begin
          render(buf)
          recorder.capture_frame(buf)
          block.call(recorder)
          render(buf)
          recorder.capture_frame(buf)
        ensure
          recorder.stop
        end
      end
    end

    class Screen
      def record_cast(
        output_path : String,
        width : Int32 = 80,
        height : Int32 = 24,
        title : String? = nil,
        &block : Asciicast::ScreenRecorder -> Nil
      ) : Nil
        recorder = Asciicast::ScreenRecorder.new(output_path, width: width, height: height, title: title || @name)
        buf = Buffer.new(width, height)
        recorder.start
        begin
          render(buf, 0, 0, width, height)
          recorder.capture_frame(buf)
          block.call(recorder)
          render(buf, 0, 0, width, height)
          recorder.capture_frame(buf)
        ensure
          recorder.stop
        end
      end
    end
  end
end

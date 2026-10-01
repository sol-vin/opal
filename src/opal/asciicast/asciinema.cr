require "../asciicast"

module Opal
  # Asciinema alias for the asciicast recording and playback subsystem.
  # Available via optional require:
  #   require "opal/asciicast/asciinema"
  module Asciinema
    alias Header = Asciicast::Header
    alias Event = Asciicast::Event
    alias Writer = Asciicast::Writer
    alias Reader = Asciicast::Reader
    alias Driver = Asciicast::Driver
    alias Uploader = Asciicast::Uploader
    alias ScreenRecorder = Asciicast::ScreenRecorder
    alias PlaybackEngine = Asciicast::PlaybackEngine
    alias PlaybackFrame = Asciicast::PlaybackFrame
    alias VCR = Asciicast::VCR

    # Records an application session directly to an Asciinema v2 (.cast) file.
    def self.record(
      output_path : String,
      width : Int32 = 80,
      height : Int32 = 24,
      title : String = "Opal Session",
      term : String = "xterm-256color",
      &block : Asciicast::VCR -> Nil
    ) : Asciicast::VCR
      Asciicast::VCR.record(output_path, width: width, height: height, title: title, term: term, &block)
    end

    # Loads and plays back an Asciinema v2 (.cast) recording.
    def self.play(
      path_or_content : String,
      speed : Float64 = 1.0,
      loop : Bool = false,
      &block : UI::Buffer, Int32 -> Nil
    ) : Nil
      Asciicast::VCR.load(path_or_content).play(speed: speed, loop: loop, &block)
    end

    # Instantiates an isolated VCR cassette deck
    def self.new_vcr : Asciicast::VCR
      Asciicast::VCR.new
    end
  end
end

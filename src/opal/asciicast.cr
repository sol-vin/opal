require "../opal"
require "json"
require "./asciicast/header"
require "./asciicast/event"
require "./asciicast/writer"
require "./asciicast/reader"
require "./asciicast/driver"
require "./asciicast/uploader"

module Opal
  # Asciinema v2 terminal session recording, playback, and parsing.
  # Available via optional require:
  #   require "opal/asciicast"
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
      time_advance : Float64 = 0.05
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
end

require "json"

module Opal
  module Asciicast
    # Represents the Asciinema v2 file header (Line 1 of a .cast recording).
    # Spec: https://github.com/asciinema/asciinema/blob/develop/doc/asciicast-v2.md
    struct Header
      include JSON::Serializable

      property version : Int32 = 2
      property width : Int32
      property height : Int32
      property timestamp : Int64
      property title : String?
      property env : Hash(String, String)?
      property theme : Hash(String, String)?
      property idle_time_limit : Float64?

      def initialize(
        @width : Int32 = 80,
        @height : Int32 = 24,
        @title : String? = nil,
        @timestamp : Int64 = Time.utc.to_unix,
        term : String = "xterm-256color",
        shell : String = "/bin/bash",
        @theme : Hash(String, String)? = nil,
        @idle_time_limit : Float64? = nil,
      )
        @env = {
          "TERM"  => term,
          "SHELL" => shell,
        }
      end
    end
  end
end

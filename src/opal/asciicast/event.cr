require "json"

module Opal
  module Asciicast
    # Represents an individual event in an Asciinema v2 stream.
    # Each event is formatted as a 3-element JSON array: [time, type, data]
    struct Event
      getter time : Float64
      getter type : String
      getter data : String

      def initialize(@time : Float64, @type : String, @data : String)
      end

      # Convenience constructor for output events
      def self.output(time : Float64, data : String) : Event
        new(time, "o", data)
      end

      # Convenience constructor for input events
      def self.input(time : Float64, data : String) : Event
        new(time, "i", data)
      end

      # Convenience constructor for marker events
      def self.marker(time : Float64, label : String) : Event
        new(time, "m", label)
      end

      def output? : Bool
        @type == "o"
      end

      def input? : Bool
        @type == "i"
      end

      def marker? : Bool
        @type == "m"
      end

      def to_json(json : JSON::Builder) : Nil
        json.array do
          json.number(@time.round(3))
          json.string(@type)
          json.string(@data)
        end
      end

      def to_s(io : IO) : Nil
        io << "[" << @time.round(3) << ", " << @type.to_json << ", " << @data.to_json << "]"
      end

      def self.from_json(json_str : String) : Event
        arr = Array(JSON::Any).from_json(json_str)
        from_json_array(arr)
      end

      def self.from_json_array(arr : Array(JSON::Any)) : Event
        raise ArgumentError.new("Invalid event array: expected 3 elements") if arr.size < 3
        time = arr[0].as_f? || arr[0].as_i?.try(&.to_f64) || 0.0_f64
        type = arr[1].as_s
        data = arr[2].as_s
        Event.new(time, type, data)
      end
    end
  end
end

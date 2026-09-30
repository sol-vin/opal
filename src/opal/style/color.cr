module Opal
  # Color model supporting 16 standard ANSI colors, 256 indexed palette, and 24-bit TrueColor RGB.
  struct Color
    enum Type
      None
      ANSI16
      ANSI256
      RGB
    end

    getter type : Type
    getter code : Int32
    getter r : UInt8
    getter g : UInt8
    getter b : UInt8

    def initialize(@type : Type, @code : Int32 = 0, @r : UInt8 = 0_u8, @g : UInt8 = 0_u8, @b : UInt8 = 0_u8)
    end

    def self.none : Color
      new(Type::None)
    end

    def self.ansi(code : Int32) : Color
      new(Type::ANSI16, code: code)
    end

    def self.index(code : Int32) : Color
      new(Type::ANSI256, code: code.clamp(0, 255))
    end

    def self.rgb(r : Int, g : Int, b : Int) : Color
      new(Type::RGB, r: r.to_u8.clamp(0_u8, 255_u8), g: g.to_u8.clamp(0_u8, 255_u8), b: b.to_u8.clamp(0_u8, 255_u8))
    end

    # Parses hex string like "#ff79c6", "61AFEF", or "#fff"
    def self.hex(raw : String) : Color
      str = raw.lstrip('#')
      if str.size == 3
        r = (str[0..0] * 2).to_u8(16) rescue 0_u8
        g = (str[1..1] * 2).to_u8(16) rescue 0_u8
        b = (str[2..2] * 2).to_u8(16) rescue 0_u8
        rgb(r, g, b)
      elsif str.size == 6
        r = str[0..1].to_u8(16) rescue 0_u8
        g = str[2..3].to_u8(16) rescue 0_u8
        b = str[4..5].to_u8(16) rescue 0_u8
        rgb(r, g, b)
      else
        none
      end
    end

    # Named color helpers
    def self.black
      ansi(30)
    end

    def self.red
      ansi(31)
    end

    def self.green
      ansi(32)
    end

    def self.yellow
      ansi(33)
    end

    def self.blue
      ansi(34)
    end

    def self.magenta
      ansi(35)
    end

    def self.cyan
      ansi(36)
    end

    def self.white
      ansi(37)
    end

    def self.bright_black
      ansi(90)
    end # Gray

    def self.bright_red
      ansi(91)
    end

    def self.bright_green
      ansi(92)
    end

    def self.bright_yellow
      ansi(93)
    end

    def self.bright_blue
      ansi(94)
    end

    def self.bright_magenta
      ansi(95)
    end

    def self.bright_cyan
      ansi(96)
    end

    def self.bright_white
      ansi(97)
    end

    # Resolves a symbol or string (e.g. :red, "#ff0000", "blue") into a Color
    def self.from(val : Color | Symbol | String) : Color
      case val
      when Color
        val
      when Symbol
        from_name(val.to_s)
      when String
        if val.starts_with?('#') || (val.size == 6 && val =~ /^[0-9a-fA-F]+$/)
          hex(val)
        else
          from_name(val)
        end
      else
        none
      end
    end

    private def self.from_name(name : String) : Color
      case name.downcase.gsub('-', '_')
      when "black"                        then black
      when "red"                          then red
      when "green"                        then green
      when "yellow"                       then yellow
      when "blue"                         then blue
      when "magenta", "purple"            then magenta
      when "cyan"                         then cyan
      when "white"                        then white
      when "gray", "grey", "bright_black" then bright_black
      when "bright_red"                   then bright_red
      when "bright_green"                 then bright_green
      when "bright_yellow"                then bright_yellow
      when "bright_blue"                  then bright_blue
      when "bright_magenta"               then bright_magenta
      when "bright_cyan"                  then bright_cyan
      when "bright_white"                 then bright_white
      else                                     none
      end
    end

    # Checks whether colors are suppressed via NO_COLOR standard
    def self.no_color? : Bool
      !ENV["NO_COLOR"]?.nil? && !ENV["NO_COLOR"]?.try(&.empty?)
    end

    # Emits the ANSI escape code for foreground
    def fg_escape : String
      return "" if @type == Type::None || Color.no_color?

      case @type
      when Type::ANSI16
        "\e[#{@code}m"
      when Type::ANSI256
        "\e[38;5;#{@code}m"
      when Type::RGB
        "\e[38;2;#{@r};#{@g};#{@b}m"
      else
        ""
      end
    end

    # Emits the ANSI escape code for background
    def bg_escape : String
      return "" if @type == Type::None || Color.no_color?

      case @type
      when Type::ANSI16
        # Background ANSI 16 is code + 10 (30..37 -> 40..47, 90..97 -> 100..107)
        bg_code = @code + 10
        "\e[#{bg_code}m"
      when Type::ANSI256
        "\e[48;5;#{@code}m"
      when Type::RGB
        "\e[48;2;#{@r};#{@g};#{@b}m"
      else
        ""
      end
    end

    # Converts color to RGB tuple (approximate for ANSI)
    def to_rgb : {UInt8, UInt8, UInt8}
      case @type
      when Type::RGB
        {@r, @g, @b}
      when Type::ANSI16
        case @code
        when 30 then {0_u8, 0_u8, 0_u8}
        when 31 then {205_u8, 49_u8, 49_u8}
        when 32 then {13_u8, 188_u8, 121_u8}
        when 33 then {229_u8, 229_u8, 16_u8}
        when 34 then {36_u8, 114_u8, 200_u8}
        when 35 then {188_u8, 63_u8, 188_u8}
        when 36 then {17_u8, 168_u8, 205_u8}
        when 37 then {229_u8, 229_u8, 229_u8}
        when 90 then {102_u8, 102_u8, 102_u8}
        when 91 then {241_u8, 76_u8, 76_u8}
        when 92 then {35_u8, 209_u8, 139_u8}
        when 93 then {245_u8, 245_u8, 67_u8}
        when 94 then {59_u8, 142_u8, 234_u8}
        when 95 then {214_u8, 112_u8, 214_u8}
        when 96 then {41_u8, 184_u8, 219_u8}
        when 97 then {255_u8, 255_u8, 255_u8}
        else         {128_u8, 128_u8, 128_u8}
        end
      when Type::ANSI256
        # Basic 256 to RGB approximation
        if @code < 16
          Color.ansi(@code < 8 ? @code + 30 : @code + 82).to_rgb
        elsif @code >= 232 # Grayscale ramp
          gray = (8 + (@code - 232) * 10).to_u8
          {gray, gray, gray}
        else # 6x6x6 color cube
          idx = @code - 16
          r = ((idx / 36) * 51).to_u8
          g = (((idx % 36) / 6) * 51).to_u8
          b = ((idx % 6) * 51).to_u8
          {r, g, b}
        end
      else
        {255_u8, 255_u8, 255_u8}
      end
    end

    # Linearly interpolates between two colors by factor t (0.0 to 1.0)
    def self.lerp(c1 : Color, c2 : Color, t : Float64) : Color
      factor = t.clamp(0.0, 1.0)
      r1, g1, b1 = c1.to_rgb
      r2, g2, b2 = c2.to_rgb

      r = (r1.to_f + (r2.to_f - r1.to_f) * factor).round.to_u8
      g = (g1.to_f + (g2.to_f - g1.to_f) * factor).round.to_u8
      b = (b1.to_f + (b2.to_f - b1.to_f) * factor).round.to_u8

      rgb(r, g, b)
    end

    # Formats color as hex string "#RRGGBB"
    def to_hex : String
      r_u, g_u, b_u = to_rgb
      sprintf("#%02X%02X%02X", r_u, g_u, b_u)
    end
  end
end

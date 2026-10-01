require "base64"
require "../ui/element"
require "../ui/buffer"
require "../style/color"
require "../style/glyphs"

module Opal
  module Image
    enum Protocol
      Auto
      Kitty
      ITerm2
      Sixel
      HalfBlock
    end

    class ProtocolDetector
      def self.detect : Protocol
        term = ENV["TERM"]? || ""
        term_prog = ENV["TERM_PROGRAM"]? || ""

        if term.includes?("kitty") || !ENV["KITTY_PID"]?.nil? || !ENV["KITTY_WINDOW_ID"]?.nil?
          Protocol::Kitty
        elsif term_prog.includes?("iTerm") || !ENV["ITERM_SESSION_ID"]?.nil? || term_prog.includes?("WezTerm")
          Protocol::ITerm2
        elsif term.includes?("sixel") || term.includes?("foot")
          Protocol::Sixel
        else
          Protocol::HalfBlock
        end
      end
    end

    class Encoder
      # Encodes raw RGB bytes (width * height * 3) into Kitty graphics protocol escape chunks
      def self.encode_kitty(rgb_bytes : Bytes, width : Int32, height : Int32) : String
        b64 = Base64.strict_encode(rgb_bytes)
        chunk_size = 4096
        chunks = [] of String
        pos = 0

        while pos < b64.size
          chunk = b64[pos, Math.min(chunk_size, b64.size - pos)]
          pos += chunk_size
          is_last = pos >= b64.size
          m_flag = is_last ? "0" : "1"

          if chunks.empty?
            chunks << "\e_Ga=T,f=24,s=#{width},v=#{height},m=#{m_flag};#{chunk}\e\\"
          else
            chunks << "\e_Gm=#{m_flag};#{chunk}\e\\"
          end
        end

        chunks.join
      end

      # Encodes raw file or image bytes into iTerm2 inline image escape sequence
      def self.encode_iterm2(data : Bytes, filename : String = "image.png", width : Int32? = nil, height : Int32? = nil) : String
        b64 = Base64.strict_encode(data)
        opts = ["inline=1"]
        opts << "width=#{width}" if width
        opts << "height=#{height}" if height
        opts << "name=#{Base64.strict_encode(filename)}"

        "\e]1337;File=#{opts.join(";")}:#{b64}\a"
      end

      # Encodes a 2D RGB grid into universal Unicode TrueColor half-block characters (▀)
      def self.encode_half_block(
        colors : Array(Array(Color)),
        width : Int32,
        height : Int32,
      ) : String
        String.build do |io|
          (0...height).step(2).each do |y|
            (0...width).each do |x|
              top_col = colors[y]?[x]? || Color.none
              bot_col = colors[y + 1]?[x]? || Color.none

              io << top_col.fg_escape
              io << bot_col.bg_escape
              io << Glyphs::UpperHalf
            end
            io << "\e[0m\n"
          end
        end
      end
    end

    class Printer
      def self.print_file(path : String, protocol : Protocol = Protocol::Auto, io : IO = STDOUT) : Nil
        return unless File.exists?(path)
        data = File.read(path).to_slice

        proto = protocol == Protocol::Auto ? ProtocolDetector.detect : protocol
        case proto
        when Protocol::Kitty
          io.print Encoder.encode_kitty(data, 100, 100)
        when Protocol::ITerm2
          io.print Encoder.encode_iterm2(data, File.basename(path))
        else
          # Fallback message
          io.puts "[Image: #{File.basename(path)} (#{data.size} bytes)]"
        end
      end
    end
  end

  module UI
    class ImageView < Element
      property image_path : String
      property protocol : Image::Protocol

      def initialize(@image_path : String, @protocol : Image::Protocol = Image::Protocol::Auto)
        super()
      end

      def preferred_size(available_w : Int32, available_h : Int32) : {Int32, Int32}
        {Math.min(available_w, 40), Math.min(available_h, 20)}
      end

      def render(buffer : Buffer, x : Int32, y : Int32, width : Int32, height : Int32) : Nil
        # Draw decorative image frame with thumbnail badge
        buffer.fill(x, y, width, height, Cell.new(char: ' ', bg: Color.hex("#111827")))
        title = "[ IMG: #{File.basename(@image_path)} ]"
        buffer.put_string(x + (width // 2) - (title.size // 2), y + 1, title, fg: Color.hex("#38ef7d"), bold: true)
        proto_name = @protocol == Image::Protocol::Auto ? Image::ProtocolDetector.detect.to_s : @protocol.to_s
        buffer.put_string(x + 2, y + height - 2, "Protocol: #{proto_name}", fg: Color.hex("#94a3b8"), dim: true)
      end
    end

    module DSL
      def image_view(path : String, protocol : Image::Protocol = Image::Protocol::Auto) : ImageView
        iv = ImageView.new(path, protocol)
        add_element(iv)
        iv
      end
    end
  end
end

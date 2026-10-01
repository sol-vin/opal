require "json"
require "./color"

module Opal
  # Common color palette file and serialization formats
  enum PaletteFormat
    GPL  # GIMP Palette (.gpl)
    PAL  # JASC-PAL (.pal)
    HEX  # Plain Hex Lines (.hex)
    JSON # JSON Object or Array (.json)
    CSS  # CSS Custom Properties (:root { --name: #hex; })

    def to_s(io : IO) : Nil
      case self
      in GPL  then io << "gpl"
      in PAL  then io << "pal"
      in HEX  then io << "hex"
      in JSON then io << "json"
      in CSS  then io << "css"
      end
    end

    def self.parse?(str : String | Symbol) : PaletteFormat?
      case str.to_s.downcase.strip.sub(/^\./, "")
      when "gpl", "gimp"
        GPL
      when "pal", "jasc", "jasc-pal"
        PAL
      when "hex", "txt"
        HEX
      when "json"
        JSON
      when "css"
        CSS
      else
        nil
      end
    end

    def extension : String
      case self
      in GPL  then ".gpl"
      in PAL  then ".pal"
      in HEX  then ".hex"
      in JSON then ".json"
      in CSS  then ".css"
      end
    end
  end

  # Bidirectional encoders and decoders for palette formats
  module PaletteFormats
    # --- GPL (GIMP Palette) ---
    def self.to_gpl(entries : Array(Tuple(String, Color)), palette_name : String = "Opal Palette", columns : Int32 = 8) : String
      String.build do |io|
        io.puts "GIMP Palette"
        io.puts "Name: #{palette_name}"
        io.puts "Columns: #{columns}"
        io.puts "#"
        entries.each do |(name, col)|
          r, g, b = col.to_rgb
          clean_name = name.presence || col.to_hex
          io.printf("%3d %3d %3d\t%s\n", r, g, b, clean_name)
        end
      end
    end

    def self.from_gpl(content : String) : Array(Tuple(String, Color))
      entries = [] of Tuple(String, Color)
      content.each_line do |line|
        line = line.strip
        next if line.empty? || line.starts_with?('#') || line.starts_with?("GIMP Palette") || line.starts_with?("Name:") || line.starts_with?("Columns:")
        parts = line.split(/\s+/, 4)
        next if parts.size < 3
        r = parts[0].to_i?
        g = parts[1].to_i?
        b = parts[2].to_i?
        next unless r && g && b
        col = Color.rgb(r, g, b)
        name = (parts.size >= 4 && !parts[3].strip.empty?) ? parts[3].strip : col.to_hex
        entries << {name, col}
      end
      entries
    end

    # --- PAL (JASC-PAL) ---
    def self.to_pal(colors : Array(Color)) : String
      String.build do |io|
        io.puts "JASC-PAL"
        io.puts "0100"
        io.puts colors.size
        colors.each do |col|
          r, g, b = col.to_rgb
          io.puts "#{r} #{g} #{b}"
        end
      end
    end

    def self.from_pal(content : String) : Array(Color)
      colors = [] of Color
      lines = content.lines.map(&.strip).reject(&.empty?)
      return colors if lines.size < 3
      return colors unless lines[0].upcase == "JASC-PAL"
      count = lines[2].to_i? || (lines.size - 3)
      lines[3..].each_with_index do |line, idx|
        break if idx >= count
        parts = line.split(/\s+/)
        next if parts.size < 3
        r = parts[0].to_i?
        g = parts[1].to_i?
        b = parts[2].to_i?
        if r && g && b
          colors << Color.rgb(r, g, b)
        end
      end
      colors
    end

    # --- HEX (Plain hex lines) ---
    def self.to_hex(colors : Array(Color), with_hash : Bool = true) : String
      String.build do |io|
        colors.each do |col|
          hex = col.to_hex
          hex = hex.lchop('#') unless with_hash
          io.puts hex
        end
      end
    end

    def self.from_hex(content : String) : Array(Color)
      colors = [] of Color
      content.each_line do |line|
        line = line.strip
        next if line.empty? || line.starts_with?("//") || line.starts_with?("# ")
        if m = line.match(/(?:#?)([0-9a-fA-F]{6}|[0-9a-fA-F]{3})/)
          hex_str = m[1]
          colors << Color.hex(hex_str)
        end
      end
      colors
    end

    # --- JSON ---
    def self.to_json_named(entries : Array(Tuple(String, Color))) : String
      String.build do |io|
        JSON.build(io, indent: 2) do |json|
          json.object do
            entries.each do |(name, col)|
              json.field(name, col.to_hex)
            end
          end
        end
      end
    end

    def self.to_json_indexed(colors : Array(Color)) : String
      String.build do |io|
        JSON.build(io, indent: 2) do |json|
          json.array do
            colors.each do |col|
              json.string(col.to_hex)
            end
          end
        end
      end
    end

    # --- CSS Custom Properties ---
    def self.to_css(entries : Array(Tuple(String, Color)), prefix : String = "") : String
      String.build do |io|
        io.puts ":root {"
        entries.each do |(name, col)|
          var_name = name.downcase.gsub(/[^a-z0-9]/, "-").gsub(/-+/, "-").strip("-")
          var_name = prefix.empty? ? "--#{var_name}" : "--#{prefix}-#{var_name}"
          io.puts "  #{var_name}: #{col.to_hex};"
        end
        io.puts "}"
      end
    end
  end
end

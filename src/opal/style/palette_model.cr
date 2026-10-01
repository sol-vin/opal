require "./color"
require "./palette_formats"

module Opal
  enum PaletteMode
    Named
    Indexed

    def to_s(io : IO) : Nil
      case self
      in Named   then io << "named"
      in Indexed then io << "indexed"
      end
    end

    def self.parse?(str : String | Symbol) : PaletteMode?
      case str.to_s.downcase.strip
      when "named", "name", "dictionary", "dict"
        Named
      when "indexed", "index", "array", "list"
        Indexed
      else
        nil
      end
    end
  end

  class NamedColorEntry
    property name : String
    property color : Color

    def initialize(@name : String, @color : Color)
    end

    def to_tuple : Tuple(String, Color)
      {@name, @color}
    end
  end

  # Core data model for a color palette.
  # Encapsulates either a Named palette (String -> Color) or an Indexed palette (Array(Color)),
  # with min/max size constraints, add/rename/remove/reorder permissions, and format conversion.
  class PaletteModel
    property mode : PaletteMode
    property named_entries : Array(NamedColorEntry)
    property indexed_colors : Array(Color)

    # Size restrictions (nil = unbounded)
    property min_colors : Int32? = nil
    property max_colors : Int32? = nil

    # Action permissions
    property? allow_add : Bool = true
    property? allow_rename : Bool = true
    property? allow_remove : Bool = true
    property? allow_reorder : Bool = true

    property palette_name : String = "Opal Palette"

    def initialize(
      @mode : PaletteMode = PaletteMode::Indexed,
      indexed_colors : Array(Color)? = nil,
      named_entries : Array(NamedColorEntry | Tuple(String, Color)) | Hash(String, Color)? = nil,
      @min_colors : Int32? = nil,
      @max_colors : Int32? = nil,
      @allow_add : Bool = true,
      @allow_rename : Bool = true,
      @allow_remove : Bool = true,
      @allow_reorder : Bool = true,
      @palette_name : String = "Opal Palette",
    )
      @indexed_colors = indexed_colors ? indexed_colors.dup : [] of Color
      @named_entries = [] of NamedColorEntry

      if named_entries
        case named_entries
        when Hash(String, Color)
          named_entries.each do |k, v|
            @named_entries << NamedColorEntry.new(k, v)
          end
        when Array
          named_entries.each do |item|
            if item.is_a?(NamedColorEntry)
              @named_entries << item
            else
              @named_entries << NamedColorEntry.new(item[0], item[1])
            end
          end
        end
      end

      # Provide sensible defaults if empty
      if @mode.indexed? && @indexed_colors.empty?
        @indexed_colors = [
          Color.hex("#F38BA8"),
          Color.hex("#FAB387"),
          Color.hex("#F9E2AF"),
          Color.hex("#A6E3A1"),
          Color.hex("#89B4FA"),
          Color.hex("#CBA6F7"),
          Color.hex("#88C0D0"),
          Color.hex("#BD93F9"),
        ]
      elsif @mode.named? && @named_entries.empty?
        @named_entries = [
          NamedColorEntry.new("primary", Color.hex("#38EF7D")),
          NamedColorEntry.new("secondary", Color.hex("#11998E")),
          NamedColorEntry.new("accent", Color.hex("#BD93F9")),
          NamedColorEntry.new("background", Color.hex("#1E1E2E")),
          NamedColorEntry.new("foreground", Color.hex("#CDD6F4")),
          NamedColorEntry.new("danger", Color.hex("#F38BA8")),
        ]
      end
    end

    # Total count of colors/entries
    def size : Int32
      @mode.named? ? @named_entries.size : @indexed_colors.size
    end

    def empty? : Bool
      size == 0
    end

    # Returns array of colors in current display order
    def colors : Array(Color)
      if @mode.named?
        @named_entries.map(&.color)
      else
        @indexed_colors.dup
      end
    end

    # Returns entry at index
    def color_at(index : Int32) : Color?
      if @mode.named?
        @named_entries[index]?.try &.color
      else
        @indexed_colors[index]?
      end
    end

    def name_at(index : Int32) : String?
      if @mode.named?
        @named_entries[index]?.try &.name
      else
        "color_#{index}"
      end
    end

    # Permission checks
    def can_add? : Bool
      return false unless @allow_add
      if max = @max_colors
        return size < max
      end
      true
    end

    def can_remove? : Bool
      return false unless @allow_remove
      if min = @min_colors
        return size > min
      end
      size > 1
    end

    def can_rename? : Bool
      @allow_rename && @mode.named?
    end

    def can_reorder? : Bool
      @allow_reorder && size > 1
    end

    # Modification operations
    def add(color : Color, name : String? = nil) : Bool
      return false unless can_add?
      if @mode.named?
        entry_name = name.presence || "color_#{@named_entries.size + 1}"
        @named_entries << NamedColorEntry.new(entry_name, color)
      else
        @indexed_colors << color
      end
      true
    end

    def remove_at(index : Int32) : Bool
      return false unless can_remove?
      if @mode.named?
        return false unless index >= 0 && index < @named_entries.size
        @named_entries.delete_at(index)
      else
        return false unless index >= 0 && index < @indexed_colors.size
        @indexed_colors.delete_at(index)
      end
      true
    end

    # Swap two indices (used for `[` and `]` reordering)
    def swap(index_a : Int32, index_b : Int32) : Bool
      return false unless can_reorder?
      return false unless index_a >= 0 && index_a < size && index_b >= 0 && index_b < size
      return true if index_a == index_b

      if @mode.named?
        @named_entries[index_a], @named_entries[index_b] = @named_entries[index_b], @named_entries[index_a]
      else
        @indexed_colors[index_a], @indexed_colors[index_b] = @indexed_colors[index_b], @indexed_colors[index_a]
      end
      true
    end

    # Move item from one position to another
    def move(from_idx : Int32, to_idx : Int32) : Bool
      return false unless can_reorder?
      return false unless from_idx >= 0 && from_idx < size && to_idx >= 0 && to_idx < size
      return true if from_idx == to_idx

      if @mode.named?
        entry = @named_entries.delete_at(from_idx)
        @named_entries.insert(to_idx, entry)
      else
        col = @indexed_colors.delete_at(from_idx)
        @indexed_colors.insert(to_idx, col)
      end
      true
    end

    def update_color(index : Int32, color : Color) : Bool
      return false unless index >= 0 && index < size
      if @mode.named?
        @named_entries[index].color = color
      else
        @indexed_colors[index] = color
      end
      true
    end

    def rename(index : Int32, new_name : String) : Bool
      return false unless can_rename?
      return false unless index >= 0 && index < @named_entries.size
      trimmed = new_name.strip
      return false if trimmed.empty?
      @named_entries[index].name = trimmed
      true
    end

    # Export format methods
    def to_gpl(name : String = @palette_name) : String
      entries = if @mode.named?
                  @named_entries.map { |e| {e.name, e.color} }
                else
                  @indexed_colors.map_with_index { |c, i| {"color_#{i}", c} }
                end
      PaletteFormats.to_gpl(entries, palette_name: name)
    end

    def to_pal : String
      PaletteFormats.to_pal(colors)
    end

    def to_hex(with_hash : Bool = true) : String
      PaletteFormats.to_hex(colors, with_hash: with_hash)
    end

    def to_json : String
      if @mode.named?
        PaletteFormats.to_json_named(@named_entries.map(&.to_tuple))
      else
        PaletteFormats.to_json_indexed(@indexed_colors)
      end
    end

    def to_css(prefix : String = "") : String
      entries = if @mode.named?
                  @named_entries.map(&.to_tuple)
                else
                  @indexed_colors.map_with_index { |c, i| {"color-#{i}", c} }
                end
      PaletteFormats.to_css(entries, prefix: prefix)
    end

    def export(format : PaletteFormat | Symbol | String, name : String = @palette_name) : String
      fmt = format.is_a?(PaletteFormat) ? format : (PaletteFormat.parse?(format) || PaletteFormat::HEX)
      case fmt
      in PaletteFormat::GPL  then to_gpl(name)
      in PaletteFormat::PAL  then to_pal
      in PaletteFormat::HEX  then to_hex
      in PaletteFormat::JSON then to_json
      in PaletteFormat::CSS  then to_css
      end
    end

    # Parsing / importing constructors
    def self.from_file(path : String) : PaletteModel
      ext = File.extname(path).downcase
      content = File.read(path)
      format = PaletteFormat.parse?(ext) || detect_format(content)
      from_content(content, format)
    end

    def self.detect_format(content : String) : PaletteFormat
      if content.starts_with?("GIMP Palette")
        PaletteFormat::GPL
      elsif content.starts_with?("JASC-PAL")
        PaletteFormat::PAL
      elsif content.strip.starts_with?("{") || content.strip.starts_with?("[")
        PaletteFormat::JSON
      elsif content.includes?(":root") || content.includes?("--")
        PaletteFormat::CSS
      else
        PaletteFormat::HEX
      end
    end

    def self.from_content(content : String, format : PaletteFormat) : PaletteModel
      case format
      in PaletteFormat::GPL
        tuples = PaletteFormats.from_gpl(content)
        new(mode: PaletteMode::Named, named_entries: tuples)
      in PaletteFormat::PAL
        colors = PaletteFormats.from_pal(content)
        new(mode: PaletteMode::Indexed, indexed_colors: colors)
      in PaletteFormat::HEX
        colors = PaletteFormats.from_hex(content)
        new(mode: PaletteMode::Indexed, indexed_colors: colors)
      in PaletteFormat::JSON
        parsed = JSON.parse(content)
        if parsed.as_h?
          entries = [] of Tuple(String, Color)
          parsed.as_h.each do |k, v|
            hex_str = v.as_s? || ""
            entries << {k, Color.hex(hex_str)}
          end
          new(mode: PaletteMode::Named, named_entries: entries)
        elsif parsed.as_a?
          colors = [] of Color
          parsed.as_a.each do |v|
            hex_str = v.as_s? || ""
            colors << Color.hex(hex_str)
          end
          new(mode: PaletteMode::Indexed, indexed_colors: colors)
        else
          new(mode: PaletteMode::Indexed)
        end
      in PaletteFormat::CSS
        entries = [] of Tuple(String, Color)
        content.scan(/--([a-zA-Z0-9_-]+)\s*:\s*(#[0-9a-fA-F]{3,8})/) do |match|
          name = match[1]
          hex = match[2]
          entries << {name, Color.hex(hex)}
        end
        new(mode: PaletteMode::Named, named_entries: entries)
      end
    end
  end
end

module Opal
  # Set of configurable UI glyphs and character symbols for controls.
  # Enables global and per-theme character swapping (e.g., retro ASCII vs modern Unicode).
  struct GlyphSet
    property window_close : String
    property window_maximize : String
    property window_minimize : String
    property window_resize : Char
    property cursor : String
    property checkbox_checked : String
    property checkbox_unchecked : String
    property radio_checked : String
    property radio_unchecked : String
    property dropdown_arrow : String
    property dropdown_arrow_up : String
    property scrollbar_thumb : Char
    property scrollbar_track : Char
    property scrollbar_arrow_up : Char
    property scrollbar_arrow_down : Char
    property scrollbar_arrow_left : Char
    property scrollbar_arrow_right : Char
    property table_junction : Char
    property table_horizontal : Char
    property table_vertical : Char
    property table_top_junction : Char
    property table_bottom_junction : Char
    property table_left_junction : Char
    property table_right_junction : Char

    def initialize(
      @window_close : String = "[x]",
      @window_maximize : String = "[^]",
      @window_minimize : String = "[-]",
      @window_resize : Char = '◢',
      @cursor : String = "▶ ",
      @checkbox_checked : String = "[x]",
      @checkbox_unchecked : String = "[ ]",
      @radio_checked : String = "(•)",
      @radio_unchecked : String = "( )",
      @dropdown_arrow : String = "▼",
      @dropdown_arrow_up : String = "▲",
      @scrollbar_thumb : Char = '█',
      @scrollbar_track : Char = '░',
      @scrollbar_arrow_up : Char = '▲',
      @scrollbar_arrow_down : Char = '▼',
      @scrollbar_arrow_left : Char = '◄',
      @scrollbar_arrow_right : Char = '►',
      @table_junction : Char = '┼',
      @table_horizontal : Char = '─',
      @table_vertical : Char = '│',
      @table_top_junction : Char = '┬',
      @table_bottom_junction : Char = '┴',
      @table_left_junction : Char = '├',
      @table_right_junction : Char = '┤',
    )
    end

    # Predefined Unicode glyph set
    def self.unicode : GlyphSet
      new
    end

    # Predefined ASCII-only glyph set for high-portability terminals
    def self.ascii : GlyphSet
      new(
        window_close: "[X]",
        window_maximize: "[+]",
        window_minimize: "[-]",
        window_resize: '+',
        cursor: "> ",
        checkbox_checked: "[X]",
        checkbox_unchecked: "[ ]",
        radio_checked: "(*)",
        radio_unchecked: "( )",
        dropdown_arrow: "v",
        dropdown_arrow_up: "^",
        scrollbar_thumb: '#',
        scrollbar_track: '.',
        scrollbar_arrow_up: '^',
        scrollbar_arrow_down: 'v',
        scrollbar_arrow_left: '<',
        scrollbar_arrow_right: '>',
        table_junction: '+',
        table_horizontal: '-',
        table_vertical: '|',
        table_top_junction: '+',
        table_bottom_junction: '+',
        table_left_junction: '+',
        table_right_junction: '+'
      )
    end

    # Returns a modified copy with selective character swaps
    def swap(
      window_close : String? = nil,
      window_maximize : String? = nil,
      window_minimize : String? = nil,
      window_resize : Char? = nil,
      cursor : String? = nil,
      checkbox_checked : String? = nil,
      checkbox_unchecked : String? = nil,
      radio_checked : String? = nil,
      radio_unchecked : String? = nil,
      dropdown_arrow : String? = nil,
      dropdown_arrow_up : String? = nil,
      scrollbar_thumb : Char? = nil,
      scrollbar_track : Char? = nil,
      scrollbar_arrow_up : Char? = nil,
      scrollbar_arrow_down : Char? = nil,
      scrollbar_arrow_left : Char? = nil,
      scrollbar_arrow_right : Char? = nil,
      table_junction : Char? = nil,
      table_horizontal : Char? = nil,
      table_vertical : Char? = nil,
      table_top_junction : Char? = nil,
      table_bottom_junction : Char? = nil,
      table_left_junction : Char? = nil,
      table_right_junction : Char? = nil,
    ) : GlyphSet
      GlyphSet.new(
        window_close: window_close || @window_close,
        window_maximize: window_maximize || @window_maximize,
        window_minimize: window_minimize || @window_minimize,
        window_resize: window_resize || @window_resize,
        cursor: cursor || @cursor,
        checkbox_checked: checkbox_checked || @checkbox_checked,
        checkbox_unchecked: checkbox_unchecked || @checkbox_unchecked,
        radio_checked: radio_checked || @radio_checked,
        radio_unchecked: radio_unchecked || @radio_unchecked,
        dropdown_arrow: dropdown_arrow || @dropdown_arrow,
        dropdown_arrow_up: dropdown_arrow_up || @dropdown_arrow_up,
        scrollbar_thumb: scrollbar_thumb || @scrollbar_thumb,
        scrollbar_track: scrollbar_track || @scrollbar_track,
        scrollbar_arrow_up: scrollbar_arrow_up || @scrollbar_arrow_up,
        scrollbar_arrow_down: scrollbar_arrow_down || @scrollbar_arrow_down,
        scrollbar_arrow_left: scrollbar_arrow_left || @scrollbar_arrow_left,
        scrollbar_arrow_right: scrollbar_arrow_right || @scrollbar_arrow_right,
        table_junction: table_junction || @table_junction,
        table_horizontal: table_horizontal || @table_horizontal,
        table_vertical: table_vertical || @table_vertical,
        table_top_junction: table_top_junction || @table_top_junction,
        table_bottom_junction: table_bottom_junction || @table_bottom_junction,
        table_left_junction: table_left_junction || @table_left_junction,
        table_right_junction: table_right_junction || @table_right_junction
      )
    end
  end
end

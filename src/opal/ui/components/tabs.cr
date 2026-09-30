require "../element"
require "../buffer"
require "../../style/color"
require "../../style/visual_width"

module Opal
  module UI
    # Data structure representing a single tab item in a tab bar.
    struct TabItem
      getter id : String
      getter label : String
      getter badge : String?
      getter shortcut : String?

      def initialize(
        @id : String,
        @label : String,
        @badge : String? = nil,
        @shortcut : String? = nil,
      )
      end
    end

    # Tabbed navigation header component for multi-view interfaces.
    class Tabs < Element
      property items : Array(TabItem)
      property active_index : Int32 = 0
      property active_fg : Color?
      property active_bg : Color?
      property inactive_fg : Color?
      property inactive_bg : Color?
      property spacing : Int32
      property? pill_style : Bool

      def initialize(
        @items : Array(TabItem) = [] of TabItem,
        @active_index : Int32 = 0,
        active_fg : Color | Symbol | String | Nil = nil,
        active_bg : Color | Symbol | String | Nil = nil,
        inactive_fg : Color | Symbol | String | Nil = nil,
        inactive_bg : Color | Symbol | String | Nil = nil,
        @spacing : Int32 = 2,
        @pill_style : Bool = false,
      )
        @active_fg = active_fg ? Color.from(active_fg) : nil
        @active_bg = active_bg ? Color.from(active_bg) : nil
        @inactive_fg = inactive_fg ? Color.from(inactive_fg) : nil
        @inactive_bg = inactive_bg ? Color.from(inactive_bg) : nil
      end

      def self.new(
        labels : Array(String),
        active_index : Int32 = 0,
        active_fg : Color | Symbol | String | Nil = nil,
        active_bg : Color | Symbol | String | Nil = nil,
        inactive_fg : Color | Symbol | String | Nil = nil,
        inactive_bg : Color | Symbol | String | Nil = nil,
        spacing : Int32 = 2,
        pill_style : Bool = false,
      ) : Tabs
        items = labels.map { |l| TabItem.new(l.downcase, l) }
        new(items, active_index, active_fg, active_bg, inactive_fg, inactive_bg, spacing, pill_style)
      end

      def self.from_labels(labels : Array(String), active : Int32 = 0) : Tabs
        items = labels.map_with_index do |lbl, idx|
          shortcut = (idx + 1) <= 9 ? (idx + 1).to_s : nil
          TabItem.new(id: lbl.downcase.gsub(/\s+/, "_"), label: lbl, shortcut: shortcut)
        end
        new(items: items, active_index: active)
      end

      def select(index : Int32) : self
        @active_index = index.clamp(0, Math.max(0, @items.size - 1))
        self
      end

      def select_id(id : String) : self
        if idx = @items.index { |it| it.id == id }
          @active_index = idx
        end
        self
      end

      def next_tab : self
        return self if @items.empty?
        @active_index = (@active_index + 1) % @items.size
        self
      end

      def prev_tab : self
        return self if @items.empty?
        @active_index = (@active_index - 1 + @items.size) % @items.size
        self
      end

      def active_tab : TabItem?
        @items[@active_index]?
      end

      def preferred_size(available_w : Int32, available_h : Int32) : {Int32, Int32}
        total_w = 0
        @items.each_with_index do |item, idx|
          total_w += formatted_item_width(item)
          total_w += @spacing if idx < @items.size - 1
        end
        {Math.min(available_w, total_w), Math.min(available_h, 1)}
      end

      def render(buffer : Buffer, x : Int32, y : Int32, width : Int32, height : Int32) : Nil
        return if width <= 0 || height <= 0 || @items.empty?

        cur_x = x

        @items.each_with_index do |item, idx|
          break if cur_x >= x + width
          is_active = (idx == @active_index)
          item_w = formatted_item_width(item)

          render_tab(buffer, cur_x, y, item, is_active, Math.min(item_w, (x + width) - cur_x))
          cur_x += item_w + @spacing
        end
      end

      private def formatted_item_width(item : TabItem) : Int32
        text = tab_string(item)
        VisualWidth.width(text)
      end

      private def tab_string(item : TabItem) : String
        io = IO::Memory.new
        io << "[ "
        if sc = item.shortcut
          io << sc << ": "
        end
        io << item.label
        if b = item.badge
          io << " (" << b << ")"
        end
        io << " ]"
        io.to_s
      end

      private def render_tab(
        buffer : Buffer,
        x : Int32,
        y : Int32,
        item : TabItem,
        is_active : Bool,
        max_w : Int32,
      ) : Nil
        th = current_theme
        a_fg = @active_fg || (pill_style? ? th.background : th.primary)
        a_bg = @active_bg || (pill_style? ? th.primary : Color.none)
        i_fg = @inactive_fg || th.text_muted
        i_bg = @inactive_bg || Color.none

        text = tab_string(item)
        if is_active
          if @pill_style
            buffer.put_string(x, y, text, fg: a_fg, bg: a_bg, bold: true, max_width: max_w)
          else
            buffer.put_string(x, y, text, fg: a_fg, bold: true, underline: true, max_width: max_w)
          end
        else
          buffer.put_string(x, y, text, fg: i_fg, bg: i_bg, dim: true, max_width: max_w)
        end
      end
    end
  end
end

require "../element"
require "../buffer"
require "../control"
require "./color_picker"
require "../../style/color"
require "../../style/border"
require "../../style/palette_model"
require "../../style/visual_width"
require "../../terminal/driver"

module Opal
  module UI
    # Interactive Palette UI control supporting Named and Indexed modes,
    # color reordering via `[` and `]`, min/max constraints, inline renaming,
    # and seamless embedded ColorPicker integration.
    class Palette < Control
      property model : PaletteModel
      property cursor : Int32 = 0

      # Embedded ColorPicker state
      getter color_picker : ColorPicker
      property? editing_color : Bool = false
      property picker_mode : ColorMode = ColorMode::RGB
      property picker_layout : ColorPickerLayout = ColorPickerLayout::Sliders
      property? show_picker_alpha : Bool = false
      property? show_picker_harmonies : Bool = true

      # Inline renaming state (Named mode)
      property? renaming : Bool = false
      property rename_buffer : String = ""

      # Visual styling
      property title : String = "Color Palette"
      property border_color : Color = Color.hex("#6272A4")
      property active_border_color : Color = Color.hex("#50FA7B")
      property? show_border : Bool = true

      # Callbacks
      property on_change : Proc(PaletteModel, Nil)? = nil
      property on_confirm : Proc(PaletteModel, Nil)? = nil
      property on_select : Proc(Int32, Color, String?, Nil)? = nil
      property? confirmed : Bool = false

      # Geometry cache
      property width : Int32
      property height : Int32
      property last_x : Int32 = 0
      property last_y : Int32 = 0
      property last_w : Int32 = 54
      property last_h : Int32 = 16

      # Status feedback message (e.g. "Copied #38EF7D to clipboard!")
      @status_msg : String? = nil
      @status_msg_ticks : Int32 = 0

      def initialize(
        @model : PaletteModel = PaletteModel.new,
        @picker_mode : ColorMode = ColorMode::RGB,
        @picker_layout : ColorPickerLayout = ColorPickerLayout::Sliders,
        @show_picker_alpha : Bool = false,
        @show_picker_harmonies : Bool = true,
        @title : String = "Color Palette",
        width : Int32? = 54,
        height : Int32? = 16,
      )
        @width = width || 54
        @height = height || 16

        initial_color = @model.color_at(0) || Color.hex("#38EF7D")
        @color_picker = ColorPicker.new(
          initial_color: initial_color,
          mode: @picker_mode,
          layout: @picker_layout,
          show_alpha: @show_picker_alpha,
          show_harmonies: @show_picker_harmonies,
          show_select_button: true
        )

        @color_picker.on_confirm = ->(chosen : Color) {
          confirm_color_edit(chosen)
        }
      end

      # Convenience constructor for indexed mode from Array(Color)
      def self.indexed(
        colors : Array(Color),
        min_colors : Int32? = nil,
        max_colors : Int32? = nil,
        allow_add : Bool = true,
        allow_remove : Bool = true,
        allow_reorder : Bool = true,
        picker_mode : ColorMode = ColorMode::RGB,
        picker_layout : ColorPickerLayout = ColorPickerLayout::Sliders,
        show_picker_alpha : Bool = false,
        show_picker_harmonies : Bool = true,
        title : String = "Indexed Palette",
        width : Int32? = 54,
        height : Int32? = 16,
      ) : Palette
        model = PaletteModel.new(
          mode: PaletteMode::Indexed,
          indexed_colors: colors,
          min_colors: min_colors,
          max_colors: max_colors,
          allow_add: allow_add,
          allow_remove: allow_remove,
          allow_reorder: allow_reorder
        )
        new(
          model: model,
          picker_mode: picker_mode,
          picker_layout: picker_layout,
          show_picker_alpha: show_picker_alpha,
          show_picker_harmonies: show_picker_harmonies,
          title: title,
          width: width,
          height: height
        )
      end

      # Convenience constructor for named mode from Hash(String, Color)
      def self.named(
        entries : Hash(String, Color),
        allow_add : Bool = true,
        allow_rename : Bool = true,
        allow_remove : Bool = true,
        picker_mode : ColorMode = ColorMode::RGB,
        picker_layout : ColorPickerLayout = ColorPickerLayout::Sliders,
        show_picker_alpha : Bool = false,
        show_picker_harmonies : Bool = true,
        title : String = "Named Palette",
        width : Int32? = 54,
        height : Int32? = 16,
      ) : Palette
        model = PaletteModel.new(
          mode: PaletteMode::Named,
          named_entries: entries,
          allow_add: allow_add,
          allow_rename: allow_rename,
          allow_remove: allow_remove
        )
        new(
          model: model,
          picker_mode: picker_mode,
          picker_layout: picker_layout,
          show_picker_alpha: show_picker_alpha,
          show_picker_harmonies: show_picker_harmonies,
          title: title,
          width: width,
          height: height
        )
      end

      # Begins editing the currently selected color with the ColorPicker
      def open_color_picker : Nil
        return if @model.empty?
        if col = @model.color_at(@cursor)
          @color_picker.color = col
          @editing_color = true
        end
      end

      # Confirms the edited color from ColorPicker back to the Palette
      def confirm_color_edit(color : Color) : Nil
        @model.update_color(@cursor, color)
        @editing_color = false
        @status_msg = "Updated color #{@cursor + 1} to #{color.to_hex}"
        @on_change.try &.call(@model)
      end

      # Cancels color editing without saving
      def cancel_color_edit : Nil
        @editing_color = false
      end

      # Moves cursor with bounds checking and triggers selection callback
      def move_cursor(delta : Int32) : Nil
        return if @model.empty?
        @cursor = (@cursor + delta).clamp(0, @model.size - 1)
        trigger_select
      end

      def set_cursor(idx : Int32) : Nil
        return if @model.empty?
        @cursor = idx.clamp(0, @model.size - 1)
        trigger_select
      end

      private def trigger_select : Nil
        if col = @model.color_at(@cursor)
          name = @model.name_at(@cursor)
          @on_select.try &.call(@cursor, col, name)
        end
      end

      # Swap selected color left/earlier (via `[` key)
      def swap_left : Nil
        return unless @model.can_reorder?
        if @cursor > 0
          @model.swap(@cursor, @cursor - 1)
          @cursor -= 1
          @status_msg = "Swapped to position #{@cursor + 1}"
          @on_change.try &.call(@model)
        end
      end

      # Swap selected color right/later (via `]` key)
      def swap_right : Nil
        return unless @model.can_reorder?
        if @cursor < @model.size - 1
          @model.swap(@cursor, @cursor + 1)
          @cursor += 1
          @status_msg = "Swapped to position #{@cursor + 1}"
          @on_change.try &.call(@model)
        end
      end

      # Adds a new color or entry
      def add_entry : Nil
        return unless @model.can_add?
        new_color = Color.hex("#50FA7B")
        if @model.mode.named?
          new_name = "color_#{@model.size + 1}"
          @model.add(new_color, new_name)
        else
          @model.add(new_color)
        end
        @cursor = @model.size - 1
        @status_msg = "Added new color (#{@model.size} total)"
        @on_change.try &.call(@model)
        trigger_select
      end

      # Removes selected entry
      def delete_selected : Nil
        return unless @model.can_remove?
        return if @model.empty?
        @model.remove_at(@cursor)
        @cursor = @cursor.clamp(0, Math.max(0, @model.size - 1))
        @status_msg = "Removed color"
        @on_change.try &.call(@model)
        trigger_select
      end

      # Starts inline renaming
      def start_rename : Nil
        return unless @model.can_rename?
        if current_name = @model.name_at(@cursor)
          @rename_buffer = current_name
          @renaming = true
        end
      end

      def confirm_rename : Nil
        return unless @renaming
        @model.rename(@cursor, @rename_buffer)
        @renaming = false
        @status_msg = "Renamed to '#{@rename_buffer}'"
        @on_change.try &.call(@model)
      end

      def cancel_rename : Nil
        @renaming = false
      end

      def handle_key(key : Terminal::KeyEvent) : Bool
        # If currently in inline renaming mode:
        if @renaming
          case key.name
          when "enter"
            confirm_rename
            return true
          when "escape", "esc"
            cancel_rename
            return true
          when "backspace"
            @rename_buffer = @rename_buffer[0...-1] unless @rename_buffer.empty?
            return true
          else
            if ch = key.char
              if ch >= ' ' && ch <= '~'
                @rename_buffer += ch
                return true
              end
            end
          end
          return true
        end

        # If currently editing with embedded ColorPicker:
        if @editing_color
          if key.name == "escape" || key.name == "esc"
            cancel_color_edit
            return true
          end
          return @color_picker.handle_key(key)
        end

        # Normal Palette Navigation
        case key.name
        when "left", "h"
          move_cursor(-1)
          true
        when "right", "l"
          move_cursor(1)
          true
        when "up", "k"
          # In named mode, up moves up 1 row; in indexed mode, up moves up 1 row (typically 8 swatches)
          step = @model.mode.named? ? 1 : 8
          move_cursor(-step)
          true
        when "down", "j"
          step = @model.mode.named? ? 1 : 8
          move_cursor(step)
          true
        when "[", "<"
          # Swap left/earlier (avoids Shift+Left to protect showcase slide navigation)
          swap_left
          true
        when "]", ">"
          # Swap right/later (avoids Shift+Right to protect showcase slide navigation)
          swap_right
          true
        when "enter", "space", "e", "E"
          open_color_picker
          true
        when "r", "R", "f2"
          start_rename
          true
        when "a", "A", "+"
          add_entry
          true
        when "x", "X", "d", "delete"
          delete_selected
          true
        when "c", "C"
          # Copy active hex code to clipboard
          if col = @model.color_at(@cursor)
            hex = col.to_hex
            Opal.clipboard.copy(hex) rescue nil
            @status_msg = "Copied #{hex} to clipboard!"
          end
          true
        when "ctrl+s", "ctrl+d", "f10", "shift+enter"
          @confirmed = true
          @on_confirm.try &.call(@model)
          true
        else
          false
        end
      end

      def handle_mouse(event : Terminal::MouseEvent) : Bool
        if @editing_color
          return @color_picker.handle_mouse(event)
        end

        # Mouse click swatch selection
        if event.action.press?
          pad_x = @last_x + (@show_border ? 1 : 0)
          pad_y = @last_y + (@show_border ? 1 : 0)

          if @model.mode.named?
            row = event.y - (pad_y + 1)
            if row >= 0 && row < @model.size
              set_cursor(row)
              if event.button.left? && @cursor == row
                # Clicked already selected item: open picker
                open_color_picker
              end
              return true
            end
          else
            # Swatches grid hit testing
            col_w = 5 # "████ "
            grid_y = pad_y + 2
            row = (event.y - grid_y) // 2
            col = (event.x - pad_x - 2) // col_w
            if row >= 0 && col >= 0 && col < 8
              idx = (row * 8) + col
              if idx >= 0 && idx < @model.size
                set_cursor(idx)
                return true
              end
            end
          end
        end

        false
      end

      def preferred_size(available_w : Int32, available_h : Int32) : {Int32, Int32}
        {Math.min(available_w, @width), Math.min(available_h, @height)}
      end

      def render(buffer : Buffer) : Nil
        render(buffer, @last_x, @last_y, @width, @height)
      end

      def render(buffer : Buffer, x : Int32, y : Int32, width : Int32, height : Int32) : Nil
        @last_x = x
        @last_y = y
        @last_w = width
        @last_h = height
        @width = width
        @height = height
        return if width <= 4 || height <= 4

        # Outer border
        if @show_border
          Graphics::Primitives2D.draw_rect(
            buffer, x, y, width, height,
            border: :rounded,
            fg: @border_color
          )

          # Header title
          mode_tag = @model.mode.named? ? "NAMED" : "INDEXED"
          limit_str = if max = @model.max_colors
                        " [#{@model.size}/#{max}]"
                      else
                        " [#{@model.size}]"
                      end
          header = " #{@title} (#{mode_tag}#{limit_str}) "
          if VisualWidth.measure(header) < width - 4
            buffer.put_string(x + 2, y, header, fg: Color.white, bold: true)
          end

          inner_x = x + 1
          inner_y = y + 1
          inner_w = width - 2
          inner_h = height - 2
        else
          inner_x = x
          inner_y = y
          inner_w = width
          inner_h = height
        end

        return if inner_w <= 0 || inner_h <= 0

        # If ColorPicker is active, render embedded editor overlay
        if @editing_color
          render_picker_overlay(buffer, inner_x, inner_y, inner_w, inner_h)
          return
        end

        # Render palette view
        if @model.mode.named?
          render_named_view(buffer, inner_x, inner_y, inner_w, inner_h)
        else
          render_indexed_view(buffer, inner_x, inner_y, inner_w, inner_h)
        end

        # Render bottom hotkey toolbar and status message
        render_bottom_bar(buffer, inner_x, inner_y + inner_h - 2, inner_w)
      end

      private def render_picker_overlay(buffer : Buffer, x : Int32, y : Int32, w : Int32, h : Int32) : Nil
        # Banner for color editing
        cur_name = @model.name_at(@cursor) || "Color #{@cursor + 1}"
        banner = " EDITING: #{cur_name} — [Enter: Confirm] [Esc: Cancel] "
        buffer.put_string(x + 1, y, banner, fg: Color.hex("#50FA7B"), bold: true)

        # Delegate rendering to embedded ColorPicker
        picker_y = y + 1
        picker_h = h - 1
        @color_picker.render(buffer, x + 1, picker_y, w - 2, picker_h)
      end

      private def render_indexed_view(buffer : Buffer, x : Int32, y : Int32, w : Int32, h : Int32) : Nil
        # Render swatches in an 8-column layout
        swatch_w = 4 # "████"
        swatches_per_row = Math.max(1, (w - 4) // (swatch_w + 1)).clamp(4, 12)
        start_x = x + 2
        start_y = y + 1

        @model.indexed_colors.each_with_index do |col, idx|
          row = idx // swatches_per_row
          col_idx = idx % swatches_per_row
          sx = start_x + (col_idx * (swatch_w + 1))
          sy = start_y + (row * 2)

          break if sy + 1 >= y + h - 3

          is_selected = (idx == @cursor)

          # Color block
          swatch_chars = "████"
          buffer.put_string(sx, sy, swatch_chars, fg: col)

          # Selection indicator under/above swatch
          if is_selected
            buffer.put_char(sx - 1, sy, '▌', fg: @active_border_color)
            buffer.put_char(sx + swatch_w, sy, '▐', fg: @active_border_color)
            # Label with index number
            idx_str = sprintf("%02d", idx + 1)
            buffer.put_string(sx + 1, sy + 1, idx_str, fg: @active_border_color, bold: true)
          else
            idx_str = sprintf("%02d", idx + 1)
            buffer.put_string(sx + 1, sy + 1, idx_str, fg: Color.hex("#6272A4"))
          end
        end

        # Readout info for active swatch
        if cur_col = @model.color_at(@cursor)
          r, g, b = cur_col.to_rgb
          h_val, s_val, l_val = cur_col.to_hsl
          info_y = y + h - 4
          if info_y > start_y
            hex_str = cur_col.to_hex
            rgb_str = sprintf("RGB: %3d, %3d, %3d", r, g, b)
            hsl_str = sprintf("HSL: %3d°, %2d%%, %2d%%", h_val.round.to_i, (s_val * 100).round.to_i, (l_val * 100).round.to_i)
            readout = "Selected ##{@cursor + 1}: #{hex_str} | #{rgb_str} | #{hsl_str}"
            buffer.put_string(x + 2, info_y, readout, fg: Color.hex("#F8F8F2"), bold: true)
          end
        end
      end

      private def render_named_view(buffer : Buffer, x : Int32, y : Int32, w : Int32, h : Int32) : Nil
        # Two-column or table view of named entries
        max_rows = h - 4
        scroll_offset = Math.max(0, @cursor - max_rows + 1)
        visible_entries = @model.named_entries[scroll_offset, max_rows]? || @model.named_entries

        start_y = y + 1

        visible_entries.each_with_index do |entry, row_idx|
          actual_idx = scroll_offset + row_idx
          is_selected = (actual_idx == @cursor)
          ry = start_y + row_idx

          # Cursor marker
          marker = is_selected ? "▸" : " "
          marker_fg = is_selected ? @active_border_color : Color.none
          buffer.put_string(x + 2, ry, marker, fg: marker_fg, bold: true)

          # Name field (or editing field)
          if is_selected && @renaming
            edit_text = " [#{@rename_buffer}_] "
            buffer.put_string(x + 4, ry, edit_text.ljust(18), fg: Color.hex("#F1FA8C"), bold: true)
          else
            name_text = entry.name.ljust(16)
            name_fg = is_selected ? Color.white : Color.hex("#CDD6F4")
            buffer.put_string(x + 4, ry, name_text, fg: name_fg, bold: is_selected)
          end

          # Color swatch block
          buffer.put_string(x + 22, ry, "████", fg: entry.color)

          # Hex & RGB readout
          r, g, b = entry.color.to_rgb
          spec_str = sprintf(" %s  rgb(%3d,%3d,%3d)", entry.color.to_hex, r, g, b)
          buffer.put_string(x + 27, ry, spec_str, fg: is_selected ? Color.white : Color.hex("#6272A4"))
        end
      end

      private def render_bottom_bar(buffer : Buffer, x : Int32, y : Int32, w : Int32) : Nil
        # Status / Feedback toast message
        if msg = @status_msg
          buffer.put_string(x + 2, y, " #{msg} ", fg: Color.hex("#50FA7B"), bold: true)
        end

        # Hotkey guide line
        reorder_keys = @model.can_reorder? ? " [[]/[]] Swap" : ""
        add_key = @model.can_add? ? " [a] Add" : ""
        del_key = @model.can_remove? ? " [x] Del" : ""
        ren_key = @model.can_rename? ? " [r] Rename" : ""
        save_key = " [Ctrl+S] Save"
        guide = "[Enter] Edit#{reorder_keys}#{add_key}#{del_key}#{ren_key}#{save_key} [c] Copy"
        if VisualWidth.measure(guide) < w - 2
          buffer.put_string(x + 2, y + 1, guide, fg: Color.hex("#6272A4"))
        end
      end
    end
  end

  # High-level interactive palette runner for CLI or embedding.
  def self.manage_palette(
    palette : UI::Palette,
    driver : Terminal::Driver? = nil,
    output : IO? = nil,
  ) : PaletteModel?
    drv = driver || (output ? Terminal.default_driver(output: output) : Terminal.default_driver)

    render_frame = -> {
      w, h = drv.size
      buf = UI::Buffer.new(w, h)
      palette.render(buf, 0, 0, w, h)
      drv.write(Terminal::Screen::CLEAR_ALL)
      drv.write(Terminal::Screen.move_to(1, 1))
      drv.write(buf.to_s)
      drv.flush
    }

    result : PaletteModel? = nil

    drv.raw_mode do
      drv.hide_cursor
      drv.enable_mouse
      render_frame.call

      loop do
        event = drv.read_event
        next unless event
        should_redraw = false

        case event
        when Terminal::KeyEvent
          if !palette.editing_color? && !palette.renaming? && (event.matches?("escape") || event.matches?("ctrl+c"))
            break
          end

          if palette.handle_key(event)
            should_redraw = true
            if palette.confirmed?
              result = palette.model
              break
            end
          end
        when Terminal::MouseEvent
          if palette.handle_mouse(event)
            should_redraw = true
            if palette.confirmed?
              result = palette.model
              break
            end
          end
        end

        render_frame.call if should_redraw
      end
    ensure
      drv.disable_mouse
      drv.show_cursor
    end

    result
  end
end

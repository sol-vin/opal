require "../element"
require "../buffer"
require "../control"
require "../../style/color"
require "../../style/border"
require "../../style/visual_width"
require "../../graphics/primitives_2d"
require "../../input/fuzzy"
require "../../input/core/remap_model"
require "../../input/dsl/remap_builder"
require "../../terminal/driver"

module Opal
  module UI
    # Interactive Input Remapping UI Control for Opal TUIs and Lapis (Godot 4.8) game settings.
    # Supports category tabs, live Press-Any-Key/Mouse capture modal, multi-slot bindings
    # (Primary / Secondary), conflict detection badges, fuzzy search filtering, deadzone adjustment,
    # DualShock/Xbox/Generic gamepad glyphs, and WCAG contrast-compliant theme integration.
    class InputRemapper < Control
      property model : Input::Core::InputRemapModel
      property cursor : Int32 = 0
      property active_slot : Int32 = 0
      property selected_category : String? = nil # nil = "All"

      # Interactive states
      property? capturing : Bool = false
      property? filtering : Bool = false
      property query : String = ""
      property? confirmed : Bool = false

      # Visual configuration
      property title : String = "Input Remapping"
      property? show_border : Bool = true
      property? show_categories : Bool = true
      property? show_deadzone : Bool = true
      property border_style : Symbol | Border = :rounded
      property border_color : Color? = nil
      property active_border_color : Color? = nil

      # Callbacks
      property on_change : Proc(Input::Core::InputRemapModel, Nil)? = nil
      property on_confirm : Proc(Input::Core::InputRemapModel, Nil)? = nil
      property on_rebind : Proc(Input::Core::InputAction, Int32, Input::Core::InputBinding, Nil)? = nil
      property on_conflict : Proc(Array(Input::Core::BindingConflict), Nil)? = nil

      # Geometry & layout cache for mouse interaction
      property width : Int32
      property height : Int32
      property last_x : Int32 = 0
      property last_y : Int32 = 0
      property last_w : Int32 = 68
      property last_h : Int32 = 18
      @list_start_y : Int32 = 0
      @list_height : Int32 = 0
      @scroll_offset : Int32 = 0
      @slot_col_x : Array(Int32) = [28, 46]
      @slot_col_w : Int32 = 16
      @cat_tab_boxes : Array(Tuple(Int32, Int32, String?)) = [] of Tuple(Int32, Int32, String?)

      # Status feedback toast
      property status_message : String? = nil

      def initialize(
        model : Input::Core::InputRemapModel? = nil,
        @title : String = "Input Remapping",
        @show_border : Bool = true,
        @show_categories : Bool = true,
        @show_deadzone : Bool = true,
        @border_style : Symbol | Border = :rounded,
        width : Int32? = 68,
        height : Int32? = 18,
      )
        super()
        @model = model || Input::Core::InputRemapModel.default_profile(@title)
        @width = width || 68
        @height = height || 18
      end

      # Instantiates an InputRemapper with a declarative InputRemapBuilder block.
      def self.new(
        title : String = "Input Remapping",
        conflict_policy : Input::Core::ConflictPolicy | Symbol | String = :allow,
        gamepad_style : Input::Core::GamepadStyle | Symbol | String = :dualshock,
        max_slots : Int32 = 2,
        show_border : Bool = true,
        show_categories : Bool = true,
        show_deadzone : Bool = true,
        width : Int32? = 68,
        height : Int32? = 18,
        &
      ) : InputRemapper
        mdl = Input.remap_profile(
          profile_name: title,
          max_slots: max_slots,
          conflict_policy: conflict_policy,
          gamepad_style: gamepad_style
        ) do |b|
          with b yield b
        end
        new(
          model: mdl,
          title: title,
          show_border: show_border,
          show_categories: show_categories,
          show_deadzone: show_deadzone,
          width: width,
          height: height
        )
      end

      # Returns actions filtered by the active category tab and fuzzy search query.
      def visible_actions : Array(Input::Core::InputAction)
        cat_filtered = if cat = @selected_category
                         @model.actions.select { |a| a.category == cat }
                       else
                         @model.actions
                       end

        if @query.empty?
          cat_filtered
        else
          Input::Fuzzy.filter_by(@query, cat_filtered, &.search_text).map(&.item)
        end
      end

      # Returns currently highlighted InputAction, or nil if visible list is empty.
      def selected_action : Input::Core::InputAction?
        vis = visible_actions
        return nil if vis.empty?
        idx = @cursor.clamp(0, vis.size - 1)
        vis[idx]?
      end

      # Returns all category tab names (`nil` represents "All").
      def category_tabs : Array(String?)
        tabs = [nil] of String?
        @model.categories.each { |c| tabs << c }
        tabs
      end

      # Navigation & Action API
      def move_cursor(delta : Int32) : Nil
        vis = visible_actions
        return if vis.empty?
        @cursor = (@cursor + delta).clamp(0, vis.size - 1)
      end

      def move_slot(delta : Int32) : Nil
        @active_slot = (@active_slot + delta).clamp(0, Math.max(0, @model.max_slots - 1))
      end

      def next_category : Nil
        tabs = category_tabs
        return if tabs.size <= 1
        cur_idx = tabs.index(@selected_category) || 0
        @selected_category = tabs[(cur_idx + 1) % tabs.size]
        @cursor = 0
      end

      def prev_category : Nil
        tabs = category_tabs
        return if tabs.size <= 1
        cur_idx = tabs.index(@selected_category) || 0
        @selected_category = tabs[(cur_idx - 1 + tabs.size) % tabs.size]
        @cursor = 0
      end

      def cycle_gamepad_style : Nil
        @model.gamepad_style = case @model.gamepad_style
                               in Input::Core::GamepadStyle::DualShock then Input::Core::GamepadStyle::Xbox
                               in Input::Core::GamepadStyle::Xbox      then Input::Core::GamepadStyle::Generic
                               in Input::Core::GamepadStyle::Generic   then Input::Core::GamepadStyle::DualShock
                               end
        @status_message = "Gamepad glyphs: #{@model.gamepad_style}"
      end

      def adjust_deadzone(delta : Float32) : Nil
        if act = selected_action
          return if act.locked?
          act.deadzone = (act.deadzone + delta).clamp(0.05_f32, 0.95_f32).round(2)
          @status_message = "Deadzone for '#{act.label}': #{(act.deadzone * 100).round.to_i}%"
          @on_change.try &.call(@model)
        end
      end

      def start_capture : Bool
        if act = selected_action
          if act.locked?
            @status_message = "'#{act.label}' is locked and cannot be remapped"
            return false
          end
          @capturing = true
          @status_message = "Listening for input on '#{act.label}' (Slot #{@active_slot + 1})..."
          true
        else
          false
        end
      end

      def cancel_capture : Nil
        @capturing = false
        @status_message = "Canceled input capture"
      end

      def apply_captured_binding(binding : Input::Core::InputBinding) : Bool
        @capturing = false
        act = selected_action
        return false unless act

        if @model.assign_binding(act.id, @active_slot, binding)
          lbl = binding.display_label(@model.gamepad_style)
          @status_message = "Bound '#{act.label}' [Slot #{@active_slot + 1}] → #{lbl}"
          @on_rebind.try &.call(act, @active_slot, binding)
          @on_change.try &.call(@model)
          current_conflicts = @model.conflicts
          @on_conflict.try &.call(current_conflicts) unless current_conflicts.empty?
          true
        else
          @status_message = "Conflict blocked: #{binding.display_label(@model.gamepad_style)} is already in use!"
          false
        end
      end

      # Simulates capturing a gamepad button/axis input directly (useful for Lapis/Citrine gamepad bridge & testing).
      def capture_gamepad(button_or_axis : String) : Bool
        binding = Input::Core::InputBinding.parse("pad:#{button_or_axis}", Input::Core::DeviceType::Gamepad)
        apply_captured_binding(binding)
      end

      def clear_selected_slot : Bool
        if act = selected_action
          if @model.clear_slot(act.id, @active_slot)
            @status_message = "Cleared '#{act.label}' [Slot #{@active_slot + 1}]"
            @on_change.try &.call(@model)
            return true
          end
        end
        false
      end

      def reset_selected_action : Bool
        if act = selected_action
          if @model.reset_action(act.id)
            @status_message = "Reset '#{act.label}' to defaults"
            @on_change.try &.call(@model)
            return true
          end
        end
        false
      end

      def reset_all_actions : Bool
        if @model.reset_all!
          @status_message = "Reset all bindings to default profile"
          @on_change.try &.call(@model)
          return true
        end
        false
      end

      def handle_key(key : Terminal::KeyEvent) : Bool
        # 1. Live Capture Mode: next key event becomes the new binding (unless Escape cancels)
        if @capturing
          if key.matches?("escape")
            cancel_capture
            return true
          end
          binding = Input::Core::InputBinding.from_key_event(key)
          apply_captured_binding(binding)
          return true
        end

        # 2. Search / Filter Input Mode
        if @filtering
          case key.name
          when "enter", "return"
            @filtering = false
            return true
          when "escape", "esc"
            @filtering = false
            @query = ""
            @cursor = 0
            return true
          when "backspace"
            if !@query.empty?
              @query = @query[0...-1]
              @cursor = 0
            end
            return true
          when "up"
            move_cursor(-1)
            return true
          when "down"
            move_cursor(1)
            return true
          else
            if ch = key.char
              if ch >= ' ' && !key.ctrl? && !key.alt?
                @query += ch
                @cursor = 0
                return true
              end
            end
          end
          return true
        end

        # 3. Standard Navigation & Remapping Shortcuts
        case key.name
        when "up", "k"
          move_cursor(-1)
          true
        when "down", "j"
          move_cursor(1)
          true
        when "left", "h"
          move_slot(-1)
          true
        when "right", "l"
          move_slot(1)
          true
        when "page_up", "pageup"
          move_cursor(-5)
          true
        when "page_down", "pagedown"
          move_cursor(5)
          true
        when "home"
          @cursor = 0
          true
        when "end"
          vis = visible_actions
          @cursor = Math.max(0, vis.size - 1)
          true
        when "tab"
          if key.shift?
            prev_category
          else
            next_category
          end
          true
        when "backtab"
          prev_category
          true
        when "[", "<"
          prev_category
          true
        when "]", ">"
          next_category
          true
        when "enter", "return", "space"
          start_capture
          true
        when "x", "X", "delete", "backspace"
          clear_selected_slot
          true
        when "r"
          reset_selected_action
          true
        when "R"
          reset_all_actions
          true
        when "-", "_"
          adjust_deadzone(-0.05_f32)
          true
        when "+", "="
          adjust_deadzone(0.05_f32)
          true
        when "g", "G"
          cycle_gamepad_style
          true
        when "/"
          @filtering = true
          true
        when "escape", "esc"
          if !@query.empty?
            @query = ""
            @cursor = 0
            true
          else
            false
          end
        when "ctrl+s", "f10"
          @confirmed = true
          @on_confirm.try &.call(@model)
          true
        else
          if key.matches?("ctrl+s")
            @confirmed = true
            @on_confirm.try &.call(@model)
            true
          elsif key.matches?("shift+r")
            reset_all_actions
            true
          else
            false
          end
        end
      end

      def handle_mouse(event : Terminal::MouseEvent) : Bool
        # In live capture mode, clicking a mouse button binds that mouse button!
        if @capturing
          if event.action.press? && !event.button.none?
            binding = Input::Core::InputBinding.from_mouse_event(event)
            apply_captured_binding(binding)
            return true
          end
          return false
        end

        case event.button
        when Terminal::MouseButton::WheelUp
          move_cursor(-1)
          return true
        when Terminal::MouseButton::WheelDown
          move_cursor(1)
          return true
        end

        if event.action.press? && event.button.left?
          # Check category tab bar clicks
          @cat_tab_boxes.each do |tx1, tx2, cat_val|
            if event.y == @last_y + 1 && event.x >= tx1 && event.x <= tx2
              @selected_category = cat_val
              @cursor = 0
              return true
            end
          end

          # Check action rows
          if event.y >= @list_start_y && event.y < @list_start_y + @list_height
            clicked_idx = @scroll_offset + (event.y - @list_start_y)
            vis = visible_actions
            if clicked_idx >= 0 && clicked_idx < vis.size
              was_selected = (@cursor == clicked_idx)
              @cursor = clicked_idx

              # Check which slot column was clicked
              @slot_col_x.each_with_index do |col_x, slot_i|
                if event.x >= col_x && event.x < col_x + @slot_col_w
                  was_same_slot = (@active_slot == slot_i)
                  @active_slot = slot_i
                  if was_selected && was_same_slot
                    start_capture
                  end
                  return true
                end
              end

              if was_selected
                start_capture
              end
              return true
            end
          end
        end

        false
      end

      def preferred_size(available_w : Int32, available_h : Int32) : {Int32, Int32}
        {Math.min(available_w, @width), Math.min(available_h, @height)}
      end

      def preferred_print_size(available_w : Int32) : {Int32, Int32}
        rows_needed = visible_actions.size + 7
        {Math.min(available_w, @width), Math.max(10, rows_needed)}
      end

      def render(buffer : Buffer) : Nil
        render(buffer, @last_x, @last_y, @width, @height)
      end

      def render(buffer : Buffer, x : Int32, y : Int32, width : Int32, height : Int32) : Nil
        @last_x = x
        @last_y = y
        @last_w = width
        @last_h = height
        return if width < 20 || height < 6

        th = current_theme
        b_fg = @border_color || (@focused ? (@active_border_color || th.primary) : th.border)
        bg_col = th.background

        # Fill clean background
        buffer.fill(x, y, width, height, Cell.new(' ', fg: th.text, bg: bg_col))

        if @show_border
          b_sym = @border_style.is_a?(Symbol) ? @border_style.as(Symbol) : :rounded
          Graphics::Primitives2D.draw_rect(buffer, x, y, width, height, border: b_sym, fg: b_fg)

          # Title & Conflict counter in top border
          conflict_count = @model.conflicts.size
          glyph_tag = @model.gamepad_style.to_s.upcase
          header_str = " #{@title} [#{glyph_tag}] "
          buffer.put_string(x + 2, y, header_str, fg: th.text, bg: bg_col, bold: true, max_width: width - 4)

          if conflict_count > 0
            warn_badge = " ⚠ #{conflict_count} Conflict#{conflict_count > 1 ? "s" : ""} "
            warn_x = x + width - VisualWidth.width(warn_badge) - 2
            if warn_x > x + VisualWidth.width(header_str) + 2
              buffer.put_string(warn_x, y, warn_badge, fg: th.background, bg: th.warning, bold: true)
            end
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

        return if inner_w <= 4 || inner_h <= 3

        cur_y = inner_y

        # 1. Category Tabs & Search Filter Bar
        if @show_categories && inner_h >= 8
          render_category_bar(buffer, inner_x, cur_y, inner_w, th)
          cur_y += 1
        end

        # 2. Table Column Headers
        render_column_headers(buffer, inner_x, cur_y, inner_w, th)
        cur_y += 1
        buffer.put_string(inner_x, cur_y, "─" * inner_w, fg: th.border, bg: bg_col)
        cur_y += 1

        # 3. Action Binding Rows
        footer_rows = inner_h >= 10 ? 2 : 1
        list_h = Math.max(1, (inner_y + inner_h) - cur_y - footer_rows)
        @list_start_y = cur_y
        @list_height = list_h

        render_action_rows(buffer, inner_x, cur_y, inner_w, list_h, th)

        # 4. Bottom Status & Hotkey Guide Bar
        render_footer_bar(buffer, inner_x, inner_y + inner_h - footer_rows, inner_w, footer_rows, th)

        # 5. Live Capture Modal Overlay
        if @capturing
          render_capture_overlay(buffer, inner_x, inner_y, inner_w, inner_h, th)
        end
      end

      private def render_category_bar(buffer : Buffer, x : Int32, y : Int32, w : Int32, th : Theme) : Nil
        @cat_tab_boxes.clear
        cur_x = x + 1

        category_tabs.each do |cat|
          label = cat || "All"
          is_active = (@selected_category == cat)
          pill = " #{label} "
          pill_w = VisualWidth.width(pill)
          break if cur_x + pill_w >= x + w - 18

          if is_active
            buffer.put_string(cur_x, y, pill, fg: th.background, bg: th.primary, bold: true)
          else
            buffer.put_string(cur_x, y, pill, fg: th.text_muted, bg: th.surface)
          end
          @cat_tab_boxes << {cur_x, cur_x + pill_w - 1, cat}
          cur_x += pill_w + 1
        end

        # Search query on right side of category bar
        if @filtering || !@query.empty?
          q_str = " /#{@query}#{@filtering ? "█" : ""} "
          qx = Math.max(cur_x + 1, x + w - VisualWidth.width(q_str) - 1)
          if qx < x + w
            buffer.put_string(qx, y, q_str, fg: th.accent, bg: th.surface, bold: true, max_width: (x + w) - qx)
          end
        end
      end

      private def render_column_headers(buffer : Buffer, x : Int32, y : Int32, w : Int32, th : Theme) : Nil
        dz_w = (@show_deadzone && w >= 58) ? 8 : 0
        avail_for_cols = w - 2 - dz_w
        action_col_w = Math.max(14, (avail_for_cols * 38) // 100)
        slot_total_w = avail_for_cols - action_col_w
        slots_to_show = Math.min(@model.max_slots, 2)
        slot_w = Math.max(10, slot_total_w // slots_to_show)

        @slot_col_w = slot_w
        @slot_col_x.clear
        (0...slots_to_show).each do |s_idx|
          @slot_col_x << (x + 2 + action_col_w + (s_idx * slot_w))
        end

        buffer.put_string(x + 2, y, "ACTION", fg: th.secondary, bg: th.background, bold: true)
        @slot_col_x.each_with_index do |sx, s_idx|
          hdr = s_idx == 0 ? "PRIMARY" : (s_idx == 1 ? "SECONDARY" : "SLOT #{s_idx + 1}")
          buffer.put_string(sx, y, hdr, fg: th.secondary, bg: th.background, bold: true, max_width: slot_w - 1)
        end

        if dz_w > 0
          dz_x = x + w - dz_w - 1
          buffer.put_string(dz_x, y, "DEADZONE", fg: th.secondary, bg: th.background, bold: true, max_width: dz_w)
        end
      end

      private def render_action_rows(buffer : Buffer, x : Int32, y : Int32, w : Int32, h : Int32, th : Theme) : Nil
        vis = visible_actions
        if vis.empty?
          buffer.put_string(x + 2, y, "No matching input actions", fg: th.text_muted, bg: th.background, italic: true)
          return
        end

        @cursor = @cursor.clamp(0, vis.size - 1)
        if @cursor < @scroll_offset
          @scroll_offset = @cursor
        elsif @cursor >= @scroll_offset + h
          @scroll_offset = @cursor - h + 1
        end
        @scroll_offset = @scroll_offset.clamp(0, Math.max(0, vis.size - h))

        dz_w = (@show_deadzone && w >= 58) ? 8 : 0
        action_col_w = (@slot_col_x.first? || (x + 24)) - (x + 2)

        (0...h).each do |line_idx|
          act_idx = @scroll_offset + line_idx
          break if act_idx >= vis.size

          act = vis[act_idx]
          row_y = y + line_idx
          is_selected = (act_idx == @cursor)
          row_bg = is_selected ? th.surface : th.background

          buffer.fill(x, row_y, w, 1, Cell.new(' ', fg: th.text, bg: row_bg))

          # Selection marker
          marker = is_selected ? "▸" : " "
          buffer.put_string(x + 1, row_y, marker, fg: th.primary, bg: row_bg, bold: true)

          # Action label + lock/modified indicator
          lock_suffix = act.locked? ? " [🔒]" : (act.modified? ? " *" : "")
          act_text = VisualWidth.truncate(act.label + lock_suffix, Math.max(4, action_col_w - 2))
          act_fg = act.locked? ? th.text_muted : (is_selected ? th.text : th.text)
          buffer.put_string(x + 3, row_y, act_text, fg: act_fg, bg: row_bg, bold: is_selected)

          # Binding slots
          @slot_col_x.each_with_index do |sx, s_idx|
            is_active_cell = is_selected && (@active_slot == s_idx)
            binding = act.binding_at(s_idx)
            is_conflicted = @model.slot_conflicted?(act.id, s_idx)

            badge_label = if is_active_cell && @capturing
                            "Press Key..."
                          elsif binding && !binding.empty?
                            binding.display_label(@model.gamepad_style)
                          else
                            "---"
                          end

            prefix = is_conflicted ? "⚠ " : ""
            cap_text = "[ #{prefix}#{badge_label} ]"
            cap_trunc = VisualWidth.truncate(cap_text, Math.max(6, @slot_col_w - 1))

            if is_active_cell
              cap_fg = th.background
              cap_bg = is_conflicted ? th.warning : th.primary
              buffer.put_string(sx, row_y, cap_trunc, fg: cap_fg, bg: cap_bg, bold: true)
            elsif is_conflicted
              buffer.put_string(sx, row_y, cap_trunc, fg: th.warning, bg: row_bg, bold: true)
            elsif binding && !binding.empty?
              buffer.put_string(sx, row_y, cap_trunc, fg: th.accent, bg: row_bg)
            else
              buffer.put_string(sx, row_y, cap_trunc, fg: th.text_muted, bg: row_bg)
            end
          end

          # Deadzone column
          if dz_w > 0
            dz_x = x + w - dz_w - 1
            dz_str = sprintf("%3d%%", (act.deadzone * 100).round.to_i)
            buffer.put_string(dz_x, row_y, dz_str, fg: is_selected ? th.info : th.text_muted, bg: row_bg)
          end
        end
      end

      private def render_footer_bar(buffer : Buffer, x : Int32, y : Int32, w : Int32, rows : Int32, th : Theme) : Nil
        if rows >= 2
          msg = if m = @status_message
                  m
                elsif (act = selected_action) && !@model.conflicts_for(act.id).empty?
                  c = @model.conflicts_for(act.id).first
                  other = c.other_action(act.id)
                  "⚠ Conflict: #{c.binding.display_label(@model.gamepad_style)} is also bound to '#{other}'"
                else
                  "Profile: #{@model.profile_name} (#{@model.size} actions)"
                end
          msg_fg = msg.starts_with?("⚠") ? th.warning : th.success
          buffer.put_string(x + 1, y, VisualWidth.truncate(msg, w - 2), fg: msg_fg, bg: th.background, bold: true)
          guide_y = y + 1
        else
          guide_y = y
        end

        guide = "[Enter] Rebind  [x] Clear  [r/R] Reset  [Tab] Cat  [-/+] Deadzone  [g] Pad  [/] Filter"
        buffer.put_string(x + 1, guide_y, VisualWidth.truncate(guide, w - 2), fg: th.text_muted, bg: th.background)
      end

      private def render_capture_overlay(buffer : Buffer, x : Int32, y : Int32, w : Int32, h : Int32, th : Theme) : Nil
        box_w = Math.min(w - 4, 46)
        box_h = Math.min(h - 2, 7)
        return if box_w < 20 || box_h < 5

        bx = x + (w - box_w) // 2
        by = y + (h - box_h) // 2

        buffer.fill(bx, by, box_w, box_h, Cell.new(' ', fg: th.text, bg: th.surface))
        Graphics::Primitives2D.draw_rect(buffer, bx, by, box_w, box_h, border: :double, fg: th.accent)

        act_name = selected_action.try(&.label) || "Action"
        slot_name = @active_slot == 0 ? "Primary" : "Secondary"

        title_str = " ⌨ LISTENING FOR INPUT "
        buffer.put_string(bx + (box_w - VisualWidth.width(title_str)) // 2, by, title_str, fg: th.background, bg: th.accent, bold: true)

        line1 = "Rebinding: #{act_name} (#{slot_name})"
        line2 = "Press any Key or Mouse button..."
        line3 = "[Esc] Cancel"

        buffer.put_string(bx + 2, by + 2, VisualWidth.truncate(line1, box_w - 4), fg: th.text, bg: th.surface, bold: true)
        buffer.put_string(bx + 2, by + 3, VisualWidth.truncate(line2, box_w - 4), fg: th.primary, bg: th.surface)
        if box_h >= 6
          buffer.put_string(bx + 2, by + 4, VisualWidth.truncate(line3, box_w - 4), fg: th.text_muted, bg: th.surface)
        end
      end
    end
  end

  # High-level interactive input remapper runner for CLI or modal invocation.
  def self.remap_inputs(
    remapper : UI::InputRemapper,
    driver : Terminal::Driver? = nil,
    output : IO? = nil,
  ) : Input::Core::InputRemapModel?
    drv = driver || (output ? Terminal.default_driver(output: output) : Terminal.default_driver)

    render_frame = -> {
      w, h = drv.size
      buf = UI::Buffer.new(w, h)
      remapper.render(buf, 0, 0, w, h)
      drv.write(Terminal::Screen::CLEAR_ALL)
      drv.write(Terminal::Screen.move_to(1, 1))
      drv.write(buf.to_s)
      drv.flush
    }

    result : Input::Core::InputRemapModel? = nil

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
          if !remapper.capturing? && !remapper.filtering? && (event.matches?("escape") || event.matches?("ctrl+c") || event.matches?("q"))
            break
          end

          if remapper.handle_key(event)
            should_redraw = true
            if remapper.confirmed?
              result = remapper.model
              break
            end
          end
        when Terminal::MouseEvent
          if remapper.handle_mouse(event)
            should_redraw = true
            if remapper.confirmed?
              result = remapper.model
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

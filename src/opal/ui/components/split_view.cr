require "../element"
require "../control"
require "../buffer"
require "../rect"
require "../../style/color"
require "../../style/border"
require "../../style/style"
require "../../core/split_layout"

module Opal
  module UI
    enum SplitDirection
      Horizontal
      Vertical

      def self.from(val : SplitDirection | Core::SplitOrientation | Symbol | String) : SplitDirection
        return val if val.is_a?(SplitDirection)
        if val.is_a?(Core::SplitOrientation)
          return val.vertical? ? Vertical : Horizontal
        end
        case val.to_s.downcase.strip
        when "vertical", "vert", "v", "col", "column", "top_bottom", "stacked"
          Vertical
        else
          Horizontal
        end
      end

      def to_orientation : Core::SplitOrientation
        vertical? ? Core::SplitOrientation::Vertical : Core::SplitOrientation::Horizontal
      end
    end

    # Multi-pane split view container backed by the Tier-1 `Opal::Core::SplitLayout` constraint solver.
    # Supports horizontal (side-by-side) and vertical (stacked) layouts, proportional flex ratios,
    # fixed/min/max bounds, interactive divider drag/step resizing, keyboard navigation shortcuts,
    # high-contrast Lipgloss border focus indicators, and screen-reader-friendly status line announcements.
    class SplitView < Control
      getter layout : Core::SplitLayout
      getter panes : Array(Element?)
      property separator : Char
      property separator_fg : Color
      property focus_border : Border?
      property unfocused_border : Border?
      property focus_border_fg : Color?
      property unfocused_border_fg : Color?
      property focus_title_fg : Color?
      property unfocused_title_fg : Color?
      property focus_style : Style?
      property unfocused_style : Style?
      property focus_title_prefix : String?
      property? highlight_focus : Bool
      property? high_contrast_focus : Bool
      property? show_status_line : Bool
      property? status_line_shortcuts : Bool
      property status_line_fg : Color?
      property status_line_bg : Color?
      property on_announce : Proc(String, Nil)?
      property on_focus_change : Proc(Int32, String, Nil)?
      property on_resize : Proc(Array(Float64), Nil)?

      @solved_geometries : Array(Core::PaneGeometry)
      @last_rect : Rect

      def initialize(
        first : Element? = nil,
        second : Element? = nil,
        direction : SplitDirection | Core::SplitOrientation | Symbol | String = SplitDirection::Horizontal,
        ratio : Float64? = 0.5,
        first_size : Int32? = nil,
        second_size : Int32? = nil,
        min_first_size : Int32? = nil,
        max_first_size : Int32? = nil,
        min_second_size : Int32? = nil,
        max_second_size : Int32? = nil,
        separator : Char? = nil,
        separator_fg : Color | Symbol | String = Color.none,
        focused_pane : Symbol | Int32 | String = :first,
        show_separator : Bool = true,
        resize_step : Float64 = 0.05,
        focus_border : Symbol | Border | String | Nil = nil,
        unfocused_border : Symbol | Border | String | Nil = nil,
        focus_border_fg : Color | Symbol | String | Nil = nil,
        unfocused_border_fg : Color | Symbol | String | Nil = nil,
        focus_title_fg : Color | Symbol | String | Nil = nil,
        unfocused_title_fg : Color | Symbol | String | Nil = nil,
        @focus_style : Style? = nil,
        @unfocused_style : Style? = nil,
        @focus_title_prefix : String? = nil,
        @highlight_focus : Bool = true,
        @high_contrast_focus : Bool = false,
        @show_status_line : Bool = false,
        @status_line_shortcuts : Bool = true,
        status_line_fg : Color | Symbol | String | Nil = nil,
        status_line_bg : Color | Symbol | String | Nil = nil,
        @on_announce : Proc(String, Nil)? = nil,
        @on_focus_change : Proc(Int32, String, Nil)? = nil,
        @on_resize : Proc(Array(Float64), Nil)? = nil,
        keymap : Core::SplitKeymap? = nil,
        panes : Array(Element?)? = nil,
        constraints : Array(Core::PaneConstraint)? = nil,
      )
        super()
        dir = SplitDirection.from(direction)
        @layout = Core::SplitLayout.new(
          orientation: dir.to_orientation,
          ratio: ratio,
          first_size: first_size,
          second_size: second_size,
          min_first_size: min_first_size,
          max_first_size: max_first_size,
          min_second_size: min_second_size,
          max_second_size: max_second_size,
          focused_pane: focused_pane,
          show_separator: show_separator,
          resize_step: resize_step,
          panes: constraints,
          keymap: keymap
        )

        if custom_panes = panes
          @panes = custom_panes.dup
          while @layout.pane_count < @panes.size
            @layout.add_pane
          end
        else
          @panes = [first, second] of Element?
        end

        sync_pane_titles_from_elements

        @separator = separator || (dir == SplitDirection::Horizontal ? '│' : '─')
        @separator_fg = Color.from(separator_fg)
        @focus_border = focus_border ? Border.from(focus_border) : nil
        @unfocused_border = unfocused_border ? Border.from(unfocused_border) : nil
        @focus_border_fg = focus_border_fg ? Color.from(focus_border_fg) : nil
        @unfocused_border_fg = unfocused_border_fg ? Color.from(unfocused_border_fg) : nil
        @focus_title_fg = focus_title_fg ? Color.from(focus_title_fg) : nil
        @unfocused_title_fg = unfocused_title_fg ? Color.from(unfocused_title_fg) : nil
        @status_line_fg = status_line_fg ? Color.from(status_line_fg) : nil
        @status_line_bg = status_line_bg ? Color.from(status_line_bg) : nil
        @solved_geometries = Array(Core::PaneGeometry).new(@panes.size)
        @last_rect = Rect.new(0, 0, 80, 24)
        sync_child_focus
        @layout.announce_status
      end

      def self.horizontal(
        first : Element? = nil,
        second : Element? = nil,
        ratio : Float64? = 0.5,
        first_width : Int32? = nil,
        second_width : Int32? = nil,
        min_first_width : Int32? = nil,
        max_first_width : Int32? = nil,
        min_second_width : Int32? = nil,
        max_second_width : Int32? = nil,
        separator : Char? = nil,
        separator_fg : Color | Symbol | String = Color.none,
        focused_pane : Symbol | Int32 | String = :first,
        show_separator : Bool = true,
      ) : SplitView
        new(
          first: first,
          second: second,
          direction: SplitDirection::Horizontal,
          ratio: ratio,
          first_size: first_width,
          second_size: second_width,
          min_first_size: min_first_width,
          max_first_size: max_first_width,
          min_second_size: min_second_width,
          max_second_size: max_second_width,
          separator: separator,
          separator_fg: separator_fg,
          focused_pane: focused_pane,
          show_separator: show_separator
        )
      end

      def self.vertical(
        first : Element? = nil,
        second : Element? = nil,
        ratio : Float64? = 0.5,
        first_height : Int32? = nil,
        second_height : Int32? = nil,
        min_first_height : Int32? = nil,
        max_first_height : Int32? = nil,
        min_second_height : Int32? = nil,
        max_second_height : Int32? = nil,
        separator : Char? = nil,
        separator_fg : Color | Symbol | String = Color.none,
        focused_pane : Symbol | Int32 | String = :first,
        show_separator : Bool = true,
      ) : SplitView
        new(
          first: first,
          second: second,
          direction: SplitDirection::Vertical,
          ratio: ratio,
          first_size: first_height,
          second_size: second_height,
          min_first_size: min_first_height,
          max_first_size: max_first_height,
          min_second_size: min_second_height,
          max_second_size: max_second_height,
          separator: separator,
          separator_fg: separator_fg,
          focused_pane: focused_pane,
          show_separator: show_separator
        )
      end

      def children : Array(Element)
        res = [] of Element
        @panes.each do |p|
          res << p if p
        end
        res
      end

      def direction : SplitDirection
        @layout.orientation.vertical? ? SplitDirection::Vertical : SplitDirection::Horizontal
      end

      def direction=(val : SplitDirection | Core::SplitOrientation | Symbol | String) : SplitDirection
        dir = SplitDirection.from(val)
        old_dir = direction
        @layout.orientation = dir.to_orientation
        if old_dir != dir
          if @separator == '│' && dir.vertical?
            @separator = '─'
          elsif @separator == '─' && dir.horizontal?
            @separator = '│'
          end
        end
        dir
      end

      def first : Element?
        @panes[0]?
      end

      def first=(el : Element?) : Element?
        while @panes.size < 1
          @panes << nil
        end
        @panes[0] = el
        sync_child_focus
        el
      end

      def second : Element?
        @panes[1]?
      end

      def second=(el : Element?) : Element?
        while @panes.size < 2
          @panes << nil
        end
        @panes[1] = el
        sync_child_focus
        el
      end

      def ratio : Float64?
        @layout.ratio
      end

      def ratio=(val : Float64?) : Float64?
        @layout.ratio = val
      end

      def ratios : Array(Float64)
        @layout.ratios
      end

      def set_ratios(weights : Enumerable(Float64)) : self
        @layout.set_ratios(weights)
        self
      end

      def reset_ratios! : self
        @layout.reset_ratios!
        self
      end

      def first_size : Int32?
        @layout.first_size
      end

      def first_size=(val : Int32?) : Int32?
        @layout.first_size = val
      end

      def second_size : Int32?
        @layout.second_size
      end

      def second_size=(val : Int32?) : Int32?
        @layout.second_size = val
      end

      def min_first_size : Int32?
        @layout.min_first_size
      end

      def min_first_size=(val : Int32?) : Int32?
        @layout.min_first_size = val
      end

      def max_first_size : Int32?
        @layout.max_first_size
      end

      def max_first_size=(val : Int32?) : Int32?
        @layout.max_first_size = val
      end

      def min_second_size : Int32?
        @layout.min_second_size
      end

      def min_second_size=(val : Int32?) : Int32?
        @layout.min_second_size = val
      end

      def max_second_size : Int32?
        @layout.max_second_size
      end

      def max_second_size=(val : Int32?) : Int32?
        @layout.max_second_size = val
      end

      def show_separator : Bool
        @layout.show_separator?
      end

      def show_separator? : Bool
        @layout.show_separator?
      end

      def show_separator=(val : Bool) : Bool
        @layout.show_separator = val
      end

      # Appends a pane element and its constraint to the SplitView.
      def add_pane(
        element : Element?,
        id : String? = nil,
        flex : Float64 = 1.0,
        fixed_size : Int32? = nil,
        min_size : Int32 = 0,
        max_size : Int32? = nil,
        focusable : Bool = true,
        collapsed : Bool = false,
        title : String? = nil,
      ) : self
        resolved_title = title || (element.is_a?(Box) ? element.title : nil)
        @panes << element
        @layout.add_pane(
          id: id,
          flex: flex,
          fixed_size: fixed_size,
          min_size: min_size,
          max_size: max_size,
          focusable: focusable,
          collapsed: collapsed,
          title: resolved_title
        )
        sync_child_focus
        self
      end

      # Replaces the panes and their constraints.
      def set_panes(elements : Array(Element?), constraints : Array(Core::PaneConstraint)) : self
        @panes = elements.dup
        @layout.set_panes(constraints)
        sync_pane_titles_from_elements
        sync_child_focus
        self
      end

      # --- Focus Ring Navigation Delegation ---

      def focused_index : Int32
        @layout.focused_index
      end

      def focused_id : String
        @layout.focused_id
      end

      def focused_title : String
        @layout.focused_title
      end

      def focused_pane : Symbol
        @layout.focused_pane
      end

      def focused_pane=(pane : Symbol | Int32 | String) : Symbol
        @layout.focused_pane = pane
        sync_child_focus
        notify_focus_and_announcement
        @layout.focused_pane
      end

      def focus_ring : Array(Int32)
        @layout.focus_ring
      end

      def focus_next : Int32
        idx = @layout.focus_next
        sync_child_focus
        notify_focus_and_announcement
        idx
      end

      def focus_prev : Int32
        idx = @layout.focus_prev
        sync_child_focus
        notify_focus_and_announcement
        idx
      end

      def focus_directional(direction : Symbol | String) : Int32
        idx = @layout.focus_directional(direction)
        sync_child_focus
        notify_focus_and_announcement
        idx
      end

      # Toggles/cycles active focus in the focus ring and returns the focused pane symbol.
      def toggle_focus : Symbol
        sym = @layout.toggle_focus
        sync_child_focus
        notify_focus_and_announcement
        sym
      end

      def focus_at(index : Int32) : Bool
        ok = @layout.focus_at(index)
        if ok
          sync_child_focus
          notify_focus_and_announcement
        end
        ok
      end

      def focus_by_id(id : String | Symbol) : Bool
        ok = @layout.focus_by_id(id)
        if ok
          sync_child_focus
          notify_focus_and_announcement
        end
        ok
      end

      def focus_first : Int32
        idx = @layout.focus_first
        sync_child_focus
        notify_focus_and_announcement
        idx
      end

      def focus_second : Int32
        idx = @layout.focus_second
        sync_child_focus
        notify_focus_and_announcement
        idx
      end

      def focus_last : Int32
        idx = @layout.focus_last
        sync_child_focus
        notify_focus_and_announcement
        idx
      end

      def focused_element : Element?
        @panes[@layout.focused_index]?
      end

      # --- Resizing, Zoom, Orientation & Constraint Solving Delegation ---

      # Adjusts split ratio by `delta`, clamped within `[min_ratio, max_ratio]`.
      def adjust_ratio(
        delta : Float64,
        min_ratio : Float64 = 0.1,
        max_ratio : Float64 = 0.9,
        divider_index : Int32 = 0,
      ) : Float64
        res = @layout.adjust_ratio(delta, divider_index: divider_index, min_ratio: min_ratio, max_ratio: max_ratio)
        notify_resize_and_announcement
        res
      end

      def step_grow(step : Float64 = @layout.resize_step) : Float64
        res = @layout.step_grow(step, @layout.focused_index)
        notify_resize_and_announcement
        res
      end

      def step_shrink(step : Float64 = @layout.resize_step) : Float64
        res = @layout.step_shrink(step, @layout.focused_index)
        notify_resize_and_announcement
        res
      end

      def equalize_ratios! : self
        @layout.equalize_ratios!
        notify_resize_and_announcement
        self
      end

      def toggle_orientation! : SplitDirection
        old_dir = direction
        @layout.toggle_orientation!
        new_dir = direction
        if old_dir != new_dir
          if @separator == '│' && new_dir.vertical?
            @separator = '─'
          elsif @separator == '─' && new_dir.horizontal?
            @separator = '│'
          end
        end
        @on_announce.try &.call(@layout.status_announcement)
        new_dir
      end

      def toggle_zoom! : Bool
        res = @layout.toggle_zoom!
        sync_child_focus
        @on_announce.try &.call(@layout.status_announcement)
        res
      end

      def zoomed? : Bool
        @layout.zoomed?
      end

      def set_collapsed(index : Int32, collapsed : Bool = true) : Bool
        ok = @layout.set_collapsed(index, collapsed)
        if ok
          sync_child_focus
          @on_announce.try &.call(@layout.status_announcement)
        end
        ok
      end

      def toggle_collapsed(index : Int32) : Bool
        ok = @layout.toggle_collapsed(index)
        if ok
          sync_child_focus
          @on_announce.try &.call(@layout.status_announcement)
        end
        ok
      end

      def solve_layout(x : Int32, y : Int32, width : Int32, height : Int32) : Array(Core::PaneGeometry)
        @layout.solve(x, y, width, height)
      end

      def solve_extents(available_extent : Int32) : Array(Int32)
        @layout.solve_extents(available_extent)
      end

      # --- Keyboard Shortcuts, High-Contrast Lipgloss Focus & Screen-Reader Status ---

      def keymap : Core::SplitKeymap
        @layout.keymap
      end

      def keymap=(km : Core::SplitKeymap) : Core::SplitKeymap
        @layout.keymap = km
      end

      def bind_key(key_spec : String, action : Core::SplitAction | Symbol | String) : self
        @layout.keymap.bind(key_spec, action)
        self
      end

      def unbind_key(key_spec : String) : self
        @layout.keymap.unbind(key_spec)
        self
      end

      def shortcut_hints : Array(NamedTuple(key: String, description: String))
        @layout.keymap.shortcut_hints
      end

      # Enables WCAG AAA high-contrast Lipgloss focus borders, title emphasis, and optional focus badge.
      def enable_high_contrast_focus!(
        focus_border : Symbol | Border | String = :thick,
        unfocused_border : Symbol | Border | String = :rounded,
        focus_fg : Color | Symbol | String | Nil = nil,
        unfocused_fg : Color | Symbol | String | Nil = nil,
        title_prefix : String? = nil,
      ) : self
        @highlight_focus = true
        @high_contrast_focus = true
        @focus_border = Border.from(focus_border)
        @unfocused_border = Border.from(unfocused_border)
        @focus_border_fg = Color.from(focus_fg) if focus_fg
        @unfocused_border_fg = Color.from(unfocused_fg) if unfocused_fg
        @focus_title_prefix = title_prefix if title_prefix
        self
      end

      # Resolves the active Lipgloss `Border` style for the focused pane.
      def effective_focus_border(fallback : Border? = nil) : Border
        if (st = @focus_style) && st.border.active?
          st.border
        elsif fb = @focus_border
          fb
        else
          Border.thick
        end
      end

      # Resolves the Lipgloss `Border` style for unfocused panes.
      def effective_unfocused_border(fallback : Border? = nil) : Border
        if (st = @unfocused_style) && st.border.active?
          st.border
        elsif ub = @unfocused_border
          ub
        elsif fb = fallback
          fb
        else
          Border.rounded
        end
      end

      # Resolves the WCAG contrast-verified foreground color for the focused pane's border.
      def effective_focus_border_fg : Color
        bg = current_theme.background
        min_ratio = @high_contrast_focus ? 7.0 : 4.5
        if (st = @focus_style) && st.border_foreground != Color.none
          return st.border_foreground.ensure_contrast(bg, min_ratio)
        end
        if ffg = @focus_border_fg
          return @high_contrast_focus ? ffg.ensure_contrast(bg, min_ratio) : ffg
        end
        base = @high_contrast_focus ? Color.hex("#00FFFF") : current_theme.accent
        base.ensure_contrast(bg, min_ratio)
      end

      # Resolves the foreground color for unfocused pane borders.
      def effective_unfocused_border_fg(fallback : Color? = nil) : Color
        if (st = @unfocused_style) && st.border_foreground != Color.none
          return st.border_foreground
        end
        if ufg = @unfocused_border_fg
          return ufg
        end
        if fb = fallback
          return fb if fb != Color.none
        end
        current_theme.border
      end

      # Resolves the WCAG contrast-verified foreground color for the focused pane's title.
      def effective_focus_title_fg : Color
        bg = current_theme.background
        min_ratio = @high_contrast_focus ? 7.0 : 4.5
        if (st = @focus_style) && st.foreground != Color.none
          return st.foreground.ensure_contrast(bg, min_ratio)
        end
        if tfg = @focus_title_fg
          return @high_contrast_focus ? tfg.ensure_contrast(bg, min_ratio) : tfg
        end
        base = @high_contrast_focus ? Color.hex("#FFFF00") : current_theme.primary
        base.ensure_contrast(bg, min_ratio)
      end

      # Resolves the foreground color for unfocused pane titles.
      def effective_unfocused_title_fg(fallback : Color? = nil) : Color
        if (st = @unfocused_style) && st.foreground != Color.none
          return st.foreground
        end
        if utfg = @unfocused_title_fg
          return utfg
        end
        current_theme.text_muted
      end

      # Returns the WCAG 2.1 contrast ratio of the focused border against the current theme background.
      def focus_contrast_ratio : Float64
        effective_focus_border_fg.contrast_ratio(current_theme.background).round(2)
      end

      # Returns the latest screen-reader-friendly status announcement.
      def status_announcement : String
        @layout.status_announcement
      end

      # Returns the most recently recorded announcement string.
      def last_announcement : String
        @layout.last_announcement
      end

      # Returns chronological history of screen-reader announcements.
      def announcement_history : Array(String)
        @layout.announcement_history
      end

      # Refreshes and emits a screen-reader status announcement for the currently focused pane.
      def announce_status : String
        msg = @layout.announce_status
        @on_announce.try &.call(msg)
        msg
      end

      # Formats the single-line screen-reader-friendly status bar string.
      def status_line(include_shortcuts : Bool = @status_line_shortcuts) : String
        @layout.format_status_line(include_shortcuts: include_shortcuts)
      end

      # --- Interactive Keyboard & Mouse Handling ---

      def handle_key(key : Terminal::KeyEvent) : Bool
        prev_focus = @layout.focused_index
        prev_orient = @layout.orientation

        if action = @layout.handle_key_action(
             name: key.name,
             char: key.char,
             ctrl: key.ctrl?,
             alt: key.alt?,
             shift: key.shift?
           )
          sync_child_focus
          if prev_orient != @layout.orientation
            if @separator == '│' && direction.vertical?
              @separator = '─'
            elsif @separator == '─' && direction.horizontal?
              @separator = '│'
            end
          end
          if prev_focus != @layout.focused_index
            @on_focus_change.try &.call(@layout.focused_index, @layout.focused_id)
          end
          if action.step_grow? || action.step_shrink? || action.reset_ratios? || action.equalize_ratios?
            @on_resize.try &.call(@layout.ratios)
          end
          @on_announce.try &.call(@layout.status_announcement)
          return true
        end

        # Forward to focused pane if it is an interactive Control
        if active = focused_element
          if active.is_a?(Control)
            return true if active.handle_input(key)
          elsif active.is_a?(Box) && (inner = active.child) && inner.is_a?(Control)
            return true if inner.handle_input(key)
          end
        end

        false
      end

      def handle_mouse(event : Terminal::MouseEvent) : Bool
        rx = @last_rect.x
        ry = @last_rect.y
        rw = @last_rect.width
        rh = (@show_status_line && @last_rect.height >= 2) ? (@last_rect.height - 1) : @last_rect.height

        coord = direction.horizontal? ? event.x : event.y
        origin = direction.horizontal? ? rx : ry
        total_ext = direction.horizontal? ? rw : rh

        case event.action
        when Terminal::MouseAction::Release
          if @layout.dragging?
            @layout.end_drag
            return true
          end
        when Terminal::MouseAction::Motion
          if @layout.dragging?
            if @layout.drag_to(coord, origin, total_ext)
              notify_resize_and_announcement
              return true
            end
          end
        when Terminal::MouseAction::Press
          if event.button.left?
            if div_idx = @layout.hit_test_divider(coord, rx, ry, rw, rh)
              return @layout.begin_drag(div_idx)
            end
            if pane_idx = @layout.hit_test_pane(event.x, event.y, rx, ry, rw, rh)
              focus_at(pane_idx)
              if el = @panes[pane_idx]?
                if el.is_a?(Control)
                  el.handle_input(event)
                elsif el.is_a?(Box) && (inner = el.child) && inner.is_a?(Control)
                  inner.handle_input(event)
                end
              end
              return true
            end
          end
        end

        if active = focused_element
          if active.is_a?(Control)
            return active.handle_input(event)
          elsif active.is_a?(Box) && (inner = active.child) && inner.is_a?(Control)
            return inner.handle_input(event)
          end
        end

        false
      end

      # --- Sizing & Rendering ---

      def preferred_size(available_w : Int32, available_h : Int32) : {Int32, Int32}
        return {0, 0} if @panes.empty?
        status_h = @show_status_line ? 1 : 0
        pane_avail_h = Math.max(0, available_h - status_h)

        if direction.horizontal?
          extents = @layout.solve_extents(available_w)
          active_count = @layout.panes.count { |p| !p.collapsed? }
          sep_w = (@layout.show_separator? && active_count > 1) ? (active_count - 1) * @layout.separator_size : 0

          needed_w = 0
          max_h = 0
          ratios_arr = @layout.ratios
          all_flexible = @layout.panes.all? { |p| p.fixed_size.nil? }

          @panes.each_with_index do |el, idx|
            next if @layout.panes[idx]?.try(&.collapsed?)
            pw = extents[idx]? || 0
            sw, sh = el.try(&.preferred_size(pw, pane_avail_h)) || {0, 0}
            needed_w += sw
            max_h = Math.max(max_h, sh)
          end

          if all_flexible && @panes.size == 2
            r = ratios_arr[0]?.try(&.clamp(0.05, 0.95)) || 0.5
            s1_w = @panes[0].try(&.preferred_size(extents[0]? || 0, pane_avail_h)).try(&.[0]) || 0
            s2_w = @panes[1].try(&.preferred_size(extents[1]? || 0, pane_avail_h)).try(&.[0]) || 0
            by_first = (s1_w / r).ceil.to_i
            by_second = (s2_w / (1.0 - r)).ceil.to_i
            needed_w = Math.max(needed_w, Math.max(by_first, by_second))
          end

          {Math.min(available_w, needed_w + sep_w), Math.min(available_h, max_h + status_h)}
        else
          extents = @layout.solve_extents(pane_avail_h)
          active_count = @layout.panes.count { |p| !p.collapsed? }
          sep_h = (@layout.show_separator? && active_count > 1) ? (active_count - 1) * @layout.separator_size : 0

          max_w = 0
          needed_h = 0
          ratios_arr = @layout.ratios
          all_flexible = @layout.panes.all? { |p| p.fixed_size.nil? }

          @panes.each_with_index do |el, idx|
            next if @layout.panes[idx]?.try(&.collapsed?)
            ph = extents[idx]? || 0
            sw, sh = el.try(&.preferred_size(available_w, ph)) || {0, 0}
            max_w = Math.max(max_w, sw)
            needed_h += sh
          end

          if all_flexible && @panes.size == 2
            r = ratios_arr[0]?.try(&.clamp(0.05, 0.95)) || 0.5
            s1_h = @panes[0].try(&.preferred_size(available_w, extents[0]? || 0)).try(&.[1]) || 0
            s2_h = @panes[1].try(&.preferred_size(available_w, extents[1]? || 0)).try(&.[1]) || 0
            by_first = (s1_h / r).ceil.to_i
            by_second = (s2_h / (1.0 - r)).ceil.to_i
            needed_h = Math.max(needed_h, Math.max(by_first, by_second))
          end

          {max_w, Math.min(available_h, needed_h + sep_h + status_h)}
        end
      end

      def render(buffer : Buffer, x : Int32, y : Int32, width : Int32, height : Int32) : Nil
        return if width <= 0 || height <= 0
        @last_rect = Rect.new(x, y, width, height)

        has_status_bar = @show_status_line && height >= 2
        pane_height = has_status_bar ? (height - 1) : height

        @layout.solve_into(@solved_geometries, x, y, width, pane_height)

        @solved_geometries.each do |geom|
          pane_el = @panes[geom.index]?
          if pane_el && geom.width > 0 && geom.height > 0
            if @highlight_focus && pane_el.is_a?(Box)
              render_box_with_focus_indicator(buffer, pane_el, geom)
            else
              buffer.with_clip(geom.x, geom.y, geom.width, geom.height) do
                pane_el.render(buffer, geom.x, geom.y, geom.width, geom.height)
              end
            end
          end

          if dx = geom.divider_x
            sep_fg = @separator_fg != Color.none ? @separator_fg : (@high_contrast_focus ? effective_focus_border_fg : current_theme.border)
            (0...pane_height).each do |sy|
              buffer.put_char(dx, y + sy, @separator, fg: sep_fg)
            end
          elsif dy = geom.divider_y
            sep_fg = @separator_fg != Color.none ? @separator_fg : (@high_contrast_focus ? effective_focus_border_fg : current_theme.border)
            (0...width).each do |sx|
              buffer.put_char(x + sx, dy, @separator, fg: sep_fg)
            end
          end
        end

        if has_status_bar
          render_status_line(buffer, x, y + height - 1, width)
        end
      end

      private def render_box_with_focus_indicator(buffer : Buffer, box : Box, geom : Core::PaneGeometry) : Nil
        orig_border = box.border
        orig_border_fg = box.border_fg
        orig_title_fg = box.title_fg
        orig_title = box.title

        begin
          if geom.focused?
            box.border = effective_focus_border(orig_border)
            box.border_fg = effective_focus_border_fg
            box.title_fg = effective_focus_title_fg
            if (prefix = @focus_title_prefix) && (t = orig_title)
              box.title = "#{prefix}#{t}"
            end
          else
            box.border = effective_unfocused_border(orig_border)
            box.border_fg = effective_unfocused_border_fg(orig_border_fg)
            box.title_fg = effective_unfocused_title_fg(orig_title_fg)
          end

          buffer.with_clip(geom.x, geom.y, geom.width, geom.height) do
            box.render(buffer, geom.x, geom.y, geom.width, geom.height)
          end
        ensure
          box.border = orig_border
          box.border_fg = orig_border_fg
          box.title_fg = orig_title_fg
          box.title = orig_title
        end
      end

      private def render_status_line(buffer : Buffer, x : Int32, y : Int32, width : Int32) : Nil
        return if width <= 0
        th = current_theme
        bg = @status_line_bg || th.surface
        min_ratio = @high_contrast_focus ? 7.0 : 4.5
        fg = (@status_line_fg || th.text).ensure_contrast(bg, min_ratio)

        buffer.fill(x, y, width, 1, ' ', fg, bg)
        text = " #{status_line} "
        buffer.put_string(x, y, text, fg: fg, bg: bg, bold: @high_contrast_focus, max_width: width)
      end

      private def sync_pane_titles_from_elements : Nil
        @panes.each_with_index do |el, idx|
          if el.is_a?(Box) && (box_title = el.title)
            if idx < @layout.pane_count && @layout.panes[idx].title.nil?
              @layout.update_pane(idx) do |c|
                cp = c
                cp.title = box_title
                cp
              end
            end
          end
        end
      end

      private def notify_focus_and_announcement : Nil
        @on_focus_change.try &.call(@layout.focused_index, @layout.focused_id)
        @on_announce.try &.call(@layout.status_announcement)
      end

      private def notify_resize_and_announcement : Nil
        @on_resize.try &.call(@layout.ratios)
        @on_announce.try &.call(@layout.status_announcement)
      end

      private def sync_child_focus : Nil
        f_idx = @layout.focused_index
        @panes.each_with_index do |el, idx|
          is_foc = (idx == f_idx)
          if el.is_a?(Control)
            el.focused = is_foc
          elsif el.is_a?(Box) && (inner = el.child) && inner.is_a?(Control)
            inner.focused = is_foc
          end
        end
      end
    end

    alias SplitPane = SplitView
  end
end

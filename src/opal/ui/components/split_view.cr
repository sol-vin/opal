require "../element"
require "../control"
require "../buffer"
require "../rect"
require "../../style/color"
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
    # fixed/min/max bounds, interactive divider drag/step resizing, and focus ring navigation.
    class SplitView < Control
      getter layout : Core::SplitLayout
      getter panes : Array(Element?)
      property separator : Char
      property separator_fg : Color
      property focus_border_fg : Color?
      property unfocused_border_fg : Color?
      property? highlight_focus : Bool

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
        focus_border_fg : Color | Symbol | String | Nil = nil,
        unfocused_border_fg : Color | Symbol | String | Nil = nil,
        @highlight_focus : Bool = false,
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
          panes: constraints
        )

        if custom_panes = panes
          @panes = custom_panes.dup
          while @layout.pane_count < @panes.size
            @layout.add_pane
          end
        else
          @panes = [first, second] of Element?
        end

        @separator = separator || (dir == SplitDirection::Horizontal ? '│' : '─')
        @separator_fg = Color.from(separator_fg)
        @focus_border_fg = focus_border_fg ? Color.from(focus_border_fg) : nil
        @unfocused_border_fg = unfocused_border_fg ? Color.from(unfocused_border_fg) : nil
        @solved_geometries = Array(Core::PaneGeometry).new(@panes.size)
        @last_rect = Rect.new(0, 0, 80, 24)
        sync_child_focus
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
        @panes << element
        @layout.add_pane(
          id: id,
          flex: flex,
          fixed_size: fixed_size,
          min_size: min_size,
          max_size: max_size,
          focusable: focusable,
          collapsed: collapsed,
          title: title
        )
        sync_child_focus
        self
      end

      # Replaces the panes and their constraints.
      def set_panes(elements : Array(Element?), constraints : Array(Core::PaneConstraint)) : self
        @panes = elements.dup
        @layout.set_panes(constraints)
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

      def focused_pane : Symbol
        @layout.focused_pane
      end

      def focused_pane=(pane : Symbol | Int32 | String) : Symbol
        @layout.focused_pane = pane
        sync_child_focus
        @layout.focused_pane
      end

      def focus_ring : Array(Int32)
        @layout.focus_ring
      end

      def focus_next : Int32
        idx = @layout.focus_next
        sync_child_focus
        idx
      end

      def focus_prev : Int32
        idx = @layout.focus_prev
        sync_child_focus
        idx
      end

      # Toggles/cycles active focus in the focus ring and returns the focused pane symbol.
      def toggle_focus : Symbol
        sym = @layout.toggle_focus
        sync_child_focus
        sym
      end

      def focus_at(index : Int32) : Bool
        ok = @layout.focus_at(index)
        sync_child_focus if ok
        ok
      end

      def focus_by_id(id : String | Symbol) : Bool
        ok = @layout.focus_by_id(id)
        sync_child_focus if ok
        ok
      end

      def focus_first : Nil
        @layout.focus_first
        sync_child_focus
      end

      def focus_second : Nil
        @layout.focus_second
        sync_child_focus
      end

      def focused_element : Element?
        @panes[@layout.focused_index]?
      end

      # --- Resizing & Constraint Solving Delegation ---

      # Adjusts split ratio by `delta`, clamped within `[min_ratio, max_ratio]`.
      def adjust_ratio(
        delta : Float64,
        min_ratio : Float64 = 0.1,
        max_ratio : Float64 = 0.9,
        divider_index : Int32 = 0,
      ) : Float64
        @layout.adjust_ratio(delta, divider_index: divider_index, min_ratio: min_ratio, max_ratio: max_ratio)
      end

      def step_grow(step : Float64 = @layout.resize_step) : Float64
        @layout.step_grow(step, @layout.focused_index)
      end

      def step_shrink(step : Float64 = @layout.resize_step) : Float64
        @layout.step_shrink(step, @layout.focused_index)
      end

      def solve_layout(x : Int32, y : Int32, width : Int32, height : Int32) : Array(Core::PaneGeometry)
        @layout.solve(x, y, width, height)
      end

      def solve_extents(available_extent : Int32) : Array(Int32)
        @layout.solve_extents(available_extent)
      end

      # --- Interactive Keyboard & Mouse Handling ---

      def handle_key(key : Terminal::KeyEvent) : Bool
        # Focus ring navigation: Tab / Shift+Tab
        if (key.name == "tab" && !key.shift?) || (key.char == '\t' && !key.shift?)
          focus_next
          return true
        elsif key.name == "shift+tab" || key.name == "backtab" || ((key.name == "tab" || key.char == '\t') && key.shift?)
          focus_prev
          return true
        end

        # Keyboard step resizing with Ctrl+Arrow or Ctrl+[/]
        if key.ctrl?
          case key.name
          when "right", "down", "]"
            step_grow
            return true
          when "left", "up", "["
            step_shrink
            return true
          end
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
        rh = @last_rect.height

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
            return @layout.drag_to(coord, origin, total_ext)
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
            sw, sh = el.try(&.preferred_size(pw, available_h)) || {0, 0}
            needed_w += sw
            max_h = Math.max(max_h, sh)
          end

          if all_flexible && @panes.size == 2
            r = ratios_arr[0]?.try(&.clamp(0.05, 0.95)) || 0.5
            s1_w = @panes[0].try(&.preferred_size(extents[0]? || 0, available_h)).try(&.[0]) || 0
            s2_w = @panes[1].try(&.preferred_size(extents[1]? || 0, available_h)).try(&.[0]) || 0
            by_first = (s1_w / r).ceil.to_i
            by_second = (s2_w / (1.0 - r)).ceil.to_i
            needed_w = Math.max(needed_w, Math.max(by_first, by_second))
          end

          {Math.min(available_w, needed_w + sep_w), max_h}
        else
          extents = @layout.solve_extents(available_h)
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

          {max_w, Math.min(available_h, needed_h + sep_h)}
        end
      end

      def render(buffer : Buffer, x : Int32, y : Int32, width : Int32, height : Int32) : Nil
        return if width <= 0 || height <= 0
        @last_rect = Rect.new(x, y, width, height)

        @layout.solve_into(@solved_geometries, x, y, width, height)

        @solved_geometries.each do |geom|
          pane_el = @panes[geom.index]?
          if pane_el && geom.width > 0 && geom.height > 0
            if @highlight_focus && pane_el.is_a?(Box)
              if geom.focused?
                pane_el.border_fg = @focus_border_fg || Color.from(:cyan)
              elsif ufg = @unfocused_border_fg
                pane_el.border_fg = ufg
              end
            end

            buffer.with_clip(geom.x, geom.y, geom.width, geom.height) do
              pane_el.render(buffer, geom.x, geom.y, geom.width, geom.height)
            end
          end

          if dx = geom.divider_x
            (0...height).each do |sy|
              buffer.put_char(dx, y + sy, @separator, fg: @separator_fg)
            end
          elsif dy = geom.divider_y
            (0...width).each do |sx|
              buffer.put_char(x + sx, dy, @separator, fg: @separator_fg)
            end
          end
        end
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

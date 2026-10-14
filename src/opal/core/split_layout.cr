require "../ui/rect"

module Opal
  module Core
    # Primary axis orientation for split-pane layouts.
    enum SplitOrientation
      Horizontal
      Vertical

      def self.from(val) : SplitOrientation
        return val if val.is_a?(SplitOrientation)
        case val.to_s.downcase.strip
        when "vertical", "vert", "v", "col", "column", "top_bottom", "stacked"
          Vertical
        else
          Horizontal
        end
      end
    end

    # Declarative constraint specification for an individual pane in a SplitLayout.
    struct PaneConstraint
      property id : String
      property title : String?
      property flex : Float64
      property fixed_size : Int32?
      property min_size : Int32
      property max_size : Int32?
      property? focusable : Bool
      property? collapsed : Bool

      def initialize(
        @id : String = "pane",
        @flex : Float64 = 1.0,
        @fixed_size : Int32? = nil,
        @min_size : Int32 = 0,
        @max_size : Int32? = nil,
        @focusable : Bool = true,
        @collapsed : Bool = false,
        @title : String? = nil,
      )
        @flex = Math.max(0.0, @flex)
        @min_size = Math.max(0, @min_size)
        if mx = @max_size
          @max_size = Math.max(@min_size, mx)
        end
      end

      def self.flex(
        weight : Float64 = 1.0,
        min_size : Int32 = 0,
        max_size : Int32? = nil,
        id : String = "pane",
        title : String? = nil,
        focusable : Bool = true,
      ) : PaneConstraint
        new(
          id: id,
          flex: weight,
          fixed_size: nil,
          min_size: min_size,
          max_size: max_size,
          focusable: focusable,
          title: title
        )
      end

      def self.fixed(
        size : Int32,
        min_size : Int32 = 0,
        max_size : Int32? = nil,
        id : String = "pane",
        title : String? = nil,
        focusable : Bool = true,
      ) : PaneConstraint
        new(
          id: id,
          flex: 0.0,
          fixed_size: Math.max(0, size),
          min_size: min_size,
          max_size: max_size,
          focusable: focusable,
          title: title
        )
      end

      def effective_min(available : Int32) : Int32
        return 0 if @collapsed
        @min_size.clamp(0, Math.max(0, available))
      end

      def effective_max(available : Int32) : Int32
        return 0 if @collapsed
        avail = Math.max(0, available)
        if mx = @max_size
          Math.max(effective_min(avail), mx.clamp(0, avail))
        else
          avail
        end
      end

      def clamp_extent(value : Int32, available : Int32) : Int32
        return 0 if @collapsed
        lo = effective_min(available)
        hi = effective_max(available)
        value.clamp(lo, hi)
      end
    end

    # Solved 2D bounding box and divider coordinates for a single pane.
    struct PaneGeometry
      getter index : Int32
      getter id : String
      getter x : Int32
      getter y : Int32
      getter width : Int32
      getter height : Int32
      getter? focused : Bool
      getter divider_x : Int32?
      getter divider_y : Int32?

      def initialize(
        @index : Int32,
        @id : String,
        @x : Int32,
        @y : Int32,
        @width : Int32,
        @height : Int32,
        @focused : Bool = false,
        @divider_x : Int32? = nil,
        @divider_y : Int32? = nil,
      )
      end

      def rect : UI::Rect
        UI::Rect.new(@x, @y, @width, @height)
      end

      def contains?(px : Int32, py : Int32) : Bool
        px >= @x && px < (@x + @width) && py >= @y && py < (@y + @height)
      end

      def primary_extent(orientation : SplitOrientation) : Int32
        orientation.horizontal? ? @width : @height
      end
    end

    # Semantic keyboard navigation and layout actions for SplitLayout / SplitPane.
    enum SplitAction
      FocusNext
      FocusPrev
      FocusFirst
      FocusLast
      FocusLeft
      FocusRight
      FocusUp
      FocusDown
      FocusPane1
      FocusPane2
      FocusPane3
      FocusPane4
      FocusPane5
      FocusPane6
      FocusPane7
      FocusPane8
      FocusPane9
      StepGrow
      StepShrink
      ResetRatios
      EqualizeRatios
      ToggleOrientation
      ToggleCollapse
      ToggleZoom
      AnnounceStatus

      def self.from(val : SplitAction | Symbol | String) : SplitAction
        return val if val.is_a?(SplitAction)
        case val.to_s.downcase.strip.gsub('-', '_')
        when "focus_next", "next", "next_pane"                then FocusNext
        when "focus_prev", "prev", "prev_pane", "previous"    then FocusPrev
        when "focus_first", "first", "first_pane"             then FocusFirst
        when "focus_last", "last", "last_pane"                then FocusLast
        when "focus_left", "left"                             then FocusLeft
        when "focus_right", "right"                           then FocusRight
        when "focus_up", "up"                                 then FocusUp
        when "focus_down", "down"                             then FocusDown
        when "focus_pane_1", "pane_1", "1"                    then FocusPane1
        when "focus_pane_2", "pane_2", "2"                    then FocusPane2
        when "focus_pane_3", "pane_3", "3"                    then FocusPane3
        when "focus_pane_4", "pane_4", "4"                    then FocusPane4
        when "focus_pane_5", "pane_5", "5"                    then FocusPane5
        when "focus_pane_6", "pane_6", "6"                    then FocusPane6
        when "focus_pane_7", "pane_7", "7"                    then FocusPane7
        when "focus_pane_8", "pane_8", "8"                    then FocusPane8
        when "focus_pane_9", "pane_9", "9"                    then FocusPane9
        when "step_grow", "grow", "expand"                    then StepGrow
        when "step_shrink", "shrink"                          then StepShrink
        when "reset_ratios", "reset"                          then ResetRatios
        when "equalize_ratios", "equalize", "balance"         then EqualizeRatios
        when "toggle_orientation", "orientation", "direction" then ToggleOrientation
        when "toggle_collapse", "collapse"                    then ToggleCollapse
        when "toggle_zoom", "zoom", "maximize"                then ToggleZoom
        else
          AnnounceStatus
        end
      end

      # Returns 0-based pane index for FocusPane1..FocusPane9, or nil.
      def target_pane_index : Int32?
        case self
        when .focus_pane1? then 0
        when .focus_pane2? then 1
        when .focus_pane3? then 2
        when .focus_pane4? then 3
        when .focus_pane5? then 4
        when .focus_pane6? then 5
        when .focus_pane7? then 6
        when .focus_pane8? then 7
        when .focus_pane9? then 8
        else                    nil
        end
      end
    end

    # Configurable keyboard shortcut registry for accessible SplitLayout / SplitPane navigation.
    struct SplitKeymap
      getter bindings : Hash(String, SplitAction)

      def initialize(bindings : Hash(String, SplitAction)? = nil)
        if custom = bindings
          @bindings = custom.dup
        else
          @bindings = SplitKeymap.default_bindings
        end
      end

      def self.default_bindings : Hash(String, SplitAction)
        {
          "tab"        => SplitAction::FocusNext,
          "shift+tab"  => SplitAction::FocusPrev,
          "backtab"    => SplitAction::FocusPrev,
          "f6"         => SplitAction::FocusNext,
          "shift+f6"   => SplitAction::FocusPrev,
          "alt+right"  => SplitAction::FocusRight,
          "alt+l"      => SplitAction::FocusRight,
          "alt+left"   => SplitAction::FocusLeft,
          "alt+h"      => SplitAction::FocusLeft,
          "alt+down"   => SplitAction::FocusDown,
          "alt+j"      => SplitAction::FocusDown,
          "alt+up"     => SplitAction::FocusUp,
          "alt+k"      => SplitAction::FocusUp,
          "alt+home"   => SplitAction::FocusFirst,
          "ctrl+home"  => SplitAction::FocusFirst,
          "alt+end"    => SplitAction::FocusLast,
          "ctrl+end"   => SplitAction::FocusLast,
          "alt+1"      => SplitAction::FocusPane1,
          "alt+2"      => SplitAction::FocusPane2,
          "alt+3"      => SplitAction::FocusPane3,
          "alt+4"      => SplitAction::FocusPane4,
          "alt+5"      => SplitAction::FocusPane5,
          "alt+6"      => SplitAction::FocusPane6,
          "alt+7"      => SplitAction::FocusPane7,
          "alt+8"      => SplitAction::FocusPane8,
          "alt+9"      => SplitAction::FocusPane9,
          "ctrl+right" => SplitAction::StepGrow,
          "ctrl+down"  => SplitAction::StepGrow,
          "ctrl+]"     => SplitAction::StepGrow,
          "alt+]"      => SplitAction::StepGrow,
          "ctrl+left"  => SplitAction::StepShrink,
          "ctrl+up"    => SplitAction::StepShrink,
          "ctrl+["     => SplitAction::StepShrink,
          "alt+["      => SplitAction::StepShrink,
          "ctrl+0"     => SplitAction::ResetRatios,
          "alt+0"      => SplitAction::ResetRatios,
          "ctrl+="     => SplitAction::EqualizeRatios,
          "alt+="      => SplitAction::EqualizeRatios,
          "alt+o"      => SplitAction::ToggleOrientation,
          "ctrl+o"     => SplitAction::ToggleOrientation,
          "alt+c"      => SplitAction::ToggleCollapse,
          "alt+z"      => SplitAction::ToggleZoom,
          "alt+m"      => SplitAction::ToggleZoom,
          "alt+?"      => SplitAction::AnnounceStatus,
          "f1"         => SplitAction::AnnounceStatus,
        }
      end

      def self.normalize_key_spec(key_spec : String) : String
        raw = key_spec.downcase.strip
        return "backtab" if raw == "backtab"
        parts = raw.split('+').map(&.strip).reject(&.empty?)
        mods = [] of String
        mods << "ctrl" if parts.includes?("ctrl") || parts.includes?("control")
        mods << "alt" if parts.includes?("alt") || parts.includes?("meta")
        mods << "shift" if parts.includes?("shift")
        base = parts.reject { |p| ["ctrl", "control", "alt", "meta", "shift"].includes?(p) }.first? || ""
        base = "esc" if base == "escape"
        base = "pageup" if base == "page_up"
        base = "pagedown" if base == "page_down"
        base = "space" if base == " "
        mods << base unless base.empty?
        mods.join("+")
      end

      def bind(key_spec : String, action : SplitAction | Symbol | String) : self
        norm = SplitKeymap.normalize_key_spec(key_spec)
        @bindings[norm] = SplitAction.from(action)
        self
      end

      def unbind(key_spec : String) : self
        norm = SplitKeymap.normalize_key_spec(key_spec)
        @bindings.delete(norm)
        self
      end

      # Resolves a key press descriptor (`name`, `char`, `ctrl`, `alt`, `shift`) to a `SplitAction`.
      def resolve(
        name : String,
        char : Char? = nil,
        ctrl : Bool = false,
        alt : Bool = false,
        shift : Bool = false,
      ) : SplitAction?
        raw_name = name.downcase.strip
        return @bindings["backtab"]? if raw_name == "backtab" && @bindings.has_key?("backtab")
        return @bindings["shift+tab"]? if raw_name == "shift+tab" && @bindings.has_key?("shift+tab")

        base = if raw_name.empty? && (ch = char)
                 ch == '\t' ? "tab" : ch.to_s.downcase
               elsif raw_name == "\t"
                 "tab"
               else
                 raw_name
               end

        spec = String.build do |io|
          io << "ctrl+" if ctrl
          io << "alt+" if alt
          # Only include shift+ when base isn't a shifted symbol like '?' unless it's tab or f-key
          if shift && (base == "tab" || base.starts_with?("f") || base == "left" || base == "right" || base == "up" || base == "down")
            io << "shift+"
          end
          io << base
        end

        if act = @bindings[spec]?
          return act
        end

        # Also check with char if name differed (e.g. char == '?' with shift: true, alt: true)
        if ch = char
          ch_base = (ch == '\t') ? "tab" : ch.to_s.downcase
          alt_spec = String.build do |io|
            io << "ctrl+" if ctrl
            io << "alt+" if alt
            io << "shift+" if shift && ch_base == "tab"
            io << ch_base
          end
          return @bindings[alt_spec]? if @bindings.has_key?(alt_spec)
        end

        nil
      end

      # Returns human-readable and screen-reader-friendly keyboard shortcut hints.
      def shortcut_hints : Array(NamedTuple(key: String, description: String))
        [
          {key: "Tab/Shift+Tab", description: "Switch Pane"},
          {key: "Alt+Arrows/HJKL", description: "Navigate Directionally"},
          {key: "Alt+1..9", description: "Jump to Pane"},
          {key: "Ctrl+Arrows/[]", description: "Resize Pane"},
          {key: "Ctrl+0", description: "Reset Ratios"},
          {key: "Alt+=", description: "Equalize"},
          {key: "Alt+Z", description: "Zoom Pane"},
          {key: "Alt+O", description: "Flip Orientation"},
        ]
      end
    end

    # Tier-1 Core Engine: 1D/2D Split-Pane Constraint Solver, Divider Drag/Step State Machine,
    # Focus Ring Navigation Manager, Keyboard Shortcut Dispatcher, and Screen-Reader Status Announcer.
    class SplitLayout
      property orientation : SplitOrientation
      getter panes : Array(PaneConstraint)
      getter focused_index : Int32
      property? show_separator : Bool
      property separator_size : Int32
      property resize_step : Float64
      getter? dragging : Bool
      getter active_divider : Int32?
      property keymap : SplitKeymap
      getter? zoomed : Bool
      getter last_announcement : String
      getter announcement_history : Array(String)

      # Pre-allocated scratch buffers for zero-allocation frame solving
      @extent_scratch : Array(Int32)
      @frozen_scratch : Array(Bool)
      @exact_scratch : Array(Float64)
      @geometry_scratch : Array(PaneGeometry)
      @initial_flex : Array(Float64)
      @pre_zoom_collapsed : Array(Bool)

      def initialize(
        orientation : SplitOrientation | Symbol | String = SplitOrientation::Horizontal,
        ratio : Float64? = 0.5,
        first_size : Int32? = nil,
        second_size : Int32? = nil,
        min_first_size : Int32? = nil,
        max_first_size : Int32? = nil,
        min_second_size : Int32? = nil,
        max_second_size : Int32? = nil,
        focused_pane : Symbol | Int32 | String = :first,
        @show_separator : Bool = true,
        separator_size : Int32 = 1,
        resize_step : Float64 = 0.05,
        panes : Array(PaneConstraint)? = nil,
        keymap : SplitKeymap? = nil,
      )
        @orientation = SplitOrientation.from(orientation)
        @separator_size = Math.max(0, separator_size)
        @resize_step = resize_step.clamp(0.01, 0.5)
        @dragging = false
        @active_divider = nil
        @keymap = keymap || SplitKeymap.new
        @zoomed = false
        @last_announcement = ""
        @announcement_history = [] of String

        if custom_panes = panes
          @panes = custom_panes.dup
        else
          r = (ratio || 0.5).clamp(0.0, 1.0)
          p1 = PaneConstraint.new(
            id: "first",
            flex: r,
            fixed_size: first_size,
            min_size: min_first_size || 0,
            max_size: max_first_size,
            focusable: true
          )
          p2 = PaneConstraint.new(
            id: "second",
            flex: 1.0 - r,
            fixed_size: second_size,
            min_size: min_second_size || 0,
            max_size: max_second_size,
            focusable: true
          )
          @panes = [p1, p2]
        end

        @initial_flex = @panes.map(&.flex)
        @pre_zoom_collapsed = @panes.map(&.collapsed?)
        @extent_scratch = Array(Int32).new(@panes.size, 0)
        @frozen_scratch = Array(Bool).new(@panes.size, false)
        @exact_scratch = Array(Float64).new(@panes.size, 0.0)
        @geometry_scratch = Array(PaneGeometry).new(@panes.size)
        @focused_index = 0
        focus_target(focused_pane)
        record_announcement(build_focus_announcement)
      end

      def self.horizontal(
        ratio : Float64? = 0.5,
        first_size : Int32? = nil,
        second_size : Int32? = nil,
        min_first_size : Int32? = nil,
        max_first_size : Int32? = nil,
        min_second_size : Int32? = nil,
        max_second_size : Int32? = nil,
        focused_pane : Symbol | Int32 | String = :first,
        show_separator : Bool = true,
        resize_step : Float64 = 0.05,
      ) : SplitLayout
        new(
          orientation: SplitOrientation::Horizontal,
          ratio: ratio,
          first_size: first_size,
          second_size: second_size,
          min_first_size: min_first_size,
          max_first_size: max_first_size,
          min_second_size: min_second_size,
          max_second_size: max_second_size,
          focused_pane: focused_pane,
          show_separator: show_separator,
          resize_step: resize_step
        )
      end

      def self.vertical(
        ratio : Float64? = 0.5,
        first_size : Int32? = nil,
        second_size : Int32? = nil,
        min_first_size : Int32? = nil,
        max_first_size : Int32? = nil,
        min_second_size : Int32? = nil,
        max_second_size : Int32? = nil,
        focused_pane : Symbol | Int32 | String = :first,
        show_separator : Bool = true,
        resize_step : Float64 = 0.05,
      ) : SplitLayout
        new(
          orientation: SplitOrientation::Vertical,
          ratio: ratio,
          first_size: first_size,
          second_size: second_size,
          min_first_size: min_first_size,
          max_first_size: max_first_size,
          min_second_size: min_second_size,
          max_second_size: max_second_size,
          focused_pane: focused_pane,
          show_separator: show_separator,
          resize_step: resize_step
        )
      end

      def pane_count : Int32
        @panes.size
      end

      # Appends a new pane constraint and resizes internal scratch buffers.
      def add_pane(
        id : String? = nil,
        flex : Float64 = 1.0,
        fixed_size : Int32? = nil,
        min_size : Int32 = 0,
        max_size : Int32? = nil,
        focusable : Bool = true,
        collapsed : Bool = false,
        title : String? = nil,
      ) : PaneConstraint
        resolved_id = id || default_pane_id(@panes.size)
        constraint = PaneConstraint.new(
          id: resolved_id,
          flex: flex,
          fixed_size: fixed_size,
          min_size: min_size,
          max_size: max_size,
          focusable: focusable,
          collapsed: collapsed,
          title: title
        )
        @panes << constraint
        @initial_flex << constraint.flex
        @pre_zoom_collapsed << constraint.collapsed?
        sync_scratch_capacity
        ensure_valid_focus
        constraint
      end

      # Replaces all pane constraints with a new array of constraints.
      def set_panes(constraints : Array(PaneConstraint)) : self
        @panes.clear
        @initial_flex.clear
        @pre_zoom_collapsed.clear
        @zoomed = false
        constraints.each do |c|
          @panes << c
          @initial_flex << c.flex
          @pre_zoom_collapsed << c.collapsed?
        end
        sync_scratch_capacity
        ensure_valid_focus
        record_announcement(build_focus_announcement)
        self
      end

      # Updates a specific pane constraint at `index`.
      def set_pane(index : Int32, constraint : PaneConstraint) : self
        if index >= 0 && index < @panes.size
          @panes[index] = constraint
          @initial_flex[index] = constraint.flex if index < @initial_flex.size
          @pre_zoom_collapsed[index] = constraint.collapsed? if index < @pre_zoom_collapsed.size
          ensure_valid_focus
        end
        self
      end

      # Mutates a pane constraint at `index` via a block and stores the updated struct.
      def update_pane(index : Int32, & : PaneConstraint -> PaneConstraint) : self
        if index >= 0 && index < @panes.size
          @panes[index] = yield @panes[index]
          ensure_valid_focus
        end
        self
      end

      # Primary 2-pane split ratio (`[0.0, 1.0]`).
      def ratio : Float64
        return 0.5 if @panes.empty?
        return 1.0 if @panes.size == 1
        f0 = @panes[0].flex
        f1 = @panes[1].flex
        total = f0 + f1
        total > 0.0 ? (f0 / total).clamp(0.0, 1.0) : 0.5
      end

      def ratio=(val : Float64?) : Float64?
        r = (val || 0.5).clamp(0.0, 1.0)
        if @panes.size >= 2
          p0 = @panes[0]
          p1 = @panes[1]
          p0.flex = r
          p1.flex = 1.0 - r
          @panes[0] = p0
          @panes[1] = p1
        elsif @panes.size == 1
          p0 = @panes[0]
          p0.flex = r
          @panes[0] = p0
        end
        val
      end

      # Returns normalized flex ratios across all panes (summing to 1.0 for active panes).
      def ratios : Array(Float64)
        return [] of Float64 if @panes.empty?
        total = 0.0
        @panes.each { |p| total += p.flex unless p.collapsed? }
        if total <= 0.0
          active_count = @panes.count { |p| !p.collapsed? }
          share = active_count > 0 ? (1.0 / active_count) : 0.0
          return @panes.map { |p| p.collapsed? ? 0.0 : share }
        end
        @panes.map { |p| p.collapsed? ? 0.0 : (p.flex / total) }
      end

      # Sets flex weights across panes.
      def set_ratios(weights : Enumerable(Float64)) : self
        weights.each_with_index do |w, idx|
          break if idx >= @panes.size
          p = @panes[idx]
          p.flex = Math.max(0.0, w)
          p.fixed_size = nil
          @panes[idx] = p
        end
        record_announcement(build_resize_announcement(@focused_index))
        self
      end

      # Resets flex weights to their initial values.
      def reset_ratios! : self
        @panes.each_with_index do |p, idx|
          cp = p
          cp.flex = @initial_flex[idx]? || 1.0
          @panes[idx] = cp
        end
        record_announcement("Reset split ratios: #{pane_display_label(@focused_index)} at #{pane_share_percent(@focused_index)}% #{axis_dimension_word}")
        self
      end

      # Equalizes flex weights across all active panes.
      def equalize_ratios! : self
        active_count = 0
        @panes.each_with_index do |p, idx|
          cp = p
          cp.flex = 1.0
          cp.fixed_size = nil
          @panes[idx] = cp
          active_count += 1 unless cp.collapsed?
        end
        share = active_count > 0 ? (100.0 / active_count).round.to_i : 100
        record_announcement("Equalized split ratios across #{active_count} panes (#{share}% #{axis_dimension_word} each)")
        self
      end

      # Toggles primary split orientation between Horizontal and Vertical.
      def toggle_orientation! : SplitOrientation
        @orientation = @orientation.horizontal? ? SplitOrientation::Vertical : SplitOrientation::Horizontal
        record_announcement("Switched split orientation to #{@orientation.to_s.downcase}: #{pane_display_label(@focused_index)} (#{pane_share_percent(@focused_index)}% #{axis_dimension_word})")
        @orientation
      end

      # Toggles zoom (maximize) on the currently focused pane, collapsing or restoring sibling panes.
      def toggle_zoom! : Bool
        return false if @panes.size < 2
        if @zoomed
          @panes.each_with_index do |p, idx|
            cp = p
            cp.collapsed = @pre_zoom_collapsed[idx]? || false
            @panes[idx] = cp
          end
          @zoomed = false
          ensure_valid_focus
          record_announcement("Restored split panes: #{pane_display_label(@focused_index)} (#{pane_share_percent(@focused_index)}% #{axis_dimension_word})")
        else
          @pre_zoom_collapsed = @panes.map(&.collapsed?)
          @panes.each_with_index do |p, idx|
            cp = p
            cp.collapsed = (idx != @focused_index)
            @panes[idx] = cp
          end
          @zoomed = true
          record_announcement("Maximized pane #{@focused_index + 1} of #{@panes.size}: #{pane_display_label(@focused_index)} (100% #{axis_dimension_word})")
        end
        @zoomed
      end

      # 2-pane convenience accessors for first/second fixed and min/max bounds
      def first_size : Int32?
        @panes[0]?.try(&.fixed_size)
      end

      def first_size=(val : Int32?) : Int32?
        if @panes.size >= 1
          p = @panes[0]
          p.fixed_size = val ? Math.max(0, val) : nil
          @panes[0] = p
        end
        val
      end

      def second_size : Int32?
        @panes[1]?.try(&.fixed_size)
      end

      def second_size=(val : Int32?) : Int32?
        if @panes.size >= 2
          p = @panes[1]
          p.fixed_size = val ? Math.max(0, val) : nil
          @panes[1] = p
        end
        val
      end

      def min_first_size : Int32?
        if p = @panes[0]?
          p.min_size > 0 ? p.min_size : nil
        end
      end

      def min_first_size=(val : Int32?) : Int32?
        if @panes.size >= 1
          p = @panes[0]
          p.min_size = val ? Math.max(0, val) : 0
          @panes[0] = p
        end
        val
      end

      def max_first_size : Int32?
        @panes[0]?.try(&.max_size)
      end

      def max_first_size=(val : Int32?) : Int32?
        if @panes.size >= 1
          p = @panes[0]
          p.max_size = val ? Math.max(0, val) : nil
          @panes[0] = p
        end
        val
      end

      def min_second_size : Int32?
        if p = @panes[1]?
          p.min_size > 0 ? p.min_size : nil
        end
      end

      def min_second_size=(val : Int32?) : Int32?
        if @panes.size >= 2
          p = @panes[1]
          p.min_size = val ? Math.max(0, val) : 0
          @panes[1] = p
        end
        val
      end

      def max_second_size : Int32?
        @panes[1]?.try(&.max_size)
      end

      def max_second_size=(val : Int32?) : Int32?
        if @panes.size >= 2
          p = @panes[1]
          p.max_size = val ? Math.max(0, val) : nil
          @panes[1] = p
        end
        val
      end

      # Adjusts split ratio across `divider_index` (between pane `i` and `i + 1`) by `delta`.
      # Returns the updated normalized share of pane `i` within the pair.
      def adjust_ratio(
        delta : Float64,
        divider_index : Int32 = 0,
        min_ratio : Float64 = 0.05,
        max_ratio : Float64 = 0.95,
      ) : Float64
        return ratio if @panes.size < 2
        idx = divider_index.clamp(0, @panes.size - 2)
        p_a = @panes[idx]
        p_b = @panes[idx + 1]

        pair_total = p_a.flex + p_b.flex
        pair_total = 1.0 if pair_total <= 0.0

        current_share = (p_a.flex / pair_total).clamp(0.0, 1.0)
        lo = min_ratio.clamp(0.0, 1.0)
        hi = Math.max(lo, max_ratio.clamp(0.0, 1.0))
        updated_share = (current_share + delta).clamp(lo, hi)

        p_a.flex = pair_total * updated_share
        p_b.flex = pair_total * (1.0 - updated_share)
        p_a.fixed_size = nil
        p_b.fixed_size = nil
        @panes[idx] = p_a
        @panes[idx + 1] = p_b

        record_announcement(build_resize_announcement(@focused_index))
        updated_share
      end

      # Grows the specified pane (defaults to focused pane) by `step`.
      def step_grow(step : Float64 = @resize_step, pane_index : Int32 = @focused_index) : Float64
        return ratio if @panes.size < 2
        idx = pane_index.clamp(0, @panes.size - 1)
        res = if idx < @panes.size - 1
                adjust_ratio(step.abs, divider_index: idx)
              else
                1.0 - adjust_ratio(-step.abs, divider_index: idx - 1)
              end
        record_announcement(build_resize_announcement(idx))
        res
      end

      # Shrinks the specified pane (defaults to focused pane) by `step`.
      def step_shrink(step : Float64 = @resize_step, pane_index : Int32 = @focused_index) : Float64
        return ratio if @panes.size < 2
        idx = pane_index.clamp(0, @panes.size - 1)
        res = if idx < @panes.size - 1
                adjust_ratio(-step.abs, divider_index: idx)
              else
                1.0 - adjust_ratio(step.abs, divider_index: idx - 1)
              end
        record_announcement(build_resize_announcement(idx))
        res
      end

      # Starts an interactive divider drag operation on `divider_index`.
      def begin_drag(divider_index : Int32 = 0) : Bool
        return false if @panes.size < 2
        return false unless divider_index >= 0 && divider_index < (@panes.size - 1)
        @dragging = true
        @active_divider = divider_index
        true
      end

      # Updates divider position during an active drag given mouse coordinate `coord`,
      # container start `origin` (`x` or `y`), and container `total_extent` (`width` or `height`).
      def drag_to(
        coord : Int32,
        origin : Int32,
        total_extent : Int32,
        min_ratio : Float64 = 0.05,
        max_ratio : Float64 = 0.95,
      ) : Bool
        return false unless @dragging
        div_idx = @active_divider || 0
        return false if @panes.size < 2 || total_extent <= 1

        solve_extents_into(@extent_scratch, total_extent)
        sep = @show_separator ? @separator_size : 0

        # Compute start offset of pane `div_idx` and total span of the adjacent pair `(div_idx, div_idx + 1)`
        pair_origin = origin
        (0...div_idx).each do |i|
          next if @panes[i].collapsed?
          pair_origin += @extent_scratch[i] + sep
        end

        pair_extent = @extent_scratch[div_idx] + @extent_scratch[div_idx + 1]
        return false if pair_extent <= 0

        local_offset = (coord - pair_origin).clamp(0, pair_extent)
        target_share = (local_offset.to_f / pair_extent.to_f).clamp(min_ratio, max_ratio)

        p_a = @panes[div_idx]
        p_b = @panes[div_idx + 1]
        pair_flex = p_a.flex + p_b.flex
        pair_flex = 1.0 if pair_flex <= 0.0

        p_a.flex = pair_flex * target_share
        p_b.flex = pair_flex * (1.0 - target_share)
        p_a.fixed_size = nil
        p_b.fixed_size = nil
        @panes[div_idx] = p_a
        @panes[div_idx + 1] = p_b
        record_announcement(build_resize_announcement(div_idx))
        true
      end

      # Ends an active divider drag operation.
      def end_drag : Nil
        @dragging = false
        @active_divider = nil
      end

      # Collapses or expands the pane at `index`.
      def set_collapsed(index : Int32, collapsed : Bool = true) : Bool
        return false unless index >= 0 && index < @panes.size
        p = @panes[index]
        p.collapsed = collapsed
        @panes[index] = p
        @zoomed = false
        ensure_valid_focus
        if collapsed
          record_announcement("Collapsed pane #{index + 1} of #{@panes.size}: #{pane_display_label(index)}")
        else
          record_announcement("Expanded pane #{index + 1} of #{@panes.size}: #{pane_display_label(index)} (#{pane_share_percent(index)}% #{axis_dimension_word})")
        end
        true
      end

      # Toggles collapsed state for the pane at `index`.
      def toggle_collapsed(index : Int32) : Bool
        return false unless index >= 0 && index < @panes.size
        set_collapsed(index, !@panes[index].collapsed?)
      end

      # --- Focus Ring Navigation ---

      # Returns ordered indices of all active, focusable panes in the focus ring.
      def focus_ring : Array(Int32)
        ring = [] of Int32
        @panes.each_with_index do |p, idx|
          ring << idx if p.focusable? && !p.collapsed?
        end
        ring
      end

      # Returns symbolic identifier for the currently focused pane (`:first`, `:second`, or pane ID).
      def focused_pane : Symbol
        return :first if @panes.empty?
        if @focused_index == 0
          :first
        elsif @focused_index == 1 && (@panes[1].id == "second" || @panes.size == 2)
          :second
        else
          id = @panes[@focused_index]?.try(&.id) || "first"
          case id
          when "first", "pane_0"  then :first
          when "second", "pane_1" then :second
          else
            focus_symbol_for_id(id, @focused_index)
          end
        end
      end

      def focused_pane=(pane : Symbol | Int32 | String) : Symbol
        focus_target(pane)
        record_announcement(build_focus_announcement)
        focused_pane
      end

      # Returns the string ID of the currently focused pane.
      def focused_id : String
        @panes[@focused_index]?.try(&.id) || "first"
      end

      # Returns the human-readable title (or fallback ID) of the currently focused pane.
      def focused_title : String
        pane_display_label(@focused_index)
      end

      # Advances focus forward to the next focusable pane in the ring (wrapping around).
      def focus_next : Int32
        ring = focus_ring
        return @focused_index if ring.empty?
        if cur_pos = ring.index(@focused_index)
          @focused_index = ring[(cur_pos + 1) % ring.size]
        else
          @focused_index = ring.first
        end
        record_announcement(build_focus_announcement)
        @focused_index
      end

      # Moves focus backward to the previous focusable pane in the ring (wrapping around).
      def focus_prev : Int32
        ring = focus_ring
        return @focused_index if ring.empty?
        if cur_pos = ring.index(@focused_index)
          @focused_index = ring[(cur_pos - 1 + ring.size) % ring.size]
        else
          @focused_index = ring.last
        end
        record_announcement(build_focus_announcement)
        @focused_index
      end

      # Moves focus directionally (`:left`, `:right`, `:up`, `:down`).
      def focus_directional(direction : Symbol | String) : Int32
        dir_key = direction.to_s.downcase.strip
        case dir_key
        when "left", "up", "prev", "previous"
          focus_prev
        when "right", "down", "next"
          focus_next
        else
          @focused_index
        end
      end

      # Cycles focus to the next focusable pane and returns the updated `focused_pane` symbol.
      def toggle_focus : Symbol
        focus_next
        focused_pane
      end

      # Focuses the pane at `index` if valid and focusable.
      def focus_at(index : Int32) : Bool
        return false unless index >= 0 && index < @panes.size
        pane = @panes[index]
        return false if !pane.focusable? || pane.collapsed?
        @focused_index = index
        record_announcement(build_focus_announcement)
        true
      end

      # Focuses a pane by its string/symbol ID or positional alias (`:first`, `:second`, `:left`, `:right`, `:top`, `:bottom`).
      def focus_by_id(id : String | Symbol) : Bool
        key = id.to_s.downcase.strip
        if idx = @panes.index { |p| p.id.downcase == key }
          return focus_at(idx)
        end
        if idx = @panes.index { |p| (t = p.title) && t.downcase == key }
          return focus_at(idx)
        end
        case key
        when "first", "left", "top", "0", "pane_0"
          focus_at(0)
        when "second", "right", "bottom", "1", "pane_1"
          focus_at(1)
        when "last"
          ring = focus_ring
          ring.empty? ? false : focus_at(ring.last)
        else
          if key.starts_with?("pane_")
            if parsed = key.lchop("pane_").to_i?
              return focus_at(parsed)
            end
          end
          false
        end
      end

      def focus_first : Int32
        ring = focus_ring
        focus_at(ring.first) unless ring.empty?
        @focused_index
      end

      def focus_second : Int32
        focus_at(1)
        @focused_index
      end

      def focus_last : Int32
        ring = focus_ring
        focus_at(ring.last) unless ring.empty?
        @focused_index
      end

      # --- Keyboard Action Execution & Screen-Reader Announcements ---

      # Dispatches a `SplitAction` against this layout and updates screen-reader announcements.
      def execute_action(action : SplitAction) : Bool
        if target_idx = action.target_pane_index
          return focus_at(target_idx)
        end

        case action
        in .focus_next?
          focus_next
          true
        in .focus_prev?
          focus_prev
          true
        in .focus_first?
          focus_first
          true
        in .focus_last?
          focus_last
          true
        in .focus_left?
          focus_directional(:left)
          true
        in .focus_right?
          focus_directional(:right)
          true
        in .focus_up?
          focus_directional(:up)
          true
        in .focus_down?
          focus_directional(:down)
          true
        in .focus_pane1?, .focus_pane2?, .focus_pane3?, .focus_pane4?, .focus_pane5?, .focus_pane6?, .focus_pane7?, .focus_pane8?, .focus_pane9?
          false
        in .step_grow?
          return false if @panes.size < 2
          step_grow
          true
        in .step_shrink?
          return false if @panes.size < 2
          step_shrink
          true
        in .reset_ratios?
          reset_ratios!
          true
        in .equalize_ratios?
          equalize_ratios!
          true
        in .toggle_orientation?
          toggle_orientation!
          true
        in .toggle_collapse?
          return false if @panes.size < 2
          # Toggle the first collapsed pane if one exists; otherwise collapse the next sibling pane
          if collapsed_idx = @panes.index(&.collapsed?)
            set_collapsed(collapsed_idx, false)
          else
            sibling_idx = (@focused_index + 1) % @panes.size
            set_collapsed(sibling_idx, true)
          end
        in .toggle_zoom?
          return false if @panes.size < 2
          toggle_zoom!
          true
        in .announce_status?
          announce_status
          true
        end
      end

      # Resolves a key press through `@keymap` and executes the matched `SplitAction` if any.
      def handle_key_action(
        name : String,
        char : Char? = nil,
        ctrl : Bool = false,
        alt : Bool = false,
        shift : Bool = false,
      ) : SplitAction?
        if action = @keymap.resolve(name: name, char: char, ctrl: ctrl, alt: alt, shift: shift)
          return action if execute_action(action)
        end
        nil
      end

      # Returns the latest screen-reader-friendly status announcement.
      def status_announcement : String
        if @last_announcement.empty?
          @last_announcement = build_focus_announcement
        end
        @last_announcement
      end

      # Refreshes and records a full focus & layout announcement on demand.
      def announce_status : String
        msg = build_focus_announcement
        record_announcement(msg)
        msg
      end

      # Returns a screen-reader-friendly description of the currently focused pane.
      def describe_focused_pane : String
        build_focus_announcement
      end

      # Formats a complete single-line screen-reader-friendly status bar string.
      def format_status_line(include_shortcuts : Bool = true) : String
        base = status_announcement
        return base unless include_shortcuts
        "#{base} | Shortcuts: Tab/Shift+Tab switch pane, Alt+1..9 jump, Ctrl+Arrows resize, Ctrl+0 reset, Alt+Z zoom"
      end

      # --- 1D & 2D Box Constraint Solver ---

      # Zero-allocation 1D constraint solver: computes integer cell sizes for each pane
      # into `target` given `total_extent` (including separator cells).
      def solve_extents_into(target : Array(Int32), total_extent : Int32) : Array(Int32)
        n = @panes.size
        target.clear
        return target if n == 0

        sync_scratch_capacity
        n.times do |i|
          target << 0
          @frozen_scratch[i] = false
          @exact_scratch[i] = 0.0
        end

        active_indices = 0
        n.times do |i|
          if @panes[i].collapsed?
            @frozen_scratch[i] = true
          else
            active_indices += 1
          end
        end

        return target if active_indices == 0 || total_extent <= 0

        sep_cells = (@show_separator && active_indices > 1) ? (active_indices - 1) * @separator_size : 0
        avail = Math.max(0, total_extent - sep_cells)
        return target if avail == 0

        # Step 1: Freeze panes with explicit `fixed_size`, respecting min/max bounds of all panes.
        remaining = avail
        n.times do |i|
          next if @frozen_scratch[i]
          pane = @panes[i]
          if fs = pane.fixed_size
            # Reserve minimum required space for other unfrozen panes
            other_min_sum = 0
            n.times do |j|
              next if j == i || @frozen_scratch[j]
              other_min_sum += @panes[j].effective_min(avail)
            end
            max_for_this = Math.max(0, remaining - other_min_sum)
            clamped = pane.clamp_extent(fs, avail).clamp(0, max_for_this)
            target[i] = clamped
            @frozen_scratch[i] = true
            remaining = Math.max(0, remaining - clamped)
          end
        end

        # Step 2: Iterative water-filling pass for flexible panes with min/max bounds.
        loop do
          unfrozen_count = 0
          total_flex = 0.0
          n.times do |i|
            next if @frozen_scratch[i]
            unfrozen_count += 1
            total_flex += @panes[i].flex
          end
          break if unfrozen_count == 0

          clamped_any = false
          n.times do |i|
            next if @frozen_scratch[i]
            pane = @panes[i]
            share = if total_flex > 0.0
                      remaining.to_f * (pane.flex / total_flex)
                    else
                      remaining.to_f / unfrozen_count.to_f
                    end
            @exact_scratch[i] = share

            min_b = pane.effective_min(avail)
            max_b = pane.effective_max(avail)

            if share < min_b.to_f
              assigned = Math.min(remaining, min_b)
              target[i] = assigned
              @frozen_scratch[i] = true
              remaining = Math.max(0, remaining - assigned)
              clamped_any = true
            elsif !pane.max_size.nil? && share > max_b.to_f
              assigned = Math.min(remaining, max_b)
              target[i] = assigned
              @frozen_scratch[i] = true
              remaining = Math.max(0, remaining - assigned)
              clamped_any = true
            end
          end

          break unless clamped_any
        end

        # Step 3: Distribute remaining integer cells across still-unfrozen panes using rounding / largest remainder.
        unfrozen_total = 0
        first_unfrozen = -1
        last_unfrozen = -1
        n.times do |i|
          unless @frozen_scratch[i]
            unfrozen_total += 1
            first_unfrozen = i if first_unfrozen == -1
            last_unfrozen = i
          end
        end

        if unfrozen_total == 1
          idx = first_unfrozen
          pane = @panes[idx]
          target[idx] = pane.clamp_extent(remaining, avail).clamp(0, remaining)
        elsif unfrozen_total == 2
          # Exact 2-pane rounding compatibility: first unfrozen rounds, second receives remainder
          i0 = first_unfrozen
          i1 = last_unfrozen
          p0 = @panes[i0]
          p1 = @panes[i1]
          s0 = p0.clamp_extent(@exact_scratch[i0].round.to_i, avail).clamp(0, remaining)
          s1 = p1.clamp_extent(remaining - s0, avail).clamp(0, Math.max(0, remaining - s0))
          # If p1 had a max_size that prevented it from absorbing all of (remaining - s0), give leftover back to p0 if allowed
          leftover = remaining - (s0 + s1)
          if leftover > 0
            s0 = p0.clamp_extent(s0 + leftover, avail).clamp(0, remaining - s1)
          end
          target[i0] = s0
          target[i1] = s1
        elsif unfrozen_total > 2
          allocated = 0
          n.times do |i|
            next if @frozen_scratch[i]
            floored = @exact_scratch[i].floor.to_i
            clamped = @panes[i].clamp_extent(floored, avail)
            target[i] = clamped
            allocated += clamped
          end

          rem = remaining - allocated
          while rem > 0
            best_idx = -1
            best_frac = -1.0
            n.times do |i|
              next if @frozen_scratch[i]
              max_b = @panes[i].effective_max(avail)
              next if target[i] >= max_b
              frac = @exact_scratch[i] - target[i].to_f
              if frac > best_frac
                best_frac = frac
                best_idx = i
              end
            end
            break if best_idx == -1
            target[best_idx] += 1
            rem -= 1
          end
        end

        target
      end

      # Computes and returns a new array of 1D cell sizes for each pane.
      def solve_extents(total_extent : Int32) : Array(Int32)
        result = Array(Int32).new(@panes.size)
        solve_extents_into(result, total_extent)
      end

      # Zero-allocation 2D constraint solver: populates `target` with `PaneGeometry` structs
      # for the bounding box `(x, y, width, height)`.
      def solve_into(
        target : Array(PaneGeometry),
        x : Int32,
        y : Int32,
        width : Int32,
        height : Int32,
      ) : Array(PaneGeometry)
        target.clear
        n = @panes.size
        return target if n == 0

        w = Math.max(0, width)
        h = Math.max(0, height)
        primary_avail = @orientation.horizontal? ? w : h
        solve_extents_into(@extent_scratch, primary_avail)

        sep = @show_separator ? @separator_size : 0

        # Find the last non-collapsed pane index to know which panes have a trailing separator
        last_active_idx = -1
        n.times do |i|
          last_active_idx = i unless @panes[i].collapsed?
        end

        cursor_x = x
        cursor_y = y

        n.times do |i|
          pane = @panes[i]
          ext = @extent_scratch[i]
          has_trailing_sep = !pane.collapsed? && @show_separator && sep > 0 && i < last_active_idx

          if @orientation.horizontal?
            div_x = has_trailing_sep ? (cursor_x + ext) : nil
            target << PaneGeometry.new(
              index: i,
              id: pane.id,
              x: cursor_x,
              y: y,
              width: ext,
              height: h,
              focused: (i == @focused_index),
              divider_x: div_x,
              divider_y: nil
            )
            unless pane.collapsed?
              cursor_x += ext + (has_trailing_sep ? sep : 0)
            end
          else
            div_y = has_trailing_sep ? (cursor_y + ext) : nil
            target << PaneGeometry.new(
              index: i,
              id: pane.id,
              x: x,
              y: cursor_y,
              width: w,
              height: ext,
              focused: (i == @focused_index),
              divider_x: nil,
              divider_y: div_y
            )
            unless pane.collapsed?
              cursor_y += ext + (has_trailing_sep ? sep : 0)
            end
          end
        end

        target
      end

      # Solves 2D pane geometries for `(x, y, width, height)` and returns a new `Array(PaneGeometry)`.
      def solve(x : Int32, y : Int32, width : Int32, height : Int32) : Array(PaneGeometry)
        result = Array(PaneGeometry).new(@panes.size)
        solve_into(result, x, y, width, height)
      end

      # Solves 2D pane geometries for a `UI::Rect` bounding box.
      def solve(rect : UI::Rect) : Array(PaneGeometry)
        solve(rect.x, rect.y, rect.width, rect.height)
      end

      # Returns the primary-axis coordinates (`x` for Horizontal, `y` for Vertical) of all active dividers.
      def divider_positions(x : Int32, y : Int32, width : Int32, height : Int32) : Array(Int32)
        solve_into(@geometry_scratch, x, y, width, height)
        positions = [] of Int32
        @geometry_scratch.each do |geom|
          if dx = geom.divider_x
            positions << dx
          elsif dy = geom.divider_y
            positions << dy
          end
        end
        positions
      end

      # Returns the divider index at coordinate `coord` (`x` for Horizontal, `y` for Vertical), or `nil`.
      def hit_test_divider(
        coord : Int32,
        x : Int32,
        y : Int32,
        width : Int32,
        height : Int32,
        tolerance : Int32 = 0,
      ) : Int32?
        return nil unless @show_separator && @separator_size > 0
        solve_into(@geometry_scratch, x, y, width, height)
        @geometry_scratch.each do |geom|
          div_pos = @orientation.horizontal? ? geom.divider_x : geom.divider_y
          if pos = div_pos
            if coord >= (pos - tolerance) && coord < (pos + @separator_size + tolerance)
              return geom.index
            end
          end
        end
        nil
      end

      # Returns the pane index containing `(px, py)`, or `nil`.
      def hit_test_pane(px : Int32, py : Int32, x : Int32, y : Int32, width : Int32, height : Int32) : Int32?
        solve_into(@geometry_scratch, x, y, width, height)
        @geometry_scratch.each do |geom|
          next if @panes[geom.index].collapsed?
          return geom.index if geom.contains?(px, py)
        end
        nil
      end

      private def sync_scratch_capacity : Nil
        while @extent_scratch.size < @panes.size
          @extent_scratch << 0
          @frozen_scratch << false
          @exact_scratch << 0.0
        end
      end

      private def ensure_valid_focus : Nil
        ring = focus_ring
        if ring.empty?
          @focused_index = 0
        elsif !ring.includes?(@focused_index)
          @focused_index = ring.first
        end
      end

      private def focus_target(target : Symbol | Int32 | String) : Nil
        case target
        when Int32
          focus_at(target)
        when Symbol, String
          focus_by_id(target)
        end
        ensure_valid_focus
      end

      private def default_pane_id(index : Int32) : String
        case index
        when 0 then "first"
        when 1 then "second"
        else        "pane_#{index}"
        end
      end

      private def focus_symbol_for_id(id : String, index : Int32) : Symbol
        case index
        when 0 then :first
        when 1 then :second
        when 2 then :third
        when 3 then :fourth
        else        :first
        end
      end

      private def record_announcement(message : String) : Nil
        @last_announcement = message
        @announcement_history << message
        if @announcement_history.size > 32
          @announcement_history.shift
        end
      end

      private def pane_display_label(index : Int32) : String
        if p = @panes[index]?
          if (t = p.title) && !t.strip.empty?
            t.strip
          else
            p.id
          end
        else
          "pane #{index + 1}"
        end
      end

      private def pane_share_percent(index : Int32) : Int32
        r = ratios
        val = r[index]? || 0.0
        (val * 100.0).round.to_i
      end

      private def axis_dimension_word : String
        @orientation.horizontal? ? "width" : "height"
      end

      private def build_focus_announcement : String
        return "Split layout empty" if @panes.empty?
        idx = @focused_index.clamp(0, @panes.size - 1)
        label = pane_display_label(idx)
        share = pane_share_percent(idx)
        dim = axis_dimension_word
        orient = @orientation.to_s.downcase
        state_suffix = @zoomed ? ", maximized" : ""
        "Focused pane #{idx + 1} of #{@panes.size}: #{label} (#{share}% #{dim}, #{orient} split#{state_suffix})"
      end

      private def build_resize_announcement(index : Int32) : String
        return "Split layout empty" if @panes.empty?
        idx = index.clamp(0, @panes.size - 1)
        label = pane_display_label(idx)
        share = pane_share_percent(idx)
        dim = axis_dimension_word
        "Resized pane #{idx + 1} of #{@panes.size}: #{label} to #{share}% #{dim}"
      end
    end
  end
end

require "json"
require "yaml"
require "../../terminal/ansi_parser"

module Opal
  module Input
    module Core
      # Supported physical input device categories across Opal TUIs, Godot 4.8 (Lapis), and PS2 (Citrine).
      enum DeviceType
        Keyboard
        Mouse
        Gamepad

        def to_s(io : IO) : Nil
          case self
          in Keyboard then io << "keyboard"
          in Mouse    then io << "mouse"
          in Gamepad  then io << "gamepad"
          end
        end

        def label : String
          case self
          in Keyboard then "Keyboard"
          in Mouse    then "Mouse"
          in Gamepad  then "Gamepad"
          end
        end

        def icon : String
          case self
          in Keyboard then "⌨"
          in Mouse    then "🖱"
          in Gamepad  then "🎮"
          end
        end

        def self.parse_device(value : DeviceType | Symbol | String) : DeviceType
          return value if value.is_a?(DeviceType)
          case value.to_s.downcase.strip
          when "keyboard", "key", "kb", "kbd"
            Keyboard
          when "mouse", "pointer", "cursor"
            Mouse
          when "gamepad", "pad", "joypad", "controller", "dualshock", "xinput"
            Gamepad
          else
            Keyboard
          end
        end
      end

      # Controller button glyph convention for localized/platform-authentic UI prompts.
      enum GamepadStyle
        DualShock # Sony PlayStation / Citrine PS2 (Cross, Circle, Square, Triangle)
        Xbox      # XInput / Standard PC (A, B, X, Y)
        Generic   # Generic numbered/directional labels

        def self.parse_style(value : GamepadStyle | Symbol | String) : GamepadStyle
          return value if value.is_a?(GamepadStyle)
          case value.to_s.downcase.strip
          when "dualshock", "ps2", "playstation", "sony", "citrine"
            DualShock
          when "xbox", "xinput", "pc"
            Xbox
          else
            Generic
          end
        end
      end

      # Export/import serialization formats for input binding profiles.
      enum RemapFormat
        JSON
        YAML
        LapisGodot # Godot 4.8 project.godot [input] section format

        def self.parse_format?(value : RemapFormat | Symbol | String) : RemapFormat?
          return value if value.is_a?(RemapFormat)
          case value.to_s.downcase.strip.lstrip('.')
          when "json"
            JSON
          when "yaml", "yml"
            YAML
          when "lapis", "godot", "lapis_godot", "cfg", "ini"
            LapisGodot
          else
            nil
          end
        end
      end

      # Pure value-type representing a single physical input trigger (key, mouse button, or gamepad button/axis).
      struct InputBinding
        property device : DeviceType
        property code : String
        property? ctrl : Bool
        property? alt : Bool
        property? shift : Bool
        property axis_direction : Int32 # -1, 0, or +1 for analog stick/trigger axes

        def initialize(
          @code : String,
          @device : DeviceType = DeviceType::Keyboard,
          @ctrl : Bool = false,
          @alt : Bool = false,
          @shift : Bool = false,
          @axis_direction : Int32 = 0,
        )
          @code = @code.strip.downcase
        end

        # Parses a human-readable descriptor string such as "ctrl+shift+s", "space",
        # "mouse:left", "pad:south", "gamepad:l2", "xbox:a", or "ps2:cross".
        def self.parse(descriptor : String, default_device : DeviceType = DeviceType::Keyboard) : InputBinding
          raw = descriptor.strip
          return new("", default_device) if raw.empty?

          device = default_device
          body = raw

          if colon_idx = raw.index(':')
            prefix = raw[0...colon_idx].downcase.strip
            rest = raw[(colon_idx + 1)..].strip
            case prefix
            when "key", "kb", "keyboard"
              device = DeviceType::Keyboard
              body = rest
            when "mouse", "pointer"
              device = DeviceType::Mouse
              body = rest
            when "pad", "gamepad", "joy", "joypad", "ps2", "xbox"
              device = DeviceType::Gamepad
              body = normalize_gamepad_code(rest)
            end
          elsif raw.downcase.starts_with?("mouse_")
            device = DeviceType::Mouse
            body = raw[6..].strip
          elsif raw.downcase.starts_with?("pad_") || raw.downcase.starts_with?("joy_")
            device = DeviceType::Gamepad
            body = normalize_gamepad_code(raw[4..].strip)
          end

          if device.keyboard?
            parts = body.downcase.split('+').map(&.strip).reject(&.empty?)
            ctrl = false
            alt = false
            shift = false
            base = ""

            parts.each do |p|
              case p
              when "ctrl", "control" then ctrl = true
              when "alt", "meta"     then alt = true
              when "shift"           then shift = true
              else
                base = normalize_key_code(p)
              end
            end

            new(base, DeviceType::Keyboard, ctrl: ctrl, alt: alt, shift: shift)
          elsif device.gamepad?
            axis_dir = 0
            clean = normalize_gamepad_code(body)
            if clean.ends_with?("+")
              axis_dir = 1
              clean = clean[0...-1]
            elsif clean.ends_with?("-")
              axis_dir = -1
              clean = clean[0...-1]
            end
            new(clean, DeviceType::Gamepad, axis_direction: axis_dir)
          else
            parts = body.downcase.split('+').map(&.strip).reject(&.empty?)
            ctrl = parts.includes?("ctrl")
            alt = parts.includes?("alt")
            shift = parts.includes?("shift")
            base = parts.reject { |p| p == "ctrl" || p == "alt" || p == "shift" }.first? || "left"
            new(base, DeviceType::Mouse, ctrl: ctrl, alt: alt, shift: shift)
          end
        end

        # Creates an InputBinding directly from a terminal KeyEvent.
        def self.from_key_event(event : Terminal::KeyEvent) : InputBinding
          code = normalize_key_code(event.name)
          new(
            code: code,
            device: DeviceType::Keyboard,
            ctrl: event.ctrl?,
            alt: event.alt?,
            shift: event.shift?
          )
        end

        # Creates an InputBinding directly from a terminal MouseEvent.
        def self.from_mouse_event(event : Terminal::MouseEvent) : InputBinding
          btn_code = case event.button
                     in Terminal::MouseButton::Left      then "left"
                     in Terminal::MouseButton::Middle    then "middle"
                     in Terminal::MouseButton::Right     then "right"
                     in Terminal::MouseButton::WheelUp   then "wheel_up"
                     in Terminal::MouseButton::WheelDown then "wheel_down"
                     in Terminal::MouseButton::None      then "none"
                     end
          new(
            code: btn_code,
            device: DeviceType::Mouse,
            ctrl: event.ctrl?,
            alt: event.alt?,
            shift: event.shift?
          )
        end

        def empty? : Bool
          @code.empty?
        end

        # Checks whether this binding matches a live Terminal::KeyEvent.
        def matches?(event : Terminal::KeyEvent) : Bool
          return false unless @device.keyboard?
          return false if @code.empty?
          event.matches?(descriptor)
        end

        # Checks whether this binding matches a live Terminal::MouseEvent.
        def matches?(event : Terminal::MouseEvent) : Bool
          return false unless @device.mouse?
          return false unless @ctrl == event.ctrl? && @alt == event.alt? && @shift == event.shift?
          expected = case event.button
                     in Terminal::MouseButton::Left      then "left"
                     in Terminal::MouseButton::Middle    then "middle"
                     in Terminal::MouseButton::Right     then "right"
                     in Terminal::MouseButton::WheelUp   then "wheel_up"
                     in Terminal::MouseButton::WheelDown then "wheel_down"
                     in Terminal::MouseButton::None      then "none"
                     end
          @code == expected
        end

        # Canonical string descriptor suitable for Opal::Input::KeyMap and serialization.
        def descriptor : String
          return "" if @code.empty?
          case @device
          in DeviceType::Keyboard
            parts = [] of String
            parts << "ctrl" if @ctrl
            parts << "alt" if @alt
            parts << "shift" if @shift
            parts << @code
            parts.join("+")
          in DeviceType::Mouse
            parts = [] of String
            parts << "ctrl" if @ctrl
            parts << "alt" if @alt
            parts << "shift" if @shift
            parts << @code
            "mouse:" + parts.join("+")
          in DeviceType::Gamepad
            suffix = @axis_direction > 0 ? "+" : (@axis_direction < 0 ? "-" : "")
            "pad:#{@code}#{suffix}"
          end
        end

        # Formats a human-friendly keycap badge label for UI rendering.
        def display_label(gamepad_style : GamepadStyle = GamepadStyle::DualShock) : String
          return "Unbound" if @code.empty?

          case @device
          in DeviceType::Keyboard
            parts = [] of String
            parts << "Ctrl" if @ctrl
            parts << "Alt" if @alt
            parts << "Shift" if @shift
            parts << format_key_cap(@code)
            parts.join("+")
          in DeviceType::Mouse
            parts = [] of String
            parts << "Ctrl" if @ctrl
            parts << "Alt" if @alt
            parts << "Shift" if @shift
            parts << format_mouse_cap(@code)
            parts.join("+")
          in DeviceType::Gamepad
            format_gamepad_cap(@code, @axis_direction, gamepad_style)
          end
        end

        # Converts this binding to its Godot 4.8 / Lapis key or joypad constant identifier.
        def to_lapis_symbol : String
          case @device
          in DeviceType::Keyboard
            "KEY_" + @code.upcase.gsub('-', '_')
          in DeviceType::Mouse
            case @code
            when "left"       then "MOUSE_BUTTON_LEFT"
            when "right"      then "MOUSE_BUTTON_RIGHT"
            when "middle"     then "MOUSE_BUTTON_MIDDLE"
            when "wheel_up"   then "MOUSE_BUTTON_WHEEL_UP"
            when "wheel_down" then "MOUSE_BUTTON_WHEEL_DOWN"
            else                   "MOUSE_BUTTON_LEFT"
            end
          in DeviceType::Gamepad
            case @code
            when "south"      then "JOY_BUTTON_A"
            when "east"       then "JOY_BUTTON_B"
            when "west"       then "JOY_BUTTON_X"
            when "north"      then "JOY_BUTTON_Y"
            when "l1"         then "JOY_BUTTON_LEFT_SHOULDER"
            when "r1"         then "JOY_BUTTON_RIGHT_SHOULDER"
            when "l2"         then "JOY_AXIS_TRIGGER_LEFT"
            when "r2"         then "JOY_AXIS_TRIGGER_RIGHT"
            when "l3"         then "JOY_BUTTON_LEFT_STICK"
            when "r3"         then "JOY_BUTTON_RIGHT_STICK"
            when "start"      then "JOY_BUTTON_START"
            when "select"     then "JOY_BUTTON_BACK"
            when "dpad_up"    then "JOY_BUTTON_DPAD_UP"
            when "dpad_down"  then "JOY_BUTTON_DPAD_DOWN"
            when "dpad_left"  then "JOY_BUTTON_DPAD_LEFT"
            when "dpad_right" then "JOY_BUTTON_DPAD_RIGHT"
            else                   "JOY_BUTTON_" + @code.upcase
            end
          end
        end

        def self.normalize_key_code(raw : String) : String
          case raw.downcase.strip
          when "esc"                then "escape"
          when "return", "\r", "\n" then "enter"
          when " "                  then "space"
          when "pageup", "pgup"     then "page_up"
          when "pagedown", "pgdn"   then "page_down"
          when "del"                then "delete"
          when "ins"                then "insert"
          when "bs"                 then "backspace"
          else                           raw.downcase.strip
          end
        end

        def self.normalize_gamepad_code(raw : String) : String
          case raw.downcase.strip
          when "cross", "a", "x_btn", "button_a", "south"
            "south"
          when "circle", "b", "button_b", "east"
            "east"
          when "square", "x", "button_x", "west"
            "west"
          when "triangle", "y", "button_y", "north"
            "north"
          when "lb", "l1", "left_shoulder"
            "l1"
          when "rb", "r1", "right_shoulder"
            "r1"
          when "lt", "l2", "left_trigger"
            "l2"
          when "rt", "r2", "right_trigger"
            "r2"
          when "ls", "l3", "left_stick"
            "l3"
          when "rs", "r3", "right_stick"
            "r3"
          when "back", "share", "select"
            "select"
          when "options", "menu", "start"
            "start"
          when "up", "dpad_up"
            "dpad_up"
          when "down", "dpad_down"
            "dpad_down"
          when "left", "dpad_left"
            "dpad_left"
          when "right", "dpad_right"
            "dpad_right"
          else
            raw.downcase.strip
          end
        end

        private def format_key_cap(code : String) : String
          case code
          when "space"     then "Space"
          when "enter"     then "Enter"
          when "escape"    then "Esc"
          when "tab"       then "Tab"
          when "backtab"   then "BackTab"
          when "backspace" then "Bksp"
          when "delete"    then "Del"
          when "insert"    then "Ins"
          when "up"        then "↑ Up"
          when "down"      then "↓ Down"
          when "left"      then "← Left"
          when "right"     then "→ Right"
          when "page_up"   then "PgUp"
          when "page_down" then "PgDn"
          when "home"      then "Home"
          when "end"       then "End"
          else
            code.size == 1 ? code.upcase : code.upcase
          end
        end

        private def format_mouse_cap(code : String) : String
          case code
          when "left"       then "Mouse Left"
          when "right"      then "Mouse Right"
          when "middle"     then "Mouse Mid"
          when "wheel_up"   then "Wheel Up"
          when "wheel_down" then "Wheel Down"
          else                   "Mouse #{code.capitalize}"
          end
        end

        private def format_gamepad_cap(code : String, axis_dir : Int32, style : GamepadStyle) : String
          case code
          when "south"
            case style
            in GamepadStyle::DualShock then "✕ Cross"
            in GamepadStyle::Xbox      then "(A) South"
            in GamepadStyle::Generic   then "Btn South"
            end
          when "east"
            case style
            in GamepadStyle::DualShock then "○ Circle"
            in GamepadStyle::Xbox      then "(B) East"
            in GamepadStyle::Generic   then "Btn East"
            end
          when "west"
            case style
            in GamepadStyle::DualShock then "□ Square"
            in GamepadStyle::Xbox      then "(X) West"
            in GamepadStyle::Generic   then "Btn West"
            end
          when "north"
            case style
            in GamepadStyle::DualShock then "△ Triangle"
            in GamepadStyle::Xbox      then "(Y) North"
            in GamepadStyle::Generic   then "Btn North"
            end
          when "l1"
            style.xbox? ? "LB" : "L1"
          when "r1"
            style.xbox? ? "RB" : "R1"
          when "l2"
            style.xbox? ? "LT" : "L2"
          when "r2"
            style.xbox? ? "RT" : "R2"
          when "l3"
            style.xbox? ? "LS" : "L3"
          when "r3"
            style.xbox? ? "RS" : "R3"
          when "start"
            "Start"
          when "select"
            style.xbox? ? "Back" : "Select"
          when "dpad_up"
            "D-Pad ↑"
          when "dpad_down"
            "D-Pad ↓"
          when "dpad_left"
            "D-Pad ←"
          when "dpad_right"
            "D-Pad →"
          else
            dir_str = axis_dir > 0 ? "+" : (axis_dir < 0 ? "-" : "")
            "Pad #{code.upcase}#{dir_str}"
          end
        end
      end

      # Represents a conflicting input assignment between two actions in the same or global context.
      struct BindingConflict
        getter action_a : String
        getter action_b : String
        getter slot_a : Int32
        getter slot_b : Int32
        getter binding : InputBinding

        def initialize(
          @action_a : String,
          @action_b : String,
          @slot_a : Int32,
          @slot_b : Int32,
          @binding : InputBinding,
        )
        end

        def involves?(action_id : String) : Bool
          @action_a == action_id || @action_b == action_id
        end

        def involves?(action_id : String, slot : Int32) : Bool
          (@action_a == action_id && @slot_a == slot) || (@action_b == action_id && @slot_b == slot)
        end

        def other_action(action_id : String) : String
          @action_a == action_id ? @action_b : @action_a
        end
      end

      # Policy for handling duplicate binding assignments during interactive capture.
      enum ConflictPolicy
        Allow   # Permit duplicate bindings while surfacing visual warning badges
        Swap    # Swap the conflicting binding with the previous binding of the target slot
        Replace # Clear the conflicting slot on the other action and assign to the current slot
        Block   # Reject assigning a binding that is already bound to another action

        def self.parse_policy(value : ConflictPolicy | Symbol | String) : ConflictPolicy
          return value if value.is_a?(ConflictPolicy)
          case value.to_s.downcase.strip
          when "swap"             then Swap
          when "replace", "steal" then Replace
          when "block", "reject"  then Block
          else                         Allow
          end
        end
      end

      # Represents a single logical action (e.g., "move_up", "jump", "ui_accept") and its multi-slot bindings.
      class InputAction
        getter id : String
        property label : String
        property category : String
        property description : String
        property deadzone : Float32
        property? locked : Bool
        getter bindings : Array(InputBinding?)
        getter default_bindings : Array(InputBinding?)

        def initialize(
          @id : String,
          label : String? = nil,
          @category : String = "General",
          @description : String = "",
          @deadzone : Float32 = 0.2_f32,
          @locked : Bool = false,
          max_slots : Int32 = 2,
          initial_bindings : Array(InputBinding?)? = nil,
        )
          @label = label || format_id_label(@id)
          slots = Math.max(1, max_slots)
          @bindings = Array(InputBinding?).new(slots, nil)
          if init = initial_bindings
            init.each_with_index do |b, i|
              break if i >= slots
              @bindings[i] = b
            end
          end
          @default_bindings = @bindings.dup
        end

        def max_slots : Int32
          @bindings.size
        end

        def primary : InputBinding?
          @bindings[0]? || nil
        end

        def secondary : InputBinding?
          @bindings[1]? || nil
        end

        def binding_at(slot : Int32) : InputBinding?
          @bindings[slot]? || nil
        end

        def set_binding(slot : Int32, binding : InputBinding?, update_default : Bool = false) : Bool
          return false if @locked && !update_default
          return false unless slot >= 0 && slot < @bindings.size
          @bindings[slot] = (binding && !binding.empty?) ? binding : nil
          @default_bindings[slot] = @bindings[slot] if update_default
          true
        end

        def clear_slot(slot : Int32) : Bool
          return false if @locked
          return false unless slot >= 0 && slot < @bindings.size
          @bindings[slot] = nil
          true
        end

        def clear_all : Bool
          return false if @locked
          @bindings.fill(nil)
          true
        end

        def reset_to_defaults! : Bool
          return false if @locked
          @default_bindings.each_with_index do |b, i|
            @bindings[i] = b if i < @bindings.size
          end
          true
        end

        def modified? : Bool
          @bindings != @default_bindings
        end

        def active_bindings : Array(InputBinding)
          res = [] of InputBinding
          @bindings.each do |b|
            res << b if b && !b.empty?
          end
          res
        end

        def matches?(event : Terminal::KeyEvent) : Bool
          @bindings.any? { |b| b ? b.matches?(event) : false }
        end

        def matches?(event : Terminal::MouseEvent) : Bool
          @bindings.any? { |b| b ? b.matches?(event) : false }
        end

        def search_text : String
          bind_labels = active_bindings.map(&.display_label).join(" ")
          "#{@category} #{@label} #{@id} #{@description} #{bind_labels}"
        end

        private def format_id_label(raw_id : String) : String
          raw_id.split(/[_\-\.]/).reject(&.empty?).map(&.capitalize).join(" ")
        end
      end

      # Tier-1 Core Engine Model managing a complete profile of input actions,
      # categories, multi-slot bindings, conflict resolution, Lapis/Godot export, and KeyMap synchronization.
      class InputRemapModel
        property profile_name : String
        property max_slots : Int32
        property conflict_policy : ConflictPolicy
        property gamepad_style : GamepadStyle
        property? allow_clear : Bool
        property? allow_reset : Bool
        getter actions : Array(InputAction)

        def initialize(
          @profile_name : String = "Default Controls",
          @max_slots : Int32 = 2,
          @conflict_policy : ConflictPolicy = ConflictPolicy::Allow,
          @gamepad_style : GamepadStyle = GamepadStyle::DualShock,
          @allow_clear : Bool = true,
          @allow_reset : Bool = true,
          actions : Array(InputAction)? = nil,
        )
          @max_slots = Math.max(1, @max_slots)
          @actions = actions ? actions.dup : [] of InputAction
        end

        # Creates a standard game + TUI default profile if needed.
        def self.default_profile(profile_name : String = "Default Controls") : InputRemapModel
          model = new(profile_name: profile_name)
          model.add_action("move_up", "Move Up", category: "Movement", primary: "w", secondary: "up")
          model.add_action("move_down", "Move Down", category: "Movement", primary: "s", secondary: "down")
          model.add_action("move_left", "Move Left", category: "Movement", primary: "a", secondary: "left")
          model.add_action("move_right", "Move Right", category: "Movement", primary: "d", secondary: "right")
          model.add_action("jump", "Jump / Accept", category: "Gameplay", primary: "space", secondary: "pad:south")
          model.add_action("attack", "Primary Action", category: "Gameplay", primary: "j", secondary: "pad:west")
          model.add_action("interact", "Interact / Use", category: "Gameplay", primary: "e", secondary: "pad:north")
          model.add_action("pause", "Pause Menu", category: "System", primary: "escape", secondary: "pad:start")
          model
        end

        def size : Int32
          @actions.size
        end

        def empty? : Bool
          @actions.empty?
        end

        # Distinct action categories in registration order.
        def categories : Array(String)
          cats = [] of String
          @actions.each do |act|
            cats << act.category unless cats.includes?(act.category)
          end
          cats
        end

        def action_at(index : Int32) : InputAction?
          @actions[index]?
        end

        def find_action(id : String | Symbol) : InputAction?
          key = id.to_s
          @actions.find { |a| a.id == key }
        end

        def index_of(id : String | Symbol) : Int32?
          key = id.to_s
          @actions.index { |a| a.id == key }
        end

        # Registers or updates an InputAction in the profile.
        def add_action(
          id : String | Symbol,
          label : String? = nil,
          category : String = "General",
          description : String = "",
          primary : InputBinding | String | Nil = nil,
          secondary : InputBinding | String | Nil = nil,
          deadzone : Float32 = 0.2_f32,
          locked : Bool = false,
        ) : InputAction
          act_id = id.to_s
          p_bind = parse_binding_arg(primary)
          s_bind = parse_binding_arg(secondary)

          init_binds = Array(InputBinding?).new(@max_slots, nil)
          init_binds[0] = p_bind if @max_slots >= 1
          init_binds[1] = s_bind if @max_slots >= 2

          if existing = find_action(act_id)
            existing.label = label if label
            existing.category = category
            existing.description = description unless description.empty?
            existing.deadzone = deadzone
            existing.set_binding(0, p_bind, update_default: true) if primary
            existing.set_binding(1, s_bind, update_default: true) if secondary && @max_slots >= 2
            existing.locked = locked
            return existing
          end

          action = InputAction.new(
            id: act_id,
            label: label,
            category: category,
            description: description,
            deadzone: deadzone,
            locked: locked,
            max_slots: @max_slots,
            initial_bindings: init_binds
          )
          @actions << action
          action
        end

        def add(action : InputAction) : InputAction
          @actions << action
          action
        end

        # Assigns a binding to an action's slot while applying the configured ConflictPolicy.
        # Returns true if assignment succeeded, false if blocked or invalid.
        def assign_binding(
          action_id : String | Symbol,
          slot : Int32,
          binding : InputBinding | String,
          policy : ConflictPolicy? = nil,
        ) : Bool
          target = find_action(action_id)
          return false unless target
          return false if target.locked?
          return false unless slot >= 0 && slot < target.max_slots

          resolved = binding.is_a?(InputBinding) ? binding : InputBinding.parse(binding)
          return false if resolved.empty?

          effective_policy = policy || @conflict_policy

          # If the exact same binding is already in another slot of the SAME action, clear that other slot
          (0...target.max_slots).each do |other_slot|
            next if other_slot == slot
            if existing_same = target.binding_at(other_slot)
              if existing_same == resolved
                target.clear_slot(other_slot)
              end
            end
          end

          # Check conflicts across other actions in the same category or global ("System" / "Global")
          conflicting = find_conflicting_slot(target, resolved)

          if conflict_info = conflicting
            other_action, other_slot = conflict_info
            case effective_policy
            in ConflictPolicy::Block
              return false
            in ConflictPolicy::Replace
              return false if other_action.locked?
              other_action.clear_slot(other_slot)
            in ConflictPolicy::Swap
              return false if other_action.locked?
              prev_binding = target.binding_at(slot)
              other_action.set_binding(other_slot, prev_binding)
            in ConflictPolicy::Allow
              # Allow duplicate binding; conflicts getter will report it
            end
          end

          target.set_binding(slot, resolved)
        end

        # Assigns a binding by action index.
        def assign_binding_at(
          action_index : Int32,
          slot : Int32,
          binding : InputBinding | String,
          policy : ConflictPolicy? = nil,
        ) : Bool
          if act = action_at(action_index)
            assign_binding(act.id, slot, binding, policy)
          else
            false
          end
        end

        def clear_slot(action_id : String | Symbol, slot : Int32) : Bool
          return false unless @allow_clear
          if act = find_action(action_id)
            act.clear_slot(slot)
          else
            false
          end
        end

        def reset_action(action_id : String | Symbol) : Bool
          return false unless @allow_reset
          if act = find_action(action_id)
            act.reset_to_defaults!
          else
            false
          end
        end

        def reset_all! : Bool
          return false unless @allow_reset
          @actions.each(&.reset_to_defaults!)
          true
        end

        # Computes all active duplicate binding conflicts across actions that share scope.
        def conflicts : Array(BindingConflict)
          list = [] of BindingConflict
          n = @actions.size
          (0...n).each do |i|
            act_a = @actions[i]
            (0...act_a.max_slots).each do |slot_a|
              bind_a = act_a.binding_at(slot_a)
              next unless bind_a && !bind_a.empty?

              ((i + 1)...n).each do |j|
                act_b = @actions[j]
                next unless scopes_overlap?(act_a.category, act_b.category)

                (0...act_b.max_slots).each do |slot_b|
                  bind_b = act_b.binding_at(slot_b)
                  next unless bind_b && !bind_b.empty?

                  if bind_a == bind_b
                    list << BindingConflict.new(
                      action_a: act_a.id,
                      action_b: act_b.id,
                      slot_a: slot_a,
                      slot_b: slot_b,
                      binding: bind_a
                    )
                  end
                end
              end
            end
          end
          list
        end

        def has_conflicts? : Bool
          !conflicts.empty?
        end

        def conflicts_for(action_id : String | Symbol) : Array(BindingConflict)
          key = action_id.to_s
          conflicts.select(&.involves?(key))
        end

        def slot_conflicted?(action_id : String | Symbol, slot : Int32) : Bool
          key = action_id.to_s
          conflicts.any?(&.involves?(key, slot))
        end

        # Checks whether a live event triggers the given action ID.
        def action_pressed?(action_id : String | Symbol, event : Terminal::KeyEvent | Terminal::MouseEvent) : Bool
          if act = find_action(action_id)
            act.matches?(event)
          else
            false
          end
        end

        # Returns all action IDs triggered by the given input event.
        def triggered_actions(event : Terminal::KeyEvent | Terminal::MouseEvent) : Array(String)
          matched = [] of String
          @actions.each do |act|
            matched << act.id if act.matches?(event)
          end
          matched
        end

        # Builds an Opal::Input::KeyMap wired to the current bindings in this model.
        def to_key_map(&on_trigger : String, Terminal::KeyEvent -> Nil) : KeyMap
          km = KeyMap.new
          @actions.each do |act|
            keys = [] of String
            act.active_bindings.each do |b|
              keys << b.descriptor if b.device.keyboard?
            end
            unless keys.empty?
              act_id = act.id
              km.on(keys) do |ev|
                on_trigger.call(act_id, ev)
              end
            end
          end
          km
        end

        # Builds a Footer binding badge array (`Array(NamedTuple(key: String, desc: String))`)
        # from the primary bindings of the actions in this model.
        def to_footer_bindings(category : String? = nil, limit : Int32 = 6) : Array(NamedTuple(key: String, desc: String))
          result = [] of NamedTuple(key: String, desc: String)
          @actions.each do |act|
            next if category && act.category != category
            if pri = act.primary
              result << {key: pri.display_label(@gamepad_style), desc: act.label}
              break if result.size >= limit
            end
          end
          result
        end

        # --- Serialization & Export (JSON, YAML, Lapis/Godot 4.8) ---

        def to_json_string(pretty : Bool = true) : String
          String.build do |io|
            builder = JSON::Builder.new(io)
            builder.indent = "  " if pretty
            builder.document do
              builder.object do
                builder.field "profile_name", @profile_name
                builder.field "max_slots", @max_slots
                builder.field "gamepad_style", @gamepad_style.to_s.downcase
                builder.field "actions" do
                  builder.array do
                    @actions.each do |act|
                      builder.object do
                        builder.field "id", act.id
                        builder.field "label", act.label
                        builder.field "category", act.category
                        builder.field "deadzone", act.deadzone.round(3)
                        builder.field "locked", act.locked?
                        builder.field "bindings" do
                          builder.array do
                            act.bindings.each do |b|
                              builder.string(b ? b.descriptor : "")
                            end
                          end
                        end
                      end
                    end
                  end
                end
              end
            end
          end
        end

        def to_yaml_string : String
          String.build do |io|
            YAML.build(io) do |yaml|
              yaml.mapping do
                yaml.scalar "profile_name"
                yaml.scalar @profile_name
                yaml.scalar "max_slots"
                yaml.scalar @max_slots
                yaml.scalar "gamepad_style"
                yaml.scalar @gamepad_style.to_s.downcase
                yaml.scalar "actions"
                yaml.sequence do
                  @actions.each do |act|
                    yaml.mapping do
                      yaml.scalar "id"
                      yaml.scalar act.id
                      yaml.scalar "label"
                      yaml.scalar act.label
                      yaml.scalar "category"
                      yaml.scalar act.category
                      yaml.scalar "deadzone"
                      yaml.scalar act.deadzone.round(3)
                      yaml.scalar "locked"
                      yaml.scalar act.locked?
                      yaml.scalar "bindings"
                      yaml.sequence do
                        act.bindings.each do |b|
                          yaml.scalar(b ? b.descriptor : "")
                        end
                      end
                    end
                  end
                end
              end
            end
          end
        end

        # Exports bindings in Godot 4.8 / Lapis InputMap configuration format (`[input]`).
        def to_lapis_config : String
          String.build do |io|
            io << "# Lapis / Godot 4.8 InputMap Profile: #{@profile_name}\n"
            io << "[input]\n\n"
            @actions.each do |act|
              events_str = act.active_bindings.map do |b|
                "{\"device\": \"#{b.device}\", \"symbol\": \"#{b.to_lapis_symbol}\", \"descriptor\": \"#{b.descriptor}\"}"
              end.join(", ")
              io << "#{act.id}={\n"
              io << "\"deadzone\": #{act.deadzone.round(2)},\n"
              io << "\"events\": [#{events_str}]\n"
              io << "}\n\n"
            end
          end
        end

        def export(format : RemapFormat | Symbol | String = RemapFormat::JSON) : String
          fmt = RemapFormat.parse_format?(format) || RemapFormat::JSON
          case fmt
          in RemapFormat::JSON       then to_json_string
          in RemapFormat::YAML       then to_yaml_string
          in RemapFormat::LapisGodot then to_lapis_config
          end
        end

        def self.from_json_string(content : String) : InputRemapModel
          parsed = JSON.parse(content)
          prof_name = parsed["profile_name"]?.try(&.as_s?) || "Imported Profile"
          slots = parsed["max_slots"]?.try(&.as_i?) || 2
          g_style = GamepadStyle.parse_style(parsed["gamepad_style"]?.try(&.as_s?) || "dualshock")

          model = new(profile_name: prof_name, max_slots: slots, gamepad_style: g_style)

          if actions_arr = parsed["actions"]?.try(&.as_a?)
            actions_arr.each do |item|
              id = item["id"]?.try(&.as_s?) || next
              label = item["label"]?.try(&.as_s?)
              category = item["category"]?.try(&.as_s?) || "General"
              deadzone = item["deadzone"]?.try(&.as_f?.try(&.to_f32)) || 0.2_f32
              locked = item["locked"]?.try(&.as_bool?) || false

              binds = Array(InputBinding?).new(slots, nil)
              if b_arr = item["bindings"]?.try(&.as_a?)
                b_arr.each_with_index do |b_val, idx|
                  break if idx >= slots
                  desc = b_val.as_s? || ""
                  binds[idx] = InputBinding.parse(desc) unless desc.empty?
                end
              end

              model.add(InputAction.new(
                id: id,
                label: label,
                category: category,
                deadzone: deadzone,
                locked: locked,
                max_slots: slots,
                initial_bindings: binds
              ))
            end
          end

          model
        end

        def self.from_yaml_string(content : String) : InputRemapModel
          parsed = YAML.parse(content)
          prof_name = parsed["profile_name"]?.try(&.as_s?) || "Imported Profile"
          slots = parsed["max_slots"]?.try(&.as_i?) || 2
          g_style = GamepadStyle.parse_style(parsed["gamepad_style"]?.try(&.as_s?) || "dualshock")

          model = new(profile_name: prof_name, max_slots: slots, gamepad_style: g_style)

          if actions_arr = parsed["actions"]?.try(&.as_a?)
            actions_arr.each do |item|
              id = item["id"]?.try(&.as_s?) || next
              label = item["label"]?.try(&.as_s?)
              category = item["category"]?.try(&.as_s?) || "General"
              deadzone = item["deadzone"]?.try(&.as_f?.try(&.to_f32)) || 0.2_f32
              locked = item["locked"]?.try(&.as_bool?) || false

              binds = Array(InputBinding?).new(slots, nil)
              if b_arr = item["bindings"]?.try(&.as_a?)
                b_arr.each_with_index do |b_val, idx|
                  break if idx >= slots
                  desc = b_val.as_s? || ""
                  binds[idx] = InputBinding.parse(desc) unless desc.empty?
                end
              end

              model.add(InputAction.new(
                id: id,
                label: label,
                category: category,
                deadzone: deadzone,
                locked: locked,
                max_slots: slots,
                initial_bindings: binds
              ))
            end
          end

          model
        end

        def self.from_content(content : String, format : RemapFormat? = nil) : InputRemapModel
          trimmed = content.strip
          fmt = format || (trimmed.starts_with?("{") ? RemapFormat::JSON : RemapFormat::YAML)
          case fmt
          in RemapFormat::JSON       then from_json_string(trimmed)
          in RemapFormat::YAML       then from_yaml_string(trimmed)
          in RemapFormat::LapisGodot then default_profile
          end
        end

        def self.from_file(path : String) : InputRemapModel
          ext = File.extname(path).downcase
          fmt = RemapFormat.parse_format?(ext)
          from_content(File.read(path), fmt)
        end

        private def parse_binding_arg(arg : InputBinding | String | Nil) : InputBinding?
          case arg
          when InputBinding
            arg.empty? ? nil : arg
          when String
            trimmed = arg.strip
            trimmed.empty? ? nil : InputBinding.parse(trimmed)
          else
            nil
          end
        end

        private def scopes_overlap?(cat_a : String, cat_b : String) : Bool
          return true if cat_a == cat_b
          a_lower = cat_a.downcase
          b_lower = cat_b.downcase
          a_lower == "global" || b_lower == "global" || a_lower == "system" || b_lower == "system"
        end

        private def find_conflicting_slot(target : InputAction, binding : InputBinding) : Tuple(InputAction, Int32)?
          @actions.each do |other|
            next if other.id == target.id
            next unless scopes_overlap?(target.category, other.category)
            (0...other.max_slots).each do |slot_idx|
              if b = other.binding_at(slot_idx)
                return {other, slot_idx} if b == binding
              end
            end
          end
          nil
        end
      end
    end

    # Expose core types cleanly under Opal::Input and Opal top-level
    alias DeviceType = Core::DeviceType
    alias GamepadStyle = Core::GamepadStyle
    alias RemapFormat = Core::RemapFormat
    alias InputBinding = Core::InputBinding
    alias BindingConflict = Core::BindingConflict
    alias ConflictPolicy = Core::ConflictPolicy
    alias InputAction = Core::InputAction
    alias InputRemapModel = Core::InputRemapModel
  end

  alias InputBinding = Input::Core::InputBinding
  alias InputAction = Input::Core::InputAction
  alias InputRemapModel = Input::Core::InputRemapModel
  alias ConflictPolicy = Input::Core::ConflictPolicy
  alias GamepadStyle = Input::Core::GamepadStyle
  alias RemapFormat = Input::Core::RemapFormat
end

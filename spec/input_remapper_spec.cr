require "./spec_helper"

describe "Opal Declarative Input Remapping (Tier 1 Core & Tier 2 DSL & UI)" do
  describe Opal::Input::Core::InputBinding do
    it "parses keyboard, mouse, and gamepad descriptors cleanly" do
      kb = Opal::InputBinding.parse("ctrl+shift+s")
      kb.device.should eq(Opal::Input::DeviceType::Keyboard)
      kb.code.should eq("s")
      kb.ctrl?.should be_true
      kb.shift?.should be_true
      kb.alt?.should be_false
      kb.descriptor.should eq("ctrl+shift+s")
      kb.display_label.should eq("Ctrl+Shift+S")
      kb.to_lapis_symbol.should eq("KEY_S")

      mouse = Opal::InputBinding.parse("mouse:right")
      mouse.device.should eq(Opal::Input::DeviceType::Mouse)
      mouse.code.should eq("right")
      mouse.descriptor.should eq("mouse:right")
      mouse.display_label.should eq("Mouse Right")
      mouse.to_lapis_symbol.should eq("MOUSE_BUTTON_RIGHT")

      pad = Opal::InputBinding.parse("ps2:cross")
      pad.device.should eq(Opal::Input::DeviceType::Gamepad)
      pad.code.should eq("south")
      pad.descriptor.should eq("pad:south")
      pad.display_label(Opal::GamepadStyle::DualShock).should eq("✕ Cross")
      pad.display_label(Opal::GamepadStyle::Xbox).should eq("(A) South")
      pad.to_lapis_symbol.should eq("JOY_BUTTON_A")
    end

    it "matches live Terminal::KeyEvent and Terminal::MouseEvent instances" do
      kb = Opal::InputBinding.parse("ctrl+s")
      ev_match = Opal::Terminal::KeyEvent.new("s", 's', ctrl: true)
      ev_miss = Opal::Terminal::KeyEvent.new("s", 's', ctrl: false)
      kb.matches?(ev_match).should be_true
      kb.matches?(ev_miss).should be_false

      mouse = Opal::InputBinding.parse("mouse:left")
      m_ev = Opal::Terminal::MouseEvent.new(10, 5, Opal::Terminal::MouseButton::Left, Opal::Terminal::MouseAction::Press)
      mouse.matches?(m_ev).should be_true
    end
  end

  describe Opal::Input::Core::InputRemapModel do
    it "builds profiles via Tier-2 Dual-Mode DSL (implicit and explicit receivers)" do
      model = Opal.input_map("Lapis Arena Controls", conflict_policy: :swap, gamepad_style: :dualshock) do
        category "Movement" do
          action :move_up, "Move Up", primary: "w", secondary: "up"
          action :move_down, "Move Down", primary: "s", secondary: "down"
        end

        category "Combat" do |c|
          c.action :jump, "Jump", primary: "space", secondary: "pad:south" do
            deadzone 0.15
          end
          c.bind :attack, "j", "pad:west", label: "Light Attack"
        end

        action :pause, "Pause Game", category: "System", primary: "escape", locked: true
      end

      model.profile_name.should eq("Lapis Arena Controls")
      model.size.should eq(5)
      model.categories.should eq(["Movement", "Combat", "System"])
      model.conflict_policy.should eq(Opal::ConflictPolicy::Swap)

      jump_act = model.find_action(:jump).not_nil!
      jump_act.primary.not_nil!.descriptor.should eq("space")
      jump_act.secondary.not_nil!.descriptor.should eq("pad:south")
      jump_act.deadzone.should be_close(0.15_f32, 0.001_f32)

      pause_act = model.find_action(:pause).not_nil!
      pause_act.locked?.should be_true
    end

    it "enforces conflict resolution policies (Allow, Swap, Replace, Block)" do
      # 1. Allow policy detects conflicts
      model_allow = Opal.input_map(conflict_policy: :allow) do
        category "Gameplay" do
          action :jump, "Jump", primary: "space"
          action :dodge, "Dodge", primary: "shift"
        end
      end
      model_allow.assign_binding(:dodge, 0, "space").should be_true
      model_allow.has_conflicts?.should be_true
      model_allow.conflicts.size.should eq(1)
      model_allow.slot_conflicted?(:jump, 0).should be_true
      model_allow.slot_conflicted?(:dodge, 0).should be_true

      # 2. Swap policy exchanges bindings cleanly without leaving conflicts
      model_swap = Opal.input_map(conflict_policy: :swap) do
        category "Gameplay" do
          action :jump, "Jump", primary: "space"
          action :dodge, "Dodge", primary: "c"
        end
      end
      model_swap.assign_binding(:dodge, 0, "space").should be_true
      model_swap.has_conflicts?.should be_false
      model_swap.find_action(:dodge).not_nil!.primary.not_nil!.descriptor.should eq("space")
      model_swap.find_action(:jump).not_nil!.primary.not_nil!.descriptor.should eq("c")

      # 3. Replace policy steals binding and clears the previous owner's slot
      model_replace = Opal.input_map(conflict_policy: :replace) do
        category "Gameplay" do
          action :jump, "Jump", primary: "space"
          action :dodge, "Dodge", primary: "c"
        end
      end
      model_replace.assign_binding(:dodge, 0, "space").should be_true
      model_replace.find_action(:dodge).not_nil!.primary.not_nil!.descriptor.should eq("space")
      model_replace.find_action(:jump).not_nil!.primary.should be_nil

      # 4. Block policy rejects conflicting binding
      model_block = Opal.input_map(conflict_policy: :block) do
        category "Gameplay" do
          action :jump, "Jump", primary: "space"
          action :dodge, "Dodge", primary: "c"
        end
      end
      model_block.assign_binding(:dodge, 0, "space").should be_false
      model_block.find_action(:dodge).not_nil!.primary.not_nil!.descriptor.should eq("c")
    end

    it "protects locked actions from modification or conflict stealing" do
      model = Opal.input_map(conflict_policy: :replace) do
        category "System" do
          action :pause, "Pause", primary: "escape", locked: true
          action :cancel, "Cancel", primary: "backspace"
        end
      end

      model.assign_binding(:pause, 0, "p").should be_false
      model.clear_slot(:pause, 0).should be_false
      model.assign_binding(:cancel, 0, "escape").should be_false
      model.find_action(:pause).not_nil!.primary.not_nil!.descriptor.should eq("escape")
    end

    it "generates working Opal::Input::KeyMap and Footer badge tuples" do
      model = Opal.input_map do
        action :confirm, "Confirm", primary: "enter", secondary: "space"
        action :quit, "Quit", primary: "q"
      end

      triggered = [] of String
      keymap = model.to_key_map do |act_id, _ev|
        triggered << act_id
      end

      keymap.handle(Opal::Terminal::KeyEvent.new("space", ' ')).should be_true
      keymap.handle(Opal::Terminal::KeyEvent.new("q", 'q')).should be_true
      triggered.should eq(["confirm", "quit"])

      badges = model.to_footer_bindings
      badges.size.should eq(2)
      badges[0][:key].should eq("Enter")
      badges[0][:desc].should eq("Confirm")
    end

    it "round-trips JSON, YAML, and exports Lapis/Godot 4.8 [input] configuration" do
      model = Opal.input_map("Citrine & Lapis Controls", gamepad_style: :dualshock) do
        category "Movement" do
          action :jump, "Jump", primary: "space", secondary: "pad:south", deadzone: 0.25
        end
      end

      json_str = model.export(:json)
      re_json = Opal::InputRemapModel.from_content(json_str, Opal::RemapFormat::JSON)
      re_json.profile_name.should eq("Citrine & Lapis Controls")
      re_json.find_action(:jump).not_nil!.primary.not_nil!.descriptor.should eq("space")
      re_json.find_action(:jump).not_nil!.secondary.not_nil!.descriptor.should eq("pad:south")

      yaml_str = model.export(:yaml)
      re_yaml = Opal::InputRemapModel.from_content(yaml_str, Opal::RemapFormat::YAML)
      re_yaml.profile_name.should eq("Citrine & Lapis Controls")
      re_yaml.find_action(:jump).not_nil!.secondary.not_nil!.descriptor.should eq("pad:south")

      lapis_cfg = model.export(:lapis)
      lapis_cfg.should contain("[input]")
      lapis_cfg.should contain("jump={")
      lapis_cfg.should contain("KEY_SPACE")
      lapis_cfg.should contain("JOY_BUTTON_A")
    end
  end

  describe Opal::UI::InputRemapper do
    it "supports navigation, live key capture, mouse capture, clearing, and reset to defaults" do
      remapper = Opal::UI::InputRemapper.new("Controls") do
        category "Movement" do
          action :up, "Move Up", primary: "w", secondary: "up"
          action :down, "Move Down", primary: "s", secondary: "down"
        end
        category "Actions" do
          action :fire, "Fire Weapon", primary: "j", secondary: "mouse:left"
        end
      end

      remapper.visible_actions.size.should eq(3)
      remapper.cursor.should eq(0)
      remapper.active_slot.should eq(0)

      # Move down to 'Move Down' and right to secondary slot
      remapper.handle_key(Opal::Terminal::KeyEvent.new("down")).should be_true
      remapper.cursor.should eq(1)
      remapper.handle_key(Opal::Terminal::KeyEvent.new("right")).should be_true
      remapper.active_slot.should eq(1)

      # Press Enter to enter live capture mode
      remapper.handle_key(Opal::Terminal::KeyEvent.new("enter")).should be_true
      remapper.capturing?.should be_true

      # Press 'k' to bind 'Move Down' secondary slot to 'k'
      remapper.handle_key(Opal::Terminal::KeyEvent.new("k", 'k')).should be_true
      remapper.capturing?.should be_false
      remapper.model.find_action(:down).not_nil!.secondary.not_nil!.descriptor.should eq("k")
      remapper.model.find_action(:down).not_nil!.modified?.should be_true

      # Clear slot with 'x'
      remapper.handle_key(Opal::Terminal::KeyEvent.new("x", 'x')).should be_true
      remapper.model.find_action(:down).not_nil!.secondary.should be_nil

      # Reset action to defaults with 'r'
      remapper.handle_key(Opal::Terminal::KeyEvent.new("r", 'r')).should be_true
      remapper.model.find_action(:down).not_nil!.secondary.not_nil!.descriptor.should eq("down")
      remapper.model.find_action(:down).not_nil!.modified?.should be_false

      # Capture mouse button in capture mode
      remapper.handle_key(Opal::Terminal::KeyEvent.new("enter")).should be_true
      remapper.capturing?.should be_true
      mouse_right = Opal::Terminal::MouseEvent.new(15, 8, Opal::Terminal::MouseButton::Right, Opal::Terminal::MouseAction::Press)
      remapper.handle_mouse(mouse_right).should be_true
      remapper.capturing?.should be_false
      remapper.model.find_action(:down).not_nil!.secondary.not_nil!.descriptor.should eq("mouse:right")
    end

    it "supports category tab switching, deadzone adjustment, gamepad style cycling, and fuzzy filtering" do
      remapper = Opal::UI::InputRemapper.new("Game Controls") do
        category "Movement" do
          action :up, "Move Up", primary: "w"
        end
        category "Combat" do
          action :attack, "Heavy Attack", primary: "space", secondary: "pad:south"
        end
      end

      # Switch category via Tab
      remapper.selected_category.should be_nil
      remapper.handle_key(Opal::Terminal::KeyEvent.new("tab")).should be_true
      remapper.selected_category.should eq("Movement")
      remapper.visible_actions.size.should eq(1)

      remapper.handle_key(Opal::Terminal::KeyEvent.new("tab")).should be_true
      remapper.selected_category.should eq("Combat")
      remapper.visible_actions.first.id.should eq("attack")

      # Adjust deadzone with '+'
      remapper.handle_key(Opal::Terminal::KeyEvent.new("+", '+')).should be_true
      remapper.selected_action.not_nil!.deadzone.should be_close(0.25_f32, 0.001_f32)

      # Cycle gamepad style with 'g'
      remapper.model.gamepad_style.should eq(Opal::GamepadStyle::DualShock)
      remapper.handle_key(Opal::Terminal::KeyEvent.new("g", 'g')).should be_true
      remapper.model.gamepad_style.should eq(Opal::GamepadStyle::Xbox)

      # Return to All categories and filter with '/'
      remapper.handle_key(Opal::Terminal::KeyEvent.new("tab")).should be_true
      remapper.selected_category.should be_nil
      remapper.handle_key(Opal::Terminal::KeyEvent.new("/", '/')).should be_true
      remapper.filtering?.should be_true
      remapper.handle_key(Opal::Terminal::KeyEvent.new("h", 'h')).should be_true
      remapper.handle_key(Opal::Terminal::KeyEvent.new("v", 'v')).should be_true
      remapper.handle_key(Opal::Terminal::KeyEvent.new("y", 'y')).should be_true
      remapper.handle_key(Opal::Terminal::KeyEvent.new("enter")).should be_true
      remapper.filtering?.should be_false
      remapper.visible_actions.size.should eq(1)
      remapper.visible_actions.first.id.should eq("attack")
    end

    it "integrates into Opal::UI::DSL and renders cleanly with capture modal and conflict badges" do
      ui = Opal::UI.build do
        vstack do
          input_remapper(title: "Lapis Remapper", conflict_policy: :allow) do
            category "Gameplay" do
              action :jump, "Jump", primary: "space", secondary: "pad:south"
              action :dash, "Dash", primary: "space", secondary: "pad:east"
            end
          end
        end
      end

      remapper = ui.query_one(Opal::UI::InputRemapper)
      remapper.model.has_conflicts?.should be_true

      buf = Opal::UI::Buffer.new(72, 18)
      remapper.render(buf, 0, 0, 72, 18)
      rendered = buf.to_s
      rendered.should contain("Lapis Remapper")
      rendered.should contain("Conflict")
      rendered.should contain("Jump")
      rendered.should contain("✕ Cross")

      # Activate capture modal and verify overlay rendering
      remapper.start_capture.should be_true
      buf_cap = Opal::UI::Buffer.new(72, 18)
      remapper.render(buf_cap, 0, 0, 72, 18)
      buf_cap.to_s.should contain("LISTENING FOR INPUT")
    end
  end
end

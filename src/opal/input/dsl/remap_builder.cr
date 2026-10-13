require "../core/remap_model"

module Opal
  module Input
    module DSL
      # Contextual builder for a single InputAction inside an InputRemapBuilder or CategoryBuilder.
      class ActionBuilder
        getter action : Core::InputAction

        def initialize(@action : Core::InputAction)
        end

        def label(value : String) : self
          @action.label = value
          self
        end

        def category(value : String) : self
          @action.category = value
          self
        end

        def description(value : String) : self
          @action.description = value
          self
        end

        def primary(binding : Core::InputBinding | String) : self
          b = binding.is_a?(Core::InputBinding) ? binding : Core::InputBinding.parse(binding)
          @action.set_binding(0, b, update_default: true)
          self
        end

        def secondary(binding : Core::InputBinding | String) : self
          b = binding.is_a?(Core::InputBinding) ? binding : Core::InputBinding.parse(binding)
          @action.set_binding(1, b, update_default: true)
          self
        end

        def slot(index : Int32, binding : Core::InputBinding | String) : self
          b = binding.is_a?(Core::InputBinding) ? binding : Core::InputBinding.parse(binding)
          @action.set_binding(index, b, update_default: true)
          self
        end

        def deadzone(value : Float32 | Float64) : self
          @action.deadzone = value.to_f32
          self
        end

        def locked(value : Bool = true) : self
          @action.locked = value
          self
        end
      end

      # Contextual builder for grouping actions under a shared category.
      class CategoryBuilder
        getter model : Core::InputRemapModel
        getter category_name : String

        def initialize(@model : Core::InputRemapModel, @category_name : String)
        end

        def action(
          id : String | Symbol,
          label : String? = nil,
          description : String = "",
          primary : Core::InputBinding | String | Nil = nil,
          secondary : Core::InputBinding | String | Nil = nil,
          deadzone : Float32 | Float64 = 0.2_f32,
          locked : Bool = false,
        ) : Core::InputAction
          @model.add_action(
            id: id,
            label: label,
            category: @category_name,
            description: description,
            primary: primary,
            secondary: secondary,
            deadzone: deadzone.to_f32,
            locked: locked
          )
        end

        def action(
          id : String | Symbol,
          label : String? = nil,
          description : String = "",
          primary : Core::InputBinding | String | Nil = nil,
          secondary : Core::InputBinding | String | Nil = nil,
          deadzone : Float32 | Float64 = 0.2_f32,
          locked : Bool = false,
          &
        ) : Core::InputAction
          act = action(
            id: id,
            label: label,
            description: description,
            primary: primary,
            secondary: secondary,
            deadzone: deadzone,
            locked: locked
          )
          ab = ActionBuilder.new(act)
          with ab yield ab
          act
        end

        def bind(
          id : String | Symbol,
          primary : Core::InputBinding | String,
          secondary : Core::InputBinding | String | Nil = nil,
          label : String? = nil,
        ) : Core::InputAction
          action(id, label: label, primary: primary, secondary: secondary)
        end
      end

      # Tier-2 Declarative Builder wrapping InputRemapModel with Dual-Mode (implicit/explicit receiver) block ergonomics.
      class InputRemapBuilder
        getter model : Core::InputRemapModel

        def initialize(@model : Core::InputRemapModel = Core::InputRemapModel.new)
        end

        def profile_name(name : String) : self
          @model.profile_name = name
          self
        end

        def max_slots(count : Int32) : self
          @model.max_slots = Math.max(1, count)
          self
        end

        def conflict_policy(policy : Core::ConflictPolicy | Symbol | String) : self
          @model.conflict_policy = Core::ConflictPolicy.parse_policy(policy)
          self
        end

        def gamepad_style(style : Core::GamepadStyle | Symbol | String) : self
          @model.gamepad_style = Core::GamepadStyle.parse_style(style)
          self
        end

        def allow_clear(enabled : Bool = true) : self
          @model.allow_clear = enabled
          self
        end

        def allow_reset(enabled : Bool = true) : self
          @model.allow_reset = enabled
          self
        end

        def category(name : String, &) : self
          cb = CategoryBuilder.new(@model, name)
          with cb yield cb
          self
        end

        def action(
          id : String | Symbol,
          label : String? = nil,
          category : String = "General",
          description : String = "",
          primary : Core::InputBinding | String | Nil = nil,
          secondary : Core::InputBinding | String | Nil = nil,
          deadzone : Float32 | Float64 = 0.2_f32,
          locked : Bool = false,
        ) : Core::InputAction
          @model.add_action(
            id: id,
            label: label,
            category: category,
            description: description,
            primary: primary,
            secondary: secondary,
            deadzone: deadzone.to_f32,
            locked: locked
          )
        end

        def action(
          id : String | Symbol,
          label : String? = nil,
          category : String = "General",
          description : String = "",
          primary : Core::InputBinding | String | Nil = nil,
          secondary : Core::InputBinding | String | Nil = nil,
          deadzone : Float32 | Float64 = 0.2_f32,
          locked : Bool = false,
          &
        ) : Core::InputAction
          act = action(
            id: id,
            label: label,
            category: category,
            description: description,
            primary: primary,
            secondary: secondary,
            deadzone: deadzone,
            locked: locked
          )
          ab = ActionBuilder.new(act)
          with ab yield ab
          act
        end

        def bind(
          id : String | Symbol,
          primary : Core::InputBinding | String,
          secondary : Core::InputBinding | String | Nil = nil,
          category : String = "General",
          label : String? = nil,
        ) : Core::InputAction
          action(id, label: label, category: category, primary: primary, secondary: secondary)
        end
      end
    end

    alias InputRemapBuilder = DSL::InputRemapBuilder

    # Builds an InputRemapModel via declarative DSL block.
    def self.remap_profile(
      profile_name : String = "Default Controls",
      max_slots : Int32 = 2,
      conflict_policy : Core::ConflictPolicy | Symbol | String = :allow,
      gamepad_style : Core::GamepadStyle | Symbol | String = :dualshock,
      &
    ) : Core::InputRemapModel
      model = Core::InputRemapModel.new(
        profile_name: profile_name,
        max_slots: max_slots,
        conflict_policy: Core::ConflictPolicy.parse_policy(conflict_policy),
        gamepad_style: Core::GamepadStyle.parse_style(gamepad_style)
      )
      builder = DSL::InputRemapBuilder.new(model)
      with builder yield builder
      model
    end
  end

  # Top-level declarative helper for building an InputRemapModel
  def self.input_map(
    profile_name : String = "Default Controls",
    max_slots : Int32 = 2,
    conflict_policy : Input::Core::ConflictPolicy | Symbol | String = :allow,
    gamepad_style : Input::Core::GamepadStyle | Symbol | String = :dualshock,
    &
  ) : Input::Core::InputRemapModel
    Input.remap_profile(
      profile_name: profile_name,
      max_slots: max_slots,
      conflict_policy: conflict_policy,
      gamepad_style: gamepad_style
    ) do |b|
      with b yield b
    end
  end
end

require "./command"
require "./context"
require "../input/fuzzy"

module Opal
  module CLI
    # Error raised when command line input fails parsing or validation.
    class ParseError < Exception
    end

    # Parses raw ARGV tokens according to the command tree specification.
    class Parser
      def self.parse(root_command : Command, args : Array(String)) : {Command, Context}
        current_cmd = root_command
        subcommand_idx : Int32? = nil
        flags_map = Hash(Symbol, Bool).new
        options_map = Hash(Symbol, OptionValue).new
        positional_args = [] of String

        idx = 0
        while idx < args.size
          tok = args[idx]

          if tok == "--"
            idx += 1
            while idx < args.size
              positional_args << args[idx]
              idx += 1
            end
            break
          elsif tok.starts_with?("--")
            key_part, delim, val_part = tok[2..].partition('=')
            has_val = !delim.empty?
            all_opts = current_cmd.all_options
            opt = all_opts.reverse.find { |o| o.long == "--#{key_part}" }

            unless opt
              candidates = all_opts.compact_map { |o| o.long.lstrip('-') }
              if suggestion = Input::Fuzzy.suggest(key_part, candidates)
                raise ParseError.new("Unknown option: #{tok} for command '#{current_cmd.name}'. Did you mean '--#{suggestion}'?")
              else
                raise ParseError.new("Unknown option: #{tok} for command '#{current_cmd.name}'")
              end
            end

            if opt.flag?
              flags_map[opt.name] = true
              options_map[opt.name] = true
            else
              val_str = if has_val
                          val_part
                        elsif idx + 1 < args.size && !args[idx + 1].starts_with?('-')
                          idx += 1
                          args[idx]
                        else
                          raise ParseError.new("Option #{tok} requires a value")
                        end

              validate_choices(opt, val_str)
              set_option_value(options_map, opt, val_str)
            end
          elsif tok.starts_with?('-') && tok.size > 1
            all_opts = current_cmd.all_options
            short_chars = tok[1..].chars

            if short_chars.size == 1
              char_str = "-#{short_chars[0]}"
              opt = all_opts.reverse.find { |o| o.short == char_str }

              unless opt
                raise ParseError.new("Unknown option: #{tok} for command '#{current_cmd.name}'")
              end

              if opt.flag?
                flags_map[opt.name] = true
                options_map[opt.name] = true
              else
                val_str = if idx + 1 < args.size && !args[idx + 1].starts_with?('-')
                            idx += 1
                            args[idx]
                          else
                            raise ParseError.new("Option #{tok} requires a value")
                          end
                validate_choices(opt, val_str)
                set_option_value(options_map, opt, val_str)
              end
            else
              short_chars.each do |c|
                char_str = "-#{c}"
                opt = all_opts.reverse.find { |o| o.short == char_str }
                unless opt
                  raise ParseError.new("Unknown flag: #{char_str} in #{tok}")
                end
                unless opt.flag?
                  raise ParseError.new("Option #{char_str} requires a value and cannot be clustered")
                end
                flags_map[opt.name] = true
                options_map[opt.name] = true
              end
            end
          else
            # Positional token or subcommand
            if sub = current_cmd.find_command(tok)
              current_cmd = sub
              subcommand_idx = idx
            elsif !current_cmd.subcommands.empty? && current_cmd.arguments.empty?
              candidates = current_cmd.subcommands.keys
              if suggestion = Input::Fuzzy.suggest(tok, candidates)
                raise ParseError.new("Unknown command: '#{tok}' for '#{current_cmd.name}'. Did you mean '#{suggestion}'?")
              else
                raise ParseError.new("Unknown command: '#{tok}' for '#{current_cmd.name}'")
              end
            else
              positional_args << tok
            end
          end

          idx += 1
        end

        all_opts = current_cmd.all_options

        # Populate defaults
        all_opts.each do |opt|
          if opt.flag?
            flags_map[opt.name] = (opt.default == true) unless flags_map.has_key?(opt.name)
          else
            if opt.default && !options_map.has_key?(opt.name)
              options_map[opt.name] = opt.default
            end
            if env = opt.env_var
              if (env_val = ENV[env]?) && !options_map.has_key?(opt.name)
                options_map[opt.name] = cast_value(env_val, opt.type)
              end
            end
          end
        end

        # Validate required options
        all_opts.each do |opt|
          if opt.required? && !options_map.has_key?(opt.name)
            raise ParseError.new("Missing required option: #{opt.long}")
          end
        end

        # Map positional arguments
        named_args = Hash(Symbol, String).new
        current_cmd.arguments.each_with_index do |arg_def, i|
          if i < positional_args.size
            named_args[arg_def.name] = positional_args[i]
          elsif arg_def.required?
            raise ParseError.new("Missing required argument: <#{arg_def.name}> for command '#{current_cmd.name}'")
          elsif default_val = arg_def.default
            named_args[arg_def.name] = default_val
          end
        end

        raw = if s_idx = subcommand_idx
                args[s_idx + 1..]
              else
                args.dup
              end

        context = Context.new(
          flags: flags_map,
          options: options_map,
          args: positional_args,
          named_args: named_args,
          raw_args: raw
        )

        {current_cmd, context}
      end

      private def self.validate_choices(opt : Option, val : String) : Nil
        if choices = opt.choices
          unless choices.includes?(val)
            raise ParseError.new("Invalid value '#{val}' for #{opt.long}. Allowed choices: #{choices.join(", ")}")
          end
        end
      end

      private def self.set_option_value(options_map : Hash(Symbol, OptionValue), opt : Option, raw_val : String) : Nil
        if opt.type == :array
          existing = options_map[opt.name]?
          arr = existing.is_a?(Array(String)) ? existing : [] of String
          arr << raw_val
          options_map[opt.name] = arr
        else
          options_map[opt.name] = cast_value(raw_val, opt.type)
        end
      end

      private def self.cast_value(val : String, type : Symbol) : OptionValue
        case type
        when :int
          val.to_i? || raise ParseError.new("Expected integer, got: '#{val}'")
        when :float
          val.to_f64? || raise ParseError.new("Expected float, got: '#{val}'")
        when :bool
          ["1", "true", "yes", "y", "on"].includes?(val.downcase)
        else
          val
        end
      end
    end
  end
end
require "../style"

module Opal
  module CLI
    # Generates beautifully formatted, styled terminal help screens.
    module Help
      def self.render(
        app_name : String,
        command_name : String?,
        description : String,
        subcommands : Hash(String, Command),
        options : Array(Option),
        arguments : Array(Argument),
        examples : Array(String) = [] of String,
      ) : String
        io = IO::Memory.new

        heading_style = Style.new.bold.fg(:cyan)
        cmd_style = Style.new.bold.fg(:green)
        flag_style = Style.new.fg(:yellow)
        dim_style = Style.new.faint

        # Description
        unless description.empty?
          io.puts description
          io.puts
        end

        # Usage line
        io.puts heading_style.render("Usage:")
        usage_parts = [app_name]
        usage_parts << command_name if command_name && !command_name.empty? && command_name != app_name
        usage_parts << "<subcommand>" unless subcommands.empty?
        usage_parts << "[options]" unless options.empty?
        arguments.each do |arg|
          usage_parts << (arg.required? ? "<#{arg.name}>" : "[#{arg.name}]")
        end
        io.puts "  #{usage_parts.join(" ")}"
        io.puts

        # Subcommands
        unless subcommands.empty?
          has_categories = subcommands.values.any? { |c| !c.category.nil? }
          if has_categories
            grouped = Hash(String, Array({String, Command})).new
            subcommands.each do |name, subcmd|
              next if subcmd.aliases.includes?(name) && name != subcmd.name
              cat = subcmd.category || "Available Commands"
              grouped[cat] ||= [] of {String, Command}
              grouped[cat] << {name, subcmd}
            end

            grouped.each do |cat_name, cmds|
              io.puts heading_style.render("#{cat_name}:")
              max_cmd_len = cmds.map { |n, _| n.size }.max? || 0
              cmds.each do |name, subcmd|
                padding = " " * (max_cmd_len - name.size + 4)
                alias_info = subcmd.aliases.empty? ? "" : " (aliases: #{subcmd.aliases.join(", ")})"
                io.puts "  #{cmd_style.render(name)}#{padding}#{subcmd.description}#{dim_style.render(alias_info)}"
              end
              io.puts
            end
          else
            io.puts heading_style.render("Available Commands:")
            max_cmd_len = subcommands.keys.map(&.size).max? || 0
            subcommands.each do |name, subcmd|
              next if subcmd.aliases.includes?(name) && name != subcmd.name
              padding = " " * (max_cmd_len - name.size + 4)
              alias_info = subcmd.aliases.empty? ? "" : " (aliases: #{subcmd.aliases.join(", ")})"
              io.puts "  #{cmd_style.render(name)}#{padding}#{subcmd.description}#{dim_style.render(alias_info)}"
            end
            io.puts
          end
        end

        # Positional arguments
        unless arguments.empty?
          io.puts heading_style.render("Arguments:")
          max_arg_len = arguments.map { |a| a.name.to_s.size }.max? || 0
          arguments.each do |arg|
            name_str = arg.name.to_s
            padding = " " * (max_arg_len - name_str.size + 4)
            req_info = arg.required? ? "[required]" : "[optional]"
            default_info = arg.default ? " (default: #{arg.default})" : ""
            io.puts "  #{cmd_style.render(name_str)}#{padding}#{arg.description} #{dim_style.render(req_info + default_info)}"
          end
          io.puts
        end

        # Local Options
        local_opts = options.reject(&.global?)
        unless local_opts.empty?
          io.puts heading_style.render("Options:")
          format_options(io, local_opts, flag_style, dim_style)
          io.puts
        end

        # Global Options
        global_opts = options.select(&.global?)
        unless global_opts.empty?
          io.puts heading_style.render("Global Options:")
          format_options(io, global_opts, flag_style, dim_style)
          io.puts
        end

        # Examples
        unless examples.empty?
          io.puts heading_style.render("Examples:")
          examples.each do |ex|
            io.puts "  #{dim_style.render("$")} #{ex}"
          end
          io.puts
        end

        io.to_s
      end

      private def self.format_options(io : IO, opts : Array(Option), flag_style : Style, dim_style : Style)
        formatted_flags = opts.map(&.formatted_flag)
        max_flag_len = formatted_flags.map { |f| VisualWidth.width(f) }.max? || 0

        opts.each_with_index do |opt, i|
          flag_str = formatted_flags[i]
          padding = " " * (max_flag_len - VisualWidth.width(flag_str) + 4)

          meta = [] of String
          if opt.default && !opt.flag?
            meta << "default: #{opt.default}"
          end
          if opt.choices
            meta << "choices: #{opt.choices.not_nil!.join("|")}"
          end
          if opt.env_var
            meta << "env: $#{opt.env_var}"
          end

          meta_str = meta.empty? ? "" : " (#{meta.join(", ")})"
          io.puts "  #{flag_style.render(flag_str)}#{padding}#{opt.description}#{dim_style.render(meta_str)}"
        end
      end
    end
  end
end

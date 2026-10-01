require "../style"

module Opal
  module CLI
    # Generates beautifully formatted, styled terminal help screens.
    module Help
      # Primary entrypoint rendering help for a Command object with all rich metadata
      def self.render_command(app_name : String, command : Command, context : Context? = nil) : String
        io = IO::Memory.new

        heading_style = Style.new.bold.fg(:cyan)
        cmd_style = Style.new.bold.fg(:green)
        flag_style = Style.new.fg(:yellow)
        dim_style = Style.new.faint
        title_style = Style.new.bold.fg(:magenta)

        # Header / Banner
        if h = command.header_text
          io.puts h
          io.puts
        end

        # Title
        if t = command.title
          io.puts title_style.render(t)
          io.puts
        end

        # Summary & Description
        if s = command.summary
          io.puts s
          io.puts
        end
        if !command.description.empty? && command.description != command.summary
          io.puts command.description
          io.puts
        end

        # Usage line
        io.puts heading_style.render("Usage:")
        usage_parts = [app_name]
        usage_parts << command.name if command.name != app_name && !command.name.empty?
        usage_parts << "<command>" unless command.subcommands.empty?
        usage_parts << "[options]" unless command.all_options.empty?

        command.arguments.each do |arg|
          usage_parts << arg.formatted_name
        end
        io.puts "  #{usage_parts.join(" ")}"
        io.puts

        # Subcommands
        subs = command.subcommands.reject { |k, v| k != v.name }
        unless subs.empty?
          has_categories = subs.values.any? { |c| !c.category.nil? }
          if has_categories
            grouped = Hash(String, Array({String, Command})).new
            subs.each do |name, subcmd|
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
                desc_text = subcmd.summary || subcmd.description
                io.puts "  #{cmd_style.render(name)}#{padding}#{desc_text}#{dim_style.render(alias_info)}"
              end
              io.puts
            end
          else
            io.puts heading_style.render("Available Commands:")
            max_cmd_len = subs.keys.map(&.size).max? || 0
            subs.each do |name, subcmd|
              next if subcmd.aliases.includes?(name) && name != subcmd.name
              padding = " " * (max_cmd_len - name.size + 4)
              alias_info = subcmd.aliases.empty? ? "" : " (aliases: #{subcmd.aliases.join(", ")})"
              desc_text = subcmd.summary || subcmd.description
              io.puts "  #{cmd_style.render(name)}#{padding}#{desc_text}#{dim_style.render(alias_info)}"
            end
            io.puts
          end
        end

        # Positional arguments
        unless command.arguments.empty?
          io.puts heading_style.render("Arguments:")
          max_arg_len = command.arguments.map { |a| a.formatted_name.size }.max? || 0
          command.arguments.each do |arg|
            name_str = arg.formatted_name
            padding = " " * (max_arg_len - name_str.size + 4)
            req_info = arg.required? ? "[required]" : "[optional]"
            default_info = arg.default ? " (default: #{arg.default})" : ""
            choices_info = arg.choices ? " (choices: #{arg.choices.not_nil!.join("|")})" : ""
            io.puts "  #{cmd_style.render(name_str)}#{padding}#{arg.description} #{dim_style.render(req_info + default_info + choices_info)}"
          end
          io.puts
        end

        # Options - Grouped by group property
        all_opts = command.all_options
        local_opts = all_opts.reject(&.global?)
        global_opts = all_opts.select(&.global?)

        # Group local options by .group if specified
        groups = Hash(String, Array(Option)).new
        ungrouped = [] of Option

        local_opts.each do |opt|
          if grp = opt.group
            groups[grp] ||= [] of Option
            groups[grp] << opt
          else
            ungrouped << opt
          end
        end

        unless ungrouped.empty?
          io.puts heading_style.render("Options:")
          format_options(io, ungrouped, flag_style, dim_style)
          io.puts
        end

        groups.each do |grp_name, grp_opts|
          io.puts heading_style.render("#{grp_name}:")
          format_options(io, grp_opts, flag_style, dim_style)
          io.puts
        end

        # Global Options
        unless global_opts.empty?
          io.puts heading_style.render("Global Options:")
          format_options(io, global_opts, flag_style, dim_style)
          io.puts
        end

        # Custom sections
        command.sections.each do |sec|
          io.puts heading_style.render("#{sec.title}:")
          sec.lines.each do |line|
            io.puts "  #{line}"
          end
          io.puts
        end

        # Examples
        unless command.examples.empty?
          io.puts heading_style.render("Examples:")
          command.examples.each do |ex|
            io.puts "  #{dim_style.render("$")} #{ex}"
          end
          io.puts
        end

        # Footer / Epilog
        if f = command.footer_text
          io.puts dim_style.render(f)
          io.puts
        end

        io.to_s
      end

      # Legacy / fallback render method for backward compatibility
      def self.render(
        app_name : String,
        command_name : String?,
        description : String,
        subcommands : Hash(String, Command),
        options : Array(Option),
        arguments : Array(Argument),
        examples : Array(String) = [] of String,
      ) : String
        cmd = Command.new(command_name || app_name, description)
        subcommands.each { |k, v| cmd.subcommands[k] = v }
        options.each { |o| cmd.options << o }
        arguments.each { |a| cmd.arguments << a }
        examples.each { |e| cmd.example(e) }
        render_command(app_name, cmd)
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

require "./command"

module Opal
  module CLI
    # Generates shell completion scripts for Bash, Zsh, and Fish.
    module Completion
      def self.bash(app_name : String, root : Command) : String
        commands = collect_command_names(root)
        options = root.all_options.flat_map { |o| [o.long, o.short].compact }.join(" ")

        <<-BASH
        _#{app_name}_completions() {
            local cur prev opts commands
            COMPREPLY=()
            cur="${COMP_WORDS[COMP_CWORD]}"
            prev="${COMP_WORDS[COMP_CWORD-1]}"
            opts="#{options}"
            commands="#{commands.join(" ")}"

            if [[ ${cur} == -* ]] ; then
                COMPREPLY=( $(compgen -W "${opts}" -- ${cur}) )
                return 0
            fi

            COMPREPLY=( $(compgen -W "${commands}" -- ${cur}) )
            return 0
        }
        complete -F _#{app_name}_completions #{app_name}
        BASH
      end

      def self.fish(app_name : String, root : Command) : String
        io = IO::Memory.new
        root.subcommands.each do |name, sub|
          io.puts "complete -c #{app_name} -n \"__fish_use_subcommand\" -a #{name} -d \"#{sub.description}\""
        end
        root.all_options.each do |opt|
          line = IO::Memory.new
          line << "complete -c #{app_name}"
          line << " -s #{opt.short.not_nil!.lstrip('-')}" if opt.short
          line << " -l #{opt.long.lstrip('-')}"
          line << " -d \"#{opt.description}\""
          io.puts line.to_s
        end
        io.to_s
      end

      def self.powershell(app_name : String, root : Command) : String
        commands = collect_command_names(root).map { |c| "'#{c}'" }.join(", ")
        <<-PS1
        # PowerShell completion script for #{app_name}
        Register-ArgumentCompleter -Native -CommandName #{app_name} -ScriptBlock {
            param($wordToComplete, $commandAst, $cursorPosition)
            $commands = @(#{commands})
            $commands | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object {
                [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
            }
        }
        PS1
      end

      def self.zsh(app_name : String, root : Command) : String
        <<-ZSH
        #compdef #{app_name}

        _#{app_name}() {
            local line state

            _arguments -C \\
                "1: :->command" \\
                "*::arg:->args"

            case $state in
                command)
                    local -a subcommands
                    subcommands=(
        #{root.subcommands.map { |k, v| "                \"#{k}:#{v.description}\"" }.join('\n')}
                    )
                    _describe 'command' subcommands
                    ;;
            esac
        }

        compdef _#{app_name} #{app_name}
        ZSH
      end

      private def self.collect_command_names(cmd : Command) : Array(String)
        names = cmd.subcommands.keys
        names
      end
    end
  end
end

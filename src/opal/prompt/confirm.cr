require "../style"
require "../terminal"

module Opal
  module Prompt
    # Boolean confirmation prompt (y/N).
    class Confirm
      def self.run(
        question : String,
        default : Bool = true,
        driver : Terminal::Driver? = nil,
      ) : Bool
        term = driver || Terminal.default_driver
        q_style = Style.new.bold.fg(:cyan)
        dim_style = Style.new.faint

        hint = default ? "(Y/n)" : "(y/N)"
        prompt_str = "#{q_style.render("?")} #{question} #{dim_style.render(hint)} "

        term.write(prompt_str)
        term.flush

        result = term.raw_mode do
          loop do
            event = term.read_event
            case event
            when Terminal::KeyEvent
              case event.name.downcase
              when "y"
                term.write("yes\n")
                term.flush
                break true
              when "n"
                term.write("no\n")
                term.flush
                break false
              when "enter"
                term.write(default ? "yes\n" : "no\n")
                term.flush
                break default
              when "ctrl+c"
                term.write("\n")
                term.flush
                exit 130
              end
            end
          end
        end

        result
      end
    end
  end
end

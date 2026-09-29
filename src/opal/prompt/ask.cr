require "../style"
require "../terminal"

module Opal
  module Prompt
    # Text input prompt with validation and default fallback.
    class Ask
      def self.run(
        question : String,
        default : String? = nil,
        required : Bool = false,
        driver : Terminal::Driver? = nil,
      ) : String
        q_style = Style.new.bold.fg(:cyan)
        dim_style = Style.new.faint

        default_hint = default ? dim_style.render(" (#{default})") : ""
        prompt_str = "#{q_style.render("?")} #{question}#{default_hint}: "

        loop do
          print prompt_str
          STDOUT.flush

          input = gets.try(&.strip) || ""

          if input.empty?
            if default
              return default
            elsif !required
              return ""
            else
              puts "\e[31mThis field is required.\e[0m"
            end
          else
            return input
          end
        end
      end
    end
  end
end

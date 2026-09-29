module Opal
  module FormModule
    alias ValidatorFn = Proc(String, String?)

    # Common built-in validation helpers for form inputs.
    module Validator
      def self.required(message : String = "Field is required") : ValidatorFn
        ->(val : String) {
          val.strip.empty? ? message : nil
        }
      end

      def self.min_length(min : Int32, message : String? = nil) : ValidatorFn
        msg = message || "Must be at least #{min} characters"
        ->(val : String) {
          val.size < min ? msg : nil
        }
      end

      def self.email(message : String = "Must be a valid email address") : ValidatorFn
        ->(val : String) {
          (val =~ /^[\w.+-]+@[\w.-]+\.[a-zA-Z]{2,}$/) ? nil : message
        }
      end

      def self.regex(pattern : Regex, message : String = "Invalid format") : ValidatorFn
        ->(val : String) {
          (val =~ pattern) ? nil : message
        }
      end
    end
  end
end

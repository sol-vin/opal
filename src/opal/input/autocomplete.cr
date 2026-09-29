module Opal
  module Input
    # Autocompletion engine supporting static dictionaries, dynamic providers,
    # and ghost text preview generation.
    class Autocomplete
      enum Mode
        Prefix
        Fuzzy
      end

      property mode : Mode = Mode::Prefix
      property candidates : Array(String)
      @providers = [] of (String -> Array(String))

      def initialize(candidates : Array(String) = [] of String)
        @candidates = candidates
      end

      # Adds candidate words for autocompletion
      def candidates(*words : String) : self
        words.each { |w| @candidates << w }
        self
      end

      def candidates(words : Array(String)) : self
        @candidates.concat(words)
        self
      end

      # Adds a dynamic provider block generating suggestions based on query
      def provider(&block : String -> Array(String)) : self
        @providers << block
        self
      end

      # Sets matching mode (:prefix or :fuzzy)
      def match_mode(m : Symbol) : self
        @mode = (m == :fuzzy) ? Mode::Fuzzy : Mode::Prefix
        self
      end

      # Returns all matching candidates for the current query
      def matches(query : String) : Array(String)
        return [] of String if query.empty?

        results = [] of String
        q_down = query.downcase

        # Check static candidates
        @candidates.each do |c|
          case @mode
          when Mode::Prefix
            results << c if c.downcase.starts_with?(q_down)
          when Mode::Fuzzy
            results << c if fuzzy_match?(c.downcase, q_down)
          end
        end

        # Check dynamic providers
        @providers.each do |p|
          p.call(query).each do |c|
            results << c unless results.includes?(c)
          end
        end

        results
      end

      # Returns the ghost text suffix for the best match, or nil if no match
      # Example: query "bu", match "build" -> returns "ild"
      def ghost_text(query : String) : String?
        return nil if query.empty?

        best_match = matches(query).first?
        return nil unless best_match

        if best_match.downcase.starts_with?(query.downcase)
          suffix = best_match[query.size..]
          suffix.empty? ? nil : suffix
        else
          nil
        end
      end

      # Returns the full completed string for the best match, or the query itself
      def complete(query : String) : String
        matches(query).first? || query
      end

      private def fuzzy_match?(source : String, pattern : String) : Bool
        src_idx = 0
        pat_idx = 0
        src_chars = source.chars
        pat_chars = pattern.chars

        while src_idx < src_chars.size && pat_idx < pat_chars.size
          if src_chars[src_idx] == pat_chars[pat_idx]
            pat_idx += 1
          end
          src_idx += 1
        end

        pat_idx == pat_chars.size
      end
    end
  end

  # Convenience DSL to define an Autocomplete engine
  def self.autocomplete(&block : Input::Autocomplete -> Nil) : Input::Autocomplete
    ac = Input::Autocomplete.new
    block.call(ac)
    ac
  end
end

module Opal
  module Input
    # Result of a fuzzy string match containing the matched score and character indices.
    struct FuzzyMatch(T)
      getter item : T
      getter target : String
      getter score : Int32
      getter matched_indices : Array(Int32)

      def initialize(@item : T, @target : String, @score : Int32, @matched_indices : Array(Int32))
      end
    end

    # High-performance fuzzy matching algorithm with rune highlighting.
    module Fuzzy
      # Matches a query string against a target string and computes a score + matched rune indices.
      def self.match(query : String, target : String) : FuzzyMatch(String)?
        return FuzzyMatch(String).new(target, target, 0, [] of Int32) if query.empty?

        q_chars = query.downcase.chars
        t_chars = target.chars
        t_lower = target.downcase.chars

        q_idx = 0
        score = 0
        matched_indices = [] of Int32
        prev_matched_idx = -2

        t_lower.each_with_index do |tch, tidx|
          break if q_idx >= q_chars.size

          if tch == q_chars[q_idx]
            matched_indices << tidx

            # Base match point
            score += 10

            # Consecutive character match bonus
            if tidx == prev_matched_idx + 1
              score += 20
            end

            # Word boundary bonus (start of string or after separator)
            if tidx == 0
              score += 35
            elsif ['/', '_', '-', '.', ' ', '\\'].includes?(t_chars[tidx - 1])
              score += 30
            elsif t_chars[tidx].uppercase? && t_chars[tidx - 1].lowercase?
              # CamelCase boundary
              score += 25
            end

            # Penalty for distance from previous matched index
            if prev_matched_idx >= 0 && tidx > prev_matched_idx + 1
              distance = tidx - prev_matched_idx - 1
              score -= Math.min(distance * 2, 15)
            end

            prev_matched_idx = tidx
            q_idx += 1
          end
        end

        # If not all query characters matched, return nil
        return nil unless q_idx == q_chars.size

        # Exact match bonus
        if query.size == target.size
          score += 60
        end

        FuzzyMatch(String).new(target, target, score, matched_indices)
      end

      # Filters and ranks a list of items by fuzzy match score in descending order.
      def self.filter(query : String, items : Array(String)) : Array(FuzzyMatch(String))
        filter_by(query, items) { |it| it }
      end

      # Filters and ranks generic items using a custom key selector function.
      def self.filter_by(query : String, items : Array(T), &key_selector : T -> String) : Array(FuzzyMatch(T)) forall T
        results = [] of FuzzyMatch(T)

        items.each do |item|
          key = key_selector.call(item)
          if match_res = match(query, key)
            results << FuzzyMatch(T).new(item, key, match_res.score, match_res.matched_indices)
          end
        end

        # Sort highest score first; for equal scores, shorter strings rank higher
        results.sort! do |a, b|
          if a.score != b.score
            b.score <=> a.score
          else
            a.target.size <=> b.target.size
          end
        end

        results
      end
      # Computes the Levenshtein edit distance between two strings.
      def self.levenshtein(s1 : String, s2 : String) : Int32
        m = s1.size
        n = s2.size
        return n if m == 0
        return m if n == 0

        d = Array.new(m + 1) { Array.new(n + 1, 0) }
        (0..m).each { |i| d[i][0] = i }
        (0..n).each { |j| d[0][j] = j }

        s1_chars = s1.chars
        s2_chars = s2.chars

        (1..m).each do |i|
          (1..n).each do |j|
            cost = (s1_chars[i - 1].downcase == s2_chars[j - 1].downcase) ? 0 : 1
            d[i][j] = Math.min(
              d[i - 1][j] + 1,
              Math.min(
                d[i][j - 1] + 1,
                d[i - 1][j - 1] + cost
              )
            )
          end
        end

        d[m][n]
      end

      # Suggests the closest matching candidate for a typo, or nil if no good match.
      def self.suggest(query : String, candidates : Array(String) | Enumerable(String), max_distance : Int32 = 3) : String?
        best_candidate : String? = nil
        min_dist = max_distance + 1

        candidates.each do |cand|
          dist = levenshtein(query, cand)
          if dist < min_dist
            min_dist = dist
            best_candidate = cand
          end
        end

        best_candidate
      end
    end
  end
end

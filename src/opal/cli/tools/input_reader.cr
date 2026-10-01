require "csv"
require "json"

module Opal
  module CLI
    module Tools
      # Intelligent stream parser and format sensor for Unix CLI utilities.
      module InputReader
        # Cleans content by stripping UTF-8 BOM and surrounding whitespace
        def self.clean(content : String) : String
          content.lstrip('\uFEFF').strip
        end

        # Auto-detects data format from raw string content.
        def self.detect_format(content : String) : Symbol
          trimmed = clean(content)
          return :words if trimmed.empty?

          if trimmed.starts_with?('{') || trimmed.starts_with?('[')
            return :json
          end

          lines = trimmed.split('\n')
          sample = lines.first(5).reject(&.strip.empty?)

          # Check for Markdown table: lines containing '|' with divider row
          if sample.any? { |l| l.includes?('|') } && sample.any? { |l| l =~ /\|?\s*[-:]+[-| :]*\|?/ }
            return :markdown
          end

          # Check for TSV (tab separated)
          if sample.any?(&.includes?('\t'))
            return :tsv
          end

          # Check for CSV (comma separated)
          if sample.any?(&.includes?(','))
            return :csv
          end

          :words
        end

        # Parses tabular data into {headers, rows} with format detection and delimiter overrides.
        def self.parse_table_data(
          content : String,
          format : Symbol = :auto,
          delimiter : String? = nil,
          custom_headers : Array(String)? = nil,
          no_headers : Bool = false,
        ) : {Array(String), Array(Array(String))}
          cleaned = clean(content)
          fmt = (format == :auto) ? detect_format(cleaned) : format

          headers = [] of String
          rows = [] of Array(String)

          case fmt
          when :json
            headers, rows = parse_json_table(cleaned, no_headers)
          when :csv
            headers, rows = parse_csv_table(cleaned, delimiter || ",", no_headers)
          when :tsv
            headers, rows = parse_delimited_table(cleaned, delimiter || "\t", no_headers)
          when :markdown
            headers, rows = parse_markdown_table(cleaned, no_headers)
          else # :words
            delim = delimiter || " "
            headers, rows = parse_delimited_table(cleaned, delim, no_headers)
          end

          # Override headers if explicitly provided
          if h = custom_headers
            headers = h
          end

          {headers, rows}
        end

        # Parses key-value pairs (e.g. for BarChart, PieChart) from JSON, TSV, or lines.
        def self.parse_key_value_pairs(content : String) : Array({String, Float64})
          trimmed = clean(content)
          results = [] of {String, Float64}

          if trimmed.starts_with?('{') || trimmed.starts_with?('[')
            begin
              parsed = JSON.parse(trimmed)
              if obj = parsed.as_h?
                obj.each do |k, v|
                  if num = v.as_f? || v.as_i64?.try(&.to_f64)
                    results << {k, num}
                  end
                end
                return results
              elsif arr = parsed.as_a?
                arr.each do |item|
                  if item.is_a?(JSON::Any) && (item_arr = item.as_a?) && item_arr.size >= 2
                    k = item_arr[0].to_s
                    if num = item_arr[1].as_f? || item_arr[1].as_i64?.try(&.to_f64) || item_arr[1].to_s.to_f64?
                      results << {k, num}
                    end
                  end
                end
                return results
              end
            rescue
            end
          end

          # Line-based parser (handles "Label: 42", "Label=42", "Label\t42", "Label 42")
          trimmed.each_line do |line|
            l = line.strip
            next if l.empty? || l.starts_with?('#')

            if l.includes?(':')
              k, _, v = l.partition(':')
              if val = v.strip.to_f64?
                results << {k.strip, val}
              end
            elsif l.includes?('=')
              k, _, v = l.partition('=')
              if val = v.strip.to_f64?
                results << {k.strip, val}
              end
            elsif l.includes?(',')
              parts = l.split(',').reject(&.empty?)
              if parts.size >= 2 && (val = parts.last.strip.to_f64?)
                k = parts[0...-1].join(',').strip
                results << {k, val}
              end
            elsif l.includes?('\t')
              parts = l.split('\t').reject(&.empty?)
              if parts.size >= 2 && (val = parts[1].strip.to_f64?)
                results << {parts[0].strip, val}
              end
            else
              parts = l.split(/\s+/).reject(&.empty?)
              if parts.size >= 2 && (val = parts.last.strip.to_f64?)
                k = parts[0...-1].join(' ')
                results << {k, val}
              end
            end
          end

          results
        end

        # Alias for parse_key_value_pairs
        def self.parse_labeled_series(content : String) : Array({String, Float64})
          parse_key_value_pairs(content)
        end

        # Parses a stream of numeric values (for Sparkline or single-series LineGraph).
        def self.parse_numeric_stream(content : String) : Array(Float64)
          tokens = clean(content).split(/[\s,;\t\r\n\[\]\(\)]+/).reject(&.empty?)
          results = [] of Float64
          tokens.each do |tok|
            if val = tok.to_f64?
              results << val
            end
          end
          results
        end

        # Alias for parse_numeric_stream
        def self.parse_number_series(content : String) : Array(Float64)
          parse_numeric_stream(content)
        end

        private def self.parse_json_table(content : String, no_headers : Bool) : {Array(String), Array(Array(String))}
          cleaned = clean(content)
          parsed = JSON.parse(cleaned)
          headers = [] of String
          rows = [] of Array(String)

          if arr = parsed.as_a?
            return {headers, rows} if arr.empty?

            if arr.first.as_h?
              # Array of Objects: [{"name": "A", "val": 1}, ...]
              # Preserve insertion order from first object, then union subsequent
              all_keys = [] of String
              arr.each do |item|
                if h = item.as_h?
                  h.each_key do |k|
                    all_keys << k unless all_keys.includes?(k)
                  end
                end
              end

              headers = all_keys
              arr.each do |item|
                if h = item.as_h?
                  row = all_keys.map { |k| h[k]?.try(&.to_s) || "" }
                  rows << row
                end
              end
            elsif arr.first.as_a?
              # Array of Arrays: [["Header1", "Header2"], ["Val1", "Val2"]]
              if no_headers
                arr.each do |row_arr|
                  rows << row_arr.as_a.map(&.to_s)
                end
                col_count = rows.map(&.size).max? || 0
                headers = (1..col_count).map { |i| "Col #{i}" }
              else
                headers = arr.first.as_a.map(&.to_s)
                arr[1..].each do |row_arr|
                  rows << row_arr.as_a.map(&.to_s)
                end
              end
            end
          elsif obj = parsed.as_h?
            # Single object: {"status": "ok", "count": 42} -> 2-column key/value table
            headers = ["Key", "Value"]
            obj.each do |k, v|
              rows << [k, v.to_s]
            end
          end

          {headers, rows}
        rescue
          {[] of String, [] of Array(String)}
        end

        private def self.parse_csv_table(content : String, delim : String, no_headers : Bool) : {Array(String), Array(Array(String))}
          raw_rows = CSV.parse(content, separator: delim.chars.first? || ',')
          return {[] of String, [] of Array(String)} if raw_rows.empty?

          if no_headers
            col_count = raw_rows.map(&.size).max? || 0
            headers = (1..col_count).map { |i| "Col #{i}" }
            {headers, raw_rows}
          else
            headers = raw_rows.first
            rows = raw_rows[1..]? || [] of Array(String)
            {headers, rows}
          end
        rescue
          {[] of String, [] of Array(String)}
        end

        private def self.parse_delimited_table(content : String, delim : String, no_headers : Bool) : {Array(String), Array(Array(String))}
          lines = content.strip.split('\n').reject(&.strip.empty?)
          return {[] of String, [] of Array(String)} if lines.empty?

          all_rows = lines.map do |line|
            if delim == " "
              line.strip.split(/\s+/)
            else
              line.split(delim).map(&.strip)
            end
          end

          if no_headers
            col_count = all_rows.map(&.size).max? || 0
            headers = (1..col_count).map { |i| "Col #{i}" }
            {headers, all_rows}
          else
            headers = all_rows.first
            rows = all_rows[1..]? || [] of Array(String)
            {headers, rows}
          end
        end

        private def self.parse_markdown_table(content : String, no_headers : Bool) : {Array(String), Array(Array(String))}
          lines = content.strip.split('\n').reject(&.strip.empty?)
          table_lines = lines.select { |l| l.includes?('|') }
          return {[] of String, [] of Array(String)} if table_lines.empty?

          # Filter out divider lines like |---|:---:|---|
          filtered = table_lines.reject { |l| l =~ /^\s*\|?\s*[-:]+[-| :]*\|?\s*$/ }
          return {[] of String, [] of Array(String)} if filtered.empty?

          parsed_rows = filtered.map do |line|
            trimmed = line.strip.lstrip('|').rstrip('|')
            trimmed.split('|').map(&.strip)
          end

          if no_headers
            col_count = parsed_rows.map(&.size).max? || 0
            headers = (1..col_count).map { |i| "Col #{i}" }
            {headers, parsed_rows}
          else
            headers = parsed_rows.first
            rows = parsed_rows[1..]? || [] of Array(String)
            {headers, rows}
          end
        end
      end
    end
  end
end

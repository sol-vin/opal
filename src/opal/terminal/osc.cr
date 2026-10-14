require "base64"

module Opal
  module Terminal
    # Operating System Command (OSC) escape sequences for modern terminal emulators.
    module OSC
      # Represents a parsed or constructed OSC 8 terminal hyperlink span.
      record LinkSpan, url : String, label : String, id : String? = nil do
        def to_osc8 : String
          OSC.hyperlink(@label, @url, @id)
        end
      end

      OSC8_REGEX = /\e\]8;([^;]*);([^\a\e]*)(?:\a|\e\\)(.*?)\e\]8;;(?:\a|\e\\)/m

      # Returns true if the string begins with a standard URI scheme.
      def self.url_like?(value : String) : Bool
        value.starts_with?("http://") ||
          value.starts_with?("https://") ||
          value.starts_with?("file://") ||
          value.starts_with?("mailto:") ||
          value.starts_with?("about:") ||
          value.starts_with?("ftp://") ||
          value.starts_with?("ssh://")
      end

      # Normalizes `(url, label)` arguments while remaining backward-compatible
      # with `(label, url)` when the second argument is an explicit URL.
      def self.resolve_link_args(first : String, second : String? = nil) : {String, String}
        if second.nil? || second.empty?
          {first, first}
        elsif !url_like?(first) && url_like?(second)
          {second, first}
        else
          {first, second}
        end
      end

      # Generates an OSC 8 clickable hyperlink escape sequence.
      # Supported by Windows Terminal, iTerm2, Kitty, WezTerm, Alacritty, GNOME Terminal, etc.
      def self.hyperlink(text : String, url : String, id : String? = nil) : String
        params = id ? "id=#{id}" : ""
        "\e]8;#{params};#{url}\e\\#{text}\e]8;;\e\\"
      end

      # Declarative `link(url, label)` OSC 8 terminal hyperlink helper.
      # If `label` is omitted, defaults to `url`. Also supports `(label, url)` if `second` is a URI.
      def self.link(url : String, label : String? = nil, id : String? = nil) : String
        target_url, target_label = resolve_link_args(url, label)
        hyperlink(target_label, target_url, id)
      end

      # Normalizes a GitHub repository identifier (e.g. `"opal"` -> `"sol-vin/opal"`).
      def self.normalize_github_repo(repo : String, default_owner : String = "sol-vin") : String
        cleaned = repo.strip.lstrip('/').rstrip('/')
        cleaned.includes?('/') ? cleaned : "#{default_owner}/#{cleaned}"
      end

      # Constructs a canonical GitHub URL for a repository, RFC/discussion, issue, or pull request.
      def self.github_url(
        repo : String,
        kind : Symbol | String = :repo,
        number : Int32 | String? = nil,
      ) : String
        full_repo = normalize_github_repo(repo)
        base = "https://github.com/#{full_repo}"
        return base if number.nil? && kind.to_s.downcase.in?("repo", "home", "")

        case kind.to_s.downcase
        when "rfc", "discussion", "discussions"
          number ? "#{base}/discussions/#{number}" : "#{base}/discussions"
        when "issue", "issues"
          number ? "#{base}/issues/#{number}" : "#{base}/issues"
        when "pr", "pull", "pulls"
          number ? "#{base}/pull/#{number}" : "#{base}/pulls"
        else
          number ? "#{base}/#{kind}/#{number}" : base
        end
      end

      # Generates an OSC 8 clickable hyperlink to a GitHub RFC/Discussion, Issue, or PR.
      def self.github_link(
        repo : String,
        kind : Symbol | String,
        number : Int32 | String,
        label : String? = nil,
        id : String? = nil,
      ) : String
        url = github_url(repo, kind, number)
        default_label = case kind.to_s.downcase
                        when "rfc"
                          "RFC ##{number}"
                        when "discussion", "discussions"
                          "Discussion ##{number}"
                        when "issue", "issues"
                          "Issue ##{number}"
                        when "pr", "pull", "pulls"
                          "PR ##{number}"
                        else
                          "#{kind.to_s.upcase} ##{number}"
                        end
        hyperlink(label || default_label, url, id)
      end

      # Generates an OSC 8 clickable hyperlink for a GitHub RFC Discussion (`RFC #XX`).
      def self.rfc_link(repo : String, number : Int32 | String, label : String? = nil, id : String? = nil) : String
        github_link(repo, :rfc, number, label, id)
      end

      # Generates an OSC 8 clickable hyperlink for a GitHub Discussion (`Discussion #XX`).
      def self.discussion_link(repo : String, number : Int32 | String, label : String? = nil, id : String? = nil) : String
        github_link(repo, :discussion, number, label, id)
      end

      # Generates an OSC 8 clickable hyperlink for a GitHub Issue (`Issue #XX`).
      def self.issue_link(repo : String, number : Int32 | String, label : String? = nil, id : String? = nil) : String
        github_link(repo, :issue, number, label, id)
      end

      # Generates an OSC 8 clickable hyperlink for a GitHub Pull Request (`PR #XX`).
      def self.pr_link(repo : String, number : Int32 | String, label : String? = nil, id : String? = nil) : String
        github_link(repo, :pr, number, label, id)
      end

      # Parses all OSC 8 hyperlink spans contained within a string.
      def self.parse_links(text : String) : Array(LinkSpan)
        spans = [] of LinkSpan
        text.scan(OSC8_REGEX) do |match|
          params = match[1]
          url = match[2]
          label = match[3]
          id = nil
          if params.starts_with?("id=")
            id = params[3..]
          elsif (idx = params.index("id="))
            rest = params[(idx + 3)..]
            id = rest.split(':').first?
          end
          spans << LinkSpan.new(url: url, label: label, id: id)
        end
        spans
      end

      # Generates an OSC 52 clipboard copy escape sequence using strict Base64 encoding.
      # Allows copying text directly into the host OS clipboard over SSH and local terminal sessions.
      # clipboard target: 'c' = primary clipboard, 'p' = selection clipboard
      def self.clipboard_copy(text : String, target : Char = 'c') : String
        encoded = Base64.strict_encode(text)
        "\e]52;#{target};#{encoded}\e\\"
      end

      # Directly copies text to the system clipboard via STDOUT using OSC 52.
      def self.copy_to_clipboard(text : String, io : IO = STDOUT, target : Char = 'c') : Nil
        io << clipboard_copy(text, target)
        io.flush
      end
    end
  end
end

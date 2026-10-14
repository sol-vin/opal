require "../element"
require "../../style/color"
require "../../style/visual_width"
require "../../terminal/osc"

module Opal
  module UI
    # Renders an OSC 8 clickable terminal hyperlink element for terminal UIs.
    class Link < Element
      property url : String
      property label : String
      property link_id : String?
      property fg : Color
      property bg : Color
      property? bold : Bool
      property? dim : Bool
      property? italic : Bool
      property? underline : Bool
      property icon : String?

      def initialize(
        url : String,
        label : String? = nil,
        id : String? = nil,
        fg : Color | Symbol | String = :cyan,
        bg : Color | Symbol | String = Color.none,
        @bold : Bool = false,
        @dim : Bool = false,
        @italic : Bool = false,
        @underline : Bool = true,
        @icon : String? = nil,
      )
        @url, @label = Terminal::OSC.resolve_link_args(url, label)
        @link_id = id
        @fg = Color.from(fg)
        @bg = Color.from(bg)
      end

      # Creates a Link element pointing to a GitHub RFC/Discussion, Issue, or Pull Request.
      def self.github(
        repo : String,
        kind : Symbol | String,
        number : Int32 | String,
        label : String? = nil,
        id : String? = nil,
        fg : Color | Symbol | String = :cyan,
        bg : Color | Symbol | String = Color.none,
        bold : Bool = false,
        dim : Bool = false,
        italic : Bool = false,
        underline : Bool = true,
        icon : String? = nil,
      ) : Link
        target_url = Terminal::OSC.github_url(repo, kind, number)
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
        new(
          url: target_url,
          label: label || default_label,
          id: id,
          fg: fg,
          bg: bg,
          bold: bold,
          dim: dim,
          italic: italic,
          underline: underline,
          icon: icon
        )
      end

      def self.rfc(
        repo : String,
        number : Int32 | String,
        label : String? = nil,
        fg : Color | Symbol | String = :cyan,
        bold : Bool = false,
        underline : Bool = true,
      ) : Link
        github(repo, :rfc, number, label: label, fg: fg, bold: bold, underline: underline)
      end

      def self.issue(
        repo : String,
        number : Int32 | String,
        label : String? = nil,
        fg : Color | Symbol | String = :cyan,
        bold : Bool = false,
        underline : Bool = true,
      ) : Link
        github(repo, :issue, number, label: label, fg: fg, bold: bold, underline: underline)
      end

      def self.pr(
        repo : String,
        number : Int32 | String,
        label : String? = nil,
        fg : Color | Symbol | String = :cyan,
        bold : Bool = false,
        underline : Bool = true,
      ) : Link
        github(repo, :pr, number, label: label, fg: fg, bold: bold, underline: underline)
      end

      def display_text : String
        if ic = @icon
          "#{ic} #{@label}"
        else
          @label
        end
      end

      def to_osc8 : String
        Terminal::OSC.hyperlink(display_text, @url, @link_id)
      end

      def preferred_size(available_w : Int32, available_h : Int32) : {Int32, Int32}
        w = VisualWidth.width(display_text)
        {Math.min(w, available_w), Math.min(1, available_h)}
      end

      def render(buffer : Buffer, x : Int32, y : Int32, width : Int32, height : Int32) : Nil
        return if width <= 0 || height <= 0
        buffer.put_string(
          x: x,
          y: y,
          text: display_text,
          fg: @fg,
          bg: @bg,
          bold: @bold,
          dim: @dim,
          italic: @italic,
          underline: @underline,
          max_width: width,
          keep_bg: true,
          hyperlink: @url
        )
      end
    end
  end
end

require "../style"
require "../terminal"

module Opal
  module Prompt
    # Smooth Unicode progress bar with percentage, counters, and in-place redrawing.
    class ProgressBar
      SUB_BLOCKS = [" ", "▏", "▎", "▍", "▌", "▋", "▊", "▉", "█"]

      property total : Int32
      property current : Int32
      property bar_width : Int32
      property color : Color
      property title : String?

      @driver : Terminal::Driver
      @start_time : Time::Instant

      def initialize(
        @total : Int32,
        @bar_width : Int32 = 30,
        color : Color | Symbol | String = :cyan,
        @title : String? = nil,
        driver : Terminal::Driver? = nil,
      )
        @current = 0
        @color = Color.from(color)
        @driver = driver || Terminal.default_driver
        @start_time = Time.instant
      end

      # Yields an active progress bar and renders updates.
      def self.run(
        total : Int32,
        bar_width : Int32 = 30,
        color : Color | Symbol | String = :cyan,
        title : String? = nil,
        driver : Terminal::Driver? = nil,
        &block : ProgressBar -> Nil
      ) : Nil
        bar = new(total, bar_width, color, title, driver)
        bar.render
        yield bar
        bar.finish
      end

      # Increments current value by *step* and redraws.
      def advance(step : Int32 = 1) : Nil
        set(@current + step)
      end

      # Sets current progress value and redraws.
      def set(val : Int32) : Nil
        @current = val.clamp(0, @total)
        render
      end

      def percent : Float64
        return 100.0 if @total <= 0
        (@current.to_f / @total) * 100.0
      end

      # Renders the progress bar string to the terminal.
      def render : Nil
        fraction = @total > 0 ? (@current.to_f / @total).clamp(0.0, 1.0) : 1.0
        total_sub_steps = (@bar_width * 8 * fraction).round.to_i

        full_blocks = total_sub_steps // 8
        remainder = total_sub_steps % 8

        bar_str = IO::Memory.new
        full_blocks.times { bar_str << "█" }
        if full_blocks < @bar_width
          bar_str << SUB_BLOCKS[remainder]
          empty_count = @bar_width - full_blocks - 1
          empty_count.times { bar_str << "░" }
        end

        styled_bar = Style.new.fg(@color).render(bar_str.to_s)
        dim_style = Style.new.faint
        bold_style = Style.new.bold

        prefix = @title ? "#{bold_style.render(@title.not_nil!)} " : ""
        pct_str = sprintf("%3.0f%%", percent)
        counter_str = "(#{@current}/#{@total})"

        @driver.write("\r\e[2K#{prefix}[#{styled_bar}] #{bold_style.render(pct_str)} #{dim_style.render(counter_str)}")
        @driver.flush
      end

      def finish : Nil
        set(@total)
        @driver.write("\n")
        @driver.flush
      end
    end
  end
end

require "../element"
require "../buffer"
require "../../style/color"
require "../../style/border"
require "../../style/visual_width"
require "../../terminal/driver"

module Opal
  module UI
    # Represents a single directory or file entry in FileDialog
    struct FileEntry
      getter name : String
      getter path : String
      getter? directory : Bool
      getter size : Int64
      getter modified : Time

      def initialize(
        @name : String,
        @path : String,
        @directory : Bool,
        @size : Int64 = 0_i64,
        @modified : Time = Time.utc,
      )
      end

      def display_size : String
        if @name == ".." || @directory
          "<DIR>"
        elsif @size < 1024
          "#{@size} B"
        elsif @size < 1024 * 1024
          "#{(@size / 1024.0).round(1)} KB"
        else
          "#{(@size / (1024.0 * 1024.0)).round(1)} MB"
        end
      end

      def icon : String
        if @name == ".." || @directory
          "[DIR]"
        else
          case File.extname(@name).downcase
          when ".cr"                    then "[CR]"
          when ".yml", ".yaml", ".json" then "[CFG]"
          when ".md", ".txt"            then "[DOC]"
          when ".png", ".jpg", ".svg"   then "[IMG]"
          when ".exe", ".bat", ".cmd"   then "[BIN]"
          when ".lock"                  then "[LCK]"
          else                               "[-]"
          end
        end
      end
    end

    # Interactive file and directory picker with directory traversal,
    # file/folder icons, live filter search, and split preview pane.
    class FileDialog < Control
      getter current_path : String
      getter? show_hidden : Bool
      property filter_query : String = ""
      property cursor : Int32 = 0
      property mode : Symbol # :open_file, :open_dir, :save_file
      property preview_fn : Proc(String, String)?
      getter? confirmed : Bool = false
      getter selected_path : String? = nil
      @entries : Array(FileEntry) = [] of FileEntry

      def initialize(
        initial_path : String = ".",
        @mode : Symbol = :open_file,
        @show_hidden : Bool = false,
        @preview_fn : Proc(String, String)? = nil,
      )
        @current_path = File.expand_path(initial_path)
        load_entries
        super()
      end

      def entries : Array(FileEntry)
        @entries
      end

      def load_entries(dir_path : String = @current_path) : Nil
        @entries.clear
        norm_dir = File.expand_path(dir_path)
        @current_path = norm_dir

        # Add parent navigation entry if not at root
        parent = File.dirname(norm_dir)
        if parent != norm_dir
          @entries << FileEntry.new("..", parent, true)
        end

        raw_entries = [] of FileEntry
        begin
          Dir.children(norm_dir).each do |name|
            next if !@show_hidden && name.starts_with?('.')
            full = File.join(norm_dir, name)
            is_dir = File.directory?(full) rescue false
            size = 0_i64
            mod = Time.utc
            begin
              info = File.info(full)
              size = info.size
              mod = info.modification_time
            rescue
            end
            raw_entries << FileEntry.new(name, full, is_dir, size, mod)
          end
        rescue
          # Permission error or unreadable directory
        end

        # Sort: directories first (alphabetical), then files (alphabetical)
        dirs = raw_entries.select(&.directory?).sort_by(&.name.downcase)
        files = raw_entries.reject(&.directory?).sort_by(&.name.downcase)

        dirs.each { |d| @entries << d }
        files.each { |f| @entries << f }
      end

      def filtered_entries : Array(FileEntry)
        return @entries if @filter_query.empty?
        q = @filter_query.downcase
        @entries.select do |e|
          e.name == ".." || e.name.downcase.includes?(q)
        end
      end

      def selected_entry : FileEntry?
        fe = filtered_entries
        return nil if fe.empty?
        idx = @cursor.clamp(0, Math.max(0, fe.size - 1))
        fe[idx]
      end

      def cursor_up : Nil
        @cursor = Math.max(0, @cursor - 1)
      end

      def cursor_down : Nil
        max_idx = Math.max(0, filtered_entries.size - 1)
        @cursor = Math.min(max_idx, @cursor + 1)
      end

      def page_up(lines : Int32 = 10) : Nil
        @cursor = Math.max(0, @cursor - lines)
      end

      def page_down(lines : Int32 = 10) : Nil
        max_idx = Math.max(0, filtered_entries.size - 1)
        @cursor = Math.min(max_idx, @cursor + lines)
      end

      def change_directory(new_path : String) : Nil
        @current_path = File.expand_path(new_path)
        @cursor = 0
        @filter_query = ""
        load_entries
      end

      def go_up : Nil
        parent = File.dirname(@current_path)
        if parent != @current_path
          change_directory(parent)
        end
      end

      def open_selected : Bool
        if entry = selected_entry
          if entry.directory?
            change_directory(entry.path)
            false
          else
            @selected_path = entry.path
            @confirmed = true
            true
          end
        else
          false
        end
      end

      def append_char(ch : Char) : Nil
        @filter_query += ch
        @cursor = 0
      end

      def backspace : Nil
        if @filter_query.empty?
          go_up
        else
          @filter_query = @filter_query[0...-1]
          @cursor = 0
        end
      end

      def toggle_hidden : Nil
        @show_hidden = !@show_hidden
        load_entries
      end

      def handle_key(key : Terminal::KeyEvent) : Bool
        case key.name
        when "up", "ctrl+p"
          cursor_up
          true
        when "down", "ctrl+n"
          cursor_down
          true
        when "pageup"
          page_up
          true
        when "pagedown"
          page_down
          true
        when "enter"
          open_selected
          true
        when "backspace"
          backspace
          true
        when "left"
          go_up
          true
        when "right"
          if (entry = selected_entry) && entry.directory?
            change_directory(entry.path)
            true
          else
            false
          end
        when "ctrl+h"
          toggle_hidden
          true
        else
          if key.name.size == 1 && !key.ctrl? && !key.alt?
            ch = key.name[0]
            if ch.ascii? && !ch.control?
              append_char(ch)
              return true
            end
          end
          false
        end
      end

      def handle_mouse(event : Terminal::MouseEvent) : Bool
        case event.button
        when Terminal::MouseButton::WheelUp
          cursor_up
          true
        when Terminal::MouseButton::WheelDown
          cursor_down
          true
        else
          false
        end
      end

      def preferred_size(available_w : Int32, available_h : Int32) : {Int32, Int32}
        {available_w, available_h}
      end

      def render(buffer : Buffer, x : Int32, y : Int32, width : Int32, height : Int32) : Nil
        return if width < 15 || height < 5

        # Erase entire file dialog area with spaces to ensure zero dirty cells
        buffer.fill(x, y, width, height, ' ')

        cur_y = y

        # 1. Header Path Breadcrumb
        title_str = "Path: #{@current_path}"
        max_p_w = width - 2
        if VisualWidth.width(title_str) > max_p_w
          title_str = "..." + title_str[-(max_p_w - 6)..]
        end
        buffer.put_string(x, cur_y, title_str, fg: Color.cyan, bold: true)
        cur_y += 1

        # 2. Search / Filter query bar
        if !@filter_query.empty?
          buffer.put_string(x, cur_y, "Filter: [ ", fg: Color.yellow, bold: true)
          buffer.put_string(x + 10, cur_y, @filter_query, fg: Color.bright_white, bold: true)
          buffer.put_string(x + 10 + VisualWidth.width(@filter_query), cur_y, " ]", fg: Color.yellow)
        else
          buffer.put_string(x, cur_y, "Filter: (type to filter files)", fg: Color.bright_black, italic: true)
        end
        cur_y += 1

        buffer.put_string(x, cur_y, "─" * width, fg: Color.bright_black)
        cur_y += 1

        fe = filtered_entries
        list_h = (y + height - 2) - cur_y
        return if list_h <= 0

        has_preview = width >= 50
        max_w_clamp = Math.max(24, width - 20)
        list_w = has_preview ? ((width * 0.55).to_i.clamp(24, max_w_clamp)) : width

        # 3. Render Entries List
        if fe.empty?
          buffer.put_string(x + 2, cur_y, "(No matching files or directories)", fg: Color.bright_black, italic: true)
        else
          # Compute scrolling window
          scroll_offset = 0
          if @cursor >= list_h
            scroll_offset = @cursor - list_h + 1
          end

          (0...list_h).each do |line_idx|
            entry_idx = scroll_offset + line_idx
            break if entry_idx >= fe.size

            entry = fe[entry_idx]
            is_active = (entry_idx == @cursor)
            row_y = cur_y + line_idx

            if is_active
              buffer.put_string(x, row_y, "▶ ", fg: Color.cyan, bold: true)
            else
              buffer.put_string(x, row_y, "  ")
            end

            # Icon & Name
            icon_str = entry.icon + " "
            buffer.put_string(x + 2, row_y, icon_str)
            icon_len = VisualWidth.width(icon_str)

            size_str = entry.display_size
            size_len = VisualWidth.width(size_str)
            name_max_w = Math.max(6, list_w - 4 - icon_len - size_len - 2)

            name_disp = entry.name
            if VisualWidth.width(name_disp) > name_max_w
              name_disp = name_disp[0...(name_max_w - 3)] + "..."
            end

            name_fg = if is_active
                        Color.bright_white
                      elsif entry.directory?
                        Color.cyan
                      else
                        Color.white
                      end

            name_bg = is_active ? Color.bright_black : Color.none

            buffer.put_string(x + 2 + icon_len, row_y, name_disp, fg: name_fg, bg: name_bg, bold: (is_active || entry.directory?))

            # Right-aligned size in entry column
            size_x = x + list_w - size_len - 1
            if size_x > x + 2 + icon_len + VisualWidth.width(name_disp)
              size_fg = entry.directory? ? Color.yellow : Color.bright_black
              buffer.put_string(size_x, row_y, size_str, fg: size_fg, dim: !entry.directory?)
            end
          end
        end

        # 4. Render Preview Pane (if width allows)
        if has_preview
          divider_x = x + list_w
          (cur_y...(y + height - 2)).each do |div_y|
            buffer.put_char(divider_x, div_y, '│', fg: Color.bright_black)
          end

          preview_x = divider_x + 2
          preview_w = (x + width) - preview_x

          if sel = selected_entry
            p_y = cur_y
            buffer.put_string(preview_x, p_y, "#{sel.icon} #{sel.name}", fg: Color.cyan, bold: true, max_width: preview_w)
            p_y += 1
            buffer.put_string(preview_x, p_y, "Size: #{sel.display_size}  Mod: #{sel.modified.to_s("%Y-%m-%d %H:%M")}", fg: Color.bright_black, max_width: preview_w)
            p_y += 1
            buffer.put_string(preview_x, p_y, "─" * preview_w, fg: Color.bright_black)
            p_y += 1

            if fn = @preview_fn
              content = fn.call(sel.path)
              content.split('\n').each do |line|
                break if p_y >= y + height - 2
                buffer.put_string(preview_x, p_y, line, fg: Color.bright_white, max_width: preview_w)
                p_y += 1
              end
            elsif sel.directory?
              # List child preview
              begin
                child_count = Dir.children(sel.path).size
                buffer.put_string(preview_x, p_y, "Directory containing #{child_count} items.", fg: Color.bright_black, italic: true)
                p_y += 2
                buffer.put_string(preview_x, p_y, "Press [Enter] to enter directory.", fg: Color.yellow)
              rescue
                buffer.put_string(preview_x, p_y, "(Permission denied)", fg: Color.red)
              end
            else
              # Text preview for readable files
              begin
                if File.size(sel.path) < 256 * 1024
                  lines = File.read_lines(sel.path)
                  max_prev_lines = (y + height - 2) - p_y
                  lines.first(max_prev_lines).each_with_index do |fline, lidx|
                    break if p_y >= y + height - 2
                    line_num_str = sprintf("%3d │ ", lidx + 1)
                    buffer.put_string(preview_x, p_y, line_num_str, fg: Color.bright_black)
                    text_x = preview_x + VisualWidth.width(line_num_str)
                    buffer.put_string(text_x, p_y, fline, fg: Color.bright_white, max_width: preview_w - VisualWidth.width(line_num_str))
                    p_y += 1
                  end
                else
                  buffer.put_string(preview_x, p_y, "(Large file - preview disabled)", fg: Color.bright_black, italic: true)
                end
              rescue
                buffer.put_string(preview_x, p_y, "(Binary or unreadable file)", fg: Color.bright_black, italic: true)
              end
            end
          end
        end

        # 5. Footer Instructions
        foot_y = y + height - 1
        buffer.put_string(x, foot_y, "─" * width, fg: Color.bright_black)
        foot_y += 1 if foot_y < buffer.height
        hints = " [Enter] Open  [Backspace/←] Up  [Type] Filter  [Ctrl+H] Hidden "
        buffer.put_string(x, Math.min(y + height - 1, buffer.height - 1), hints, fg: Color.bright_black)
      end
    end
  end

  # High-level interactive file dialog helper.
  def self.file_dialog(
    initial_path : String = ".",
    mode : Symbol = :open_file,
    show_hidden : Bool = false,
    preview : Proc(String, String)? = nil,
    driver : Terminal::Driver? = nil,
  ) : String?
    drv = driver || Terminal.default_driver
    dialog = UI::FileDialog.new(
      initial_path: initial_path,
      mode: mode,
      show_hidden: show_hidden,
      preview_fn: preview
    )

    render_frame = -> {
      w, h = drv.size
      buf = UI::Buffer.new(w, h)
      dialog.render(buf, 0, 0, w, h)
      drv.write(Terminal::Screen::CLEAR_ALL)
      drv.write(Terminal::Screen.move_to(1, 1))
      drv.write(buf.to_s)
      drv.flush
    }

    result : String? = nil

    drv.raw_mode do
      drv.hide_cursor
      render_frame.call

      loop do
        event = drv.read_event
        next unless event
        should_redraw = false

        case event
        when Terminal::KeyEvent
          if event.matches?("escape") || event.matches?("ctrl+c")
            break
          end

          if dialog.handle_key(event)
            should_redraw = true
            if dialog.confirmed?
              result = dialog.selected_path
              break
            end
          end
        end

        render_frame.call if should_redraw
      end
    ensure
      drv.show_cursor
    end

    result
  end
end

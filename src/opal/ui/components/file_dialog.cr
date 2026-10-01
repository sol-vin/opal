require "../control"
require "../buffer"
require "../../style/color"
require "../../style/border"
require "../../style/visual_width"
require "../../style/theme"
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
    # file type filters, save file mode, new file/folder creation,
    # theme compliance, and full mouse hit detection.
    class FileDialog < Control
      getter current_path : String
      getter? show_hidden : Bool
      property filter_query : String = ""
      property cursor : Int32 = 0
      property mode : Symbol # :open_file, :open_folder, :open_dir, :save_file, :new_file, :new_folder
      property preview_fn : Proc(String, String)?

      # File type filters (e.g. [".cr", ".json"])
      property filters : Array(String)
      property filter_presets : Array({String, Array(String)})
      property active_filter_idx : Int32 = 0

      # Filename input for save / new file modes
      property filename_input : String = ""
      property? overwrite_warning : Bool = false
      property validation_error : String? = nil

      getter? confirmed : Bool = false
      getter? canceled : Bool = false
      getter selected_path : String? = nil

      @entries : Array(FileEntry) = [] of FileEntry

      # Mouse hit detection tracking
      @hit_entries = [] of {Int32, Int32, Int32, Int32, Int32, String, Bool} # x, y, w, h, index, path, is_dir
      @hit_breadcrumbs = [] of {Int32, Int32, Int32, Int32, String}          # x, y, w, h, path
      @hit_buttons = [] of {Int32, Int32, Int32, Int32, Symbol}              # x, y, w, h, action
      @last_click_time : Time::Instant = Time.instant - 1.second
      @last_click_idx : Int32? = nil

      def initialize(
        initial_path : String = ".",
        @mode : Symbol = :open_file,
        @show_hidden : Bool = false,
        filters : Array(String) = [] of String,
        filter_presets : Array({String, Array(String)}) = [] of {String, Array(String)},
        @preview_fn : Proc(String, String)? = nil,
      )
        @current_path = File.expand_path(initial_path)
        @filters = filters.map(&.downcase)
        @filter_presets = filter_presets
        @entries = [] of FileEntry

        if !@filters.empty? && @filter_presets.empty?
          @filter_presets << {"Filtered Files", @filters}
          @filter_presets << {"All Files (*.*)", ["*"]}
        end

        super()
        load_entries
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

      # Returns active file extensions allowed by the current filter preset or filter list
      def current_filter_extensions : Array(String)
        if !@filter_presets.empty? && @active_filter_idx < @filter_presets.size
          @filter_presets[@active_filter_idx][1]
        else
          @filters
        end
      end

      def filtered_entries : Array(FileEntry)
        exts = current_filter_extensions
        base = if exts.empty? || exts.includes?("*")
                 @entries
               else
                 @entries.select do |e|
                   e.name == ".." || e.directory? || exts.includes?(File.extname(e.name).downcase)
                 end
               end

        return base if @filter_query.empty?
        q = @filter_query.downcase
        base.select do |e|
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
        @overwrite_warning = false
        @validation_error = nil
        load_entries
      end

      def go_up : Nil
        parent = File.dirname(@current_path)
        if parent != @current_path
          change_directory(parent)
        end
      end

      def cycle_filter : Nil
        return if @filter_presets.empty?
        @active_filter_idx = (@active_filter_idx + 1) % @filter_presets.size
        @cursor = 0
      end

      def open_selected : Bool
        @validation_error = nil

        case @mode
        when :open_folder, :open_dir
          if entry = selected_entry
            if entry.directory?
              if entry.name == ".."
                go_up
                false
              else
                change_directory(entry.path)
                false
              end
            else
              false
            end
          else
            confirm_folder(@current_path)
            true
          end
        when :save_file
          name = @filename_input.strip
          if name.empty? && (entry = selected_entry) && !entry.directory?
            name = entry.name
          end

          if name.empty?
            @validation_error = "Please enter a target filename"
            return false
          end

          target_path = File.join(@current_path, name)
          if File.exists?(target_path) && !@overwrite_warning
            @overwrite_warning = true
            return false
          end

          @selected_path = target_path
          @confirmed = true
          true
        when :new_file, :new_folder
          name = @filename_input.strip
          if name.empty?
            @validation_error = "Name cannot be empty"
            return false
          end

          if name.includes?('/') || name.includes?('\\') || name.includes?(':')
            @validation_error = "Name cannot contain slashes or colons"
            return false
          end

          target_path = File.join(@current_path, name)
          if File.exists?(target_path)
            @validation_error = "Item already exists"
            return false
          end

          begin
            if @mode == :new_folder
              Dir.mkdir_p(target_path)
            else
              File.touch(target_path)
            end
            @selected_path = target_path
            @confirmed = true
            true
          rescue ex
            @validation_error = "Creation error: #{ex.message}"
            false
          end
        else # :open_file
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
      end

      def confirm_folder(folder_path : String = @current_path) : Bool
        @selected_path = folder_path
        @confirmed = true
        true
      end

      def append_char(ch : Char) : Nil
        if @mode == :save_file || @mode == :new_file || @mode == :new_folder
          @filename_input += ch
          @overwrite_warning = false
          @validation_error = nil
        else
          @filter_query += ch
          @cursor = 0
        end
      end

      def backspace : Nil
        if @mode == :save_file || @mode == :new_file || @mode == :new_folder
          if !@filename_input.empty?
            @filename_input = @filename_input[0...-1]
            @overwrite_warning = false
            @validation_error = nil
          end
        else
          if @filter_query.empty?
            go_up
          else
            @filter_query = @filter_query[0...-1]
            @cursor = 0
          end
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
        when "enter", "return"
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
        when "ctrl+f"
          cycle_filter
          true
        when "ctrl+o", "ctrl+s"
          if @mode == :open_folder || @mode == :open_dir
            confirm_folder
            true
          elsif @mode == :save_file
            open_selected
            true
          else
            false
          end
        when "escape"
          if @overwrite_warning
            @overwrite_warning = false
            true
          else
            @canceled = true
            false
          end
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
        # 1. Mouse wheel scrolling
        case event.button
        when Terminal::MouseButton::WheelUp
          cursor_up
          return true
        when Terminal::MouseButton::WheelDown
          cursor_down
          return true
        end

        return false unless event.action == Terminal::MouseAction::Press

        mx = event.x
        my = event.y
        now = Time.instant

        # 2. Check Action Buttons click
        @hit_buttons.each do |bx, by, bw, bh, action|
          if mx >= bx && mx < bx + bw && my >= by && my < by + bh
            case action
            when :open, :confirm
              open_selected
              return true
            when :select_folder
              confirm_folder
              return true
            when :up
              go_up
              return true
            when :filter
              cycle_filter
              return true
            when :cancel
              @canceled = true
              return true
            end
          end
        end

        # 3. Check Breadcrumb Path segments click
        @hit_breadcrumbs.each do |bx, by, bw, bh, path|
          if mx >= bx && mx < bx + bw && my >= by && my < by + bh
            change_directory(path)
            return true
          end
        end

        # 4. Check File Entry row clicks
        fe = filtered_entries
        @hit_entries.each do |bx, by, bw, bh, entry_idx, path, is_dir|
          if mx >= bx && mx < bx + bw && my >= by && my < by + bh
            is_double = (@last_click_idx == entry_idx) && ((now - @last_click_time).total_milliseconds < 450)
            @last_click_time = now
            @last_click_idx = entry_idx
            @cursor = entry_idx

            if entry = fe[entry_idx]?
              if @mode == :save_file && !entry.directory?
                @filename_input = entry.name
                @overwrite_warning = false
              end
            end

            if is_double
              if is_dir
                change_directory(path)
              else
                open_selected
              end
            end
            return true
          end
        end

        false
      end

      def preferred_size(available_w : Int32, available_h : Int32) : {Int32, Int32}
        {available_w, available_h}
      end

      def render(buffer : Buffer, x : Int32, y : Int32, width : Int32, height : Int32) : Nil
        return if width < 15 || height < 5
        @hit_entries.clear
        @hit_breadcrumbs.clear
        @hit_buttons.clear

        th = current_theme
        c_bg = th.background
        c_surf = th.surface
        c_pri = th.primary
        c_acc = th.accent
        c_bdr = th.border
        c_txt = th.text
        c_mut = th.text_muted
        c_warn = th.warning
        c_err = th.danger

        # Erase entire file dialog area with spaces to ensure zero dirty cells
        buffer.fill(x, y, width, height, ' ', fg: c_txt, bg: c_bg)

        cur_y = y

        # 1. Header & Breadcrumbs
        up_btn = "[ Up ]"
        buffer.put_string(x, cur_y, up_btn, fg: c_pri, bg: c_surf, bold: true)
        @hit_buttons << {x, cur_y, VisualWidth.width(up_btn), 1, :up}

        path_x = x + VisualWidth.width(up_btn) + 1
        path_label = "Path: "
        buffer.put_string(path_x, cur_y, path_label, fg: c_mut)
        path_x += VisualWidth.width(path_label)

        # Break path into clickable breadcrumb segments
        parts = @current_path.split(File::SEPARATOR).reject(&.empty?)
        accum_path = @current_path.starts_with?(File::SEPARATOR) ? File::SEPARATOR.to_s : ""

        parts.each_with_index do |part, pidx|
          break if path_x >= x + width - 10
          accum_path = File.join(accum_path, part)
          seg_text = "#{part}#{File::SEPARATOR}"
          seg_w = VisualWidth.width(seg_text)

          buffer.put_string(path_x, cur_y, seg_text, fg: c_pri, bold: (pidx == parts.size - 1))
          @hit_breadcrumbs << {path_x, cur_y, seg_w, 1, accum_path}
          path_x += seg_w
        end
        cur_y += 1

        # 2. Filter / Input bar
        filter_label = if @mode == :save_file
                         "Save As: "
                       elsif @mode == :new_file
                         "New File: "
                       elsif @mode == :new_folder
                         "New Folder: "
                       else
                         "Filter: "
                       end

        buffer.put_string(x, cur_y, filter_label, fg: c_acc, bold: true)
        input_x = x + VisualWidth.width(filter_label)

        active_input_val = (@mode == :save_file || @mode == :new_file || @mode == :new_folder) ? @filename_input : @filter_query
        if !active_input_val.empty?
          buffer.put_string(input_x, cur_y, "[ ", fg: c_mut)
          buffer.put_string(input_x + 2, cur_y, active_input_val, fg: c_txt, bold: true)
          bracket_x = input_x + 2 + VisualWidth.width(active_input_val)
          buffer.put_char(bracket_x, cur_y, '█', fg: c_pri)
          buffer.put_string(bracket_x + 1, cur_y, " ]", fg: c_mut)
        else
          placeholder_hint = (@mode == :save_file || @mode == :new_file || @mode == :new_folder) ? "(type name here)" : "(type to filter)"
          buffer.put_string(input_x, cur_y, placeholder_hint, fg: c_mut, italic: true)
        end

        # Show active filter extension badge on right if available
        if !@filter_presets.empty?
          preset_name = @filter_presets[@active_filter_idx][0]
          preset_badge = "[ #{preset_name} ]"
          badge_w = VisualWidth.width(preset_badge)
          badge_x = x + width - badge_w - 1
          if badge_x > input_x + VisualWidth.width(active_input_val) + 4
            buffer.put_string(badge_x, cur_y, preset_badge, fg: c_bg, bg: c_acc, bold: true)
            @hit_buttons << {badge_x, cur_y, badge_w, 1, :filter}
          end
        end
        cur_y += 1

        # Overwrite or validation error warnings
        if @overwrite_warning
          warn_str = "[!] File exists. Overwrite? Press [Enter] to confirm, [Esc] to cancel."
          buffer.put_string(x, cur_y, warn_str, fg: c_warn, bold: true)
          cur_y += 1
        elsif err = @validation_error
          buffer.put_string(x, cur_y, "[!] #{err}", fg: c_err, bold: true)
          cur_y += 1
        end

        buffer.put_string(x, cur_y, "─" * width, fg: c_bdr)
        cur_y += 1

        fe = filtered_entries
        list_h = (y + height - 2) - cur_y

        has_preview = width >= 54
        max_w_clamp = Math.max(24, width - 20)
        list_w = has_preview ? ((width * 0.54).to_i.clamp(24, max_w_clamp)) : width

        if list_h > 0
          # 3. Render Entries List
          if fe.empty?
            buffer.put_string(x + 2, cur_y, "(No matching files or directories)", fg: c_mut, italic: true)
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
                buffer.put_string(x, row_y, "> ", fg: c_pri, bold: true)
              else
                buffer.put_string(x, row_y, "  ")
              end

              # Icon & Name
              icon_str = entry.icon + " "
              buffer.put_string(x + 2, row_y, icon_str, fg: entry.directory? ? c_acc : c_mut)
              icon_len = VisualWidth.width(icon_str)

              size_str = entry.display_size
              size_len = VisualWidth.width(size_str)
              name_max_w = Math.max(6, list_w - 4 - icon_len - size_len - 2)

              name_disp = entry.name
              if VisualWidth.width(name_disp) > name_max_w
                name_disp = name_disp[0...(name_max_w - 3)] + "..."
              end

              name_fg = if is_active
                          th.primary
                        elsif entry.directory?
                          c_acc
                        else
                          c_txt
                        end

              name_bg = is_active ? c_surf : Color.none

              buffer.put_string(x + 2 + icon_len, row_y, name_disp, fg: name_fg, bg: name_bg, bold: (is_active || entry.directory?))

              # Right-aligned size in entry column
              size_x = x + list_w - size_len - 1
              if size_x > x + 2 + icon_len + VisualWidth.width(name_disp)
                size_fg = entry.directory? ? c_acc : c_mut
                buffer.put_string(size_x, row_y, size_str, fg: size_fg)
              end

              # Store hit box for row click
              @hit_entries << {x, row_y, list_w, 1, entry_idx, entry.path, entry.directory?}
            end
          end

          # 4. Render Preview Pane (if width allows)
          if has_preview
            divider_x = x + list_w
            (cur_y...(y + height - 2)).each do |div_y|
              buffer.put_char(divider_x, div_y, '│', fg: c_bdr)
            end

            preview_x = divider_x + 2
            preview_w = (x + width) - preview_x

            if sel = selected_entry
              p_y = cur_y
              buffer.put_string(preview_x, p_y, "#{sel.icon} #{sel.name}", fg: c_pri, bold: true, max_width: preview_w)
              p_y += 1
              buffer.put_string(preview_x, p_y, "Size: #{sel.display_size}  Mod: #{sel.modified.to_s("%Y-%m-%d %H:%M")}", fg: c_mut, max_width: preview_w)
              p_y += 1
              buffer.put_string(preview_x, p_y, "─" * preview_w, fg: c_bdr)
              p_y += 1

              if fn = @preview_fn
                content = fn.call(sel.path)
                content.split('\n').each do |line|
                  break if p_y >= y + height - 2
                  buffer.put_string(preview_x, p_y, line, fg: c_txt, max_width: preview_w)
                  p_y += 1
                end
              elsif sel.directory?
                begin
                  child_count = Dir.children(sel.path).size
                  buffer.put_string(preview_x, p_y, "Directory containing #{child_count} items.", fg: c_mut, italic: true)
                  p_y += 2
                  buffer.put_string(preview_x, p_y, "Double click or [Enter] to navigate.", fg: c_acc)
                rescue
                  buffer.put_string(preview_x, p_y, "(Permission denied)", fg: c_err)
                end
              else
                begin
                  if File.size(sel.path) < 256 * 1024
                    lines = File.read_lines(sel.path)
                    max_prev_lines = (y + height - 2) - p_y
                    lines.first(max_prev_lines).each_with_index do |fline, lidx|
                      break if p_y >= y + height - 2
                      line_num_str = sprintf("%3d │ ", lidx + 1)
                      buffer.put_string(preview_x, p_y, line_num_str, fg: c_mut)
                      text_x = preview_x + VisualWidth.width(line_num_str)
                      buffer.put_string(text_x, p_y, fline, fg: c_txt, max_width: preview_w - VisualWidth.width(line_num_str))
                      p_y += 1
                    end
                  else
                    buffer.put_string(preview_x, p_y, "(Large file - preview disabled)", fg: c_mut, italic: true)
                  end
                rescue
                  buffer.put_string(preview_x, p_y, "(Binary or unreadable file)", fg: c_mut, italic: true)
                end
              end
            end
          end
        end

        # 5. Footer Action Buttons & Hints
        foot_y = y + height - 1
        buffer.put_string(x, foot_y - 1, "─" * width, fg: c_bdr)

        cur_fx = x
        btn_action_label = case @mode
                           when :open_folder, :open_dir then "[ Select Folder ]"
                           when :save_file              then "[ Save ]"
                           when :new_file               then "[ Create File ]"
                           when :new_folder             then "[ Create Folder ]"
                           else                              "[ Open ]"
                           end

        buffer.put_string(cur_fx, foot_y, btn_action_label, fg: c_bg, bg: c_pri, bold: true)
        @hit_buttons << {cur_fx, foot_y, VisualWidth.width(btn_action_label), 1, :confirm}
        cur_fx += VisualWidth.width(btn_action_label) + 1

        btn_cancel = "[ Cancel ]"
        buffer.put_string(cur_fx, foot_y, btn_cancel, fg: c_txt, bg: c_surf)
        @hit_buttons << {cur_fx, foot_y, VisualWidth.width(btn_cancel), 1, :cancel}
        cur_fx += VisualWidth.width(btn_cancel) + 2

        hints = if @mode == :open_folder || @mode == :open_dir
                  "Ctrl+O/Enter to select folder │ Click / Double Click"
                elsif @mode == :save_file
                  "Enter to Save │ Click item to fill name"
                else
                  "Enter/Double Click to Open │ Backspace to Go Up"
                end

        avail_hints_w = (x + width) - cur_fx
        if avail_hints_w > 0
          buffer.put_string(cur_fx, foot_y, hints, fg: c_mut, max_width: avail_hints_w)
        end
      end
    end

    # Specialized OpenFileDialog for files or folders with extension filtering
    class OpenFileDialog < FileDialog
      def initialize(
        initial_path : String = ".",
        folder_mode : Bool = false,
        filters : Array(String) = [] of String,
        show_hidden : Bool = false,
      )
        super(
          initial_path: initial_path,
          mode: folder_mode ? :open_folder : :open_file,
          show_hidden: show_hidden,
          filters: filters
        )
      end
    end

    # Specialized SaveFileDialog for saving files with filename entry and overwrite guards
    class SaveFileDialog < FileDialog
      def initialize(
        initial_path : String = ".",
        default_name : String = "untitled.txt",
        filters : Array(String) = [] of String,
        show_hidden : Bool = false,
      )
        super(
          initial_path: initial_path,
          mode: :save_file,
          show_hidden: show_hidden,
          filters: filters
        )
        @filename_input = default_name
      end
    end

    # Specialized NewFileDialog for creating new files or folders on disk
    class NewFileDialog < FileDialog
      def initialize(
        initial_path : String = ".",
        is_folder : Bool = false,
        show_hidden : Bool = false,
      )
        super(
          initial_path: initial_path,
          mode: is_folder ? :new_folder : :new_file,
          show_hidden: show_hidden
        )
      end
    end
  end

  # High-level interactive file dialog helper
  def self.file_dialog(
    initial_path : String = ".",
    mode : Symbol = :open_file,
    show_hidden : Bool = false,
    filters : Array(String) = [] of String,
    preview : Proc(String, String)? = nil,
    driver : Terminal::Driver? = nil,
  ) : String?
    dialog = UI::FileDialog.new(
      initial_path: initial_path,
      mode: mode,
      show_hidden: show_hidden,
      filters: filters,
      preview_fn: preview
    )
    run_file_dialog_loop(dialog, driver)
  end

  # High-level helper for opening files
  def self.open_file_dialog(
    initial_path : String = ".",
    filters : Array(String) = [] of String,
    driver : Terminal::Driver? = nil,
  ) : String?
    dialog = UI::OpenFileDialog.new(initial_path: initial_path, filters: filters)
    run_file_dialog_loop(dialog, driver)
  end

  # High-level helper for choosing folders
  def self.open_folder_dialog(
    initial_path : String = ".",
    driver : Terminal::Driver? = nil,
  ) : String?
    dialog = UI::OpenFileDialog.new(initial_path: initial_path, folder_mode: true)
    run_file_dialog_loop(dialog, driver)
  end

  # High-level helper for saving files
  def self.save_file_dialog(
    initial_path : String = ".",
    default_name : String = "untitled.txt",
    filters : Array(String) = [] of String,
    driver : Terminal::Driver? = nil,
  ) : String?
    dialog = UI::SaveFileDialog.new(initial_path: initial_path, default_name: default_name, filters: filters)
    run_file_dialog_loop(dialog, driver)
  end

  # High-level helper for creating new files or folders
  def self.new_file_dialog(
    initial_path : String = ".",
    is_folder : Bool = false,
    driver : Terminal::Driver? = nil,
  ) : String?
    dialog = UI::NewFileDialog.new(initial_path: initial_path, is_folder: is_folder)
    run_file_dialog_loop(dialog, driver)
  end

  # Internal loop runner for interactive dialogs
  private def self.run_file_dialog_loop(dialog : UI::FileDialog, driver : Terminal::Driver?) : String?
    drv = driver || Terminal.default_driver

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
      drv.enable_mouse
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
            elsif dialog.canceled?
              break
            end
          end
        when Terminal::MouseEvent
          if dialog.handle_mouse(event)
            should_redraw = true
            if dialog.confirmed?
              result = dialog.selected_path
              break
            elsif dialog.canceled?
              break
            end
          end
        end

        render_frame.call if should_redraw
      end
    ensure
      drv.disable_mouse
      drv.show_cursor
    end

    result
  end
end

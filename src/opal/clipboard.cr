require "./terminal/osc"

module Opal
  # Cross-platform system clipboard utility for terminal applications.
  # Provides dual-layer clipboard copying:
  # 1. Terminal OSC 52 escape sequences for remote/SSH/multiplexed sessions.
  # 2. Native OS clipboard integration (Windows `clip.exe`, macOS `pbcopy`, Linux `wl-copy`/`xclip`).
  module Clipboard
    # Copies text to the system clipboard.
    # By default, both emits OSC 52 escape sequences to `io` and invokes the native OS clipboard utility.
    def self.copy(
      text : String,
      io : IO = STDOUT,
      use_native : Bool = true,
      use_osc52 : Bool = true,
    ) : Bool
      success = false

      # 1. Emit OSC 52 escape sequence to terminal
      if use_osc52
        begin
          Terminal::OSC.copy_to_clipboard(text, io)
          success = true
        rescue
          # Terminal stream might not be writable
        end
      end

      # 2. Invoke native OS clipboard if enabled
      if use_native
        native_success = copy_native(text)
        success = success || native_success
      end

      success
    end

    # Reads text from the host OS clipboard using platform-specific tools.
    def self.paste : String?
      {% if flag?(:windows) %}
        begin
          stdout = IO::Memory.new
          # Use powershell Get-Clipboard on Windows
          status = Process.run(
            "powershell.exe",
            ["-NoProfile", "-NonInteractive", "-Command", "Get-Clipboard"],
            output: stdout
          )
          status.success? ? stdout.to_s.rstrip("\r\n") : nil
        rescue
          nil
        end
      {% elsif flag?(:darwin) %}
        begin
          stdout = IO::Memory.new
          status = Process.run("pbpaste", output: stdout)
          status.success? ? stdout.to_s : nil
        rescue
          nil
        end
      {% else %}
        # Linux / BSD: Try Wayland (wl-paste) first, then X11 (xclip / xsel)
        begin
          stdout = IO::Memory.new
          status = Process.run("wl-paste", output: stdout)
          return stdout.to_s if status.success?
        rescue
        end

        begin
          stdout = IO::Memory.new
          status = Process.run("xclip", ["-selection", "clipboard", "-o"], output: stdout)
          return stdout.to_s if status.success?
        rescue
        end

        begin
          stdout = IO::Memory.new
          status = Process.run("xsel", ["--clipboard", "--output"], output: stdout)
          return stdout.to_s if status.success?
        rescue
        end

        nil
      {% end %}
    end

    # Returns true if native OS clipboard tools or OSC 52 are available.
    def self.supported? : Bool
      true
    end

    # Copies text using platform-specific subprocesses.
    private def self.copy_native(text : String) : Bool
      {% if flag?(:windows) %}
        # Windows: Use built-in clip.exe via cmd /c clip
        begin
          input_io = IO::Memory.new(text)
          status = Process.run("cmd.exe", ["/c", "clip"], input: input_io)
          return true if status.success?
        rescue
        end

        # Fallback to PowerShell Set-Clipboard
        begin
          input_io = IO::Memory.new(text)
          status = Process.run("powershell.exe", ["-NoProfile", "-NonInteractive", "-Command", "$input | Set-Clipboard"], input: input_io)
          return status.success?
        rescue
          false
        end
      {% elsif flag?(:darwin) %}
        # macOS: Built-in pbcopy
        begin
          input_io = IO::Memory.new(text)
          status = Process.run("pbcopy", input: input_io)
          status.success?
        rescue
          false
        end
      {% else %}
        # Linux / BSD: Try Wayland (wl-copy) then X11 (xclip / xsel)
        begin
          input_io = IO::Memory.new(text)
          status = Process.run("wl-copy", input: input_io)
          return true if status.success?
        rescue
        end

        begin
          input_io = IO::Memory.new(text)
          status = Process.run("xclip", ["-selection", "clipboard"], input: input_io)
          return true if status.success?
        rescue
        end

        begin
          input_io = IO::Memory.new(text)
          status = Process.run("xsel", ["--clipboard", "--input"], input: input_io)
          return true if status.success?
        rescue
        end

        false
      {% end %}
    end
  end
end

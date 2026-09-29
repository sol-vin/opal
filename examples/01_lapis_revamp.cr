require "../src/opal"

# Example 1: Real-world Lapis CLI Revamp
# Demonstrates how the Lapis CLI toolchain is cleanly implemented with Opal,
# eliminating repetitive OptionParser boilerplate, manual ARGV slicing, and raw ANSI strings.

app = Opal.cli "lapis", "0.2.0" do |cli|
  cli.description "Unified Crystal Engine Toolchain for Godot"

  cli.flag :quiet, "--quiet", "-q", description: "Suppress non-essential log output", global: true
  cli.flag :verbose, "--verbose", description: "Enable verbose debug logging", global: true

  # lapis dirs
  cli.command :dirs do |cmd|
    cmd.description "Ensure all project and binary output directories exist"
    cmd.run do |ctx|
      puts Opal.style.bold.fg(:green).render("[Lapis] Ensuring output directories exist...")
      0
    end
  end

  # lapis deps
  cli.command :deps do |cmd|
    cmd.description "Verify and copy Crystal runtime dependencies & libgodot DLLs"
    cmd.option :target, "--target-bin=DIR", "-t", description: "Target directory to synchronize"
    cmd.run do |ctx|
      target = ctx.string?(:target) || "bin"
      puts Opal.style.fg(:cyan).render("[Lapis] Syncing dependencies to #{target}...")
      0
    end
  end

  # lapis build
  cli.command :build do |cmd|
    cmd.description "Compile Crystal game libraries, plugins, or standalone executables"
    cmd.option :entry, "--entry=ENTRY", "-e", description: "Entry file", default: "src/main.cr"
    cmd.option :output, "--output=OUT", "-o", description: "Output binary path"
    cmd.option :flags, "--flags=FLAGS", description: "Compilation flags"
    cmd.flag :release, "--release", "-r", description: "Build with release optimizations"

    cmd.example "lapis build -e src/editor/plugin.cr -o bin/plugin.dll -r"

    cmd.run do |ctx|
      entry = ctx.string(:entry)
      out_path = ctx.string?(:output) || "bin/game.dll"
      release = ctx.flag?(:release)

      badge = release ? Opal.style.bold.bg(:magenta).fg(:white).render(" RELEASE ") : Opal.style.bold.bg(:blue).fg(:white).render(" DEBUG ")
      puts "#{badge} Compiling #{entry} -> #{out_path}"
      0
    end
  end

  # lapis bind (with nested subcommands: engine, project)
  cli.command :bind do |bind_cmd|
    bind_cmd.alias_name "generate", "bindings"
    bind_cmd.description "Generate typed bindings for Godot engine or project custom nodes"

    bind_cmd.subcommand :engine do |sub|
      sub.description "Generate LibGodot engine class bindings"
      sub.run do |_ctx|
        puts Opal.style.bold.fg(:cyan).render("[Lapis] Generating engine bindings...")
        0
      end
    end

    bind_cmd.subcommand :project do |sub|
      sub.description "Generate wrappers for custom GDScript nodes"
      sub.run do |_ctx|
        puts Opal.style.bold.fg(:cyan).render("[Lapis] Generating custom project bindings...")
        0
      end
    end
  end

  # lapis test
  cli.command :test do |cmd|
    cmd.description "Run unit specs, in-editor tool tests, and runtime test projects"
    cmd.option :project, "--project=PROJECT", "-p", description: "Target project"
    cmd.option :filter, "--filter=PATTERN", "-f", description: "Test pattern filter"

    cmd.run do |ctx|
      proj = ctx.string?(:project) || "all"
      puts Opal.style.bold.fg(:green).render("[Lapis] Running tests for project: #{proj}")
      0
    end
  end
end

exit app.run(ARGV)

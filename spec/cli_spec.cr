require "./spec_helper"

describe Opal::CLI do
  it "defines and routes top-level commands" do
    executed = false
    app = Opal.cli("test_cli", "1.0.0") do |cli|
      cli.command :greet do |cmd|
        cmd.description "Greet a user"
        cmd.run do |_ctx|
          executed = true
          0
        end
      end
    end

    status = app.run(["greet"])
    status.should eq(0)
    executed.should be_true
  end

  it "routes deeply nested subcommands" do
    executed = false
    app = Opal.cli("db_tool") do |cli|
      cli.command :db do |db|
        db.command :migrate do |mig|
          mig.run do |_ctx|
            executed = true
            0
          end
        end
      end
    end

    app.run(["db", "migrate"]).should eq(0)
    executed.should be_true
  end

  it "supports command aliases" do
    executed = false
    app = Opal.cli("tool") do |cli|
      cli.command :generate do |cmd|
        cmd.alias_name "gen", "g"
        cmd.run { |_ctx| executed = true; 0 }
      end
    end

    app.run(["gen"]).should eq(0)
    executed.should be_true
  end

  it "parses boolean flags and clustered short flags" do
    captured_quiet = false
    captured_verbose = false

    app = Opal.cli("tool") do |cli|
      cli.flag :quiet, "--quiet", "-q"
      cli.flag :verbose, "--verbose", "-v"
      cli.command :run do |cmd|
        cmd.run do |ctx|
          captured_quiet = ctx.flag?(:quiet)
          captured_verbose = ctx.flag?(:verbose)
          0
        end
      end
    end

    app.run(["run", "-qv"]).should eq(0)
    captured_quiet.should be_true
    captured_verbose.should be_true
  end

  it "parses typed options: string, int, float, array" do
    res_str = ""
    res_int = 0
    res_float = 0.0
    res_arr = [] of String

    app = Opal.cli("tool") do |cli|
      cli.command :test do |cmd|
        cmd.option :name, "--name=NAME", "-n"
        cmd.option :count, "--count=N", "-c", type: :int
        cmd.option :ratio, "--ratio=R", type: :float
        cmd.option :tag, "--tag=TAG", type: :array

        cmd.run do |ctx|
          res_str = ctx.string(:name)
          res_int = ctx.int(:count)
          res_float = ctx.float(:ratio)
          res_arr = ctx.array(:tag)
          0
        end
      end
    end

    app.run(["test", "-n", "Opal", "--count=42", "--ratio", "3.14", "--tag=core", "--tag=ui"]).should eq(0)
    res_str.should eq("Opal")
    res_int.should eq(42)
    res_float.should eq(3.14)
    res_arr.should eq(["core", "ui"])
  end

  it "enforces choices validation on options" do
    app = Opal.cli("tool") do |cli|
      cli.command :format do |cmd|
        cmd.option :type, "--type=TYPE", choices: ["json", "yaml", "xml"]
        cmd.run { |_ctx| 0 }
      end
    end

    # Valid choice
    app.run(["format", "--type=json"]).should eq(0)

    # Invalid choice returns error code 1
    app.run(["format", "--type=txt"]).should eq(1)
  end

  it "validates required options" do
    app = Opal.cli("tool") do |cli|
      cli.command :auth do |cmd|
        cmd.option :token, "--token=TOKEN", required: true
        cmd.run { |_ctx| 0 }
      end
    end

    # Missing required option returns 1
    app.run(["auth"]).should eq(1)

    # Provided required option returns 0
    app.run(["auth", "--token=secret"]).should eq(0)
  end

  it "parses required and optional positional arguments" do
    captured_arg1 = ""
    captured_arg2 = ""

    app = Opal.cli("tool") do |cli|
      cli.command :copy do |cmd|
        cmd.argument :src, required: true
        cmd.argument :dst, default: "backup.txt"
        cmd.run do |ctx|
          captured_arg1 = ctx.arg!(:src)
          captured_arg2 = ctx.arg(:dst) || ""
          0
        end
      end
    end

    app.run(["copy", "main.cr"]).should eq(0)
    captured_arg1.should eq("main.cr")
    captured_arg2.should eq("backup.txt")

    app.run(["copy", "main.cr", "custom.cr"]).should eq(0)
    captured_arg2.should eq("custom.cr")
  end

  it "propagates global flags to all subcommands" do
    received_quiet = false

    app = Opal.cli("lapis") do |cli|
      cli.flag :quiet, "--quiet", "-q", global: true

      cli.command :build do |build|
        build.run do |ctx|
          received_quiet = ctx.flag?(:quiet)
          0
        end
      end
    end

    app.run(["build", "-q"]).should eq(0)
    received_quiet.should be_true
  end

  it "executes before and after hooks" do
    events = [] of String

    app = Opal.cli("tool") do |cli|
      cli.command :deploy do |cmd|
        cmd.before { |_ctx| events << "before" }
        cmd.after { |_ctx| events << "after" }
        cmd.run do |_ctx|
          events << "action"
          0
        end
      end
    end

    app.run(["deploy"]).should eq(0)
    events.should eq(["before", "action", "after"])
  end

  it "renders styled help text with command list and options" do
    app = Opal.cli("godot_tool", "2.1.0") do |cli|
      cli.description "Game engine helper"
      cli.command :build, "Compile game binaries"
    end

    help = app.help_text("godot_tool")
    help.should contain("Usage:")
    help.should contain("godot_tool")
    help.should contain("build")
    help.should contain("Compile game binaries")
  end

  it "generates bash and fish completion scripts" do
    app = Opal.cli("mycli") do |cli|
      cli.command :run, "Run task"
      cli.flag :debug, "--debug"
    end

    bash_script = Opal::CLI::Completion.bash("mycli", app)
    bash_script.should contain("_mycli_completions()")
    bash_script.should contain("complete -F _mycli_completions mycli")

    fish_script = Opal::CLI::Completion.fish("mycli", app)
    fish_script.should contain("complete -c mycli")
    fish_script.should contain("run")
  end
  it "accepts global options preceding subcommands" do
    received_quiet = false
    executed = false

    app = Opal.cli("lapis") do |cli|
      cli.flag :quiet, "--quiet", "-q", global: true
      cli.command :build do |build|
        build.run do |ctx|
          executed = true
          received_quiet = ctx.flag?(:quiet)
          0
        end
      end
    end

    app.run(["-q", "build"]).should eq(0)
    executed.should be_true
    received_quiet.should be_true
  end

  it "suggests close command match on typo" do
    app = Opal.cli("tool") do |cli|
      cli.command :build, "Compile game"
      cli.command :test, "Run test suite"
    end

    expect_raises(Opal::CLI::ParseError, /Did you mean 'build'/) do
      Opal::CLI::Parser.parse(app, ["biuld"])
    end
  end

  it "suggests close option match on typo" do
    app = Opal.cli("tool") do |cli|
      cli.command :build do |b|
        b.flag :release, "--release", "-r"
      end
    end

    expect_raises(Opal::CLI::ParseError, /Did you mean '--release'/) do
      Opal::CLI::Parser.parse(app, ["build", "--releas"])
    end
  end

  it "groups commands by category in help text" do
    app = Opal.cli("lapis") do |cli|
      cli.command :build do |b|
        b.category "Build Commands"
        b.description "Compile code"
      end
      cli.command :test do |t|
        t.category "Test Commands"
        t.description "Run specs"
      end
    end

    help = app.help_text("lapis")
    help.should contain("Build Commands:")
    help.should contain("Test Commands:")
    help.should contain("build")
    help.should contain("test")
  end

  it "generates powershell completion scripts" do
    app = Opal.cli("mycli") do |cli|
      cli.command :build, "Build task"
      cli.command :test, "Test task"
    end

    ps_script = Opal::CLI::Completion.powershell("mycli", app)
    ps_script.should contain("Register-ArgumentCompleter")
    ps_script.should contain("'build'")
    ps_script.should contain("'test'")
  end
end

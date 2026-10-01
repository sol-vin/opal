require "json"
require "../../ui/components/tree"
require "../command"

module Opal
  module CLI
    module Tools
      module TreeTool
        def self.register(cmd : Command)
          cmd.summary "Render directory hierarchies or JSON trees with branch connectors"
          cmd.description "Draws a clean tree view with Unicode branch connectors (├──, └──), colored nodes, and file type indicators."

          cmd.arg :path, "Directory path or '-' for JSON stdin (default: '.')", required: false, default: "."

          cmd.group "Traversal & Display" do
            cmd.opt :depth, "-L, --depth=N", "Maximum recursion depth", default: 3, type: :int
            cmd.flag :all, "-a, --all", description: "Include hidden files (dotfiles)"
            cmd.flag :dirs_only, "-d, --dirs-only", description: "List directories only"
            cmd.flag :json, "--json", description: "Parse piped STDIN as JSON tree"
            cmd.opt :title, "-t, --title=TITLE", "Optional tree header title"
          end

          cmd.section "PIPELINE COMPOSITION" do |s|
            s.example "opal tree . -L 2"
            s.example "opal tree src/opal -d"
            s.example "cat package.json | opal tree --json"
          end

          cmd.run do |ctx|
            if ctx.flag?(:json) || (ctx.pipe? && (ctx.arg(:path) == "-" || ctx.arg(:path) == "."))
              # Attempt JSON tree
              if content = ctx.stdin_content
                if content.strip.starts_with?('{') || content.strip.starts_with?('[')
                  begin
                    parsed = JSON.parse(content)
                    root_node = json_to_tree_node("root", parsed)
                    UI::Tree.print([root_node], title: ctx.string?(:title))
                    next 0
                  rescue
                  end
                end
              end
            end

            target_path = ctx.arg(:path) || "."
            unless Dir.exists?(target_path) || File.exists?(target_path)
              STDERR.puts "\e[31mError:\e[0m Path not found: '#{target_path}'"
              next 1
            end

            max_depth = ctx.int(:depth)
            show_hidden = ctx.flag?(:all)
            dirs_only = ctx.flag?(:dirs_only)

            root_node = build_dir_tree(target_path, 0, max_depth, show_hidden, dirs_only)
            title = ctx.string?(:title) || "Directory: #{target_path}"

            UI::Tree.print([root_node], title: title)
            0
          end
        end

        def self.build_dir_tree(
          path : String,
          current_depth : Int32,
          max_depth : Int32,
          show_hidden : Bool,
          dirs_only : Bool,
        ) : UI::TreeNode
          name = File.basename(path)
          name = path if name.empty?

          if File.directory?(path)
            node = UI::TreeNode.new(name, color: :cyan)
            if current_depth < max_depth
              begin
                entries = Dir.children(path).sort
                entries.each do |entry|
                  next if !show_hidden && entry.starts_with?('.')
                  child_path = File.join(path, entry)
                  is_dir = File.directory?(child_path)
                  next if dirs_only && !is_dir

                  child_node = build_dir_tree(child_path, current_depth + 1, max_depth, show_hidden, dirs_only)
                  node.add(child_node)
                end
              rescue
              end
            end
            node
          else
            ext = File.extname(path)
            color : Symbol = case ext
                             when ".cr", ".rb", ".py", ".js", ".ts", ".go", ".rs", ".c", ".cpp" then :green
                             when ".json", ".yaml", ".yml", ".toml", ".xml", ".csv"             then :yellow
                             when ".md", ".txt", ".doc"                                         then :white
                             else                                                                    :white
                             end
            UI::TreeNode.new(name, color: color)
          end
        end

        def self.json_to_tree_node(key : String, val : JSON::Any) : UI::TreeNode
          if obj = val.as_h?
            node = UI::TreeNode.new("#{key} (object)", color: :cyan)
            obj.each do |k, v|
              node.add(json_to_tree_node(k, v))
            end
            node
          elsif arr = val.as_a?
            node = UI::TreeNode.new("#{key} [#{arr.size}]", color: :yellow)
            arr.each_with_index do |v, idx|
              node.add(json_to_tree_node("[#{idx}]", v))
            end
            node
          else
            color : Symbol = val.raw.is_a?(Number) ? :yellow : (val.raw.is_a?(Bool) ? :magenta : :green)
            UI::TreeNode.new("#{key}: #{val.raw}", color: color)
          end
        end
      end
    end
  end
end

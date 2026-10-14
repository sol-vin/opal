require "./spec_helper"

describe Opal::Core::SplitLayout do
  describe "1D & 2D Constraint Solver" do
    it "solves horizontal proportional flex ratios across 2 panes" do
      layout = Opal::Core::SplitLayout.horizontal(ratio: 0.25, show_separator: true)
      extents = layout.solve_extents(81) # 81 - 1 separator = 80 available
      extents.should eq([20, 60])

      geoms = layout.solve(0, 0, 81, 24)
      geoms.size.should eq(2)
      geoms[0].rect.should eq(Opal::UI::Rect.new(0, 0, 20, 24))
      geoms[0].divider_x.should eq(20)
      geoms[1].rect.should eq(Opal::UI::Rect.new(21, 0, 60, 24))
      geoms[1].divider_x.should be_nil
    end

    it "solves vertical proportional flex ratios across 2 panes" do
      layout = Opal::Core::SplitLayout.vertical(ratio: 0.4, show_separator: true)
      extents = layout.solve_extents(21) # 21 - 1 separator = 20 available
      extents.should eq([8, 12])

      geoms = layout.solve(5, 10, 80, 21)
      geoms[0].rect.should eq(Opal::UI::Rect.new(5, 10, 80, 8))
      geoms[0].divider_y.should eq(18)
      geoms[1].rect.should eq(Opal::UI::Rect.new(5, 19, 80, 12))
      geoms[1].divider_y.should be_nil
    end

    it "solves N-pane flex weights with Largest Remainder integer distribution" do
      layout = Opal::Core::SplitLayout.new(
        orientation: :horizontal,
        show_separator: true,
        panes: [
          Opal::Core::PaneConstraint.flex(1.0, id: "nav"),
          Opal::Core::PaneConstraint.flex(2.0, id: "main"),
          Opal::Core::PaneConstraint.flex(1.0, id: "telemetry"),
        ]
      )
      # 102 total width - 2 separators = 100 available -> [25, 50, 25]
      extents = layout.solve_extents(102)
      extents.should eq([25, 50, 25])
      layout.divider_positions(0, 0, 102, 20).should eq([25, 76])
    end

    it "enforces min_size and max_size bounds with water-filling redistribution" do
      # Pane 0 wants 20% of 100 (= 20), but has min_size: 35 -> clamped to 35, Pane 1 gets 65
      layout_min = Opal::Core::SplitLayout.horizontal(
        ratio: 0.2,
        min_first_size: 35,
        show_separator: false
      )
      layout_min.solve_extents(100).should eq([35, 65])

      # Pane 0 wants 50% of 100 (= 50), but has max_size: 30 -> clamped to 30, Pane 1 gets 70
      layout_max = Opal::Core::SplitLayout.horizontal(
        ratio: 0.5,
        max_first_size: 30,
        show_separator: false
      )
      layout_max.solve_extents(100).should eq([30, 70])

      # Pane 1 has min_second_size: 80 -> Pane 1 gets 80, Pane 0 gets 20
      layout_sec = Opal::Core::SplitLayout.horizontal(
        ratio: 0.5,
        min_second_size: 80,
        show_separator: false
      )
      layout_sec.solve_extents(100).should eq([20, 80])
    end

    it "handles collapsed panes and reclaims separator space" do
      layout = Opal::Core::SplitLayout.new(
        orientation: :horizontal,
        show_separator: true,
        panes: [
          Opal::Core::PaneConstraint.flex(1.0, id: "left"),
          Opal::Core::PaneConstraint.flex(1.0, id: "center"),
          Opal::Core::PaneConstraint.flex(1.0, id: "right"),
        ]
      )
      layout.set_collapsed(1, true)
      # Only 2 active panes -> 1 separator -> 61 - 1 = 60 available -> [30, 0, 30]
      layout.solve_extents(61).should eq([30, 0, 30])
    end

    it "reuses pre-allocated geometry buffer in solve_into" do
      layout = Opal::Core::SplitLayout.horizontal(ratio: 0.5)
      buf = Array(Opal::Core::PaneGeometry).new(2)
      res1 = layout.solve_into(buf, 0, 0, 41, 10)
      res1.object_id.should eq(buf.object_id)
      res1[0].width.should eq(20)
      res1[1].width.should eq(20)
    end
  end

  describe "Focus Ring Navigation & Resizing State Machine" do
    it "cycles focus forward and backward around focusable panes, skipping non-focusable or collapsed panes" do
      layout = Opal::Core::SplitLayout.new(
        orientation: :horizontal,
        panes: [
          Opal::Core::PaneConstraint.new(id: "jobs", flex: 1.0, focusable: true),
          Opal::Core::PaneConstraint.new(id: "divider_banner", flex: 1.0, focusable: false),
          Opal::Core::PaneConstraint.new(id: "logs", flex: 1.0, focusable: true),
          Opal::Core::PaneConstraint.new(id: "metrics", flex: 1.0, focusable: true),
        ]
      )

      layout.focus_ring.should eq([0, 2, 3])
      layout.focused_index.should eq(0)
      layout.focused_id.should eq("jobs")

      layout.focus_next.should eq(2)
      layout.focused_id.should eq("logs")

      layout.focus_next.should eq(3)
      layout.focused_id.should eq("metrics")

      # Wrap around to first focusable pane
      layout.focus_next.should eq(0)
      layout.focused_id.should eq("jobs")

      # Backward wrap-around
      layout.focus_prev.should eq(3)
      layout.focused_id.should eq("metrics")

      # Collapsing focused pane automatically moves focus to valid ring member
      layout.set_collapsed(3, true)
      layout.focus_ring.should eq([0, 2])
      layout.focused_index.should eq(0)
    end

    it "supports step_grow, step_shrink, reset_ratios!, and interactive divider dragging" do
      layout = Opal::Core::SplitLayout.horizontal(ratio: 0.5, resize_step: 0.1)
      layout.step_grow.should be_close(0.6, 0.001)
      layout.ratio.should be_close(0.6, 0.001)

      layout.step_shrink.should be_close(0.5, 0.001)
      layout.step_grow(0.2).should be_close(0.7, 0.001)

      layout.reset_ratios!
      layout.ratio.should be_close(0.5, 0.001)

      # Interactive drag from x=50 to x=30 in a 101-wide container (100 available)
      layout.hit_test_divider(50, 0, 0, 101, 20).should eq(0)
      layout.begin_drag(0).should be_true
      layout.dragging?.should be_true
      layout.drag_to(30, 0, 101).should be_true
      layout.ratio.should be_close(0.3, 0.001)
      layout.end_drag
      layout.dragging?.should be_false
    end
  end

  describe "Declarative Opal.split_pane & Opal::DSL::SplitPane" do
    it "builds 2-pane and 3-pane split layouts via top-level Opal.split_pane DSL" do
      split = Opal.split_pane(direction: :horizontal, min_first_size: 15, max_first_size: 40) do
        pane(title: "Job Queue", id: "jobs", flex: 1.0, min_size: 15, border: :rounded) do
          text "video_01.mp4 [RUNNING]"
        end
        pane(title: "FFmpeg Telemetry", id: "telemetry", flex: 2.0, min_size: 25, border: :rounded) do
          sparkline([59.5, 60.0, 60.2], title: "FPS")
        end
        pane(title: "Encoder Log", id: "logs", flex: 1.0, min_size: 15, border: :rounded) do
          text "frame=1024 fps=60.0"
        end
        focus "telemetry"
      end

      split.is_a?(Opal::DSL::SplitPane).should be_true
      split.layout.pane_count.should eq(3)
      split.focused_id.should eq("telemetry")
      split.focused_index.should eq(1)

      buf = Opal::UI::Buffer.new(82, 8)
      split.render(buf, 0, 0, 82, 8)
      rendered = buf.render_to_string(with_ansi: false)

      rendered.should contain("Job Queue")
      rendered.should contain("FFmpeg Telemetry")
      rendered.should contain("Encoder Log")

      # Keyboard Tab / Shift+Tab navigation and Ctrl+Arrow resize
      split.handle_key(Opal::Terminal::KeyEvent.new("tab")).should be_true
      split.focused_id.should eq("logs")

      split.handle_key(Opal::Terminal::KeyEvent.new("backtab")).should be_true
      split.focused_id.should eq("telemetry")

      initial_ratios = split.ratios
      split.handle_key(Opal::Terminal::KeyEvent.new("right", ctrl: true)).should be_true
      split.ratios[1].should be > initial_ratios[1]
    end
  end
end

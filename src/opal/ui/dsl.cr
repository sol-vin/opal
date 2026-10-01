require "./element"
require "./components/text"
require "./components/badge"
require "./components/rule"
require "./components/stack"
require "./components/box"
require "./components/table"
require "./components/viewport"
require "./components/sparkline"
require "./components/barchart"
require "./components/gauge"
require "./components/tree"
require "./components/modal"
require "./components/toast"
require "./components/filter_list"
require "./markdown/renderer"
require "./components/command_palette"
require "./components/split_view"
require "./components/code_view"
require "./components/tabs"
require "./components/hex_viewer"
require "./components/file_dialog"
require "./components/color_picker"
require "./components/color_picker_3d"
require "./components/button"
require "./components/dropdown"
require "./components/scrollbar"
require "./components/window"
require "./components/canvas_2d"
require "./components/mesh_3d"
require "./components/checkbox"
require "./components/slider"

module Opal
  module UI
    # Declarative DSL builder for composing element trees.
    class Builder
      getter root : Element?

      def text(
        content : String,
        fg : Color | Symbol | String = Color.none,
        bg : Color | Symbol | String = Color.none,
        bold : Bool = false,
        dim : Bool = false,
        italic : Bool = false,
        underline : Bool = false,
      ) : Text
        el = Text.new(content, fg: fg, bg: bg, bold: bold, dim: dim, italic: italic, underline: underline)
        set_root_or_child(el)
        el
      end

      def badge(
        label : String,
        bg : Color | Symbol | String = :blue,
        fg : Color | Symbol | String = :white,
        bold : Bool = true,
      ) : Badge
        el = Badge.new(label, bg: bg, fg: fg, bold: bold)
        set_root_or_child(el)
        el
      end

      def rule(char : Char = '─', fg : Color | Symbol | String = Color.none) : Rule
        el = Rule.new(char: char, fg: fg)
        set_root_or_child(el)
        el
      end

      def box(
        border : Symbol | Border = :rounded,
        border_fg : Color | Symbol | String = Color.none,
        padding : Int32 = 0,
        title : String? = nil,
        title_fg : Color | Symbol | String = :cyan,
        bg : Color | Symbol | String = Color.none,
        &block : Builder -> Nil
      ) : Box
        sub_builder = Builder.new
        block.call(sub_builder)
        el = Box.new(
          child: sub_builder.root,
          border: border,
          border_fg: border_fg,
          padding: padding,
          title: title,
          title_fg: title_fg,
          bg: bg
        )
        set_root_or_child(el)
        el
      end

      def vstack(spacing : Int32 = 0, &block : StackBuilder -> Nil) : VStack
        sb = StackBuilder.new
        block.call(sb)
        stack = VStack.new(spacing: spacing)
        sb.elements.each { |e| stack.add(e) }
        set_root_or_child(stack)
        stack
      end

      def hstack(spacing : Int32 = 0, &block : StackBuilder -> Nil) : HStack
        sb = StackBuilder.new
        block.call(sb)
        stack = HStack.new(spacing: spacing)
        sb.elements.each { |e| stack.add(e) }
        set_root_or_child(stack)
        stack
      end

      def table(
        headers : Array(String) = [] of String,
        header_fg : Color | Symbol | String = :cyan,
        border_fg : Color | Symbol | String = Color.none,
        &block : TableBuilder -> Nil
      ) : Table
        tbl = Table.new(headers: headers, header_fg: header_fg, border_fg: border_fg)
        tb = TableBuilder.new(tbl)
        block.call(tb)
        set_root_or_child(tbl)
        tbl
      end

      def viewport(
        content : String,
        offset_y : Int32 = 0,
        fg : Color | Symbol | String = Color.none,
        show_scrollbar : Bool = true,
      ) : Viewport
        el = Viewport.new(content: content, offset_y: offset_y, fg: fg, show_scrollbar: show_scrollbar)
        set_root_or_child(el)
        el
      end

      def sparkline(
        data : Array(Float64),
        color : Color | Symbol | String = :cyan,
        title : String? = nil,
        min : Float64? = nil,
        max : Float64? = nil,
      ) : Sparkline
        el = Sparkline.new(data: data, color: color, title: title, min: min, max: max)
        set_root_or_child(el)
        el
      end

      def barchart(
        title : String? = nil,
        bar_char : Char = '█',
        max_value : Float64? = nil,
        &block : BarChartBuilder -> Nil
      ) : BarChart
        chart = BarChart.new(title: title, bar_char: bar_char, max_value: max_value)
        bb = BarChartBuilder.new(chart)
        block.call(bb)
        set_root_or_child(chart)
        chart
      end

      def pie_chart(
        title : String? = nil,
        donut : Bool = false,
        &block : PieChartBuilder -> Nil
      ) : PieChart
        chart = PieChart.new(title: title, donut: donut)
        pb = PieChartBuilder.new(chart)
        block.call(pb)
        set_root_or_child(chart)
        chart
      end

      def line_graph(
        title : String? = nil,
        min_y : Float64? = nil,
        max_y : Float64? = nil,
        show_grid : Bool = true,
        show_legend : Bool = true,
        &block : LineGraphBuilder -> Nil
      ) : LineGraph
        graph = LineGraph.new(
          title: title,
          min_y: min_y,
          max_y: max_y,
          show_grid: show_grid,
          show_legend: show_legend
        )
        gb = LineGraphBuilder.new(graph)
        block.call(gb)
        set_root_or_child(graph)
        graph
      end

      def ascii_image(
        image : Opal::Image::PixelBuffer,
        mode : Symbol | AsciiRenderMode = :half_block,
        interpolation : Symbol | Opal::Image::Interpolation = :bilinear,
        ramp : String = AsciiImage::RAMP_STANDARD,
        colorize : Bool = true,
        bold : Bool = false,
        bg : Color | Symbol | String = Color.none,
      ) : AsciiImage
        el = AsciiImage.new(
          image: image,
          mode: mode,
          interpolation: interpolation,
          ramp: ramp,
          colorize: colorize,
          bold: bold,
          bg: bg
        )
        set_root_or_child(el)
        el
      end

      def gauge(
        ratio : Float64,
        label : String? = nil,
        color : Color | Symbol | String | Nil = nil,
        filled_char : Char = '█',
        empty_char : Char = '░',
      ) : Gauge
        el = Gauge.new(ratio: ratio, label: label, color: color, filled_char: filled_char, empty_char: empty_char)
        set_root_or_child(el)
        el
      end

      def tree(title : String? = nil, &block : TreeBuilder -> Nil) : Tree
        tr = Tree.new(title: title)
        tb = TreeBuilder.new(tr)
        block.call(tb)
        set_root_or_child(tr)
        tr
      end

      def modal(
        title : String,
        message : String,
        buttons : Array(String) = ["OK"],
        selected_button : Int32 = 0,
        border_fg : Color | Symbol | String = :cyan,
        title_fg : Color | Symbol | String = :bright_white,
        button_fg : Color | Symbol | String = :white,
        selected_fg : Color | Symbol | String = :black,
        selected_bg : Color | Symbol | String = :cyan,
        dim_backdrop : Bool = true,
      ) : Modal
        el = Modal.new(
          title: title,
          message: message,
          buttons: buttons,
          selected_button: selected_button,
          border_fg: border_fg,
          title_fg: title_fg,
          button_fg: button_fg,
          selected_fg: selected_fg,
          selected_bg: selected_bg,
          dim_backdrop: dim_backdrop
        )
        set_root_or_child(el)
        el
      end

      def markdown(content : String, width : Int32 = 80) : MarkdownElement
        el = MarkdownElement.new(content, width)
        set_root_or_child(el)
        el
      end

      def split_view(
        direction : SplitDirection = SplitDirection::Horizontal,
        ratio : Float64? = 0.5,
        first_size : Int32? = nil,
        second_size : Int32? = nil,
        separator : Char? = nil,
        separator_fg : Color | Symbol | String = Color.none,
        focused_pane : Symbol = :first,
        show_separator : Bool = true,
        &block : SplitBuilder -> Nil
      ) : SplitView
        sb = SplitBuilder.new
        block.call(sb)
        el = SplitView.new(
          first: sb.first,
          second: sb.second,
          direction: direction,
          ratio: ratio,
          first_size: first_size,
          second_size: second_size,
          separator: separator,
          separator_fg: separator_fg,
          focused_pane: focused_pane,
          show_separator: show_separator
        )
        set_root_or_child(el)
        el
      end

      def code_view(
        code : String,
        language : Symbol = :plain,
        start_line : Int32 = 1,
        highlighted_line : Int32? = nil,
        scroll_offset : Int32 = 0,
        show_line_numbers : Bool = true,
        gutter_fg : Color | Symbol | String = :dark_gray,
        cursor_fg : Color | Symbol | String = :yellow,
      ) : CodeView
        el = CodeView.new(
          code: code,
          language: language,
          start_line: start_line,
          highlighted_line: highlighted_line,
          scroll_offset: scroll_offset,
          show_line_numbers: show_line_numbers,
          gutter_fg: gutter_fg,
          cursor_fg: cursor_fg
        )
        set_root_or_child(el)
        el
      end

      def tabs(
        labels : Array(String),
        active_index : Int32 = 0,
        active_fg : Color | Symbol | String = :bright_white,
        active_bg : Color | Symbol | String = :blue,
        inactive_fg : Color | Symbol | String = :gray,
        pill_style : Bool = false,
      ) : Tabs
        el = Tabs.from_labels(labels, active: active_index)
        el.active_fg = Color.from(active_fg)
        el.active_bg = Color.from(active_bg)
        el.inactive_fg = Color.from(inactive_fg)
        el.pill_style = pill_style
        set_root_or_child(el)
        el
      end

      def hex_viewer(
        bytes : Bytes | Slice(UInt8) | Array(UInt8),
        base_address : UInt64 = 0_u64,
        bytes_per_row : Int32 = 16,
        scroll_offset : Int32 = 0,
        selected_byte : Int32? = nil,
      ) : HexViewer
        el = HexViewer.new(
          bytes: bytes,
          base_address: base_address,
          bytes_per_row: bytes_per_row,
          scroll_offset: scroll_offset,
          selected_byte: selected_byte
        )
        set_root_or_child(el)
        el
      end

      def file_dialog(
        initial_path : String = ".",
        mode : Symbol = :open_file,
        show_hidden : Bool = false,
        preview_fn : Proc(String, String)? = nil,
      ) : FileDialog
        el = FileDialog.new(
          initial_path: initial_path,
          mode: mode,
          show_hidden: show_hidden,
          preview_fn: preview_fn
        )
        set_root_or_child(el)
        el
      end

      def color_picker(
        initial_color : Color = Color.hex("#89B4FA"),
        active_channel : Symbol = :red,
        presets : Array(Color)? = nil,
      ) : ColorPicker
        el = ColorPicker.new(
          initial_color: initial_color,
          active_channel: active_channel,
          presets: presets
        )
        set_root_or_child(el)
        el
      end

      def color_picker_3d(
        shape : ColorPickerShape = ColorPickerShape::Cube3D,
        pitch : Float64 = 0.42,
        yaw : Float64 = 0.58,
        auto_rotate : Bool = false,
        initial_color : Color = Color.hex("#89B4FA"),
        size : Int32 = 12,
      ) : ColorPicker3D
        el = ColorPicker3D.new(
          shape: shape,
          pitch: pitch,
          yaw: yaw,
          auto_rotate: auto_rotate,
          initial_color: initial_color,
          size: size
        )
        set_root_or_child(el)
        el
      end

      def button(
        label : String,
        icon : String? = nil,
        variant : Symbol = :primary,
        toggle : Bool = false,
        active : Bool = false,
        disabled : Bool = false,
        shortcut_char : Char? = nil,
        &block : Button -> Nil
      ) : Button
        el = Button.new(
          label: label,
          icon: icon,
          variant: variant,
          toggle: toggle,
          active: active,
          disabled: disabled,
          shortcut_char: shortcut_char,
          on_click: block
        )
        set_root_or_child(el)
        el
      end

      def button(
        label : String,
        icon : String? = nil,
        variant : Symbol = :primary,
        toggle : Bool = false,
        active : Bool = false,
        disabled : Bool = false,
        shortcut_char : Char? = nil,
      ) : Button
        el = Button.new(
          label: label,
          icon: icon,
          variant: variant,
          toggle: toggle,
          active: active,
          disabled: disabled,
          shortcut_char: shortcut_char
        )
        set_root_or_child(el)
        el
      end

      def dropdown(
        items : Array(String),
        selected_index : Int32 = 0,
        placeholder : String = "Select...",
        expanded : Bool = false,
        max_visible_items : Int32 = 6,
        &block : (Int32, String) -> Nil
      ) : Dropdown
        el = Dropdown.new(
          items: items,
          selected_index: selected_index,
          placeholder: placeholder,
          expanded: expanded,
          max_visible_items: max_visible_items,
          on_change: block
        )
        set_root_or_child(el)
        el
      end

      def dropdown(
        items : Array(String),
        selected_index : Int32 = 0,
        placeholder : String = "Select...",
        expanded : Bool = false,
        max_visible_items : Int32 = 6,
      ) : Dropdown
        el = Dropdown.new(
          items: items,
          selected_index: selected_index,
          placeholder: placeholder,
          expanded: expanded,
          max_visible_items: max_visible_items
        )
        set_root_or_child(el)
        el
      end

      def scrollbar(
        orientation : ScrollBar::Orientation = ScrollBar::Orientation::Vertical,
        min_value : Int32 = 0,
        max_value : Int32 = 100,
        value : Int32 = 0,
        page_size : Int32 = 10,
        show_arrows : Bool = true,
        &block : Int32 -> Nil
      ) : ScrollBar
        el = ScrollBar.new(
          orientation: orientation,
          min_value: min_value,
          max_value: max_value,
          value: value,
          page_size: page_size,
          show_arrows: show_arrows,
          on_change: block
        )
        set_root_or_child(el)
        el
      end

      def scrollbar(
        orientation : ScrollBar::Orientation = ScrollBar::Orientation::Vertical,
        min_value : Int32 = 0,
        max_value : Int32 = 100,
        value : Int32 = 0,
        page_size : Int32 = 10,
        show_arrows : Bool = true,
      ) : ScrollBar
        el = ScrollBar.new(
          orientation: orientation,
          min_value: min_value,
          max_value: max_value,
          value: value,
          page_size: page_size,
          show_arrows: show_arrows
        )
        set_root_or_child(el)
        el
      end

      def window(
        title : String,
        x : Int32 = 2,
        y : Int32 = 2,
        width : Int32 = 40,
        height : Int32 = 12,
        min_width : Int32 = 18,
        min_height : Int32 = 5,
        closable : Bool = true,
        minimizable : Bool = true,
        maximizable : Bool = true,
        resizable : Bool = true,
        &block : Builder -> Nil
      ) : Window
        sub_builder = Builder.new
        block.call(sub_builder)
        el = Window.new(
          title: title,
          x: x,
          y: y,
          width: width,
          height: height,
          min_width: min_width,
          min_height: min_height,
          closable: closable,
          minimizable: minimizable,
          maximizable: maximizable,
          resizable: resizable,
          content: sub_builder.root
        )
        set_root_or_child(el)
        el
      end

      def canvas_2d(
        width : Int32? = nil,
        height : Int32? = nil,
        &block : (Buffer, Int32, Int32, Int32, Int32) -> Nil
      ) : Canvas2D
        el = Canvas2D.new(width: width, height: height, &block)
        set_root_or_child(el)
        el
      end

      def mesh_3d(
        shape : Symbol = :cube,
        pitch : Float64 = 0.4,
        yaw : Float64 = 0.6,
        roll : Float64 = 0.0,
        scale : Float64 = 7.0,
        auto_rotate : Bool = false,
        wireframe : Bool = false,
        color : Color | Symbol | String = :cyan,
      ) : Mesh3D
        el = Mesh3D.new(
          shape: shape,
          pitch: pitch,
          yaw: yaw,
          roll: roll,
          scale: scale,
          auto_rotate: auto_rotate,
          wireframe: wireframe,
          color: color
        )
        set_root_or_child(el)
        el
      end

      def switch(
        label : String? = nil,
        on : Bool = false,
        disabled : Bool = false,
        &block : Bool -> Nil
      ) : Switch
        el = Switch.new(label, on, disabled, &block)
        set_root_or_child(el)
        el
      end

      def switch(
        label : String? = nil,
        on : Bool = false,
        disabled : Bool = false,
      ) : Switch
        el = Switch.new(label, on, disabled)
        set_root_or_child(el)
        el
      end

      def checkbox(
        label : String? = nil,
        checked : Bool = false,
        disabled : Bool = false,
        &block : Bool -> Nil
      ) : Checkbox
        el = Checkbox.new(label, checked, disabled, &block)
        set_root_or_child(el)
        el
      end

      def checkbox(
        label : String? = nil,
        checked : Bool = false,
        disabled : Bool = false,
      ) : Checkbox
        el = Checkbox.new(label, checked, disabled)
        set_root_or_child(el)
        el
      end

      def slider(
        value : Number = 0.0,
        min : Number = 0.0,
        max : Number = 100.0,
        step : Number = 1.0,
        label : String? = nil,
        show_value : Bool = true,
        disabled : Bool = false,
        &block : Float64 -> Nil
      ) : Slider
        el = Slider.new(value, min, max, step, label, show_value, disabled, &block)
        set_root_or_child(el)
        el
      end

      def slider(
        value : Number = 0.0,
        min : Number = 0.0,
        max : Number = 100.0,
        step : Number = 1.0,
        label : String? = nil,
        show_value : Bool = true,
        disabled : Bool = false,
      ) : Slider
        el = Slider.new(value, min, max, step, label, show_value, disabled)
        set_root_or_child(el)
        el
      end

      def radio_set(
        items : Array(String | RadioButton),
        selected_index : Int32? = 0,
        horizontal : Bool = false,
        disabled : Bool = false,
        &block : (Int32, String) -> Nil
      ) : RadioSet
        el = RadioSet.new(items, selected_index, horizontal, disabled, &block)
        set_root_or_child(el)
        el
      end

      def radio_set(
        items : Array(String | RadioButton),
        selected_index : Int32? = 0,
        horizontal : Bool = false,
        disabled : Bool = false,
      ) : RadioSet
        el = RadioSet.new(items, selected_index, horizontal, disabled)
        set_root_or_child(el)
        el
      end

      def collapsible(
        title : String,
        collapsed : Bool = true,
        disabled : Bool = false,
        &block : Builder -> Nil
      ) : Collapsible
        sub_builder = Builder.new
        block.call(sub_builder)
        el = Collapsible.new(title: title, child: sub_builder.root, collapsed: collapsed, disabled: disabled)
        set_root_or_child(el)
        el
      end

      def digits(
        text : String,
        fg : Color | Symbol | String = :bright_cyan,
        bg : Color | Symbol | String = Color.none,
        bold : Bool = true,
      ) : Digits
        el = Digits.new(text, fg: fg, bg: bg, bold: bold)
        set_root_or_child(el)
        el
      end

      def rich_log(
        max_lines : Int32 = 1000,
        auto_scroll : Bool = true,
        highlight_ansi : Bool = true,
      ) : RichLog
        el = RichLog.new(max_lines: max_lines, auto_scroll: auto_scroll, highlight_ansi: highlight_ansi)
        set_root_or_child(el)
        el
      end

      def loading_indicator(
        label : String? = nil,
        style : Symbol = :dots,
        fg : Color | Symbol | String = Color.none,
      ) : LoadingIndicator
        el = LoadingIndicator.new(label: label, style: style, fg: Color.from(fg))
        set_root_or_child(el)
        el
      end

      def header(
        title : String = "Opal Application",
        subtitle : String? = nil,
        icon : String? = "[*]",
        show_clock : Bool = true,
      ) : Header
        el = Header.new(title: title, subtitle: subtitle, icon: icon, show_clock: show_clock)
        set_root_or_child(el)
        el
      end

      def footer(
        bindings : Array(NamedTuple(key: String, desc: String)) = [] of NamedTuple(key: String, desc: String),
      ) : Footer
        el = Footer.new(bindings)
        set_root_or_child(el)
        el
      end

      def placeholder(
        label : String? = nil,
        border : Symbol | Border = :rounded,
      ) : Placeholder
        el = Placeholder.new(label: label, border: border)
        set_root_or_child(el)
        el
      end

      def dock(&block : DockContainer -> Nil) : DockContainer
        dc = DockContainer.new
        block.call(dc)
        set_root_or_child(dc)
        dc
      end

      def grid(
        columns : Array(GridTrack | Int32 | Float64 | String) = [GridTrack.fr(1.0)],
        rows : Array(GridTrack | Int32 | Float64 | String) = [GridTrack.fr(1.0)],
        gutter_x : Int32 = 1,
        gutter_y : Int32 = 0,
        &block : GridContainer -> Nil
      ) : GridContainer
        gc = GridContainer.new(columns: columns, rows: rows, gutter_x: gutter_x, gutter_y: gutter_y)
        block.call(gc)
        set_root_or_child(gc)
        gc
      end

      def content_switcher(current : String? = nil, &block : ContentSwitcher -> Nil) : ContentSwitcher
        cs = ContentSwitcher.new(current: current)
        block.call(cs)
        set_root_or_child(cs)
        cs
      end

      private def set_root_or_child(el : Element) : Nil
        @root ||= el
      end
    end

    class SplitBuilder
      getter first : Element?
      getter second : Element?

      def first(&block : Builder -> Nil) : Nil
        b = Builder.new
        block.call(b)
        @first = b.root
      end

      def second(&block : Builder -> Nil) : Nil
        b = Builder.new
        block.call(b)
        @second = b.root
      end
    end

    # Builder for stack children
    class StackBuilder
      getter elements : Array(Element) = [] of Element

      def add(el : Element) : Nil
        @elements << el
      end

      def text(
        content : String,
        fg : Color | Symbol | String = Color.none,
        bg : Color | Symbol | String = Color.none,
        bold : Bool = false,
        dim : Bool = false,
        italic : Bool = false,
        underline : Bool = false,
      ) : Text
        el = Text.new(content, fg: fg, bg: bg, bold: bold, dim: dim, italic: italic, underline: underline)
        add(el)
        el
      end

      def badge(
        label : String,
        bg : Color | Symbol | String = :blue,
        fg : Color | Symbol | String = :white,
        bold : Bool = true,
      ) : Badge
        el = Badge.new(label, bg: bg, fg: fg, bold: bold)
        add(el)
        el
      end

      def rule(char : Char = '─', fg : Color | Symbol | String = Color.none) : Rule
        el = Rule.new(char: char, fg: fg)
        add(el)
        el
      end

      def box(
        border : Symbol | Border = :rounded,
        border_fg : Color | Symbol | String = Color.none,
        padding : Int32 = 0,
        title : String? = nil,
        title_fg : Color | Symbol | String = :cyan,
        bg : Color | Symbol | String = Color.none,
        &block : Builder -> Nil
      ) : Box
        b = Builder.new
        block.call(b)
        el = Box.new(
          child: b.root,
          border: border,
          border_fg: border_fg,
          padding: padding,
          title: title,
          title_fg: title_fg,
          bg: bg
        )
        add(el)
        el
      end

      def vstack(spacing : Int32 = 0, &block : StackBuilder -> Nil) : VStack
        sb = StackBuilder.new
        block.call(sb)
        stack = VStack.new(spacing: spacing)
        sb.elements.each { |e| stack.add(e) }
        add(stack)
        stack
      end

      def hstack(spacing : Int32 = 0, &block : StackBuilder -> Nil) : HStack
        sb = StackBuilder.new
        block.call(sb)
        stack = HStack.new(spacing: spacing)
        sb.elements.each { |e| stack.add(e) }
        add(stack)
        stack
      end

      def table(
        headers : Array(String) = [] of String,
        header_fg : Color | Symbol | String = :cyan,
        border_fg : Color | Symbol | String = Color.none,
        &block : TableBuilder -> Nil
      ) : Table
        tbl = Table.new(headers: headers, header_fg: header_fg, border_fg: border_fg)
        tb = TableBuilder.new(tbl)
        block.call(tb)
        add(tbl)
        tbl
      end

      def sparkline(
        data : Array(Float64),
        color : Color | Symbol | String = :cyan,
        title : String? = nil,
        min : Float64? = nil,
        max : Float64? = nil,
      ) : Sparkline
        el = Sparkline.new(data: data, color: color, title: title, min: min, max: max)
        add(el)
        el
      end

      def barchart(
        title : String? = nil,
        bar_char : Char = '█',
        max_value : Float64? = nil,
        &block : BarChartBuilder -> Nil
      ) : BarChart
        chart = BarChart.new(title: title, bar_char: bar_char, max_value: max_value)
        bb = BarChartBuilder.new(chart)
        block.call(bb)
        add(chart)
        chart
      end

      def gauge(
        ratio : Float64,
        label : String? = nil,
        color : Color | Symbol | String | Nil = nil,
        filled_char : Char = '█',
        empty_char : Char = '░',
      ) : Gauge
        el = Gauge.new(ratio: ratio, label: label, color: color, filled_char: filled_char, empty_char: empty_char)
        add(el)
        el
      end

      def tree(title : String? = nil, &block : TreeBuilder -> Nil) : Tree
        tr = Tree.new(title: title)
        tb = TreeBuilder.new(tr)
        block.call(tb)
        add(tr)
        tr
      end

      def markdown(content : String, width : Int32 = 80) : MarkdownElement
        el = MarkdownElement.new(content, width)
        add(el)
        el
      end

      def split_view(
        direction : SplitDirection = SplitDirection::Horizontal,
        ratio : Float64? = 0.5,
        first_size : Int32? = nil,
        second_size : Int32? = nil,
        separator : Char? = nil,
        separator_fg : Color | Symbol | String = Color.none,
        focused_pane : Symbol = :first,
        show_separator : Bool = true,
        &block : SplitBuilder -> Nil
      ) : SplitView
        sb = SplitBuilder.new
        block.call(sb)
        el = SplitView.new(
          first: sb.first,
          second: sb.second,
          direction: direction,
          ratio: ratio,
          first_size: first_size,
          second_size: second_size,
          separator: separator,
          separator_fg: separator_fg,
          focused_pane: focused_pane,
          show_separator: show_separator
        )
        add(el)
        el
      end

      def code_view(
        code : String,
        language : Symbol = :plain,
        start_line : Int32 = 1,
        highlighted_line : Int32? = nil,
        scroll_offset : Int32 = 0,
        show_line_numbers : Bool = true,
        gutter_fg : Color | Symbol | String = :dark_gray,
        cursor_fg : Color | Symbol | String = :yellow,
      ) : CodeView
        el = CodeView.new(
          code: code,
          language: language,
          start_line: start_line,
          highlighted_line: highlighted_line,
          scroll_offset: scroll_offset,
          show_line_numbers: show_line_numbers,
          gutter_fg: gutter_fg,
          cursor_fg: cursor_fg
        )
        add(el)
        el
      end

      def tabs(
        labels : Array(String),
        active_index : Int32 = 0,
        active_fg : Color | Symbol | String = :bright_white,
        active_bg : Color | Symbol | String = :blue,
        inactive_fg : Color | Symbol | String = :gray,
        pill_style : Bool = false,
      ) : Tabs
        el = Tabs.from_labels(labels, active: active_index)
        el.active_fg = Color.from(active_fg)
        el.active_bg = Color.from(active_bg)
        el.inactive_fg = Color.from(inactive_fg)
        el.pill_style = pill_style
        add(el)
        el
      end

      def hex_viewer(
        bytes : Bytes | Slice(UInt8) | Array(UInt8),
        base_address : UInt64 = 0_u64,
        bytes_per_row : Int32 = 16,
        scroll_offset : Int32 = 0,
        selected_byte : Int32? = nil,
      ) : HexViewer
        el = HexViewer.new(
          bytes: bytes,
          base_address: base_address,
          bytes_per_row: bytes_per_row,
          scroll_offset: scroll_offset,
          selected_byte: selected_byte
        )
        add(el)
        el
      end

      def file_dialog(
        initial_path : String = ".",
        mode : Symbol = :open_file,
        show_hidden : Bool = false,
        preview_fn : Proc(String, String)? = nil,
      ) : FileDialog
        el = FileDialog.new(
          initial_path: initial_path,
          mode: mode,
          show_hidden: show_hidden,
          preview_fn: preview_fn
        )
        add(el)
        el
      end

      def color_picker(
        initial_color : Color = Color.hex("#89B4FA"),
        active_channel : Symbol = :red,
        presets : Array(Color)? = nil,
      ) : ColorPicker
        el = ColorPicker.new(
          initial_color: initial_color,
          active_channel: active_channel,
          presets: presets
        )
        add(el)
        el
      end

      def color_picker_3d(
        shape : ColorPickerShape = ColorPickerShape::Cube3D,
        pitch : Float64 = 0.42,
        yaw : Float64 = 0.58,
        auto_rotate : Bool = false,
        initial_color : Color = Color.hex("#89B4FA"),
        size : Int32 = 12,
      ) : ColorPicker3D
        el = ColorPicker3D.new(
          shape: shape,
          pitch: pitch,
          yaw: yaw,
          auto_rotate: auto_rotate,
          initial_color: initial_color,
          size: size
        )
        add(el)
        el
      end

      def pie_chart(
        title : String? = nil,
        donut : Bool = false,
        &block : PieChartBuilder -> Nil
      ) : PieChart
        chart = PieChart.new(title: title, donut: donut)
        pb = PieChartBuilder.new(chart)
        block.call(pb)
        add(chart)
        chart
      end

      def line_graph(
        title : String? = nil,
        min_y : Float64? = nil,
        max_y : Float64? = nil,
        show_grid : Bool = true,
        show_legend : Bool = true,
        &block : LineGraphBuilder -> Nil
      ) : LineGraph
        graph = LineGraph.new(
          title: title,
          min_y: min_y,
          max_y: max_y,
          show_grid: show_grid,
          show_legend: show_legend
        )
        gb = LineGraphBuilder.new(graph)
        block.call(gb)
        add(graph)
        graph
      end

      def ascii_image(
        image : Opal::Image::PixelBuffer,
        mode : Symbol | AsciiRenderMode = :half_block,
        interpolation : Symbol | Opal::Image::Interpolation = :bilinear,
        ramp : String = AsciiImage::RAMP_STANDARD,
        colorize : Bool = true,
        bold : Bool = false,
        bg : Color | Symbol | String = Color.none,
      ) : AsciiImage
        el = AsciiImage.new(
          image: image,
          mode: mode,
          interpolation: interpolation,
          ramp: ramp,
          colorize: colorize,
          bold: bold,
          bg: bg
        )
        add(el)
        el
      end

      def switch(
        label : String? = nil,
        on : Bool = false,
        disabled : Bool = false,
        &block : Bool -> Nil
      ) : Switch
        el = Switch.new(label, on, disabled, &block)
        add(el)
        el
      end

      def switch(
        label : String? = nil,
        on : Bool = false,
        disabled : Bool = false,
      ) : Switch
        el = Switch.new(label, on, disabled)
        add(el)
        el
      end

      def checkbox(
        label : String? = nil,
        checked : Bool = false,
        disabled : Bool = false,
        &block : Bool -> Nil
      ) : Checkbox
        el = Checkbox.new(label, checked, disabled, &block)
        add(el)
        el
      end

      def checkbox(
        label : String? = nil,
        checked : Bool = false,
        disabled : Bool = false,
      ) : Checkbox
        el = Checkbox.new(label, checked, disabled)
        add(el)
        el
      end

      def slider(
        value : Number = 0.0,
        min : Number = 0.0,
        max : Number = 100.0,
        step : Number = 1.0,
        label : String? = nil,
        show_value : Bool = true,
        disabled : Bool = false,
        &block : Float64 -> Nil
      ) : Slider
        el = Slider.new(value, min, max, step, label, show_value, disabled, &block)
        add(el)
        el
      end

      def slider(
        value : Number = 0.0,
        min : Number = 0.0,
        max : Number = 100.0,
        step : Number = 1.0,
        label : String? = nil,
        show_value : Bool = true,
        disabled : Bool = false,
      ) : Slider
        el = Slider.new(value, min, max, step, label, show_value, disabled)
        add(el)
        el
      end

      def radio_set(
        items : Array(String | RadioButton),
        selected_index : Int32? = 0,
        horizontal : Bool = false,
        disabled : Bool = false,
        &block : (Int32, String) -> Nil
      ) : RadioSet
        el = RadioSet.new(items, selected_index, horizontal, disabled, &block)
        add(el)
        el
      end

      def radio_set(
        items : Array(String | RadioButton),
        selected_index : Int32? = 0,
        horizontal : Bool = false,
        disabled : Bool = false,
      ) : RadioSet
        el = RadioSet.new(items, selected_index, horizontal, disabled)
        add(el)
        el
      end

      def collapsible(
        title : String,
        collapsed : Bool = true,
        disabled : Bool = false,
        &block : Builder -> Nil
      ) : Collapsible
        sub_builder = Builder.new
        block.call(sub_builder)
        el = Collapsible.new(title: title, child: sub_builder.root, collapsed: collapsed, disabled: disabled)
        add(el)
        el
      end

      def digits(
        text : String,
        fg : Color | Symbol | String = :bright_cyan,
        bg : Color | Symbol | String = Color.none,
        bold : Bool = true,
      ) : Digits
        el = Digits.new(text, fg: fg, bg: bg, bold: bold)
        add(el)
        el
      end

      def rich_log(
        max_lines : Int32 = 1000,
        auto_scroll : Bool = true,
        highlight_ansi : Bool = true,
      ) : RichLog
        el = RichLog.new(max_lines: max_lines, auto_scroll: auto_scroll, highlight_ansi: highlight_ansi)
        add(el)
        el
      end

      def loading_indicator(
        label : String? = nil,
        style : Symbol = :dots,
        fg : Color | Symbol | String = Color.none,
      ) : LoadingIndicator
        el = LoadingIndicator.new(label: label, style: style, fg: Color.from(fg))
        add(el)
        el
      end
    end

    # Builder for table rows
    class TableBuilder
      def initialize(@table : Table)
      end

      def row(cells : Array(String)) : Nil
        @table.row(cells)
      end
    end

    # Builder for bar charts
    class BarChartBuilder
      def initialize(@chart : BarChart)
      end

      def bar(label : String, value : Float64 | Int32, color : Color | Symbol | String = :cyan, formatted : String? = nil) : Nil
        @chart.add(label, value.to_f, color, formatted)
      end
    end

    # Builder for pie charts
    class PieChartBuilder
      def initialize(@chart : PieChart)
      end

      def slice(label : String, value : Float64 | Int32, color : Color | Symbol | String = :cyan, formatted : String? = nil) : Nil
        @chart.add(label, value.to_f, color, formatted)
      end
    end

    # Builder for line graphs
    class LineGraphBuilder
      def initialize(@graph : LineGraph)
      end

      def series(name : String, data : Array(Float64), color : Color | Symbol | String = :cyan) : LineSeries
        @graph.add_series(name, data, color)
      end
    end

    # Builder for tree hierarchies
    class TreeBuilder
      def initialize(@tree : Tree)
      end

      def node(label : String, color : Color | Symbol | String = :white, icon : String? = nil, &block : TreeNode -> Nil) : TreeNode
        @tree.add(label, color, icon, &block)
      end

      def node(label : String, color : Color | Symbol | String = :white, icon : String? = nil) : TreeNode
        n = TreeNode.new(label, color, icon)
        @tree.add(n)
        n
      end
    end

    # Builds and renders an element tree to a string buffer.
    def self.render(width : Int32 = 80, height : Int32 = 24, &block : Builder -> Nil) : String
      builder = Builder.new
      block.call(builder)

      return "" unless root = builder.root

      w, h = root.preferred_size(width, height)
      buffer = Buffer.new(Math.max(1, w), Math.max(1, h))
      root.render(buffer, 0, 0, buffer.width, buffer.height)
      buffer.to_s
    end

    # Builds an element tree from a block.
    def self.build(&block : Builder -> Nil) : Element
      builder = Builder.new
      block.call(builder)
      builder.root || Text.new("")
    end

    # Creates and returns a DockContainer configured via DSL block
    def self.dock(&block : DockContainer -> Nil) : DockContainer
      dc = DockContainer.new
      block.call(dc)
      dc
    end

    # Creates and returns a GridContainer configured via DSL block
    def self.grid(
      columns : Array(GridTrack | Int32 | Float64 | String) = [GridTrack.fr(1.0)],
      rows : Array(GridTrack | Int32 | Float64 | String) = [GridTrack.fr(1.0)],
      gutter_x : Int32 = 1,
      gutter_y : Int32 = 0,
      &block : GridContainer -> Nil
    ) : GridContainer
      gc = GridContainer.new(columns: columns, rows: rows, gutter_x: gutter_x, gutter_y: gutter_y)
      block.call(gc)
      gc
    end

    # Creates a Screen with declarative root composed via Builder block
    def self.screen(name : String, title : String? = nil, &block : Builder -> Nil) : Screen
      root_el = build(&block)
      Screen.new(name: name, title: title, root: root_el)
    end

    # Creates a ModalScreen with declarative root composed via Builder block
    def self.modal_screen(name : String = "modal", title : String? = nil, &block : Builder -> Nil) : ModalScreen
      root_el = build(&block)
      ModalScreen.new(name: name, title: title, root: root_el)
    end
  end
end

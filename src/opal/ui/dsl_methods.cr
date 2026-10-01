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
require "./components/switch"
require "./components/radio_set"
require "./components/collapsible"
require "./components/digits"
require "./components/rich_log"
require "./components/loading_indicator"
require "./components/header"
require "./components/footer"
require "./components/placeholder"
require "./components/content_switcher"
require "./components/scissor"
require "./components/mask"
require "./components/group"
require "./components/meter"
require "../style/animation"
require "./layouts/dock"
require "./layouts/grid"

module Opal
  module UI
    # Comprehensive component factory mixin.
    # Can be included in `Builder`, `StackBuilder`, `Screen`, or any custom class.
    module DSL
      # Appends an element into the current builder context.
      # Builders override this to store in @root or @elements.
      def add_element(el : Element) : Element
        el
      end

      # Appends an existing element into the current builder context.
      def add(el : Element) : Element
        add_element(el)
      end

      # Operator syntax for `add`.
      def <<(el : Element) : Element
        add_element(el)
      end

      # Alias for inserting custom elements or controls.
      def custom(el : Element) : Element
        add_element(el)
      end

      # --- Visual Components ---

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
        add_element(el)
        el
      end

      def badge(
        label : String,
        bg : Color | Symbol | String = :blue,
        fg : Color | Symbol | String = :white,
        bold : Bool = true,
      ) : Badge
        el = Badge.new(label, bg: bg, fg: fg, bold: bold)
        add_element(el)
        el
      end

      def rule(char : Char = '─', fg : Color | Symbol | String = Color.none) : Rule
        el = Rule.new(char: char, fg: fg)
        add_element(el)
        el
      end

      def box(
        border : Symbol | Border = :rounded,
        border_fg : Color | Symbol | String = Color.none,
        padding : Int32 = 0,
        title : String? = nil,
        title_fg : Color | Symbol | String = :cyan,
        bg : Color | Symbol | String = Color.none,
        child : Element? = nil,
        &
      ) : Box
        sub_builder = Builder.new
        with sub_builder yield sub_builder
        el = Box.new(
          child: child || sub_builder.root,
          border: border,
          border_fg: border_fg,
          padding: padding,
          title: title,
          title_fg: title_fg,
          bg: bg
        )
        add_element(el)
        el
      end

      def box(
        border : Symbol | Border = :rounded,
        border_fg : Color | Symbol | String = Color.none,
        padding : Int32 = 0,
        title : String? = nil,
        title_fg : Color | Symbol | String = :cyan,
        bg : Color | Symbol | String = Color.none,
        child : Element? = nil,
      ) : Box
        el = Box.new(
          child: child,
          border: border,
          border_fg: border_fg,
          padding: padding,
          title: title,
          title_fg: title_fg,
          bg: bg
        )
        add_element(el)
        el
      end

      def vstack(spacing : Int32 = 0, &) : VStack
        sb = StackBuilder.new
        with sb yield sb
        stack = VStack.new(spacing: spacing)
        sb.elements.each { |e| stack.add(e) }
        add_element(stack)
        stack
      end

      def vstack(elements : Enumerable(Element) = [] of Element, spacing : Int32 = 0) : VStack
        stack = VStack.new(spacing: spacing)
        elements.each { |e| stack.add(e) }
        add_element(stack)
        stack
      end

      def hstack(spacing : Int32 = 0, &) : HStack
        sb = StackBuilder.new
        with sb yield sb
        stack = HStack.new(spacing: spacing)
        sb.elements.each { |e| stack.add(e) }
        add_element(stack)
        stack
      end

      def hstack(elements : Enumerable(Element) = [] of Element, spacing : Int32 = 0) : HStack
        stack = HStack.new(spacing: spacing)
        elements.each { |e| stack.add(e) }
        add_element(stack)
        stack
      end

      def table(
        headers : Array(String) = [] of String,
        header_fg : Color | Symbol | String = :cyan,
        border_fg : Color | Symbol | String = Color.none,
        &
      ) : Table
        tbl = Table.new(headers: headers, header_fg: header_fg, border_fg: border_fg)
        tb = TableBuilder.new(tbl)
        with tb yield tb
        add_element(tbl)
        tbl
      end

      def table(
        headers : Array(String) = [] of String,
        rows : Array(Array(String)) = [] of Array(String),
        header_fg : Color | Symbol | String = :cyan,
        border_fg : Color | Symbol | String = Color.none,
      ) : Table
        tbl = Table.new(headers: headers, rows: rows, header_fg: header_fg, border_fg: border_fg)
        add_element(tbl)
        tbl
      end

      def viewport(
        content : String,
        offset_y : Int32 = 0,
        fg : Color | Symbol | String = Color.none,
        show_scrollbar : Bool = true,
      ) : Viewport
        el = Viewport.new(content: content, offset_y: offset_y, fg: fg, show_scrollbar: show_scrollbar)
        add_element(el)
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
        add_element(el)
        el
      end

      def barchart(
        title : String? = nil,
        bar_char : Char = '█',
        max_value : Float64? = nil,
        &
      ) : BarChart
        chart = BarChart.new(title: title, bar_char: bar_char, max_value: max_value)
        bb = BarChartBuilder.new(chart)
        with bb yield bb
        add_element(chart)
        chart
      end

      def pie_chart(
        title : String? = nil,
        donut : Bool = false,
        &
      ) : PieChart
        chart = PieChart.new(title: title, donut: donut)
        pb = PieChartBuilder.new(chart)
        with pb yield pb
        add_element(chart)
        chart
      end

      def line_graph(
        title : String? = nil,
        min_y : Float64? = nil,
        max_y : Float64? = nil,
        show_grid : Bool = true,
        show_legend : Bool = true,
        &
      ) : LineGraph
        graph = LineGraph.new(
          title: title,
          min_y: min_y,
          max_y: max_y,
          show_grid: show_grid,
          show_legend: show_legend
        )
        gb = LineGraphBuilder.new(graph)
        with gb yield gb
        add_element(graph)
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
        add_element(el)
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
        add_element(el)
        el
      end

      def tree(title : String? = nil, &) : Tree
        tr = Tree.new(title: title)
        tb = TreeBuilder.new(tr)
        with tb yield tb
        add_element(tr)
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
        add_element(el)
        el
      end

      def markdown(content : String, width : Int32 = 80) : MarkdownElement
        el = MarkdownElement.new(content, width: width)
        add_element(el)
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
        &
      ) : SplitView
        sb = SplitBuilder.new
        with sb yield sb
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
        add_element(el)
        el
      end

      def code_view(
        code : String = "",
        language : Symbol | String = :plain,
        start_line : Int32 = 1,
        highlighted_line : Int32? = nil,
        scroll_offset : Int32 = 0,
        show_line_numbers : Bool = true,
        gutter_fg : Color | Symbol | String | Nil = nil,
        cursor_fg : Color | Symbol | String | Nil = nil,
        cursor_indicator : String? = nil,
      ) : CodeView
        el = CodeView.new(
          code: code,
          language: language,
          start_line: start_line,
          highlighted_line: highlighted_line,
          scroll_offset: scroll_offset,
          show_line_numbers: show_line_numbers,
          gutter_fg: gutter_fg,
          cursor_fg: cursor_fg,
          cursor_indicator: cursor_indicator
        )
        add_element(el)
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
        add_element(el)
        el
      end

      def tabs(
        items : Array(TabItem),
        active_index : Int32 = 0,
        active_fg : Color | Symbol | String = :bright_white,
        active_bg : Color | Symbol | String = :blue,
        inactive_fg : Color | Symbol | String = :gray,
        spacing : Int32 = 2,
        pill_style : Bool = false,
      ) : Tabs
        el = Tabs.new(
          items: items,
          active_index: active_index,
          active_fg: active_fg,
          active_bg: active_bg,
          inactive_fg: inactive_fg,
          spacing: spacing,
          pill_style: pill_style
        )
        add_element(el)
        el
      end

      def hex_viewer(
        bytes : Bytes | Slice(UInt8) | Array(UInt8),
        base_address : UInt64 = 0_u64,
        bytes_per_row : Int32 = 16,
        scroll_offset : Int32 = 0,
        selected_byte : Int32? = nil,
        address_fg : Color | Symbol | String = :dark_gray,
        zero_fg : Color | Symbol | String = :dark_gray,
        non_zero_fg : Color | Symbol | String = Color.none,
        ascii_fg : Color | Symbol | String = :cyan,
        selected_fg : Color | Symbol | String = :black,
        selected_bg : Color | Symbol | String = :yellow,
      ) : HexViewer
        el = HexViewer.new(
          bytes: bytes,
          base_address: base_address,
          bytes_per_row: bytes_per_row,
          scroll_offset: scroll_offset,
          selected_byte: selected_byte,
          address_fg: address_fg,
          zero_fg: zero_fg,
          non_zero_fg: non_zero_fg,
          ascii_fg: ascii_fg,
          selected_fg: selected_fg,
          selected_bg: selected_bg
        )
        add_element(el)
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
        add_element(el)
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
        add_element(el)
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
        add_element(el)
        el
      end

      # --- Interactive Controls ---

      def button(
        label : String,
        icon : String? = nil,
        variant : Symbol = :primary,
        style : Symbol? = nil,
        toggle : Bool = false,
        active : Bool = false,
        disabled : Bool = false,
        shortcut_char : Char? = nil,
        border : Symbol | Border | Nil = nil,
        &on_click : Button -> Nil
      ) : Button
        v = style || variant
        el = Button.new(
          label: label,
          icon: icon,
          variant: v,
          toggle: toggle,
          active: active,
          disabled: disabled,
          shortcut_char: shortcut_char,
          on_click: on_click
        )
        el.border_style = border.is_a?(Symbol) ? Border.from(border) : border if border
        add_element(el)
        el
      end

      def button(
        label : String,
        icon : String? = nil,
        variant : Symbol = :primary,
        style : Symbol? = nil,
        toggle : Bool = false,
        active : Bool = false,
        disabled : Bool = false,
        shortcut_char : Char? = nil,
        border : Symbol | Border | Nil = nil,
      ) : Button
        v = style || variant
        el = Button.new(
          label: label,
          icon: icon,
          variant: v,
          toggle: toggle,
          active: active,
          disabled: disabled,
          shortcut_char: shortcut_char
        )
        el.border_style = border.is_a?(Symbol) ? Border.from(border) : border if border
        add_element(el)
        el
      end

      def dropdown(
        items : Array(String),
        selected_index : Int32 = 0,
        placeholder : String = "Select...",
        expanded : Bool = false,
        max_visible_items : Int32 = 6,
        border : Symbol | Border | Nil = nil,
        &on_change : Int32, String -> Nil
      ) : Dropdown
        el = Dropdown.new(
          items: items,
          selected_index: selected_index,
          placeholder: placeholder,
          expanded: expanded,
          max_visible_items: max_visible_items,
          on_change: on_change
        )
        el.border = border.is_a?(Symbol) ? Border.from(border) : border if border
        add_element(el)
        el
      end

      def dropdown(
        items : Array(String),
        selected_index : Int32 = 0,
        placeholder : String = "Select...",
        expanded : Bool = false,
        max_visible_items : Int32 = 6,
        border : Symbol | Border | Nil = nil,
      ) : Dropdown
        el = Dropdown.new(
          items: items,
          selected_index: selected_index,
          placeholder: placeholder,
          expanded: expanded,
          max_visible_items: max_visible_items
        )
        el.border = border.is_a?(Symbol) ? Border.from(border) : border if border
        add_element(el)
        el
      end

      def scrollbar(
        orientation : ScrollBar::Orientation | Symbol = ScrollBar::Orientation::Vertical,
        min_value : Int32 = 0,
        max_value : Int32 = 100,
        value : Int32 = 0,
        page_size : Int32 = 10,
        length : Int32? = nil,
        total : Int32? = nil,
        show_arrows : Bool = true,
        &on_scroll : Int32 -> Nil
      ) : ScrollBar
        effective_max = total || max_value
        el = ScrollBar.new(
          orientation: orientation,
          min_value: min_value,
          max_value: effective_max,
          value: value,
          page_size: page_size,
          show_arrows: show_arrows,
          on_change: on_scroll
        )
        add_element(el)
        el
      end

      def scrollbar(
        orientation : ScrollBar::Orientation | Symbol = ScrollBar::Orientation::Vertical,
        min_value : Int32 = 0,
        max_value : Int32 = 100,
        value : Int32 = 0,
        page_size : Int32 = 10,
        length : Int32? = nil,
        total : Int32? = nil,
        show_arrows : Bool = true,
      ) : ScrollBar
        effective_max = total || max_value
        el = ScrollBar.new(
          orientation: orientation,
          min_value: min_value,
          max_value: effective_max,
          value: value,
          page_size: page_size,
          show_arrows: show_arrows
        )
        add_element(el)
        el
      end

      def window(
        title : String,
        x : Int32 = 0,
        y : Int32 = 0,
        width : Int32 = 40,
        height : Int32 = 15,
        border : Symbol | Border = :rounded,
        resizable : Bool = true,
        minimizable : Bool = true,
        maximizable : Bool = true,
        child : Element? = nil,
        &
      ) : Window
        sub_builder = Builder.new
        with sub_builder yield sub_builder
        el = Window.new(
          title: title,
          child: child || sub_builder.root,
          x: x,
          y: y,
          width: width,
          height: height,
          border: border,
          resizable: resizable,
          minimizable: minimizable,
          maximizable: maximizable
        )
        add_element(el)
        el
      end

      def window(
        title : String,
        x : Int32 = 0,
        y : Int32 = 0,
        width : Int32 = 40,
        height : Int32 = 15,
        border : Symbol | Border = :rounded,
        resizable : Bool = true,
        minimizable : Bool = true,
        maximizable : Bool = true,
        child : Element? = nil,
      ) : Window
        el = Window.new(
          title: title,
          child: child,
          x: x,
          y: y,
          width: width,
          height: height,
          border: border,
          resizable: resizable,
          minimizable: minimizable,
          maximizable: maximizable
        )
        add_element(el)
        el
      end

      def canvas_2d(width : Int32 = 40, height : Int32 = 20, &) : Canvas2D
        el = Canvas2D.new(width: width, height: height)
        with el yield el
        add_element(el)
        el
      end

      def mesh_3d(
        mesh : Opal::Graphics::Mesh3D,
        camera_dist : Float64 = 3.5,
        pitch : Float64 = 0.0,
        yaw : Float64 = 0.0,
        roll : Float64 = 0.0,
        render_mode : Symbol | MeshRenderMode = :wireframe,
        border : Symbol | Border = :rounded,
        width : Int32? = nil,
        height : Int32? = nil,
      ) : Mesh3DElement
        el = Mesh3DElement.new(
          mesh: mesh,
          camera_dist: camera_dist,
          pitch: pitch,
          yaw: yaw,
          roll: roll,
          render_mode: render_mode,
          border: border,
          width: width,
          height: height
        )
        add_element(el)
        el
      end

      def switch(label : String, on : Bool = false, disabled : Bool = false, &on_change : Bool -> Nil) : Switch
        el = Switch.new(label: label, on: on, disabled: disabled)
        el.on_change(&on_change)
        add_element(el)
        el
      end

      def switch(label : String, on : Bool = false, disabled : Bool = false) : Switch
        el = Switch.new(label: label, on: on, disabled: disabled)
        add_element(el)
        el
      end

      def checkbox(label : String, checked : Bool = false, disabled : Bool = false, &on_change : Bool -> Nil) : Checkbox
        el = Checkbox.new(label: label, checked: checked, disabled: disabled)
        el.on_change(&on_change)
        add_element(el)
        el
      end

      def checkbox(label : String, checked : Bool = false, disabled : Bool = false) : Checkbox
        el = Checkbox.new(label: label, checked: checked, disabled: disabled)
        add_element(el)
        el
      end

      def slider(
        min : Number = 0.0,
        max : Number = 100.0,
        value : Number = 0.0,
        step : Number = 1.0,
        label : String? = nil,
        show_value : Bool = true,
        disabled : Bool = false,
        color : Color | Symbol | String | Nil = nil,
        &on_change : Float64 -> Nil
      ) : Slider
        el = Slider.new(
          value: value,
          min: min,
          max: max,
          step: step,
          label: label,
          show_value: show_value,
          disabled: disabled,
          on_change: on_change
        )
        el.thumb_fg = Color.from(color) if color
        add_element(el)
        el
      end

      def slider(
        min : Number = 0.0,
        max : Number = 100.0,
        value : Number = 0.0,
        step : Number = 1.0,
        label : String? = nil,
        show_value : Bool = true,
        disabled : Bool = false,
        color : Color | Symbol | String | Nil = nil,
      ) : Slider
        el = Slider.new(
          value: value,
          min: min,
          max: max,
          step: step,
          label: label,
          show_value: show_value,
          disabled: disabled
        )
        el.thumb_fg = Color.from(color) if color
        add_element(el)
        el
      end

      def radio_set(
        options : Array(String)? = nil,
        items : Array(String)? = nil,
        selected_index : Int32 = 0,
        disabled : Bool = false,
        horizontal : Bool = false,
        &on_change : Int32, String -> Nil
      ) : RadioSet
        itms = (items || options || [] of String).map { |s| s.as(String | RadioButton) }
        el = RadioSet.new(items: itms, selected_index: selected_index, horizontal: horizontal, disabled: disabled, on_change: on_change)
        add_element(el)
        el
      end

      def radio_set(
        options : Array(String)? = nil,
        items : Array(String)? = nil,
        selected_index : Int32 = 0,
        disabled : Bool = false,
        horizontal : Bool = false,
      ) : RadioSet
        itms = (items || options || [] of String).map { |s| s.as(String | RadioButton) }
        el = RadioSet.new(items: itms, selected_index: selected_index, horizontal: horizontal, disabled: disabled)
        add_element(el)
        el
      end

      def collapsible(
        title : String,
        collapsed : Bool = true,
        disabled : Bool = false,
        child : Element? = nil,
        &
      ) : Collapsible
        sub_builder = Builder.new
        with sub_builder yield sub_builder
        el = Collapsible.new(title: title, child: child || sub_builder.root, collapsed: collapsed, disabled: disabled)
        add_element(el)
        el
      end

      def collapsible(
        title : String,
        child : Element? = nil,
        collapsed : Bool = true,
        disabled : Bool = false,
      ) : Collapsible
        el = Collapsible.new(title: title, child: child, collapsed: collapsed, disabled: disabled)
        add_element(el)
        el
      end

      def digits(
        text : String,
        fg : Color | Symbol | String = :bright_cyan,
        bg : Color | Symbol | String = Color.none,
        bold : Bool = true,
      ) : Digits
        el = Digits.new(text, fg: fg, bg: bg, bold: bold)
        add_element(el)
        el
      end

      def rich_log(
        max_lines : Int32 = 1000,
        auto_scroll : Bool = true,
        highlight_ansi : Bool = true,
      ) : RichLog
        el = RichLog.new(max_lines: max_lines, auto_scroll: auto_scroll, highlight_ansi: highlight_ansi)
        add_element(el)
        el
      end

      def loading_indicator(
        label : String? = nil,
        style : Symbol = :dots,
        fg : Color | Symbol | String = Color.none,
      ) : LoadingIndicator
        el = LoadingIndicator.new(label: label, style: style, fg: Color.from(fg))
        add_element(el)
        el
      end

      def header(
        title : String = "Opal Application",
        subtitle : String? = nil,
        icon : String? = "[*]",
        show_clock : Bool = true,
      ) : Header
        el = Header.new(title: title, subtitle: subtitle, icon: icon, show_clock: show_clock)
        add_element(el)
        el
      end

      def footer(
        bindings : Array(NamedTuple(key: String, desc: String)) = [] of NamedTuple(key: String, desc: String),
      ) : Footer
        el = Footer.new(bindings)
        add_element(el)
        el
      end

      def placeholder(
        label : String? = nil,
        border : Symbol | Border = :rounded,
      ) : Placeholder
        el = Placeholder.new(label: label, border: border)
        add_element(el)
        el
      end

      def dock(&) : DockContainer
        dc = DockContainer.new
        with dc yield dc
        add_element(dc)
        dc
      end

      def grid(
        columns : Array(GridTrack | Int32 | Float64 | String) = [GridTrack.fr(1.0)],
        rows : Array(GridTrack | Int32 | Float64 | String) = [GridTrack.fr(1.0)],
        gutter_x : Int32 = 1,
        gutter_y : Int32 = 0,
        &
      ) : GridContainer
        gc = GridContainer.new(columns: columns, rows: rows, gutter_x: gutter_x, gutter_y: gutter_y)
        with gc yield gc
        add_element(gc)
        gc
      end

      def content_switcher(current : String? = nil, &) : ContentSwitcher
        cs = ContentSwitcher.new(current: current)
        with cs yield cs
        add_element(cs)
        cs
      end

      # Scissor clipping container restricting child rendering to a specific rect
      def scissor(rect : Rect, &) : ScissorContainer
        builder = Builder.new
        with builder yield builder
        container = ScissorContainer.new(rect, builder.root)
        add_element(container)
        container
      end

      def scissor(x : Int32, y : Int32, width : Int32, height : Int32, &) : ScissorContainer
        scissor(Rect.new(x, y, width, height)) { |b| yield b }
      end

      # Masking container rendering children under an active MaskMap
      def mask(mask_map : MaskMap, feather : Bool = true, offset_x : Int32 = 0, offset_y : Int32 = 0, &) : MaskContainer
        builder = Builder.new
        with builder yield builder
        container = MaskContainer.new(mask_map, builder.root, feather: feather, offset_x: offset_x, offset_y: offset_y)
        add_element(container)
        container
      end

      # Group layout container supporting directional flow and overflow clipping
      def group(
        title : String? = nil,
        direction : LayoutDirection = LayoutDirection::Vertical,
        overflow : OverflowPolicy = OverflowPolicy::Hidden,
        border : Border = Border.none,
        padding : Int32 = 0,
        &
      ) : Group
        grp = Group.new(title: title, direction: direction, overflow: overflow, border: border, padding: padding)
        builder = Builder.new
        with builder yield builder
        if root = builder.root
          grp.add(root)
        end
        add_element(grp)
        grp
      end

      # Alias for group
      def container(
        title : String? = nil,
        direction : LayoutDirection = LayoutDirection::Vertical,
        overflow : OverflowPolicy = OverflowPolicy::Hidden,
        border : Border = Border.none,
        padding : Int32 = 0,
        &
      ) : Group
        grp = Group.new(title: title, direction: direction, overflow: overflow, border: border, padding: padding)
        builder = Builder.new
        with builder yield builder
        if root = builder.root
          grp.add(root)
        end
        add_element(grp)
        grp
      end

      # Fractional 1/8th Unicode block meter
      def meter(
        value : Float64,
        orientation : MeterOrientation = MeterOrientation::Horizontal,
        gradient : MeterGradient = MeterGradient::Heat,
        show_label : Bool = true,
        width : Int32? = nil,
        height : Int32? = nil,
      ) : Meter
        m = Meter.new(value: value, orientation: orientation, gradient: gradient, show_label: show_label, width: width, height: height)
        add_element(m)
        m
      end

      # Compact 1-character meter glyph
      def compact_meter(value : Float64) : Text
        ch = Glyphs.h_bar(value)
        text(ch.to_s, fg: value > 0.8 ? Color.hex("#ff0844") : (value > 0.5 ? Color.hex("#ffd200") : Color.hex("#38ef7d")), bold: true)
      end

      # Tween animator helper
      def tween(
        from_val : Float64,
        to_val : Float64,
        duration : Time::Span,
        easing : Animation::Easing = Animation::Easing::Linear,
        &block : Float64 -> Nil
      ) : Animation::Tween
        tw = Animation::Tween.new(from_val, to_val, duration, easing)
        tw.on_update(&block)
        tw
      end

      # Interactive Markdown Viewer element
      def markdown_viewer(
        content : String,
        scrollable : Bool = true,
        auto_scroll : Bool = false,
        scroll_speed : Float64 = 1.0,
        width : Int32 = 80,
      ) : MarkdownViewer
        mv = MarkdownViewer.new(content, width: width, scrollable: scrollable, auto_scroll: auto_scroll, scroll_speed: scroll_speed)
        add_element(mv)
        mv
      end

      # Asynchronous Markdown Viewer with loading throbber
      def async_markdown_viewer(
        label : String = "Loading markdown...",
        scrollable : Bool = true,
        auto_scroll : Bool = false,
        scroll_speed : Float64 = 1.0,
        width : Int32 = 80,
        &block : -> String
      ) : AsyncMarkdownViewer
        mv = AsyncMarkdownViewer.new(label, width: width, scrollable: scrollable, auto_scroll: auto_scroll, scroll_speed: scroll_speed, &block)
        add_element(mv)
        mv
      end
    end
  end
end

require "lib_glfw"

module CrystGLFW
  # A Window represents a GLFW Window and its associated OpenGL context.
  struct Window
    alias MoveCallback = Proc(Int32, Int32, Nil)
    alias ResizeCallback = Proc(Int32, Int32, Nil)
    alias CloseCallback = Proc(Nil)
    alias RefreshCallback = Proc(Nil)
    alias ToggleFocusCallback = Proc(Nil)
    alias ToggleIconificationCallback = Proc(Nil)
    alias FramebufferResizeCallback = Proc(Int32, Int32, Nil)
    alias KeyCallback = Proc(KeyEvent, Nil)
    alias CharCallback = Proc(CharEvent, Nil)
    alias MouseButtonCallback = Proc(MouseButtonEvent, Nil)
    alias ScrollCallback = Proc(Float64, Float64, Nil)
    alias CursorCrossThresholdCallback = Proc(Nil)
    alias CursorMoveCallback = Proc(Float64, Float64, Nil)
    alias FileDropCallback = Proc(Array(String), Nil)

    alias WindowCallback = MoveCallback |
                           ResizeCallback |
                           CloseCallback |
                           RefreshCallback |
                           ToggleFocusCallback |
                           ToggleIconificationCallback |
                           FramebufferResizeCallback |
                           KeyCallback |
                           CharCallback |
                           MouseButtonCallback |
                           ScrollCallback |
                           CursorCrossThresholdCallback |
                           CursorMoveCallback |
                           FileDropCallback |
                           Nil

    # A callback registry that maps a unique LibGLFW Window pointer to a callback.
    # This allows multiple window objects to reference the same underlying GLFW window and
    # define callbacks for it universally.
    @@callback_registry = {} of Pointer(LibGLFW::Window) => Hash(Symbol, WindowCallback)

    # Returns the window whose context is current.
    #
    # ```
    # current_window = CrystGLFW::Window.current
    # ```
    #
    # NOTE: This method must be called from within a `CrystGLFW#run` block definition.
    def self.current
      new(LibGLFW.get_current_context)
    end

    # :nodoc:
    def self.set_hints(hints : Hash(Symbol, Int32 | Symbol))
      hints.each do |key, value|
        hint_value = value.is_a?(Symbol) ? CrystGLFW[value] : value
        LibGLFW.window_hint CrystGLFW[key], hint_value
      end
    end

    # :nodoc:
    def self.clear_hints
      LibGLFW.default_window_hints
    end

    # Creates a new GLFW window.
    #
    # ```
    # # Create a window that is 640x480, titled "My Test Window".
    # window = CrystGLFW::Window.new(width: 640, height: 480, title: "My Test Window")
    # ```
    #
    # This method accepts the following arguments:
    # - *width*, the desired width of the window in screen coordinates.
    # - *height*, the desired height of the window in screen coordinates.
    # - *title*, the title of the window.
    # - *monitor*, the monitor to use for full screen mode. If left blank, the context will run in windowed mode.
    # - *sharing_window*, the window whose context to share resource with. If left blank, no resource sharing occurs.
    # - *hints*, the desired window options. If left blank, GLFW defaults will be used.
    #
    # There are several different kinds of hints that can be set, all of which can be found in the GLFW documentation.
    # To specify hints for window creation, create a hash:
    #
    # ```
    # hints = { :client_api => :opengl_es_api, :context_version_major => 3 }
    # window = CrystGLFW::Window.new(title: "My Window", monitor: CrystGLFW::Monitor.primary, hints: hints)
    # ```
    #
    # Hints are cleared after window creation, so they are only used when passed.
    #
    # NOTE: This method must be called from within a `CrystGLFW#run` block definition.
    def initialize(width = 640, height = 480, title = "", monitor = nil, sharing_window = nil, hints = nil)
      Window.set_hints(hints) if hints
      @handle = LibGLFW.create_window width, height, title, monitor, sharing_window
      Window.clear_hints if hints
      initialize_callbacks unless @@callback_registry[@handle]?
    end

    # :nodoc:
    def initialize(handle : Pointer(LibGLFW::Window))
      @handle = handle
      initialize_callbacks unless @@callback_registry[@handle]?
    end

    # Destroys the underlying GLFW Window and removes it from the callback registry.
    #
    # NOTE: This method must be called from within a `CrystGLFW#run` block definition.
    def destroy
      LibGLFW.destroy_window @handle
      @@callback_registry.delete @handle
    end

    # Returns true if the window is currently marked for closing. False otherwise.
    #
    # ```
    # until window.should_close?
    #   window.wait_events
    #   window.swap_buffers
    # end
    # ```
    #
    # NOTE: This method must be called from within a `CrystGLFW#run` block definition.
    def should_close?
      LibGLFW.window_should_close(@handle) == CrystGLFW[:true]
    end

    # Marks this window for closing.
    #
    # ```
    # window.on_key do |key_event|
    #   # if the 'q' key is held down, then mark the window for closing.
    #   if key_event.key.is? :key_q && key_event.repeat?
    #     window.should_close
    #   end
    # end
    # ```
    #
    # NOTE: This method must be called from within a `CrystGLFW#run` block definition.
    def should_close
      LibGLFW.set_window_should_close @handle, CrystGLFW[:true]
    end

    # The exact opposite of `#should_close`
    #
    # NOTE: This method must be called from within a `CrystGLFW#run` block definition.
    def should_not_close
      LibGLFW.set_window_should_close @handle, CrystGLFW[:false]
    end

    # Sets the window's title.
    #
    # ```
    # window.on_key |key_event|
    #   # If the key is printable, then set the window title to the name of the key.
    #   window.title = key_event.key.name if key_event.key.printable? && key_event.press?
    # end
    # ```
    #
    # This method accepts the following arguments:
    # - *title*, the desired title of the window.
    #
    # NOTE: This method must be called from within a `CrystGLFW#run` block definition.
    def title=(title : String)
      LibGLFW.set_window_title @handle, title
    end

    # Returns the position of the window, in screen coordinates, as a named tuple.
    #
    # ```
    # pos = window.position 
    # puts "The window's top left corner is at (#{pos[:x]}, #{pos[:y]})."
    # ```
    #
    # NOTE: This method must be called from within a `CrystGLFW#run` block definition.
    def position
      LibGLFW.get_window_pos @handle, out x, out y
      {x: x, y: y}
    end

    # Sets the position of the window.
    #
    # ```
    # # Set the window's top left corner at (150, 150).
    # window.position = {x: 150, y: 150}
    # ```
    #
    # This method accepts the following arguments:
    # - *pos*, the desired position of the window.
    #
    # NOTE: This method must be called from within a `CrystGLFW#run` block definition.
    def position=(pos : NamedTuple(x: Int32, y: Int32))
      LibGLFW.set_window_pos @handle, pos[:x], pos[:y]
    end

    # Returns the dimensions of the window, in screen coordinates, as a named tuple.
    #
    # ```
    # dim = window.dimensions
    # puts "The window is currently #{dim[:width]} x #{dim[:height]}"
    # ```
    #
    # NOTE: This method must be called from within a `CrystGLFW#run` block definition.
    def dimensions
      LibGLFW.get_window_size @handle, out width, out height
      {width: width, height: height}
    end

    # Sets the dimensions of the window.
    #
    # ```
    # # Set the window's dimensions to be 640x480.
    # window.dimensions = {width: 640, height: 480}
    # ```
    #
    # This method accepts the following arguments:
    # - *dim*, the desired dimensions of the window.
    #
    # NOTE: This method must be called from within a `CrystGLFW#run` block definition.
    def dimensions=(dim : NamedTuple(width: Int32, height: Int32))
      LibGLFW.set_window_size @handle, dim[:width], dim[:height]
    end

    # See `#dimensions`
    def size
      dimensions
    end

    # See `#dimensions=`
    def size=(s : NamedTuple(width: Int32, height: Int32))
      dimensions = s
    end

    # Returns the corners of the window.
    #
    # ```
    # window.position = {x: 100, y: 100}
    #
    # # Retrieve the window's corners.
    # c = window.corners
    #
    # # Get the top left corner coordinates.
    # tl = c[:top_left]
    # 
    # # Print the coordinates.
    # puts "Top Left: (#{tl[:x]}, #{tl[:y]})" # => "Top Left: (100, 100)"
    # ```
    #
    # Each corner is labeled accordingly: top_left, top_right, bottom_right, bottom_left
    #
    # NOTE: This method must be called from within a `CrystGLFW#run` block definition.
    def corners
      p, d = position, dimensions
      top_left = p
      top_right = { x: (p[:x] + d[:width]), y: p[:y] }
      bottom_right = { x: (p[:x] + d[:width]), y: (p[:y] + d[:height]) }
      bottom_left = { x: p[:x], y: (p[:y] + d[:height]) }
      { top_left: top_left, top_right: top_right, bottom_right: bottom_right, bottom_left: bottom_left }
    end

    # Returns true if the window contains the given coordinates. False otherwise.
    #
    # ```
    # window.position = {x: 100, y: 100}
    # window.size = {width: 100, height: 100}
    #
    # # Check if the location (150, 150) is inside the window.
    # window.contains? {x: 150, y: 150} # => true
    #
    # # Check if the location (1000, 1000) is inside the window.
    # window.contains? {x: 1000, y: 1000} # => false
    # ```
    #
    # This method accepts the following arguments:
    #  -*coordinates*, the coordinates to check.
    #
    # NOTE: This method must be called from within a `CrystGLFW#run` block definition.
    def contains?(coordinates : NamedTuple(x : Number, y : Number))
      c, x, y = corners, coordinates[:x], coordinates[:y]
      tl, br = c[:top_left], c[:bottom_right]
      x >= tl[:x] && x <= br[:x] && y >= tl[:y] && y <= br[:y]
    end

    # Sets the size limits of the window.
    #
    # ```
    # # Disallows the window to be resized smaller than 100x100.
    # window.set_size_limits min_width: 100, min_height: 100
    #
    # # Disallows the window to be resized larger than 640x480.
    # window.set_size_limits max_width: 640, max_height: 480
    # ```
    #
    # This method accepts the following arguments:
    # - *min_width*, the minimum width of the window, in screen coordinates.
    # - *min_height*, the minimum height of the window, in screen coordinates.
    # - *max_width*, the maximum width of the window, in screen coordinates.
    # - *max_height*, the maximum height of the window, in screen coordinates.
    #
    # NOTE: This method must be called from within a `CrystGLFW#run` block definition.
    def set_size_limits(min_width = CrystGLFW[:dont_care], min_height = CrystGLFW[:dont_care],
                        max_width = CrystGLFW[:dont_care], max_height = CrystGLFW[:dont_care])
      LibGLFW.set_window_size_limits @handle, min_width, min_height, max_width, max_height
    end

    # Alternate syntax for `#set_size_limits`.
    #
    # ```
    # # Disallow the window to be resized smaller than 100x100 or larger than 640x480.
    # limits = {min_width: 100, min_height: 100, max_width: 640, max_height: 480}
    # window.size_limits = limits
    # ```
    #
    # This method accepts the following arguments:
    # - *limits*, the desired size limits to impose on the window.
    #
    # NOTE: This method must be called from within a `CrystGLFW#run` block definition.
    def size_limits=(limits : NamedTuple(min_width: Int32, min_height: Int32,
                                         max_width: Int32, max_height: Int32)
      set_size_limits limits[:min_width], limits[:min_height], limits[:max_width], limits[:max_height]
    end

    # Sets the aspect ratio of the window.
    #
    # ```
    # # Sets the window's aspect ratio to 16:9.
    # window.set_aspect_ratio 16, 9
    # ```
    #
    # NOTE: This method must be called from within a `CrystGLFW#run` block definition.
    def set_aspect_ratio(numerator = CrystGLFW[:dont_care], denominator = CrystGLFW[:dont_care])
      LibGLFW.set_aspect_ratio @handle, numerator, denominator
    end

    # Alternate syntax for `#set_aspect_ratio`.
    #
    # ```
    # # Sets the window's aspect ratio to 16:9.
    # window.aspect_ratio = {numerator: 16, denominator: 9}
    # ```
    #
    # NOTE: This method must be called from within a `CrystGLFW#run` block definition.
    def aspect_ratio=(ratio : NamedTuple(numerator: Int32, denominator: Int32))
      set_aspect_ratio ratio[:numerator], ratio[:denominator]
    end

    # Returns the dimensions of the framebuffer
    #
    # ```
    # # Retrieve the framebuffer's dimensions.
    # fb_dim = window.framebuffer_dimensions
    # 
    # # Print the dimensions of the framebuffer.
    # puts "The dimensions of the framebuffer are #{fb_dim[:width]} x #{fb_dim[:height]}."
    # ```
    #
    # NOTE: This method must be called from within a `CrystGLFW#run`block definition.
    def framebuffer_dimensions
      LibGLFW.get_framebuffer_size @handle, out width, out height
      {width: width, height: height}
    end

    # See `#framebuffer_dimensions`.
    def framebuffer_size
      framebuffer_dimensions
    end

    # Returns the size of the window's frame at each of its edges in screen coordinates.
    #
    # ```
    # # Retrieve the size of the window's frame along the top edge.
    # title_bar_height = window.frame_size[:top]
    #
    # # Print out the title bar's height.
    # puts "This window's title bar is #{title_bar_height} screen coordinates tall."
    # ```
    #
    # Each edge of the window is accessible: left, top, right, bottom.
    #
    # NOTE: This method must be called from within a `CrystGLFW#run` block definition.
    def frame_size
      LibGLFW.get_window_frame_size @handle, out left, out top, out right, out bottom
      {left: left, top: top, right: right, bottom: bottom}
    end

    # Iconifies (minimizes) the window. The exact opposite of `#restore`.
    #
    # NOTE: This method must be called from within a `CrystGLFW#run` block definition.
    def iconify
      LibGLFW.iconify_window @handle
    end

    # Restores (de-minimizes) the window. The exact opposite of `#iconify`.
    #
    # NOTE: This method must be called from within a `CrystGLFW#run` block definition.
    def restore
      LibGLFW.restore_window @handle
    end

    # Maximizes the window.
    #
    # NOTE: This method must be called from within a `CrystGLFW#run` block definition.
    def maximize
      LibGLFW.maximize_window @handle
    end

    # Shows the window (makes it visible). The exact opposite of `#hide`.
    #
    # NOTE: This method must be called from within a `CrystGLFW#run` block definition.
    def show
      LibGLFW.show_window @handle
    end

    # Hides the window (makes it invisible). The exact opposite of `#show`.
    #
    # NOTE: This method must be called from within a `CrystGLFW#run` block definition.
    def hide
      LibGLFW.hide_window @handle
    end

    # Focuses the window.
    #
    # NOTE: This method must be called from within a `CrystGLFW#run` block definition.
    def focus
      LibGLFW.focus_window @handle
    end

    # Returns true if the window is full screened. False otherwise.
    #
    # NOTE: This method must be called from within a `CrystGLFW#run` block definition.
    def full_screen?
      monitor_handle = LibGLFW.get_window_monitor(@handle)
      !monitor_handle.nil?
    end

    # Returns the window's monitor if the window is in fullscreen mode. Returns nil otherwise.
    #
    # NOTE: This method must be called from within a `CrystGLFW#run` block definition.
    def monitor
      LibGLFW.get_window_monitor(@handle)
    end

    # Sets the monitor used for full screen mode.
    #
    # ```
    # monitor = Monitor.primary
    # unless window.full_screen?
    #   window.set_monitor monitor 
    # end
    # ```
    #
    # The monitor's current video mode is used when the window is made full-screen.
    #
    # This method accepts the following arguments:
    # - *monitor*, the monitor that will be used for full screen mode.
    #
    # NOTE: This method must be called from within a `CrystGLFW#run` block definition.
    def set_monitor(monitor : CrystGLFW::Monitor)
      video_mode = monitor.video_mode
      LibGLFW.set_window_monitor @handle, monitor, CrystGLFW[:dont_care], CrystGLFW[:dont_care],
                                          video_mode.width, video_mode.height, video_mode.refresh_rate
    end

    # Alternate syntax for `#set_monitor`
    #
    # NOTE: This method must be called from within a `CrystGLFW#run` block definition.
    def monitor=(monitor : CrystGLFW::Monitor)
      set_monitor monitor
    end

    # Exits full screen mode and enters windowed mode with the given settings.
    #
    # ```
    # if window.full_screen?
    #   # Enter windowed mode at (50, 50) with dimensions 800x600.
    #   window.exit_full_screen(x: 50, y: 50, width: 800, height: 600)
    # end
    # ```
    #
    # This method accepts the following arguments:
    # - *x*, the x-coordinate of the window's desired position.
    # - *y*, the y-coordinate of the window's desired position.
    # - *width*, the width of the window.
    # - *height*, the height of the window.
    #
    # NOTE: This method must be called from within a `CrystGLFW#run` block definition.
    def exit_full_screen(x : Int32 = 100, y : Int32 = 100, width : Int32 = 640, height : Int32 = 480)
      LibGLFW.set_window_monitor @handle, nil, x, y, width, height, CrystGLFW[:dont_care]
    end

    # Sets the window's icon.
    #
    # TODO: Add an example here.
    #
    # This method accepts the following arguments:
    # - *icon*, the window's desired icon image.
    #
    # NOTE: This method must be called from within a `CrystGLFW#run` block definition.
    def set_icon(icon : Image)
      LibGLFW.set_window_icon @handle, 1, image
    end

    # Alternate syntax for `#set_icon`
    #
    # NOTE: This method must be called from within a `CrystGLFW#run` block definition.
    def icon=(icon : Image)

    # Returns true if the window is focused. False otherwise.
    #
    # NOTE: This method must be called from within a `CrystGLFW#run` block definition.
    def focused?
      check_attribute :focused
    end

    # Returns true if the window is iconified (minimized). False otherwise.
    #
    # NOTE: This method must be called from within a `CrystGLFW#run` block definition.
    def iconified?
      check_attribute :iconified
    end

    # Returns true if the window is maximized. False otherwise.
    #
    # NOTE: This method must be called from within a `CrystGLFW#run` block definition.
    def maximized?
      check_attribute :maximized
    end

    # Returns true if the window is visible. False otherwise.
    #
    # NOTE: This method must be called from within a `CrystGLFW#run` block definition.
    def visible?
      check_attribute :visible
    end

    # Returns true if the window is resizable. False otherwise.
    #
    # NOTE: This method must be called from within a `CrystGLFW#run` block definition.
    def resizable?
      check_attribute :resizable
    end

    # Returns true if the window is decorated. False otherwise.
    #
    # NOTE: This method must be called from within a `CrystGLFW#run` block definition.
    def decorated?
      check_attribute :decorated
    end

    # Returns true if the window is floating. False otherwise.
    #
    # NOTE: This method must be called from within a `CrystGLFW#run` block definition.
    def floating?
      check_attribute :floating
    end

    # Sets the window's cursor
    #
    # ```
    # cursor = Cursor.new(:hand_cursor)
    # window.set_cursor cursor
    # ```
    # 
    # This method accepts the following arguments:
    # - *new_cursor*, the window's new cursor.
    #
    # NOTE: This method must be called from within a `CrystGLFW#run` block definition.
    def set_cursor(new_cursor : Cursor)
      LibGLFW.set_cursor @handle, new_cursor
    end

    # Alternate syntax for `#set_cursor`
    #
    # NOTE: This method must be called from within a `CrystGLFW#run` block definition.
    def cursor=(new_cursor : Cursor)
      set_cursor new_cursor
    end

    # Removes the window's current cursor.
    #
    # ```
    # window.remove_cursor if window.should_close?
    # ```
    #
    # NOTE: This method must be called from within a `CrystGLFW#run` block definition.
    def remove_cursor
      LibGLFW.set_cursor @handle, nil
    end
    
    # Returns the cursor's position relative to the window's position.
    #
    # ```
    # cp = window.cursor_position
    # puts "The cursor is located at (#{cp[:x]}, #{cp[:y]})"
    # ```
    #
    # NOTE: This method must be called from within a `CrystGLFW#run` block definition.
    def cursor_position
      LibGLFW.get_cursor_pos @handle, out x, out y
      {x: x, y: y}
    end

    # Sets the cursor's position relative to the window's position.
    #
    # ```
    # # Set the cursor position to the top-left corner of the window.
    # window.set_cursor_position 0, 0
    #
    # # Set the cursor position to the middle of the 200x200 window.
    # window.set_cursor_position 100, 100
    # ```
    #
    # This method accepts the following arguments:
    # - *x*, the desired x coordinate of the cursor.
    # - *y*, the desired y coordinate of the cursor.
    #
    # NOTE: This method must be called from within a `CrystGLFW#run` block definition.
    def set_cursor_position(x : Float64, y : Float64)
      LibGLFW.set_cursor_pos @handle, x, y
    end

    # Alternate syntax for `#set_cursor_position`.
    #
    # ```
    # # Set the cursor position to the top-left corner of the window.
    # window.cursor_position = {x: 0, y: 0}
    #
    # # Set the cursor position to the middle of the 200x200 window.
    # window.cursor_position = {x: 100, y: 100}
    # ```
    #
    # This method accepts the following arguments:
    # - *pos*, the desired coordinates of the cursor's position.
    #
    # NOTE: This method must be called from within a `CrystGLFW#run` block definition.
    def cursor_position=(pos : NamedTuple(x: Float64, y: Float64))
      set_cursor_position pos[:x], pos[:y]
    end

    # Returns the current cursor mode's label. 
    #
    # ```
    # case window.cursor_mode
    # when :cursor_normal
    #   puts "The cursor is normal!"
    # when :cursor_hidden
    #   puts "The cursor is hidden!"
    # when :cursor_disable
    #   puts "The cursor is disabled!"
    # end
    # ```
    #
    # NOTE: This method must be called from within a `CrystGLFW#run` block definition.
    def cursor_mode
      value = LibGLFW.get_input_mode @handle, CrystGLFW[:cursor]
      [:cursor_normal, :cursor_hidden, :cursor_disable].find { |option| CrystGLFW[option] == value }
    end

    # Sets the window's cursor mode.
    #
    # ```
    # # Sets the cursor mode to normal.
    # window.set_cursor_mode :cursor_normal
    #
    # # Sets the cursor mode to hidden.
    # window.set_cursor_mode :cursor_hidden
    #
    # # Sets the cursor mode to disabled.
    # window.set_cursor_mode :cursor_disable
    # ```
    #
    # This method accepts the following arguments:
    # - *label*, the label of the desired cursor mode.
    #
    # *label* can be one of the following: :cursor_normal, :cursor_hidden, :cursor_disable
    #
    # NOTE: This method must be called from within a `CrystGLFW#run` block definition.
    def set_cursor_mode(label : Symbol)
      LibGLFW.set_input_mode @handle, CrystGLFW[:cursor], CrystGLFW[label]
    end

    # Returns true if sticky keys are enabled. False otherwise.
    #
    # NOTE: This method must be called from within a `CrystGLFW#run` block definition.
    def sticky_keys?
      value = LibGLFW.get_input_mode @handle, CrystGLFW[:sticky_keys]
      value == CrystGLFW[:true]
    end

    # Enables sticky keys.
    #
    # NOTE: This method must be called from within a `CrystGLFW#run` block definition.
    def enable_sticky_keys
      LibGLFW.set_input_mode @handle, CrystGLFW[:sticky_keys], CrystGLFW[:true]
    end

    # Disables sticky keys.
    #
    # NOTE: This method must be called from within a `CrystGLFW#run` block definition.
    def disable_sticky_keys
      LibGLFW.set_input_mode @handle, CrystGLFW[:sticky_keys], CrystGLFW[:false]
    end

    # Returns true if sticky mouse buttons are enabled. False otherwise.
    #
    # NOTE: This method must be called from within a `CrystGLFW#run` block definition.
    def sticky_mouse_buttons?
      value = LibGLFW.get_input_mode @handle, CrystGLFW[:sticky_mouse_buttons]
      value == CrystGLFW[:true]
    end

    # Enables sticky mouse buttons.
    #
    # NOTE: This method must be called from within a `CrystGLFW#run` block definition.
    def enable_sticky_mouse_buttons
      LibGLFW.set_input_mode @handle, CrystGLFW[:sticky_mouse_buttons], CrystGLFW[:true]
    end
    
    # Disables sticky mouse buttons.
    #
    # NOTE: This method must be called from within a `CrystGLFW#run` block definition.
    def disable_sticky_mouse_buttons
      LibGLFW.set_input_mode @handle, CrystGLFW[:sticky_mouse_buttons], CrystGLFW[:false]
    end

    # Returns the contents of the system clipboard as a String.
    #
    # ```
    # puts window.clipboard # Prints the contents of the clipboard.
    # ```
    #
    # NOTE: This method must be called from within a `CrystGLFW#run` block definition.
    def clipboard
      String.new(LibGLFW.get_clipboard_string(@handle))
    end

    # Sets the contents of the system clipboard.
    #
    # ```
    # window.set_clipboard "Hello from GLFW!"
    # ```
    #
    # This method accepts the following arguments:
    # - *clipboard_string*, the desired contents of the clipboard.
    def set_clipboard(clipboard_string : String)
      LibGLFW.set_clipboard_string @handle, clipboard_string
    end

    # Alternate syntax for `#set_clipboard`.
    #
    # NOTE: This method must be called from within a `CrystGLFW#run` block definition.
    def clipboard=(clipboard_string : String)
      set_clipboard clipboard_string
    end

    # Sets the window to be the current OpenGL context.
    #
    # ```
    # window = Window.new(title: "Awesome window")
    # window.make_context_current
    # until window.should_close?
    #   window.wait_events
    #   window.swap_buffers
    # end
    # ```
    #
    # NOTE: This method must be called from within a `CrystGLFW#run` block definition.
    def make_context_current
      LibGLFW.make_context_current @handle
    end

    # Swaps the front and back buffers.
    #
    # ```
    # window = Window.new(title: "Awesome window")
    # window.make_context_current
    # until window.should_close?
    #   window.wait_events
    #   window.swap_buffers
    # end
    # ```
    # 
    # NOTE: This method must be called from within a `CrystGLFW#run` block definition.
    def swap_buffers
      LibGLFW.swap_buffers @handle
    end

    # :nodoc:
    def ==(other : Window)
      @handle == other.to_unsafe
    end

    # :nodoc:
    def to_unsafe
      @handle
    end

    # Checks a window attribute by label.
    private def check_attribute(attribute_label : Symbol)
      value = LibGLFW.get_window_attrib @handle, CrystGLFW[attribute_label]
      value == CrystGLFW[:true]
    end

    # Sets the immutable move callback shim.
    private def set_move_callback
      callback = LibGLFW::Windowposfun.new do |handle, x, y|
        @@callback_registry[handle][:move].as(MoveCallback).try &.call(x, y)
      end
      LibGLFW.set_window_pos_callback @handle, callback
    end

    # Sets the immutable resize callback shim.
    private def set_resize_callback
      callback = LibGLFW::Windowsizefun.new do |handle, width, height|
        @@callback_registry[handle][:resize].as(ResizeCallback).try &.call(width, height)
      end
      LibGLFW.set_window_size_callback @handle, callback
    end

    # Sets the immutable close callback shim.
    private def set_close_callback
      callback = LibGLFW::Windowclosefun.new do |handle|
        @@callback_registry[handle][:close].as(CloseCallback).try &.call
      end
      LibGLFW.set_window_close_callback @handle, callback
    end

    # Sets the immutable refresh callback shim.
    private def set_refresh_callback
      callback = LibGLFW::Windowrefreshfun.new do |handle|
        @@callback_registry[handle][:refresh].as(RefreshCallback).try &.call
      end
      LibGLFW.set_window_refresh_callback @handle, callback
    end

    # Sets the immutable toggle focus callback shim.
    private def set_toggle_focus_callback
      callback = LibGLFW::Windowfocusfun.new do |handle, focused?|
        @@callback_registry[handle][:toggle_focus].as(ToggleFocusCallback).try &.call
      end
      LibGLFW.set_window_focus_callback @handle, callback
    end

    # Sets the immutable toggle iconification callback shim.
    private def set_toggle_iconification_callback
      callback = LibGLFW::Windowiconifyfun.new do |handle, iconified?|
        @@callback_registry[handle][:toggle_iconification].as(ToggleIconificationCallback).try &.call
      end
      LibGLFW.set_window_iconify_callback @handle, callback
    end

    # Sets the immutable framebuffer resize callback shim.
    private def set_framebuffer_resize_callback
      callback = LibGLFW::Framebuffersizefun.new do |handle, width, height|
        @@callback_registry[handle][:framebuffer_resize].as(FramebufferResizeCallback).try &.call(width, height)
      end
      LibGLFW.set_framebuffer_size_callback @handle, callback
    end

    # Sets the immutable key callback shim.
    private def set_key_callback
      callback = LibGLFW::Keyfun.new do |handle, key_code, scancode, action, modifiers|
        key_event = KeyEvent.new(Key.new(key_code, scancode), action, modifiers)
        @@callback_registry[handle][:key].as(KeyCallback).try &.call(key_event)
      end
      LibGLFW.set_key_callback @handle, callback
    end

    # Sets the immutable character callback shim.
    private def set_char_callback
      callback = LibGLFW::Charmodsfun.new do |handle, char, modifiers|
        char_event = CharEvent.new(char.chr, modifiers)
        @@callback_registry[handle][:char].as(CharCallback).try &.call(char_event)
      end
      LibGLFW.set_char_mods_callback @handle, callback
    end

    # Sets the immutable mouse button callback shim.
    private def set_mouse_button_callback
      callback = LibGLFW::Mousebuttonfun.new do |handle, button, action, modifiers|
        mouse_button_event = MouseButtonEvent.new(MouseButton.new(button), action, modifiers)
        @@callback_registry[handle][:mouse_button].as(MouseButtonCallback).try &.call(mouse_button_event)
      end
      LibGLFW.set_mouse_button_callback @handle, callback
    end

    # Sets the immutable scroll callback shim.
    private def set_scroll_callback
      callback = LibGLFW::Scrollfun.new do |handle, x, y|
        @@callback_registry[handle][:scroll].as(ScrollCallback).try &.call(x, y)
      end
      LibGLFW.set_scroll_callback @handle, callback
    end

    # Sets the immutable cursor cross threshold callback shim.
    private def set_cursor_cross_threshold_callback
      callback = LibGLFW::Cursorenterfun.new do |handle, entered?|
        @@callback_registry[handle][:cursor_cross_threshold].as(CursorCrossThresholdCallback).try &.call
      end
      LibGLFW.set_cursor_enter_callback @handle, callback
    end

    # Sets the immutable cursor move callback shim.
    private def set_cursor_move_callback
      callback = LibGLFW::Cursorposfun.new do |handle, x, y|
        @@callback_registry[handle][:cursor_move].as(CursorMoveCallback).try &.call(x, y)
      end
      LibGLFW.set_cursor_pos_callback @handle, callback
    end

    # Sets the immutable file drop callback shim.
    private def set_file_drop_callback
      callback = LibGLFW::Dropfun.new do |handle, count, raw_paths|
        paths = count.times.map { |i| String.new(raw_paths[i]) }
        @@callback_registry[handle][:file_drop].as(FileDropCallback).try &.call(paths.to_a)
      end
      LibGLFW.set_drop_callback @handle, callback
    end

    # Initializes the callback registry.
    private def initialize_callbacks
      @@callback_registry[@handle] = Hash(Symbol, WindowCallback).new
    end

    # Defines all of the callback methods.
    macro define_callbacks(pairs)
    {% for symbol, camel in pairs %}
      define_callback({{symbol}}, {{camel}})
    {% end %}
    end

    # Defines a callback method.
    macro define_callback(symbol, camel)
    def on_{{symbol.id}}(&callback : {{camel}}Callback)
      set_{{symbol.id}}_callback unless @@callback_registry[@handle][{{symbol}}]?
      @@callback_registry[@handle][{{symbol}}] = callback
    end
    end

    # Call the define_callbacks macro.
    define_callbacks({
      :move                   => Move,
      :resize                 => Resize,
      :close                  => Close,
      :refresh                => Refresh,
      :toggle_focus           => ToggleFocus,
      :toggle_iconification   => ToggleIconification,
      :framebuffer_resize     => FramebufferResize,
      :key                    => Key,
      :char                   => Char,
      :mouse_button           => MouseButton,
      :scroll                 => Scroll,
      :cursor_cross_threshold => CursorCrossThreshold,
      :cursor_move            => CursorMove,
      :file_drop              => FileDrop,
    })
  end
end

module CrystGLFW
  module Event
    # A WindowKeyEvent is generated by the `Window#on_key` callback and contains a `Key` along with
    # an interface to determine what action occurred with the key.
    struct WindowKey < Any
      include Modifiers

      @@actions : Array(Symbol) = [:press, :release, :repeat]
      @action : Symbol | Nil

      getter window : CrystGLFW::Window
      getter key : CrystGLFW::Key

      # :nodoc:
      def initialize(window : Window, key : Key, action_code : Int32, modifiers : Int32)
        @window = window
        @key = key
        @action = @@actions.find { |action| CrystGLFW[action] == action_code }
        set_modifiers modifiers
      end

      # Returns true if the key was pressed. False otherwise.
      #
      # ```
      # window.on_key do |key_event|
      #   puts "a key was pressed." if key_event.press?
      # end
      # ```
      def press?
        @action == :press
      end

      # Returns true if the key was released. False otherwise.
      #
      # ```
      # window.on_key do |key_event|
      #   puts "a key was released." if key_event.release?
      # end
      # ```
      def release?
        @action == :release
      end

      # Returns true if the key was held down. False otherwise.
      #
      # ```
      # window.on_key do |key_event|
      #   puts "a key was held down." if key_event.repeat?
      # end
      # ```
      def repeat?
        @action == :repeat
      end
    end
  end
end

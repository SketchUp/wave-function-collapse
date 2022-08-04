module Examples
  module WFC

    class WorldGenerator

      # @return [Integer]
      attr_reader :width, :height

      # @return [Array<TileDefinition>] definitions
      attr_reader :definitions

      # @param [Integer] width
      # @param [Integer] height
      # @param [Array<TileDefinition>] definitions
      def initialize(width, height, definitions)
        @width = width
        @height = @height
        @definitions = definitions
      end

      # @return [void]
      def run
      end

    end

  end
end

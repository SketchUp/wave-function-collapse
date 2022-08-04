module Examples
  module WFC

    class Tile

      # @return [WorldGenerator]
      attr_reader :world

      # @return [Sketchup::ComponentInstance] instance
      attr_reader :instance

      # @return [Integer] index
      attr_reader :index

      # @return [Geom::Point3d] position
      attr_reader :position

      # @return [Array<TileDefinition>] possibilities
      attr_reader :possibilities

      # @param [WorldGenerator] world
      # @param [Sketchup::ComponentInstance] instance
      # @param [Integer] index
      def initialize(world, instance, index)
        @world = world
        @instance = instance
        @index = index

        y = index / world.width
        x = index - (y * world.width)
        @position = Geom::Point3d.new(x, y, 0)

        @possibilities = world.definitions.dup
      end

      # @return [Integer]
      def entropy
        possibilities.size
      end

      def resolved?
        entropy == 1
      end

      def failed?
        entropy.zero?
      end

      def untouched?
        entropy == world.definitions.size
      end

      # @param [TileDefinition] definition
      def remove_possibility(definition)
        if possibilities.delete(definition)
          update
        end
      end

      # @param [TileDefinition] definition
      def resolve_to(definition)
        raise unless possibilities.include?(definition)
        possibilities.select! { |d| d == definition }
        update
      end

      private

      def update
        if resolved?
          instance.definition = possibilities.first.instance.definition
        end
      end

    end

  end
end

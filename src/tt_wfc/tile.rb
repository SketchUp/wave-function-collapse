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

        @possibilities = world.possibilities.dup
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
        entropy == world.possibilities.size
      end

      # @param [Array<Possibility>] possibilities
      def remove_possibilities(possibilities)
        # puts
        # p [:possibilities, :before, @possibilities.size, entropy]
        possibilities.each { |possibility|
          raise "expected Possibility, got #{possibility.class}" unless possibility.is_a?(Possibility)
          # raise 'already resolved' if resolved?
          # @possibilities.delete(possibility)
          puts "WARN: #{self} unable to remove possibility" if @possibilities.delete(possibility).nil?
        }
        raise "#{self} failed to resolve" if failed?
        # p [:possibilities, :after, @possibilities.size, entropy]
        update
      end

      # @param [Possibility] possibility
      def remove_possibility(possibility)
        raise "expected Possibility, got #{possibility.class}" unless possibility.is_a?(Possibility)
        raise 'already resolved' if resolved?
        if possibilities.delete(possibility)
          update
        end
      end

      # @param [Possibility] possibility
      def resolve_to(possibility)
        raise "expected Possibility, got #{possibility.class}" unless possibility.is_a?(Possibility)
        raise 'already resolved' if resolved?
        raise 'possibility not found' unless possibilities.select! { |item| item == possibility }
        raise "#{self} failed to resolve" if failed?
        update
      end

      # @param [Tile] tile
      def edge_index_to_neighbor(tile)
        # :north, :east, :south, :west
        if tile.north_of?(self)
          0
        elsif tile.east_of?(self)
          1
        elsif tile.south_of?(self)
          2
        elsif tile.west_of?(self)
          3
        end
      end

      # @param [Tile] tile
      def north_of?(tile)
        position.x == tile.position.x &&
        position.y == tile.position.y + 1
      end

      # @param [Tile] tile
      def east_of?(tile)
        position.x == tile.position.x + 1 &&
        position.y == tile.position.y
      end

      # @param [Tile] tile
      def south_of?(tile)
        position.x == tile.position.x &&
        position.y == tile.position.y - 1
      end

      # @param [Tile] tile
      def west_of?(tile)
        position.x == tile.position.x - 1 &&
        position.y == tile.position.y
      end

      # @return [String]
        def to_s
          x, y = position.to_a.map(&:to_i)
          "Tile<(#{x}, #{y}) #{entropy}:#{world.possibilities.size}>"
        end

      private

      def update
        if resolved?
          puts "Resolved #{self}."
          possibility = possibilities.first
          instance.definition = possibility.definition.instance.definition

          tr = Geom::Transformation.translation(instance.transformation.origin)
          instance.transformation = tr * possibility.transformation
        else
          # p [:update]
          instance.material = world.material_from_entropy(entropy)
        end
      end

    end

  end
end

require 'tt_wfc/tile_edge'

module Examples
  module WFC

    class TileDefinition

      # NOTE: It's important the order is clockwise.
      EDGE_IDS = [
        :north, :east, :south, :west
      ]

      # @return [Sketchup::ComponentInstance]
      attr_reader :instance

      # @return [Integer]
      attr_reader :weight

      # @return [Array<TileDefinition::TileEdge>]
      attr_reader :edges

      # @param [Sketchup::ComponentInstance] instance
      # @param [Integer] weight
      def initialize(instance, weight: 1)
        @instance = instance
        @weight = weight
        @edges = EDGE_IDS.map { |edge_id|
          TileEdge.new(self, edge_id)
        }
      end

      # @return [Array<Geom::Point3d>]
      def edge_midpoints
        edges.map(&:position)
      end

      # @return [String]
      def to_s
        "TileDefinition(#{object_id})"
      end
      alias inspect to_s

    end # class

  end # module WFC
end # module Examples

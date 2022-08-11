require 'tt_wfc/tile_edge'

module Examples
  module WFC

    class TilePrototype

      # NOTE: It's important the order is clockwise.
      EDGE_IDS = [
        :north, :east, :south, :west
      ]

      # @return [Sketchup::ComponentInstance]
      attr_reader :instance

      # @return [Integer]
      attr_accessor :weight

      # @return [Array<TileEdge>]
      attr_reader :edges

      # @param [Sketchup::ComponentInstance] instance
      # @param [Integer] weight
      def initialize(instance, weight: 1)
        @instance = instance
        @weight = weight
        assets = AssetManager.new(instance.model) # KLUDGE! Circular dependency!
        @edges = EDGE_IDS.map { |edge_id|
          assets.deserialize_tile_edge(self, edge_id)
        }
      end

      # @return [Sketchup::ComponentDefinition]
      def definition
        instance.definition
      end

      # @return [Array<Geom::Point3d>]
      def edge_midpoints
        edges.map(&:position)
      end

      # @return [Geom::Point3d]
      def centroid
        point = Geom::Point3d.new
        edge_midpoints.each { |pt|
          point.offset!(pt.to_a)
        }
        point.x /= 4
        point.y /= 4
        point.z /= 4
        point
      end

      # @return [String]
      def to_s
        "TilePrototype(#{object_id})"
      end
      alias inspect to_s

    end # class

  end # module WFC
end # module Examples

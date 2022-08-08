require 'tt_wfc/constants/boundingbox'

module Examples
  module WFC

    class TileDefinition

      class TileEdge

        include BoundingBoxConstants

        # @return [TileDefinition]
        attr_reader :tile

        # @return [Symbol]
        attr_reader :edge_id

        # @return [String]
        attr_reader :type

        # @param [TileDefinition] tile
        # @param [Symbol] edge_id
        # @param [Geom::Point3d] position
        def initialize(tile, edge_id)
          @tile = tile
          @edge_id = edge_id
          @type = deserialize(tile.instance)
          @position = nil # Lazily computed.
          # Cache what instance transformation was used to compute the position.
          # If this changes the position must be recalculated
          @last_transformation_origin = nil
        end

        def type=(value)
          @type = value
          serialize(tile.instance)
        end

        # @return [Geom::Point3d]
        def position
          if @last_transformation_origin.nil? ||
              @last_transformation_origin != tile.instance.transformation.origin
            @position = edge_position(tile.instance, edge_id)
            @last_transformation_origin = tile.instance.transformation.origin
          end
          @position
        end

        # @return [String]
        def to_s
          "#{@tile}:#{@edge_id}"
        end
        alias inspect to_s

        private

        SECTION_ID = 'tt_wfc'.freeze

        # @param [Sketchup::ComponentInstance] instance
        def serialize(instance)
          instance.definition.set_attribute(SECTION_ID, @edge_id.to_s, @type)
        end

        # @param [Sketchup::ComponentInstance] instance
        def deserialize(instance)
          instance.definition.get_attribute(SECTION_ID, @edge_id.to_s, nil)
        end

        # @param [Sketchup::ComponentInstance] instance
        # @param [Symbol] edge_id
        # @return [Geom::Point3d]
        def edge_position(instance, edge_id)
          bb = instance.bounds
          case edge_id
          when :north
            i1 = BB_LEFT_BACK_BOTTOM
            i2 = BB_RIGHT_BACK_BOTTOM
          when :south
            i1 = BB_LEFT_FRONT_BOTTOM
            i2 = BB_RIGHT_FRONT_BOTTOM
          when :east
            i1 = BB_RIGHT_FRONT_BOTTOM
            i2 = BB_RIGHT_BACK_BOTTOM
          when :west
            i1 = BB_LEFT_FRONT_BOTTOM
            i2 = BB_LEFT_BACK_BOTTOM
          else
            raise "invalid edge ID: #{edge_id}"
          end
          pt1 = bb.corner(i1)
          pt2 = bb.corner(i2)
          pt = Geom.linear_combination(0.5, pt1, 0.5, pt2)
          pt.z = 0.0
          pt
        end

      end

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

require 'tt_wfc/constants/boundingbox'

module Examples
  module WFC

    class TileDefinition

      class ConnectionPoint

        include BoundingBoxConstants

        # @return [TileDefinition]
        attr_reader :tile

        # @return [Symbol]
        attr_reader :connection_id

        # @return [String]
        attr_reader :type

        # @param [TileDefinition] tile
        # @param [Symbol] connection_id
        # @param [Geom::Point3d] position
        def initialize(tile, connection_id)
          @tile = tile
          @connection_id = connection_id
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
            @position = connection_position(tile.instance, connection_id)
            @last_transformation_origin = tile.instance.transformation.origin
          end
          @position
        end

        # @return [String]
        def to_s
          "#{@tile}:#{@connection_id}"
        end
        alias inspect to_s

        private

        SECTION_ID = 'tt_wfc'.freeze

        # @param [Sketchup::ComponentInstance] instance
        def serialize(instance)
          instance.definition.set_attribute(SECTION_ID, @connection_id.to_s, @type)
        end

        # @param [Sketchup::ComponentInstance] instance
        def deserialize(instance)
          instance.definition.get_attribute(SECTION_ID, @connection_id.to_s, nil)
        end

        # @param [Sketchup::ComponentInstance] instance
        # @param [Symbol] connection_id
        # @return [Geom::Point3d]
        def connection_position(instance, connection_id)
          bb = instance.bounds
          case connection_id
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
            raise "invalid connection ID: #{connection_id}"
          end
          pt1 = bb.corner(i1)
          pt2 = bb.corner(i2)
          pt = Geom.linear_combination(0.5, pt1, 0.5, pt2)
          pt.z = 0.0
          pt
        end

      end

      # NOTE: It's important the order is clockwise.
      CONNECTION_IDS = [
        :north, :east, :south, :west
      ]

      # @return [Sketchup::ComponentInstance]
      attr_reader :instance

      # @return [Integer]
      attr_reader :weight

      # @return [Array<TileDefinition::ConnectionPoint>]
      attr_reader :connections

      # @param [Sketchup::ComponentInstance] instance
      # @param [Integer] weight
      def initialize(instance, weight: 1)
        @instance = instance
        @weight = weight
        @connections = CONNECTION_IDS.map { |connection_id|
          ConnectionPoint.new(self, connection_id)
        }
      end

      # @return [Array<Geom::Point3d>]
      def connection_points
        connections.map(&:position)
      end

      # @return [String]
      def to_s
        "TileDefinition(#{object_id})"
      end
      alias inspect to_s

    end # class

  end # module WFC
end # module Examples

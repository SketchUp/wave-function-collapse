require 'tt_wfc/constants/boundingbox'

module Examples
  module WFC

    class Tile

      class ConnectionPoint

        include BoundingBoxConstants

        attr_reader :tile, :connection_id, :position
        attr_reader :type

        # @param [Tile] tile
        # @param [Symbol] connection_id
        # @param [Geom::Point3d] position
        def initialize(tile, connection_id, position)
          @tile = tile
          @connection_id = connection_id
          @position = position

          @type = deserialize(tile.instance)
        end

        def type=(value)
          @type = value
          serialize(tile.instance)
        end

        def to_s
          "#{@tile}:#{@connection_id}"
        end

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

      end

      CONNECTION_IDS = [
        :north, :south, :east, :west
      ]

      attr_reader :instance

      # @param [Sketchup::ComponentInstance] instance
      def initialize(instance)
        @instance = instance
      end

      # @return [Array<Geom::Point3d>]
      def connection_points
        CONNECTION_IDS.map { |connection_id|
          connection_position(@instance, connection_id)
        }
      end

      # @return [Array<Tile::ConnectionPoint>]
      def connections
        CONNECTION_IDS.map { |connection_id|
          pt = connection_position(@instance, connection_id)
          ConnectionPoint.new(self, connection_id, pt)
        }
      end

      def to_s
        "Tile(#{object_id})"
      end

      private

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

    end # class

  end # module WFC
end # module Examples

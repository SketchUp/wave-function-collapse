module Examples
  module WFC

    class Tile

      class RelationShips

        attr_reader :connection_id, :connected

        # @param [Symbol] connection_id
        # @param [Array<Integer>] connected
        def initialize(connection_id, connected)
          @connection_id = connection_id
          @connected = connected
        end

        def add(instance_id)
          @connected << instance_id
        end

        def remove(instance_id)
          @connected.delete(instance_id)
        end

      end # class

      class ConnectionPoint
        attr_reader :tile, :connection_id, :position, :relationships
        # @param [Tile] tile
        # @param [Symbol] connection_id
        # @param [Geom::Point3d] position
        # @param [RelationShips] relationships
        def initialize(tile, connection_id, position, relationships)
          @tile = tile
          @connection_id = connection_id
          @position = position
          @relationships = relationships
        end
      end

      CONNECTION_IDS = [
        :north, :south, :east, :west
      ]

      attr_reader :connections

      # @param [Sketchup::ComponentInstance] instance
      def initialize(instance)
        @instance = instance
        @connections = load_connections(instance)
      end

      # @param [Symbol] connection_id
      # @param [Sketchup::ComponentInstance] other_instance
      # @param [Symbol] other_connection_id
      def connect(connection_id, other_instance, other_connection_id)
        connect_to(connection_id, other_instance, other_connection_id)

        other_tile = Tile.new(other_instance)
        other_tile.connect_to(other_connection_id, @instance, connection_id)
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
          relationships = @connections[connection_id]
          ConnectionPoint.new(self, connection_id, pt, relationships)
        }
      end

      private

      # @param [Symbol] connection_id
      # @param [Sketchup::ComponentInstance] other_instance
      # @param [Symbol] other_connection_id
      def connect_to(connection_id, other_instance, other_connection_id)
        check_connection_id(connection_id)
        check_connection_id(other_connection_id)

        relationships = @connections[connection_id]
        relationships.add(other_instance.persistent_id)

        write_connections_ids(@instance, connection_id, relationships.connected)
        nil
      end

      # @param [Symbol] connection_id
      # @raise [ArgumentError] if `connection_id` is not valid
      def check_connection_id(connection_id)
        raise ArgumentError, "invalid connection ID: #{connection_id}"
      end

      SECTION_ID = 'tt_wfc'.freeze

      # @param [Sketchup::ComponentInstance] instance
      # @return [Hash{Symbol, Connection}]
      def load_connections(instance)
        data = {}
        CONNECTION_IDS.map { |connection_id|
          # position = connection_position(instance, connection_id)
          connections = read_connections_ids(instance, connection_id)
          relationships = RelationShips.new(connection_id, connections)
          data[connection_id] = relationships
        }
        data
      end

      # @param [Sketchup::ComponentInstance] instance
      # @param [Symbol] connection_id
      # @return [Array<Hash{Symbol, Integer}>]
      def read_connections_ids(instance, connection_id)
        instance.get_attribute(SECTION_ID, connection_id.to_s, [])
      end

      # @param [Sketchup::ComponentInstance] instance
      # @param [Array<Hash{Symbol, Integer}>] connections
      def write_connections_ids(instance, connection_id, connections)
        instance.set_attribute(SECTION_ID, connection_id.to_s, connections)
      end

      BB_LEFT_FRONT_BOTTOM = 0
      BB_RIGHT_FRONT_BOTTOM = 1
      BB_LEFT_BACK_BOTTOM = 2
      BB_RIGHT_BACK_BOTTOM = 3

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

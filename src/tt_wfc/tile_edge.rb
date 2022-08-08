require 'tt_wfc/constants/boundingbox'

module Examples
  module WFC

    class TileEdge

      include BoundingBoxConstants

      # @return [TileDefinition]
      attr_reader :tile

      # @return [Symbol] :north, :east, :south, :west
      attr_reader :edge_id

      # @return [String]
      attr_reader :type

      # @param [TileDefinition] tile
      # @param [Symbol] edge_id :north, :east, :south, :west
      # @param [Geom::Point3d] position
      def initialize(tile, edge_id)
        @tile = tile
        @edge_id = edge_id
        @type, @reversed = deserialize(tile.instance)
        deserialize_symmetric # KLUDGE!
        @position = nil # Lazily computed.
        # Cache what instance transformation was used to compute the position.
        # If this changes the position must be recalculated
        @last_transformation_origin = nil
      end

      def type=(value)
        @type = value
        serialize(tile.instance)
        deserialize_symmetric
      end

      def reversed?
        @reversed
      end

      def symmetrical?
        @symmetrical
      end

      def assigned?
        !@type.nil?
      end

      def assign(type:, reversed: false)
        @type = type
        @reversed = reversed
        serialize(tile.instance)
        deserialize_symmetric
      end

      # @param [TileEdge] other
      def can_connect_to?(other)
        if symmetrical?
          type == other.type
        else
          type == other.type && reversed? != other.reversed?
        end
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
      # @param [Boolean] reversed
      def serialize(instance)
        root = instance.definition.attribute_dictionary(SECTION_ID, true)
        dictionary = root.attribute_dictionary(@edge_id.to_s, true)
        dictionary['type'] = @type
        dictionary['reversed'] = @reversed
      end

      # @param [Sketchup::ComponentInstance] instance
      def deserialize(instance)
        root = instance.definition.attribute_dictionary(SECTION_ID, false)
        if root.attribute_dictionaries.nil?
          # Legacy
          # instance.definition.get_attribute(SECTION_ID, @edge_id.to_s, nil)
          warn "Reading legacy data for #{self}"
          type = root[@edge_id.to_s]
          [type, false]
        else
          edge_key = @edge_id.to_s
          type        = root.get_attribute(edge_key, 'type')
          reversed    = root.get_attribute(edge_key, 'reversed', false)
          [type, reversed]
        end
      end

      # @param [Sketchup::ComponentInstance] instance
      # @param [Symbol] edge_id
      # @return [Geom::Point3d]
      def edge_position(instance, edge_id)
        bb = instance.definition.bounds
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
        pt.transform(instance.transformation)
      end

      # KLUDGE! (Dedup)
      ATTR_DICT = 'tt_wfc'
      ATTR_TYPES = 'connection_types'

      # @param [Sketchup::Model] model
      # @return [Array<ConnectionType>]
      def get_connection_types
        # KLUDGE!
        model = Sketchup.active_model
        model.get_attribute(ATTR_DICT, ATTR_TYPES, []).map { |data|
          type_id, color, symmetrical = data
          symmetrical = true if symmetrical.nil?
          # ConnectionType.new(type_id, color, symmetrical)
          [type_id, color, symmetrical]
        }
      end

      def deserialize_symmetric
        # KLUDGE!
        type_id, color, symmetrical = get_connection_types.find { |t| t[0] == type }
        @symmetrical = symmetrical
      end

    end

  end # module WFC
end # module Examples

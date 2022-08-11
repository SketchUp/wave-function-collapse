require 'tt_wfc/constants/boundingbox'

module Examples
  module WFC

    class TileEdge

      include BoundingBoxConstants

      # @return [TilePrototype]
      attr_reader :tile

      # @return [Symbol] `:north`, `:east`, `:south`, `:west`
      attr_reader :edge_id

      # @return [EdgePrototype, nil]
      attr_accessor :prototype

      # @return [Boolean]
      attr_writer :reversed

      # @param [TilePrototype] tile
      # @param [Symbol] edge_id :north, :east, :south, :west
      def initialize(tile, edge_id)
        @tile = tile
        @edge_id = edge_id
        @prototype = nil # @type [EdgePrototype, nil]
        @reversed = false

        @position = nil # Lazily computed.
        # Cache what instance transformation was used to compute the position.
        # If this changes the position must be recalculated
        @last_transformation_origin = nil
      end

      # @return [String]
      def type_id
        prototype&.type_id
      end

      # @return [String]
      def type
        warn "deprecated #{self}#type"
        prototype&.type_id
      end

      def reversed?
        @reversed
      end

      def symmetrical?
        prototype.nil? || prototype.symmetrical
      end

      def assigned?
        !@prototype.nil?
      end

      # @param [TileEdge] other
      def can_connect_to?(other)
        if symmetrical?
          prototype == other.prototype
        else
          prototype == other.prototype && reversed? != other.reversed?
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

    end

  end # module WFC
end # module Examples

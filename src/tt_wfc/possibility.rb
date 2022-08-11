module Examples
  module WFC

    Possibility = Struct.new(:prototype, :edges, :transformation) do

      # @return [Integer]
      def weight
        prototype.weight
      end

    end
    # @!parse
    #   class Possibility
    #     # @return [TilePrototype]
    #     attr_accessor :prototype
    #
    #     # @return [Array<TileEdge>]
    #     attr_accessor :edges
    #
    #     # @return [Geom::Transformation]
    #     attr_accessor :transformation
    #   end

  end
end

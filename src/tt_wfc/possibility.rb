module Examples
  module WFC

    Possibility = Struct.new(:prototype, :edges, :transformation) do

      def weight
        prototype.weight
      end

    end
    # @!parse
    #   class Possibility
    #     attr_accessor :prototype, :edges, :transformation
    #   end

  end
end

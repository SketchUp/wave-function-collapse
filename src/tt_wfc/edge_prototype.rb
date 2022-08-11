module Examples
  module WFC

    EdgePrototype = Struct.new(:type_id, :color, :symmetrical)
    # @!parse
    #   class EdgePrototype
    #     # @return [String]
    #     attr_accessor :type_id
    #
    #     # @return [String]
    #     attr_accessor :color
    #
    #     # @return [Boolean]
    #     attr_accessor :symmetrical
    #   end

  end
end

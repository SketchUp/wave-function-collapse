module Examples
  module WFC

    class TileQueue

      def initialize
        @set = Set.new
      end

      # @param [Object]
      # @return [Boolean]
      def push(value)
        return false if @set.include?(value)

        @set.add(value)
        true
      end

      # @return [Object]
      def pop
        item = @set.min { |a, b| a.entropy <=> b.entropy }
        @set.delete(item)
        item
      end

      # @param [Enumerable]
      def insert(values)
        values.each { |value| push(value) }
      end

      def empty?
        @set.empty?
      end

      # @return [Integer]
      def size
        @set.size
      end
      alias :length :size

    end

  end
end

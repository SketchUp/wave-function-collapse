module Examples
  module WFC

    class UniqQueue

      def initialize
        @queue = Queue.new
        @set = Set.new
      end

      # @param [Object]
      # @return [Boolean]
      def push(value)
        return false if @set.include?(value)

        @queue.push(value)
        @set.add(value)
        true
      end

      # @return [Object]
      def pop
        item = @queue.pop
        @set.delete(item)
        item
      end

      # @param [Enumerable]
      def insert(values)
        values.each { |value| push(value) }
      end

      def empty?
        @queue.empty?
      end

      # @return [Integer]
      def size
        @queue.size
      end
      alias :length :size

    end

  end
end

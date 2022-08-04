require 'tt_wfc/tile'
require 'tt_wfc/uniq_queue'

module Examples
  module WFC

    class WorldGenerator

      # @return [Integer]
      attr_reader :width, :height

      # @return [Array<TileDefinition>] definitions
      attr_reader :definitions

      # @return [Float]
      attr_reader :speed

      # @param [Integer] width
      # @param [Integer] height
      # @param [Array<TileDefinition>] definitions
      def initialize(width, height, definitions)
        @width = width
        @height = height
        @definitions = definitions # Tile Definitions
        @state = nil
        @timer = nil
        @speed = 0.1 # seconds
      end

      # @return [void]
      def run
        model = Sketchup.active_model
        # Not disabling UI because this will be a "long operation" that uses a
        # timer for the main loop.
        model.start_operation('Generate World') # rubocop:disable SketchupPerformance/OperationDisableUI
        tiles = setup(model)
        @state = State.new(tiles, UniqQueue.new)
        resume
      end

      def stop
        pause
        @state = nil
        Sketchup.active_model.commit_operation
      end

      def stopped?
        @state.nil?
      end

      def paused?
        @timer.nil?
      end

      def pause
        UI.stop_timer(@timer) if @timer
        @timer = nil
      end

      def resume
        # TODO: Don't resume if not complete.
        raise 'already running' if @timer
        @timer = UI.start_timer(speed, true, &method(:update))
      end

      def update
        puts 'update...'
        if state.stack.empty?
          unresolved = state.tiles.reject(&:resolved?)
          if unresolved.empty?
            puts 'complete!'
            stop
            return
          end

          touched = unresolved.reject(&:untouched?)
          if touched.empty?
            tile = unresolved.sample
          else
            tile = touched.min { |a, b| a.entropy <=> b.entropy }
          end
        else
          tile = state.stack.pop
        end
        solve_tile(tile)
      end

      private

      State = Struct.new(:tiles, :stack)
      # @!parse
      #   class State
      #     attr_accessor :tiles, :stack
      #   end

      # @return [State]
      attr_reader :state

      # @param [Tile]
      def solve_tile(tile)
        raise 'already resolved' if tile.resolved?

        definition = tile.possibilities.sample
        tile.resolve_to(definition)
        # TODO: update possibilities of neighbors
        unresolved = neighbors(tile).reject(&:resolved?)
        state.stack.insert(unresolved)
      end

      # @param [Tile]
      # @return [Array<Tile>]
      def neighbors(tile)
        positions = [
          tile.position.offset([-1,  0]),
          tile.position.offset([ 0, -1]),
          tile.position.offset([ 1,  0]),
          tile.position.offset([ 0,  1]),
        ]
        positions.map { |position| tile_at(position) }.compact
      end

      # @param [Geom::Point3d] position
      # @return [Tile]
      def tile_at(position)
        return nil if position.x < 0
        return nil if position.y < 0
        return nil if position.x >= width
        return nil if position.y >= height

        index = (width * position.y) + position.x
        state.tiles[index]
      end

      # @param [Sketchup::Model] model
      # @return [Array<Tile>]
      def setup(model)
        placeholder = generate_placeholder(model)
        instances = generate_instance_grid(model, placeholder)
        instances.map.with_index { |instance, i|
          Tile.new(self, instance, i)
        }
      end

      # @param [Sketchup::Model] model
      # @return [Sketchup::ComponentDefinition]
      def generate_placeholder(model)
        definition = model.definitions.add('WFC Placeholder')
        points = [
          Geom::Point3d.new(-0.5.m, -0.5.m, 0),
          Geom::Point3d.new( 0.5.m, -0.5.m, 0),
          Geom::Point3d.new( 0.5.m,  0.5.m, 0),
          Geom::Point3d.new(-0.5.m,  0.5.m, 0),
        ]
        face = definition.entities.add_face(points)
        face.reverse! if face.normal.samedirection?(Z_AXIS.reverse)
        face.material = 'pink'
        face.back_material = 'purple'
        definition
      end

      # @param [Sketchup::Model] model
      # @param [Sketchup::ComponentDefinition] placeholder
      # @return [Array<Sketchup::ComponentInstance>]
      def generate_instance_grid(model, placeholder)
        size = 1.m
        offset = size / 2

        instances = []
        group = model.entities.add_group
        group.transform!(Geom::Vector3d.new(0, 0, 1.m))
        width.times { |x|
          height.times { |y|
            point = Geom::Point3d.new((x * size) + offset, (y * size) + offset, 0)
            tr = Geom::Transformation.translation(point)
            instances << group.entities.add_instance(placeholder, tr)
          }
        }
        instances
      end

    end

  end
end

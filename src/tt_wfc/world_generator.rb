require 'tt_wfc/tile'
require 'tt_wfc/uniq_queue'

module Examples
  module WFC

    Possibility = Struct.new(:definition, :edges, :transformation)

    class WorldGenerator

      # @return [Integer]
      attr_reader :width, :height

      # @return [Array<TileDefinition>]
      attr_reader :definitions

      # @return [Array<Possibility>]
      attr_reader :possibilities

      # @return [Float]
      attr_reader :speed

      # @param [Integer] width
      # @param [Integer] height
      # @param [Array<TileDefinition>] definitions
      def initialize(width, height, definitions)
        @width = width
        @height = height
        @definitions = definitions # Tile Definitions
        @possibilities = generate_possibilities(definitions)
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
        raise 'generator is done' if stopped?
        raise 'already running' if @timer
        @timer = UI.start_timer(speed, true, &method(:update))
      end

      def update
        # puts 'update...'
        if state.stack.empty?
          unresolved = state.tiles.reject(&:resolved?)
          if unresolved.empty?
            puts 'Generation complete!'
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

        possibility = tile.possibilities.sample
        tile.resolve_to(possibility)
        unresolved = neighbors(tile).reject(&:resolved?)

        unresolved.each { |neighbor|
          constrain_possibilities(neighbor)
        }
        unresolved.reject!(&:resolved?) # Reject newly solved tiles

        state.stack.insert(unresolved)
      end

      # @param [Tile]
      def constrain_possibilities(tile)
        constrainers = neighbors(tile).reject(&:untouched?)
        constrainers.each { |constrainer|
          i1 = tile.edge_index_to_neighbor(constrainer)
          i2 = constrainer.edge_index_to_neighbor(tile)

          invalid = tile.possibilities.reject { |possibility|
            constrainer.possibilities.any? { |cp|
              possibility.edges[i1] == cp.edges[i2]
            }
          }
          tile.remove_possibilities(invalid)
        }
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
        # face.material = 'pink'
        # face.back_material = 'purple'
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
            instance = group.entities.add_instance(placeholder, tr)
            instance.material = 'purple'
            instances << instance
          }
        }
        instances
      end

      # @param [Array<TileDefinition>] definitions
      def generate_possibilities(definitions)
        result = []
        definitions.each { |definition|
          edges = definition.connections.map(&:type)
          4.times { |i|
            # :north, :east, :south, :west
            # --------------------
            # edges = [n, e, s, w]
            # tr = 0
            # --------------------
            # edges = [e, s, w, n]
            # tr = -90
            # --------------------
            # edges = [s, w, n, e]
            # tr = -180
            # --------------------
            # edges = [w, n, e, s]
            # tr = -270
            tr = Geom::Transformation.rotation(ORIGIN, Z_AXIS, 90.degrees * -i)
            result << Possibility.new(definition, edges.rotate(i), tr)
          }
        }
        result
      end

    end

  end
end

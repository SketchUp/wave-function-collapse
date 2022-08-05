require 'tt_wfc/tile'
require 'tt_wfc/tile_queue'

module Examples
  module WFC

    Possibility = Struct.new(:definition, :edges, :transformation)
    # @!parse
    #   class Possibility
    #     attr_accessor :definition, :edges, :transformation
    #   end

    class WorldGenerator

      # @return [Integer]
      attr_reader :width, :height

      # @return [Array<TileDefinition>]
      attr_reader :definitions

      # @return [Array<Possibility>]
      attr_reader :possibilities

      # @return [Float]
      attr_reader :speed

      # @return [State]
      attr_reader :state

      # @return [Integer]
      attr_reader :seed

      # @param [Integer] width
      # @param [Integer] height
      # @param [Array<TileDefinition>] definitions
      # @param [Integer] seed
      def initialize(width, height, definitions, seed: nil)
        @seed = seed || Random.new_seed
        @random = Random.new(@seed)
        @width = width
        @height = height
        @definitions = definitions # Tile Definitions
        @possibilities = generate_possibilities(definitions)
        @materials = generate_entropy_materials(@possibilities.size)
        @state = nil
        @timer = nil

        # Sketchup.write_default('TT_WFC', 'Speed', 0.01)
        @speed = Sketchup.read_default('TT_WFC', 'Speed', 0.1) # seconds

        # Sketchup.write_default('TT_WFC', 'Log', true)
        @log = Sketchup.read_default('TT_WFC', 'Log', false)
      end

      # @param [Boolean] start_paused
      # @return [void]
      def run(start_paused: false)
        model = Sketchup.active_model
        # Not disabling UI because this will be a "long operation" that uses a
        # timer for the main loop.
        model.start_operation('Generate World') # rubocop:disable SketchupPerformance/OperationDisableUI
        tiles = setup(model)
        @state = State.new(tiles, TileQueue.new, :running)
        start_paused ? pause : resume
      end

      def stop
        pause
        @state.status = :stopped if @state
        Sketchup.active_model.commit_operation
      end

      def running?
        @state && @state.status == :running
      end

      def stopped?
        @state && @state.status == :stopped
      end

      def paused?
        @state && @state.status == :paused
      end

      def pause
        UI.stop_timer(@timer) if @timer
        @timer = nil
        @state.status = :paused if @state
      end

      def resume
        raise 'generator is done' if stopped?
        raise 'already running' if @timer
        if speed > 0.0
          @timer = UI.start_timer(speed, true, &method(:update))
        else
          model = Sketchup.active_model
          # Because this isn't done in a timer we can disable the UI and get
          # more performance out of the operation.
          model.commit_operation
          model.start_operation('WFC Turbo', true, false, true)
          # Fast iteration. A timer at 0.0 will be slower than a normal loop.
          t = Time.now
          until stopped?
            update
          end
          elapsed = Time.now - t
          SKETCHUP_CONSOLE.show # TODO: Debug - remove after proper log control.
          puts "Elapsed time: #{elapsed.round(4)} seconds"
        end
      end

      def update
        log { '' }
        log { 'Update...' }
        if state.queue.empty?
          unresolved = state.tiles.reject(&:resolved?)
          if unresolved.empty?
            log { 'Generation complete!' }
            stop
            return
          end

          touched = unresolved.reject(&:untouched?)
          if touched.empty?
            tile = sample(unresolved)
          else
            tile = touched.min { |a, b| a.entropy <=> b.entropy }
          end
        else
          tile = state.queue.pop
        end
        solve_tile(tile)
      rescue
        pause
        raise
      end

      # @param [Integer] entropy
      # @return [Sketchup::Material]
      def material_from_entropy(entropy)
        max = @possibilities.size
        ratio = entropy.to_f / max.to_f
        i = ((@materials.size - 1) * ratio).to_i
        # p [:entropy, entropy, :max, max, :ratio, ratio, :i, i, @materials[i].name, @materials[i].color.to_a]
        @materials[i]
      end

      private

      STATUSES = [:running, :paused, :stopped]

      State = Struct.new(:tiles, :queue, :status)
      # @!parse
      #   class State
      #     attr_accessor :tiles, :queue, :status
      #   end

      # @param [Tile]
      def solve_tile(tile)
        raise 'already resolved' if tile.resolved?

        possibility = sample(tile.possibilities)
        log { "Sampled #{tile} for #{tile.possibilities.size} possibilities." }
        tile.resolve_to(possibility)
        unresolved = neighbors(tile).reject(&:resolved?)
        unresolved = sort_by_entropy(unresolved)

        unresolved.each { |neighbor|
          constrain_possibilities(neighbor)
        }
        unresolved.reject!(&:resolved?) # Reject newly solved tiles

        state.queue.insert(unresolved)
      end

      # @param [Enumerable] enumerable
      # @param [Object]
      def sample(enumerable)
        index = @random.rand(enumerable.size)
        enumerable[index]
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
          before = tile.possibilities.size
          tile.remove_possibilities(invalid)
          log { "Restrained #{tile} by #{invalid.size} possibilities (#{before} to #{tile.possibilities.size})." } unless invalid.empty?
        }
      end

      # @param [Array<Tile>] tiles
      def sort_by_entropy(tiles)
        tiles.sort { |a, b| a.entropy <=> b.entropy }
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

      # @param [Integer] max_entropy
      # @param [Integer] steps Number of materials to generate.
      # @return [Array<Sketchup::Material>]
      def generate_entropy_materials(max_entropy, steps = 10)
        model = Sketchup.active_model
        # Discard old materials.
        existing = model.materials.select { |material|
          material.get_attribute('tt_wfc', 'entropy', false)
        }
        existing.each { |material|
          model.materials.remove(material)
        }
        # Generate new materials.
        step_range = max_entropy / steps
        resolved_color = Sketchup::Color.new('white')
        unresolved_color = Sketchup::Color.new('orange')
        steps.times.map { |i|
          min = step_range * i
          max = min + step_range
          weight = i.to_f / steps.to_f
          material = model.materials.add("WCF Entropy (#{min}-#{max})")
          material.color = resolved_color.blend(unresolved_color, weight)
          material.set_attribute('tt_wfc', 'entropy', [min, max])
          material
        }
      end

      def log
        puts yield if @log
      end

    end

  end
end

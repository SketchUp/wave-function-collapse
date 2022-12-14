require 'tt_wfc/possibility'
require 'tt_wfc/tile'
require 'tt_wfc/tile_queue'

module Examples
  module WFC

    class WorldGenerator

      STATUSES = [:running, :paused, :stopped]

      State = Struct.new(:tiles, :queue, :status)
      # @!parse
      #   class State
      #     # @return [Array<Tile>]
      #     attr_accessor :tiles
      #
      #     # @return [TileQueue]
      #     attr_accessor :queue
      #
      #     # @return [Symbol]
      #     attr_accessor :status
      #   end

      # @return [Integer]
      attr_reader :width, :height

      # @return [Array<TilePrototype>]
      attr_reader :prototypes

      # @return [Array<Possibility>]
      attr_reader :possibilities

      # @return [Float]
      attr_reader :speed

      # @return [State]
      attr_reader :state

      # @return [Integer]
      attr_reader :seed

      # @return [Float]
      attr_reader :speed

      # @overload break_at_iteration=(value)
      # @param [Boolean] value
      attr_writer :break_at_iteration

      # @param [Integer] width
      # @param [Integer] height
      # @param [Array<TilePrototype>] prototypes
      # @param [Integer] seed
      # @param [Float] speed
      # @param [Boolean] break_at_iteration
      # @param [Boolean] log
      def initialize(width, height, prototypes,
          seed: nil,
          speed: 0.1,
          break_at_iteration: false,
          log: false
        )
        @log = log
        @seed = seed || Random.new_seed
        @random = Random.new(@seed)
        @width = width
        @height = height
        @speed = speed # seconds
        @break_at_iteration = break_at_iteration
        @possibilities = generate_possibilities(prototypes)
        @materials = generate_entropy_materials(@possibilities.size)
        @state = nil
        @timer = nil
      end

      # @return [void]
      def run
        model = Sketchup.active_model
        # Not disabling UI because this will be a "long operation" that uses a
        # timer for the main loop.
        model.start_operation('Generate World') # rubocop:disable SketchupPerformance/OperationDisableUI
        tiles = setup(model)
        @state = State.new(tiles, TileQueue.new, :running)
        break_at_iteration? ? pause : resume
      end

      def break_at_iteration?
        @break_at_iteration
      end

      # @return [void]
      def stop
        pause
        state.status = :stopped if state
        Sketchup.active_model.commit_operation
      end

      def running?
        state && state.status == :running
      end

      def stopped?
        state && state.status == :stopped
      end

      def paused?
        state && state.status == :paused
      end

      # @return [void]
      def pause
        UI.stop_timer(@timer) if @timer
        @timer = nil
        state&.status = :paused
      end

      # @param [Float] value
      def speed=(value)
        was_running = running?
        pause if was_running
        @speed = value
        resume if was_running
      end

      # @return [void]
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
        state&.status = :running
      end

      # @return [void]
      def update
        log { '' }
        log { 'Update...' }
        if state.queue.empty?
          # All waves from previous resolve is processed. Pick a new tile.
          log { '> Pick new...' }
          unresolved = state.tiles.reject(&:resolved?)
          if unresolved.empty?
            log { 'Generation complete!' }
            stop
            return
          end

          touched = unresolved.reject(&:untouched?)
          if touched.empty?
            # First time picking a tile, pick one at random.
            # Can this be done as part of setup? (Avoid this branch)
            log { '> Sample random...' }
            tile = sample(unresolved)
          else
            # Pick the tile with least entropy, as that will increase the chance
            # of successfully solving the tile.
            log { '> Pick by least entropy...' }
            # tile = touched.min { |a, b| a.entropy <=> b.entropy }
            tile = sample_by_least_entropy(state.tiles)
          end
          solve_tile(tile)
        else
          # This is the wave propagation branch.
          log { '> Next in queue...' }
          tile = state.queue.pop # TODO: Use least entropy like above?
          propagate(tile)
        end
        tick
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
        @materials[i]
      end

      def to_s
        "#{self.class}(#{state&.status || 'initial'}, #{width}x#{height}, seed: #{seed})"
      end
      alias inspect to_s

      private

      # @param [Tile] tile
      # @return [void]
      def solve_tile(tile)
        # If a tile was resolved as a result of constraints it's neighbors needs
        # to be processed.
        unless tile.resolved?
          possibility = weighted_sample(tile.possibilities)
          log { "Sampled #{tile} for #{tile.possibilities.size} possibilities. (#{tile.instance.persistent_id})" }
          tile.resolve_to(possibility)
        end
        propagate(tile)
      end

      # @param [Tile] tile
      # @return [void]
      def propagate(tile)
        # Once a tile is resolved all it's neighbors needs to be evaluated.
        # If any of those change their neighbors also needs to be evaluated.
        # The unresolved neighbors are constrained in the order of least
        # entropy in order to increase the chance of being able to resolve
        # a solution.
        unresolved = neighbors(tile).reject(&:resolved?)
        unresolved = sort_by_entropy(unresolved)

        log { "#{tile} unresolved neighbors: #{unresolved}" }

        # Any modified neighboring tiles must be put into the queue for
        # evaluation.
        modified = unresolved.select { |neighbor|
          constrain_possibilities(neighbor) > 0
        }
        state.queue.insert(modified)
      end

      # @param [Enumerable] enumerable
      # @return [Object]
      def sample(enumerable)
        index = @random.rand(enumerable.size)
        enumerable[index]
      end

      # @param [Enumerable] enumerable
      # @return [Object]
      def weighted_sample(enumerable)
        # https://github.com/robert/wavefunction-collapse/blob/21b2e5d95ec7db6057382bfb61ba4557cdd436f4/main.py#L258
        sum_weight = enumerable.sum(&:weight)
        value = @random.rand(sum_weight)
        enumerable.find { |n|
          value -= n.weight
          value < 0
        }
      end

      # @param [Array<Tile>] tiles
      # @return [Tile]
      def sample_by_least_entropy(tiles)
        unresolved = tiles.select(&:unresolved?)
        cache = unresolved.map { |tile|
          e = shannon_entropy(tile.possibilities)
          [tile, e]
        }.sort { |a, b| a[1] <=> b[1] }
        # 0 = tile
        # 1 = weight
        # cache.min { |a, b| a[1] <=> b[1] }
        # In case there are multiple with equal minimal entropy, add some
        # randomness to it so it's not based on order in the collection.
        # Using the collection order means there's a bias to the position of
        # the tile.
        tile, entropy = cache.first
        options = cache.take_while { |t, e| e == entropy }
        sample(options.map(&:first))
      end

      # @param [Enumerable] enumerable
      # @return [Float]
      def shannon_entropy(enumerable)
        # https://robertheaton.com/2018/12/17/wavefunction-collapse-algorithm/
        # https://github.com/robert/wavefunction-collapse
        #
        # Sums are over the weights of each remaining
        # allowed tile type for the square whose
        # entropy we are calculating.
        #     shannon_entropy_for_square =
        #       log(sum(weight)) -
        #       (sum(weight * log(weight)) / sum(weight))
        #
        # https://github.com/mxgmn/WaveFunctionCollapse/blob/a6f79f0f1a4220406220782b71d3fcc73a24a4c2/Model.cs#L55-L67
        sum_weight = enumerable.sum(&:weight).to_f
        sum_times_log_weight = enumerable.sum { |n| n.weight * Math.log(n.weight) }
        sum_weight - (sum_times_log_weight / sum_weight)
      end

      # @param [Tile] tile
      # @return [Integer] number of possibilities constrained
      def constrain_possibilities(tile)
        constrained = 0
        constrainers = neighbors(tile).reject(&:untouched?)
        constrainers.each { |constrainer|
          i1 = tile.edge_index_to_neighbor(constrainer)
          i2 = constrainer.edge_index_to_neighbor(tile)

          invalid = tile.possibilities.reject { |possibility|
            constrainer.possibilities.any? { |cp|
              possibility.edges[i1].can_connect_to?(cp.edges[i2])
            }
          }
          before = tile.possibilities.size
          tile.remove_possibilities(invalid)
          log { "Restrained #{tile} by #{invalid.size} possibilities (#{before} to #{tile.possibilities.size})." } unless invalid.empty?
          constrained += invalid.size
        }
        constrained
      end

      # @param [Array<Tile>] tiles
      # @return [Array<Tile>]
      def sort_by_entropy(tiles)
        tiles.sort { |a, b| a.entropy <=> b.entropy }
      end

      # @param [Tile] tile
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
        x, y = position.to_a.take(2).map(&:to_i)
        return nil if x < 0
        return nil if y < 0
        return nil if x >= width
        return nil if y >= height

        index = (width * y) + x
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

      # @return [void]
      def tick
        if break_at_iteration?
          if state.queue.empty?
            pause
          else
            resume if @timer.nil?
          end
        end
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
          # TODO: Refactor attributes to AssetManager.
        group.set_attribute('tt_wfc', 'size', [width, height])
        group.set_attribute('tt_wfc', 'seed', seed.to_s) # Number can be too big!
        group.transform!(Geom::Vector3d.new(0, 0, 1.m))
        height.times { |y|
          width.times { |x|
            point = Geom::Point3d.new((x * size) + offset, (y * size) + offset, 0)
            tr = Geom::Transformation.translation(point)
            instance = group.entities.add_instance(placeholder, tr)
            instance.set_attribute('tt_wfc', 'position', [x, y])
            instance.set_attribute('tt_wfc', 'index', (y * width) + x)
            instance.material = 'purple'
            instances << instance
          }
        }
        instances
      end

      # @param [Array<TilePrototype>] prototypes
      # @return [Array<Possibility>]
      def generate_possibilities(prototypes)
        result = []
        prototypes.each { |prototype|
          edges = prototype.edges.dup
          4.times { |i|
            # :north, :east, :south, :west
            # --------------------
            # edges = [n, e, s, w]
            # tr = 0
            # --------------------
            # edges = [e, s, w, n]
            # tr = 90
            # --------------------
            # edges = [s, w, n, e]
            # tr = 180
            # --------------------
            # edges = [w, n, e, s]
            # tr = 270
            tr = Geom::Transformation.rotation(ORIGIN, Z_AXIS, 90.degrees * i)
            result << Possibility.new(prototype, edges.rotate(i), tr)
          }
        }
        result
      end

      # @param [Integer] max_entropy
      # @param [Integer] steps Number of materials to generate.
      # @return [Array<Sketchup::Material>]
      def generate_entropy_materials(max_entropy, steps = 10)
        model = Sketchup.active_model
        # TODO: Refactor attributes to AssetManager.
        # Discard old materials.
        existing = model.materials.select { |material|
          material.get_attribute('tt_wfc', 'entropy', false)
        }
        existing.each { |material|
          model.materials.remove(material)
        }
        # Generate new materials.
        step_range = max_entropy / steps
        resolved_color = Sketchup::Color.new('purple')
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

      # @return [void]
      def log
        puts yield if @log
      end

    end

  end
end

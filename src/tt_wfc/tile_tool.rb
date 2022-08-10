require 'tt_wfc/constants/view'
require 'tt_wfc/asset_manager'
require 'tt_wfc/edge_prototype'
require 'tt_wfc/tile_edge'
require 'tt_wfc/tile_prototype'

module Examples
  module WFC

    class TileTool

      include ViewConstants

      APERTURE = 10 # pixels (pick aperture)

      DRAG_THRESHOLD = 2 # pixels

      def initialize
        @tiles = load_tiles

        # @type [Set<TileEdge>]
        @selection = Set.new

        # @type [TileEdge, nil]
        @mouse_over = nil

        # @type [Geom::Point3d, nil]
        @mouse_position = nil

        # @type [Geom::Point3d, nil]
        @mouse_left_button_down = nil

        @mouse_drag = false
      end

      def activate
        Sketchup.active_model.active_view.invalidate
      end

      # @param [Sketchup::View] view
      def deactivate(view)
        view.invalidate
      end

      # @param [Sketchup::View] view
      def suspend(view)
        view.invalidate
      end

      # @param [Sketchup::View] view
      def resume(view)
        view.invalidate
      end

      # @param [Integer] flags
      # @param [Integer] x
      # @param [Integer] y
      # @param [Sketchup::View] view
      def onMouseMove(flags, x, y, view)
        @mouse_position = Geom::Point3d.new(x, y)
        @mouse_over = pick_edge(view, x, y)

        type = @mouse_over ? @mouse_over.type || '<unassigned>' : nil

        if type
          tooltip = "Type: #{type}"
          unless @mouse_over.symmetrical?
            tooltip << ", Asymmetrical"
            tooltip << " (Reversed)" if @mouse_over.reversed?
          end
          view.tooltip = tooltip
        end

        view.invalidate
      end

      # @param [Integer] flags
      # @param [Integer] x
      # @param [Integer] y
      # @param [Sketchup::View] view
      def onLButtonDown(flags, x, y, view)
        @mouse_left_button_down = Geom::Point3d.new(x, y)
        @mouse_drag = false

        select_edge(flags, x, y, view)
        view.invalidate
      end

      # @param [Integer] flags
      # @param [Integer] x
      # @param [Integer] y
      # @param [Sketchup::View] view
      def onLButtonUp(flags, x, y, view)
        @mouse_left_button_down = nil
        @mouse_drag = false
        view.invalidate
      end

      # @param [Integer] flags
      # @param [Integer] x
      # @param [Integer] y
      # @param [Sketchup::View] view
      def getMenu(menu, flags, x, y, view)
        tile = pick_tile(view, x, y)
        if tile
          menu.add_item('Assign Tile Weight') do
            prompt_assign_tile_weight(tile)
          end
          menu.add_separator
        end
        unless @selection.empty?
          menu.add_item('Assign Edge Type') do
            prompt_assign_connection_type_to_selection
          end
          menu.add_separator
        end
        menu.add_item('Add Edge Type') do
          prompt_add_connection_type
        end
        menu.add_item('Remove Edge Type') do
          prompt_remove_connection_type
        end
        menu.add_item('Edit Edge Type') do
          prompt_edit_connection_type
        end
      end

      # @param [Sketchup::View] view
      def draw_symmetry_annotation(view, points, reversed, size)
        return if points.empty?

        half = size / 2
        symbol_points = if reversed
          # ¡
          [
            Geom::Point3d.new(0, -half, 0),
            Geom::Point3d.new(0, -half+2, 0),
            Geom::Point3d.new(0, -half+3, 0),
            Geom::Point3d.new(0, half, 0),
          ]
        else
          # !
          [
            Geom::Point3d.new(0, -half, 0),
            Geom::Point3d.new(0, half-3, 0),
            Geom::Point3d.new(0, half-2, 0),
            Geom::Point3d.new(0, half, 0),
          ]
        end
        offset = Geom::Point3d.new(-(half + 3), 0, 0) # (12 / 2) - 3
        pts = points.flat_map { |point|
          x, y, z = view.screen_coords(point).to_a.map(&:to_i)
          screen_pt = Geom::Point3d.new(x, y, z)
          tr = Geom::Transformation.new(screen_pt + offset.to_a)
          symbol_points.map { |pt| pt.transform(tr) }
        }
        view.drawing_color = 'black'
        view.line_width = 2
        view.line_stipple = ''
        view.draw2d(GL_LINES, pts)
      end

      # @param [Sketchup::View] view
      # @param [Array<Tile>] tiles
      def draw_weights(view, tiles)
        weighted = tiles.select { |tile| tile.weight > 1 }
        options = {
          bold: true,
          size: 8,
          align: TextAlignCenter,
          vertical_align: TextVerticalAlignCenter,
          color: 'white',
        }
        weighted.each { |tile|
          point = view.screen_coords(tile.centroid)
          text = "#{tile.weight}"
          bounds = view.text_bounds(point, text, options)
          x1, y1 = bounds.upper_left.to_a
          x2, y2 = bounds.lower_right.to_a
          x1 -= 1
          # x2 += 1
          pts = [
            Geom::Point3d.new(x1, y2),
            Geom::Point3d.new(x2, y2),
            Geom::Point3d.new(x2, y1),
            Geom::Point3d.new(x1, y1),
          ]
          view.drawing_color = 'black'
          view.draw2d(GL_QUADS, pts)
          view.draw_text(point, text, options)
        }
      end

      # @param [Sketchup::View] view
      def draw(view)
        view.line_stipple = ''

        draw_weights(view, @tiles)

        # Draw edges points.
        # (Backgrounds)
        assigned, unassigned = @tiles.flat_map(&:edges).partition(&:assigned?)
        symmetrical, asymmetrical = assigned.partition(&:symmetrical?)
        sym_points = symmetrical.flat_map(&:position)
        reversed, not_reversed = asymmetrical.partition(&:reversed?)
        ntr_points = not_reversed.flat_map(&:position)
        rev_points = reversed.flat_map(&:position)
        ass_points = assigned.flat_map(&:position)
        una_points = unassigned.flat_map(&:position)
        view.line_width = 2
        view.draw_points(ass_points, 12, DRAW_FILLED_SQUARE, 'black') unless ass_points.empty?
        view.draw_points(una_points, 12, DRAW_FILLED_SQUARE, 'red') unless una_points.empty?
        draw_symmetry_annotation(view, ntr_points, false, 12)
        draw_symmetry_annotation(view, rev_points, true, 12)
        # (Cross-hairs)
        view.line_width = 2
        connection_types = get_connection_types(view.model)
        connection_colors = Hash[connection_types.map { |t| [t.type_id, t.color] }]
        edges = @tiles.flat_map(&:edges)
        edges.sort_by { |c| c.type || '' }.chunk { |c| c.type || '' }.each { |type_id, items|
          color = connection_colors[type_id] || 'white'
          pts = items.map(&:position)
          view.draw_points(pts, 10, DRAW_PLUS, color)
        }

        # Draw selected connection point.
        unless @selection.empty?
          selected = @selection.map(&:position)
          view.line_width = 2
          view.draw_points(selected, 12, DRAW_OPEN_SQUARE, 'red')
        end

        # Draw moused over connection point.
        if @mouse_over
          view.line_width = 2
          view.draw_points([@mouse_over.position], 12, DRAW_OPEN_SQUARE, 'orange')
        end

        # Draw mouse drag
        if @mouse_position && @mouse_left_button_down && @mouse_drag
          points = [@mouse_left_button_down, @mouse_position]
          view.line_width = 1
          view.line_stipple = '-'
          view.drawing_color = 'purple'
          view.draw2d(GL_LINE_STRIP, points)
        end
      end

      private

      SELECT_SINGLE = 0
      SELECT_ADD = 1
      SELECT_REMOVE = 2
      SELECT_TOGGLE = 3

      # @param [Integer] flags
      # @return [Integer]
      def selection_state(flags)
        if flags.allbits?(COPY_MODIFIER_MASK | CONSTRAIN_MODIFIER_MASK)
          SELECT_REMOVE
        elsif flags.allbits?(COPY_MODIFIER_MASK)
          SELECT_ADD
        elsif flags.allbits?(CONSTRAIN_MODIFIER_MASK)
          SELECT_TOGGLE
        else
          SELECT_SINGLE
        end
      end

      # @param [Integer] flags
      # @param [Integer] x
      # @param [Integer] y
      # @param [Sketchup::View] view
      def select_edge(flags, x, y, view)
        picked = pick_edge(view, x, y)
        selection_type = selection_state(flags)
        @selection.clear if selection_type == SELECT_SINGLE
        return if picked.nil?

        case selection_type
        when SELECT_SINGLE
          @selection.clear
          @selection.add(picked)
        when SELECT_ADD
          @selection.add(picked)
        when SELECT_REMOVE
          @selection.delete(picked)
        when SELECT_TOGGLE
          if @selection.include?(picked)
            @selection.delete(picked)
          else
            @selection.add(picked)
          end
        end
        nil
      end

      # @param [Sketchup::View] view
      # @param [Integer] x
      # @param [Integer] y
      # @return [Tile::TileEdge, nil]
      def pick_edge(view, x, y)
        ph = view.pick_helper(x, y, APERTURE)

        edge = nil
        @tiles.each { |tile|
          edge = tile.edges.find { |edge|
            picked = ph.test_point(edge.position)
          }
          break if edge
        }

        edge
      end

      # @param [Sketchup::View] view
      # @param [Integer] x
      # @param [Integer] y
      # @return [Tile::TileEdge, nil]
      def pick_tile(view, x, y)
        # @type [Sketchup::PickHelper]
        ph = view.pick_helper(x, y)
        return nil if ph.count == 0

        path = ph.path_at(0)
        instance = path.find { |entity|
          next false unless entity.is_a?(Sketchup::ComponentInstance)
          dict = entity.definition.attribute_dictionary(ATTR_DICT, false)
          !dict.nil?
        }

        return nil if instance.nil?
        @tiles.find { |tile| tile.instance == instance }
      end

      # @return [Array<TilePrototype>]
      def load_tiles
        model = Sketchup.active_model
        assets = AssetManager.new(model)
        instances = assets.tile_prototype_instances(model.entities)
        assets.tile_prototypes(instances)
      end

      ATTR_DICT = 'tt_wfc'
      ATTR_TYPES = 'connection_types'

      # @param [Sketchup::Model] model
      # @return [Array<EdgePrototype>]
      def get_connection_types(model)
        model.get_attribute(ATTR_DICT, ATTR_TYPES, []).map { |data|
          type_id, color, symmetrical = data
          symmetrical = true if symmetrical.nil?
          EdgePrototype.new(type_id, color, symmetrical)
        }
      end

      # @param [Sketchup::Model] model
      # @param [EdgePrototype] type
      def add_connection_type(model, type)
        raise unless type.is_a?(EdgePrototype)
        types = get_connection_types(model)
        raise ArgumentError, "#{type[0]} already exist" if types.any? { |t| t[0] == type[0] }
        types << type
        model.set_attribute(ATTR_DICT, ATTR_TYPES, types.map(&:to_a))
      end

      # @param [Sketchup::Model] model
      # @param [String] existing_type_id
      # @param [EdgePrototype] type
      def edit_connection_type(model, existing_type_id, type)
        raise unless type.is_a?(EdgePrototype)
        types = get_connection_types(model)
        raise ArgumentError, "#{existing_type_id} doesn't exist" if types.none? { |t| t[0] == existing_type_id }
        raise ArgumentError, "#{type[0]} already exist" if existing_type_id != type.type_id && types.any? { |t| t[0] == type[0] }
        i = types.index { |t| t[0] == existing_type_id }
        types[i] = type
        p [:edit_connection_type, types.map(&:to_a)]
        model.set_attribute(ATTR_DICT, ATTR_TYPES, types.map(&:to_a))
      end

      # @param [Sketchup::Model] model
      # @param [String] existing_type_id
      def delete_connection_type(model, existing_type_id)
        types = get_connection_types(model)
        raise ArgumentError, "#{existing_type_id} doesn't exist" if types.none? { |t| t[0] == existing_type_id }
        i = types.index { |t| t[0] == existing_type_id }
        types.delete_at(i)
        model.set_attribute(ATTR_DICT, ATTR_TYPES, types.map(&:to_a))
      end

      def prompt_connection_type(title, id: 'connection-id', symmetrical: true, color: Sketchup::Color.names.sample)
        prompts = ['Connection ID', 'Symmetrical', 'Color']
        p [:symmetrical, symmetrical]
        defaults = [id, symmetrical.to_s, color]
        list = ['', 'true|false', Sketchup::Color.names.join('|')]
        result = UI.inputbox(prompts, defaults, list, title)
        result[1] = result[1] == 'true' if result
        result
      end

      def prompt_add_connection_type
        input = prompt_connection_type('Create Connection Type')
        return unless input

        type, symmetrical, color = input

        model = Sketchup.active_model
        model.start_operation('Add Connection Type', true)
        add_connection_type(model, EdgePrototype.new(type, color, symmetrical))
        model.commit_operation
      end

      def prompt_remove_connection_type
        input = prompt_pick_connection_type('Remove Connection Type')
        return unless input

        type_id = input[0]

        model = Sketchup.active_model
        model.start_operation('Remove Connection Type', true)
        delete_connection_type(model, type_id)
        remove_edge_ids(model, type_id)
        model.commit_operation
      end

      def prompt_edit_connection_type
        model = Sketchup.active_model
        types = get_connection_types(model)

        input = prompt_pick_connection_type('Select Connection Type')
        return unless input

        type_id = input[0]
        type = types.find { |t| t.type_id == type_id }
        color = type.color
        symmetrical = type.symmetrical

        input = prompt_connection_type('Edit Connection Type',
          id: type_id,
          symmetrical: symmetrical,
          color: color
        )
        return unless input

        p [:prompt_edit_connection_type, input]
        type, symmetrical, color = input

        model = Sketchup.active_model
        model.start_operation('Add Connection Type', true)
        edit_connection_type(model, type_id, EdgePrototype.new(type, color, symmetrical))
        rename_edge_ids(model, type_id, type) if type != type_id
        model.commit_operation
      end

      def rename_edge_ids(model, old_type_id, new_type_id)
        @tiles.each { |tile|
          tile.edges.each { |edge|
            next unless edge.type == old_type_id

            edge.type = new_type_id
          }
        }
      end

      def remove_edge_ids(model, type_id)
        @tiles.each { |tile|
          tile.edges.each { |edge|
            next unless edge.type == type_id

            edge.type = nil
          }
        }
      end

      def prompt_pick_connection_type(title)
        model = Sketchup.active_model
        types = get_connection_types(model)
        type_ids = types.map(&:first)

        prompts = ['Connection ID']
        defaults = [type_ids.sort.first || '']
        list = [type_ids.sort.join('|')]
        UI.inputbox(prompts, defaults, list, title)
      end

      def prompt_assign_connection_type(title)
        model = Sketchup.active_model
        types = get_connection_types(model)
        type_ids = types.map(&:first)

        prompts = ['Connection ID', 'Reversed']
        defaults = [type_ids.sort.first || '', 'false']
        boolean = 'true|false'
        list = [type_ids.sort.join('|'), boolean]
        result = UI.inputbox(prompts, defaults, list, title)
        result[1] = result[1] == 'true' if result
        result
      end

      def prompt_assign_connection_type_to_selection
        model = Sketchup.active_model
        types = get_connection_types(model)

        input = prompt_assign_connection_type('Assign Connection Type')
        return unless input

        type_id, reversed = input
        type = types.find { |t| t.type_id == type_id }
        raise unless type

        @selection.each { |edge|
          edge.assign(
            type: type_id,
            reversed: reversed,
          )
        }
      end

      # @param [TilePrototype] prototype
      def prompt_assign_tile_weight(prototype)
        title = 'Assign Weight'
        prompts = ['Weight']
        defaults = [prototype.weight]
        result = UI.inputbox(prompts, defaults, title)
        return unless result

        weight = result[0]
        model = Sketchup.active_model
        assets = AssetManager.new(model)

        model.start_operation('Assign Weight', true)
        prototype.weight = weight
        assets.serialize_tile_prototype(prototype)
        model.commit_operation

        model.active_view.invalidate
      end

    end # class

  end # module WFC
end # module Examples

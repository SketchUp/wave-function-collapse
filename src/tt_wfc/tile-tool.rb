require 'tt_wfc/constants/view'
require 'tt_wfc/tile'

module Examples
  module WFC

    class TileTool

      include ViewConstants

      DRAG_THRESHOLD = 2 # pixels

      def initialize
        @tiles = load_tiles

        # @type [Set<Tile::ConnectionPoint>]
        @selection = Set.new

        # @type [Tile::ConnectionPoint, nil]
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
        @mouse_over = pick_connection(view, x, y)
        view.invalidate
      end

      # @param [Integer] flags
      # @param [Integer] x
      # @param [Integer] y
      # @param [Sketchup::View] view
      def onLButtonDown(flags, x, y, view)
        @mouse_left_button_down = Geom::Point3d.new(x, y)
        @mouse_drag = false

        select_connection(flags, x, y, view)
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
        unless @selection.empty?
          menu.add_item('Assign Connection Type') do
            prompt_assign_connection_type_to_selection
          end
          menu.add_separator
        end
        menu.add_item('Add Connection Type') do
          prompt_add_connection_type
        end
        # menu.add_item('Remove Connection Type') do
        #   prompt_remove_connection_type
        # end
        # menu.add_item('Edit Connection Type') do
        #   prompt_edit_connection_type
        # end
      end

      # @param [Sketchup::View] view
      def draw(view)
        view.line_stipple = ''

        # Draw connections points.
        # (Backgrounds)
        points = @tiles.flat_map(&:connection_points)
        view.line_width = 2
        view.draw_points(points, 12, DRAW_FILLED_SQUARE, 'black')
        # (Cross-hairs)
        connection_types = get_connection_types(view.model)
        connection_colors = Hash[connection_types.map { |t| [t.type_id, t.color] }]
        connections = @tiles.flat_map(&:connections)
        connections.sort_by { |c| c.type || '' }.chunk { |c| c.type || '' }.each { |type_id, items|
          color = connection_colors[type_id] || 'white'
          pts = items.map(&:position)
          view.draw_points(pts, 10, DRAW_PLUS, color)
        }
        # view.draw_points(points, 10, DRAW_PLUS, 'white')

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
      def select_connection(flags, x, y, view)
        picked = pick_connection(view, x, y)
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

      APERTURE = 10 # pixels

      # @param [Sketchup::View] view
      # @param [Integer] x
      # @param [Integer] y
      # @return [Tile::ConnectionPoint, nil]
      def pick_connection(view, x, y)
        ph = view.pick_helper(x, y, APERTURE)

        connection = nil
        @tiles.each { |tile|
          connection = tile.connections.find { |connection|
            picked = ph.test_point(connection.position)
          }
          break if connection
        }

        connection
      end

      # @return [Array<Tile>]
      def load_tiles
        model = Sketchup.active_model
        tile_tag = model.layers['Tiles']
        raise "'Tiles' tag not found" if tile_tag.nil?

        instances = model.entities.grep(Sketchup::ComponentInstance).select { |instance|
          instance.layer = tile_tag
        }
        instances.map { |instance| Tile.new(instance) }
      end

      ATTR_DICT = 'tt_wfc'
      ATTR_TYPES = 'connection_types'

      ConnectionType = Struct.new(:type_id, :color)

      # @param [Sketchup::Model] model
      # @return [Array<ConnectionType>]
      def get_connection_types(model)
        model.get_attribute(ATTR_DICT, ATTR_TYPES, []).map { |data|
          type_id, color = data
          ConnectionType.new(type_id, color)
        }
      end

      # @param [Sketchup::Model] model
      # @param [ConnectionType] type
      def add_connection_type(model, type)
        raise unless type.is_a?(ConnectionType)
        types = get_connection_types(model)
        raise ArgumentError, "#{type[0]} already exist" if types.any? { |t| t[0] == type[0] }
        types << type
        model.set_attribute(ATTR_DICT, ATTR_TYPES, types.map(&:to_a))
      end

      def prompt_add_connection_type
        prompts = ['Connection ID', 'Color']
        defaults = ['connection-id', Sketchup::Color.names.sample]
        list = ['', Sketchup::Color.names.join('|')]
        input = UI.inputbox(prompts, defaults, list, 'Create Connection Type')
        return unless input

        type, color = input

        model = Sketchup.active_model
        model.start_operation('Add Connection Type', true)
        # add_connection_type(model, [type, color])
        add_connection_type(model, ConnectionType.new(type, color))
        model.commit_operation
      end

      def prompt_assign_connection_type_to_selection
        model = Sketchup.active_model
        types = get_connection_types(model)
        type_ids = types.map(&:first)

        prompts = ['Connection ID']
        defaults = [type_ids.sort.first || '']
        list = [type_ids.sort.join('|')]
        input = UI.inputbox(prompts, defaults, list, 'Assign Connection Type')
        return unless input

        type_id = input[0]
        type = types.find { |t| t.type_id == type_id }
        raise unless type

        @selection.each { |connection|
          connection.type = type_id
        }
      end

    end # class

  end # module WFC
end # module Examples

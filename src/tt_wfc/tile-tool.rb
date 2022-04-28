require 'tt_wfc/tile-tool'

module Examples
  module WFC

    class TileTool

      DRAG_THRESHOLD = 2 # pixels

      def initialize
        @tiles = load_tiles

        # @type [Tile::ConnectionPoint, nil]
        @selected = nil

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
        if @selected && @mouse_left_button_down && !@mouse_drag
          @mouse_drag = @mouse_left_button_down.distance(@mouse_position) >= DRAG_THRESHOLD
        end

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

        @selected = pick_connection(view, x, y)
        view.invalidate
      end

      # @param [Integer] flags
      # @param [Integer] x
      # @param [Integer] y
      # @param [Sketchup::View] view
      def onLButtonUp(flags, x, y, view)
        if @selected && @mouse_over && @selected.tile != @mouse_over.tile
          puts "Connected #{@selected} to #{@mouse_over}"
        end

        @mouse_left_button_down = nil
        @mouse_drag = false
        view.invalidate
      end

      # @param [Sketchup::View] view
      def draw(view)
        view.line_stipple = ''

        # Draw connections points.
        points = []
        @tiles.each { |tile|
          points.concat(tile.connection_points)
        }
        view.line_width = 2
        view.draw_points(points, 10, 3, 'orange')

        # Draw selected connection point.
        if @selected
          view.line_width = 2
          view.draw_points([@selected.position], 10, 3, 'red')
        end

        # Draw moused over connection point.
        if @mouse_over
          view.line_width = 2
          view.draw_points([@mouse_over.position], 12, 1, 'purple')
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

    end # class

  end # module WFC
end # module Examples

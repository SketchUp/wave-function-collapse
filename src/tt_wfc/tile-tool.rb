require 'tt_wfc/tile-tool'

module Examples
  module WFC

    class TileTool

      def initialize
        @tiles = load_tiles
      end

      def activate
        Sketchup.active_model.active_view.invalidate
      end

      def deactivate(view)
        view.invalidate
      end

      def suspend(view)
        view.invalidate
      end

      def resume(view)
        view.invalidate
      end

      # @param [Sketchup::View]
      def draw(view)
        points = []
        @tiles.each { |tile|
          points.concat(tile.connection_points)
        }
        view.line_width = 2
        view.draw_points(points, 10, 3, 'red')
      end

      private

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

require 'sketchup.rb'

require 'tt_wfc/tile_tool'
require 'tt_wfc/world_generator'

module Examples
  module WFC

    def self.prompt_generate
      prompts = ["Width", "Height"]
      defaults = [10, 10]
      input = UI.inputbox(prompts, defaults, "Generate World")
      return unless input

      # Use only selected tiles if any are selected.
      model = Sketchup.active_model
      tile_tag = model.layers['Tiles']
      raise "'Tiles' tag not found" if tile_tag.nil?
      source = model.selection.empty? ? model.entities : model.selection
      instances = source.grep(Sketchup::ComponentInstance).select { |instance|
        instance.layer = tile_tag
      }
      tile_definitions = instances.map { |instance| TileDefinition.new(instance) }

      @generator&.stop
      # Start the generation
      width, height = input
      @generator = WorldGenerator.new(width, height, tile_definitions)
      @generator.run
    end

    def self.stop_current_generator
      @generator&.stop
      @generator = nil
    end

    def self.prompt_load_assets
      directory = UI.select_directory(
        title: "Select Asset Directory",
      )
      return if nil

      prompts = ["Filter"]
      defaults = ["ground*"]
      input = UI.inputbox(prompts, defaults, "Filter Files to Open")
      return unless input

      filter = input[0]
      pattern = File.join(directory, filter)
      model = Sketchup.active_model
      model.start_operation("Import Assets", true)
      x = 0.0
      Dir.glob(pattern) { |file|
        puts file
        definition = model.definitions.import(file)
        entities = model.active_entities

        offset_x = definition.bounds.min.x
        tr = Geom::Transformation.translation([x - offset_x, 0.0, 0.0])
        instance = entities.add_instance(definition, tr)
        x = instance.bounds.max.x
      }
      model.commit_operation
    end

    def self.activate_tile_tool
      model = Sketchup.active_model
      return if model.nil?

      tool = TileTool.new
      model.select_tool(tool)
    end

    unless file_loaded?(__FILE__)
      menu = UI.menu('Plugins').add_submenu('Wave Function Collapse')
      menu.add_item('Generate World') {
        self.prompt_generate
      }
      id = menu.add_item('Stop Generation') {
        self.stop_current_generator
      }
      menu.set_validation_proc(id)  {
        @generator.nil? ? MF_DISABLED | MF_GRAYED : MF_ENABLED
      }
      menu.add_separator
      menu.add_item('Tile Tool') {
        self.activate_tile_tool
      }
      menu.add_item('Load Assets') {
        self.prompt_load_assets
      }
      file_loaded(__FILE__)
    end

  end # module WFC
end # module Examples

require 'sketchup.rb'

require 'tt_wfc/tile-tool'

module Examples
  module WFC

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
      menu.add_item('Tile Tool') {
        self.activate_tile_tool
      }
      menu.add_separator
      menu.add_item('Load Assets') {
        self.prompt_load_assets
      }
      file_loaded(__FILE__)
    end

  end # module WFC
end # module Examples

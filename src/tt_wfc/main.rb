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
      @generator.run(start_paused: self.start_paused?)
    end

    def self.stop_current_generator
      @generator&.stop
      @generator = nil
    end

    def self.pause_current_generator
      return if @generator.nil?

      @generator.paused? ? @generator.resume : @generator.pause
    end

    def self.toggle_start_paused
      Sketchup.write_default('TT_WFC', 'StartPaused', !self.start_paused?)
    end

    def self.start_paused?
      Sketchup.read_default('TT_WFC', 'StartPaused', false)
    end

    def self.decrease_current_generator_speed
      @generator&.decrease_speed
    end

    def self.increase_current_generator_speed
      @generator&.increase_speed
    end

    def self.advance_next_step
      @generator&.update
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

    def self.active_generator?
      @generator && !@generator.stopped?
    end

    # @param [String] basename
    # @return [String]
    def self.icon(basename)
      # https://www.svgrepo.com/
      File.join(__dir__, 'icons', "#{basename}.svg")
    end

    unless file_loaded?(__FILE__)
      # Commands
      cmd = UI::Command.new('Generate World') {
        self.prompt_generate
      }
      cmd.set_validation_proc  {
        !self.active_generator? ? MF_ENABLED : MF_DISABLED | MF_GRAYED
      }
      cmd.tooltip = cmd.menu_text
      cmd.small_icon = self.icon('world')
      cmd.large_icon = self.icon('world')
      cmd_generate_world = cmd

      cmd = UI::Command.new('Pause Generation') {
        self.pause_current_generator
      }
      cmd.set_validation_proc  {
        self.active_generator? ? MF_ENABLED : MF_DISABLED | MF_GRAYED
      }
      cmd.tooltip = cmd.menu_text
      cmd.small_icon = self.icon('pause')
      cmd.large_icon = self.icon('pause')
      cmd_pause_generation = cmd

      cmd = UI::Command.new('Stop Generation') {
        self.stop_current_generator
      }
      cmd.set_validation_proc  {
        self.active_generator? ? MF_ENABLED : MF_DISABLED | MF_GRAYED
      }
      cmd.tooltip = cmd.menu_text
      cmd.small_icon = self.icon('stop')
      cmd.large_icon = self.icon('stop')
      cmd_stop_generation = cmd

      cmd = UI::Command.new('Increase Speed') {
        self.increase_current_generator_speed
      }
      cmd.set_validation_proc  {
        self.active_generator? ? MF_ENABLED : MF_DISABLED | MF_GRAYED
      }
      cmd.tooltip = cmd.menu_text
      cmd.small_icon = self.icon('faster')
      cmd.large_icon = self.icon('faster')
      cmd_increase_speed = cmd

      cmd = UI::Command.new('Decrease Speed') {
        self.decrease_current_generator_speed
      }
      cmd.set_validation_proc  {
        self.active_generator? ? MF_ENABLED : MF_DISABLED | MF_GRAYED
      }
      cmd.tooltip = cmd.menu_text
      cmd.small_icon = self.icon('slower')
      cmd.large_icon = self.icon('slower')
      cmd_decrease_speed = cmd

      cmd = UI::Command.new('Start Paused') {
        self.toggle_start_paused
      }
      cmd.set_validation_proc  {
        self.start_paused? ? MF_CHECKED : MF_ENABLED
      }
      cmd.tooltip = cmd.menu_text
      cmd.small_icon = self.icon('halt')
      cmd.large_icon = self.icon('halt')
      cmd_toggle_start_paused = cmd

      cmd = UI::Command.new('Step') {
        self.advance_next_step
      }
      cmd.set_validation_proc  {
        self.active_generator? ? MF_ENABLED : MF_DISABLED | MF_GRAYED
      }
      cmd.tooltip = cmd.menu_text
      cmd.small_icon = self.icon('step')
      cmd.large_icon = self.icon('step')
      cmd_step = cmd

      # Menus
      menu = UI.menu('Plugins').add_submenu('Wave Function Collapse')
      menu.add_item(cmd_generate_world)
      menu.add_separator
      menu.add_item(cmd_pause_generation)
      menu.add_item(cmd_stop_generation)
      menu.add_separator
      menu.add_item(cmd_step)
      menu.add_item(cmd_toggle_start_paused)
      # menu.add_separator
      # menu.add_item(cmd_decrease_speed)
      # menu.add_item(cmd_increase_speed)
      menu.add_separator
      menu.add_item('Tile Tool') {
        self.activate_tile_tool
      }
      menu.add_item('Load Assets') {
        self.prompt_load_assets
      }

      # Toolbar
      toolbar = UI::Toolbar.new('Wave Function Collapse')
      toolbar.add_item(cmd_generate_world)
      toolbar.add_separator
      toolbar.add_item(cmd_pause_generation)
      toolbar.add_item(cmd_stop_generation)
      toolbar.add_separator
      toolbar.add_item(cmd_step)
      toolbar.add_item(cmd_toggle_start_paused)
      # toolbar.add_separator
      # toolbar.add_item(cmd_decrease_speed)
      # toolbar.add_item(cmd_increase_speed)
      toolbar.restore

      file_loaded(__FILE__)
    end

  end # module WFC
end # module Examples

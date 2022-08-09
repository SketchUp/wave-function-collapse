require 'sketchup.rb'

require 'tt_wfc/tile_tool'
require 'tt_wfc/world_generator'

module Examples
  module WFC

    # generator = Examples::WFC.generator
    def self.generator
      @generator
    end

    def self.prompt_set_speed
      speed = Sketchup.read_default('TT_WFC', 'Speed', 0.1)

      prompts = ["Speed (seconds)"]
      defaults = [speed]
      input = UI.inputbox(prompts, defaults, "Set Iteration Speed")
      return unless input

      speed = input[0]
      return UI.beep if speed < 0

      Sketchup.write_default('TT_WFC', 'Speed', speed)
    end

    def self.prompt_set_generator_seed
      seed = Sketchup.read_default('TT_WFC', 'Seed', 0)

      prompts = ["Seed (0 = Random)"]
      defaults = [seed]
      input = UI.inputbox(prompts, defaults, "Set Generator Seed")
      return unless input

      seed = input[0]
      Sketchup.write_default('TT_WFC', 'Seed', seed)
    end

    # SpeedUp.profile { Examples::WFC.generate(10, 10) }
    def self.prompt_generate
      prompts = ["Width", "Height"]
      defaults = [10, 10]
      input = UI.inputbox(prompts, defaults, "Generate World")
      return unless input

      width, height = input
      self.generate(width, height)
    end

    def self.generate(width, height)
      # Use only selected tiles if any are selected.
      model = Sketchup.active_model
      tile_tag = model.layers['Tiles']
      raise "'Tiles' tag not found" if tile_tag.nil?
      source = model.selection.empty? ? model.entities : model.selection
      instances = source.grep(Sketchup::ComponentInstance).select { |instance|
        instance.layer == tile_tag
      }
      tile_definitions = instances.map { |instance|
        weight = instance.definition.get_attribute('tt_wfc', 'weight', 1)
        TileDefinition.new(instance, weight: weight)
      }

      @generator&.stop
      # Start the generation
      seed = Sketchup.read_default('TT_WFC', 'Seed', nil)
      seed = nil if seed < 1
      @generator = WorldGenerator.new(width, height, tile_definitions, seed: seed)

      puts
      puts "Generator seed: #{@generator.seed}"

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

    def self.toggle_break_at_iteration
      Sketchup.write_default('TT_WFC', 'BreakAtIteration', !self.break_at_iteration?)
    end

    def self.break_at_iteration?
      Sketchup.read_default('TT_WFC', 'BreakAtIteration', false)
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

    def self.prompt_assign_weight
      model = Sketchup.active_model
      instances = model.selection.grep(Sketchup::ComponentInstance)
      definitions = instances.map(&:definition)
      return if definitions.empty?

      default = 1
      if definitions.size == 1
        default = definitions[0].get_attribute('tt_wfc', 'weight', 1)
      end

      prompts = ["Weight"]
      defaults = [default]
      input = UI.inputbox(prompts, defaults, "Assign Weight")
      return unless input

      weight = input[0]

      model.start_operation('Assign Weight', true)
      definitions.each { |definition|
        definition.set_attribute('tt_wfc', 'weight', weight)
      }
      model.commit_operation
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

    def self.update_asset_data
      model = Sketchup.active_model
      tile_tag = model.layers['Tiles']
      raise "'Tiles' tag not found" if tile_tag.nil?

      source = model.selection.empty? ? model.entities : model.selection
      instances = source.grep(Sketchup::ComponentInstance).select { |instance|
        instance.layer == tile_tag
      }
      model.start_operation('Update Asset Data', true)
      instances.each { |instance|
        weight = instance.definition.get_attribute('tt_wfc', 'weight', 1)
        definition = TileDefinition.new(instance, weight: weight)
        definition.edges.each { |edge|
          edge.type = edge.type # Kludge: Forces the edge to serialize.
        }
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

      cmd = UI::Command.new('Break at Iteration') {
        self.toggle_break_at_iteration
      }
      cmd.set_validation_proc  {
        self.break_at_iteration? ? MF_CHECKED : MF_ENABLED
      }
      cmd.tooltip = cmd.menu_text
      cmd_toggle_break_at_iteration = cmd

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

      cmd = UI::Command.new('Set Generator Seed') {
        self.prompt_set_generator_seed
      }
      cmd.tooltip = cmd.menu_text
      cmd.small_icon = self.icon('random')
      cmd.large_icon = self.icon('random')
      cmd_seed = cmd

      cmd = UI::Command.new('Assign Weight') {
        self.prompt_assign_weight
      }
      cmd.tooltip = cmd.menu_text
      cmd.small_icon = self.icon('weight')
      cmd.large_icon = self.icon('weight')
      cmd_weight = cmd

      cmd = UI::Command.new('Set Iteration Speed') {
        self.prompt_set_speed
      }
      cmd.tooltip = cmd.menu_text
      cmd.small_icon = self.icon('speed')
      cmd.large_icon = self.icon('speed')
      cmd_speed = cmd

      cmd = UI::Command.new('Tile Tools') {
        self.activate_tile_tool
      }
      cmd.tooltip = cmd.menu_text
      cmd.small_icon = self.icon('tag')
      cmd.large_icon = self.icon('tag')
      cmd_tile_tool = cmd

      # Menus
      menu = UI.menu('Plugins').add_submenu('Wave Function Collapse')
      menu.add_item(cmd_generate_world)
      menu.add_separator
      menu.add_item(cmd_pause_generation)
      menu.add_item(cmd_stop_generation)
      menu.add_separator
      menu.add_item(cmd_step)
      menu.add_item(cmd_toggle_start_paused)
      menu.add_item(cmd_toggle_break_at_iteration)
      menu.add_item(cmd_speed)
      menu.add_item(cmd_seed)
      # menu.add_separator
      # menu.add_item(cmd_decrease_speed)
      # menu.add_item(cmd_increase_speed)
      menu.add_separator
      menu.add_item(cmd_tile_tool)
      menu.add_item(cmd_weight)
      menu.add_item('Load Assets') {
        self.prompt_load_assets
      }
      menu.add_item('Update Asset Data') {
        self.update_asset_data
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
      toolbar.add_item(cmd_speed)
      toolbar.add_item(cmd_seed)
      toolbar.add_separator
      toolbar.add_item(cmd_tile_tool)
      toolbar.add_item(cmd_weight)
      # toolbar.add_separator
      # toolbar.add_item(cmd_decrease_speed)
      # toolbar.add_item(cmd_increase_speed)
      toolbar.restore

      file_loaded(__FILE__)
    end

=begin

model = Sketchup.active_model
generator = Examples::WFC.generator
pos = generator.possibilities.slice(4, 4)
pos.each { |pb|
  g = model.entities.add_group
  g.transform!([0,0,5.m])
  g.entities.add_instance(pb.definition.instance.definition, pb.transformation)
  g.set_attribute('wfc', 'edges', pb.edges)
}

=end

  end # module WFC
end # module Examples

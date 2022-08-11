require 'sketchup.rb'

require 'tt_wfc/asset_manager'
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
      # TODO: Update active generator
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
      model = Sketchup.active_model
      source = model.selection.empty? ? model.entities : model.selection

      assets = AssetManager.new(model)
      instances = assets.tile_prototype_instances(source)
      prototypes = assets.tile_prototypes(instances)
      raise 'no tile prototypes loaded' if prototypes.empty?

      @generator&.stop
      # Start the generation
      seed = Sketchup.read_default('TT_WFC', 'Seed', nil)
      seed = nil if seed < 1
      @generator = WorldGenerator.new(width, height, prototypes,
        seed: seed,
        # Sketchup.write_default('TT_WFC', 'Speed', 0.01)
        speed: Sketchup.read_default('TT_WFC', 'Speed', 0.1),
        # Sketchup.write_default('TT_WFC', 'Log', true)
        log: Sketchup.read_default('TT_WFC', 'Log', false),
      )

      puts
      puts "Generator seed: #{@generator.seed}"

      @generator.run(start_paused: self.start_paused?)
    end

    def self.prompt_derive
      model = Sketchup.active_model
      return unless model.selection.size == 1
      return unless model.selection.first.is_a?(Sketchup::Group)

      assets = AssetManager.new(model)
      group = model.selection.first
      instances = group.entities.grep(Sketchup::ComponentInstance)
      # Not reading the weight from the attributes, instead using the weight
      # from it's frequency in the group.
      definitions = instances.map(&:definition)
      prototypes = definitions.tally.map { |definition, count|
        instance = instances.find { |i| i.definition == definition }
        prototype = assets.deserialize_tile_prototype(instance)
        prototype.weight = count
        prototype
      }
      raise 'no tile prototypes loaded' if prototypes.empty?

      # TODO: Deduplicate logic with normal generate
      # TODO: Add seed as option
      prompts = ["Width", "Height"]
      defaults = [10, 10]
      input = UI.inputbox(prompts, defaults, "Generate World")
      return unless input

      width, height = input

      @generator&.stop
      # Start the generation
      seed = Sketchup.read_default('TT_WFC', 'Seed', nil)
      seed = nil if seed < 1
      @generator = WorldGenerator.new(width, height, prototypes,
        seed: seed,
        speed: Sketchup.read_default('TT_WFC', 'Speed', 0.1),
        log: Sketchup.read_default('TT_WFC', 'Log', false),
      )

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
      @generator&.break_at_iteration = self.break_at_iteration?
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
      return if instances.empty?

      assets = AssetManager.new(model)
      prototypes = instances.map { |instance|
        assets.deserialize_tile_prototype(instance)
      }

      default_weight = prototypes.size == 1 ? prototypes.first.weight : 1
      prompts = ['Weight']
      defaults = [default_weight]
      input = UI.inputbox(prompts, defaults, 'Assign Weight')
      return unless input

      weight = input[0]

      model.start_operation('Assign Weight', true)
      prototypes.each { |prototype|
        prototype.weight = weight
        assets.serialize_tile_prototype(prototype)
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

    def self.activate_tile_tool
      model = Sketchup.active_model
      return if model.nil?

      tool = TileTool.new
      model.select_tool(tool)
    end

    def self.active_generator?
      @generator && !@generator.stopped?
    end

    def self.context_menu(menu)
      model = Sketchup.active_model
      return unless model.selection.size == 1

      group = model.selection[0]
      return unless group.is_a?(Sketchup::Group)

      return if group.attribute_dictionary('tt_wfc', false).nil?

      menu.add_item('Derive New World') {
        self.prompt_derive
      }
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

      UI.add_context_menu_handler do |context_menu|
        self.context_menu(context_menu)
      end

      file_loaded(__FILE__)
    end

  end # module WFC
end # module Examples

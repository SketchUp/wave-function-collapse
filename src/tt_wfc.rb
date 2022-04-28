require 'sketchup.rb'
require 'extensions.rb'

module Examples # TODO: Change module name to fit the project.
  module WFC

    unless file_loaded?(__FILE__)
      ex = SketchupExtension.new('Hello Cube', 'tt_wfc/main')
      ex.description = 'SketchUp Ruby API example creating a cube.'
      ex.version     = '1.0.0'
      ex.copyright   = 'Trimble Inc © 2016-2021'
      ex.creator     = 'SketchUp'
      Sketchup.register_extension(ex, true)
      file_loaded(__FILE__)
    end

  end # module WFC
end # module Examples

require 'tt_wfc/tile_prototype'

module Examples
  module WFC

    class AssetManager

      class Attr
        DICT = 'tt_wfc'
        WEIGHT = 'weight'
      end

      # @return [Sketchup::Model]
      attr_reader :model

      # @param [Sketchup::Model] model
      def initialize(model)
        @model = model
      end

      # @param [Array<Sketchup::ComponentInstance>] instances
      # @return [Array<TilePrototype>]
      def tile_prototypes(instances)
        instances.map { |instance| deserialize_tile_prototype(instance) }
      end

      # @param [Enumerable] entities
      # @param [Array<ComponentInstance>]
      def tile_prototype_instances(entities)
        layer = tile_prototype_layer
        entities.grep(Sketchup::ComponentInstance).select { |instance|
          instance.layer == layer
        }
      end

      # @param [TilePrototype] prototype
      def serialize_tile_prototype(prototype)
        definition = prototype.definition
        set_attribute(definition, Attr::WEIGHT, prototype.weight)
      end

      # @param [Sketchup::ComponentInstance] instance
      # @return [TilePrototype]
      def deserialize_tile_prototype(instance)
        weight = get_attribute(instance.definition, Attr::WEIGHT, 1)
        TilePrototype.new(instance, weight: weight)
      end

      private

      # @return [Sketchup::Layer]
      def tile_prototype_layer
        @model.layers['Tiles'] or raise "'Tiles' tag not found"
      end

      # @param [Sketchup::Entity] entity
      # @param [String] key
      # @param [Object] default
      # @return [Object]
      def get_attribute(entity, key, default = nil)
        entity.get_attribute(Attr::DICT, key, default)
      end

      # @param [Sketchup::Entity] entity
      # @param [String] key
      # @param [Object] value
      def set_attribute(entity, key, value)
        entity.set_attribute(Attr::DICT, key, value)
      end

    end

  end
end

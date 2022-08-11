require 'tt_wfc/edge_prototype'
require 'tt_wfc/tile_edge'
require 'tt_wfc/tile_prototype'

module Examples
  module WFC

    class AssetManager

      class Attr
        DICT = 'tt_wfc'

        # TilePrototype
        WEIGHT = 'weight'

        # EdgePrototype
        CONNECTION_TYPES = 'connection_types' # Legacy
        EDGE_TYPES = CONNECTION_TYPES
        EDGE_TYPE = 'type'
        EDGE_REVERSED = 'reversed'
      end

      # @return [Sketchup::Model]
      attr_reader :model

      # @param [Sketchup::Model] model
      def initialize(model)
        @model = model
      end

      # @param [#attribute_dictionary]
      def has_wfc_data?(entity)
        !entity.attribute_dictionary(Attr::DICT, false).nil?
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

      # @param [TileEdge] edge
      def serialize_tile_edge(edge)
        root = edge.tile.definition.attribute_dictionary(Attr::DICT, true)
        dictionary = root.attribute_dictionary(edge.edge_id.to_s, true)
        dictionary[Attr::EDGE_TYPE] = edge.prototype&.type_id
        dictionary[Attr::EDGE_REVERSED] = edge.reversed?
      end

      # @param [TilePrototype] tile
      # @param [Symbol] edge_id
      # @return [TileEdge]
      def deserialize_tile_edge(tile, edge_id)
        edge_key = edge_id.to_s
        root = tile.definition.attribute_dictionary(Attr::DICT, false)
        if root.attribute_dictionaries.nil?
          # Legacy
          warn "Reading legacy data for #{self}"
          type = root[edge_key]
          prototype = get_edge_prototype(type)

          edge = TileEdge.new(tile, edge_id)
          edge.prototype = prototype
          edge
        else
          type     = root.get_attribute(edge_key, Attr::EDGE_TYPE)
          reversed = root.get_attribute(edge_key, Attr::EDGE_REVERSED, false)
          prototype = get_edge_prototype(type)

          edge = TileEdge.new(tile, edge_id)
          edge.prototype = prototype
          edge.reversed = reversed
          edge
        end
      end

      # @param [Array<EdgePrototype>] edge_types
      def serialize_edge_prototypes(edge_types)
        data = edge_types.map(&:to_a)
        set_attribute(model, Attr::EDGE_TYPES, data)
      end

      # @return [Array<EdgePrototype>]
      def deserialize_edge_prototypes
        get_attribute(model, Attr::EDGE_TYPES, []).map { |data|
          type_id, color, symmetrical = data
          symmetrical = true if symmetrical.nil?
          EdgePrototype.new(type_id, color, symmetrical)
        }
      end

      # @param [EdgePrototype] edge_type
      # @return [void]
      def add_edge_prototype(edge_type)
        raise unless edge_type.is_a?(EdgePrototype)

        edge_types = deserialize_edge_prototypes
        if edge_types.any? { |e| e.type_id == edge_type.type_id }
          raise ArgumentError, "#{edge_type.type_id} already exist"
        end

        edge_types << edge_type
        serialize_edge_prototypes(edge_types)
      end

      # @param [String] existing_type_id
      # @param [EdgePrototype] edge_type
      # @return [void]
      def edit_edge_type(existing_type_id, edge_type)
        raise unless edge_type.is_a?(EdgePrototype)

        edge_types = deserialize_edge_prototypes
        if edge_types.none? { |e| e.type_id == existing_type_id }
          raise ArgumentError, "#{existing_type_id} doesn't exist"
        end
        if existing_type_id != edge_type.type_id && edge_types.any? { |e| e.type_id == edge_type.type_id }
          raise ArgumentError, "#{edge_type.type_id} already exist"
        end

        i = edge_types.index { |e| e.type_id == existing_type_id }
        edge_types[i] = edge_type

        serialize_edge_prototypes(edge_types)
      end

      # @note This doesn't update any existing tiles.
      #
      # @param [String] existing_type_id
      def delete_edge_type(existing_type_id)
        edge_types = deserialize_edge_prototypes
        if edge_types.none? { |e| e.type_id == existing_type_id }
          raise ArgumentError, "#{existing_type_id} doesn't exist"
        end

        i = edge_types.index { |e| e.type_id == existing_type_id }
        edge_types.delete_at(i)

        serialize_edge_prototypes(edge_types)
        # TODO: Update existing tile prototype instances.
      end

      private

      # @return [Sketchup::Layer]
      def tile_prototype_layer
        model.layers['Tiles'] or raise "'Tiles' tag not found"
      end

      # @param [String, nil] type_id
      # @return [EdgePrototype, nil]
      def get_edge_prototype(type_id)
        return nil if type_id.nil? # Special case for deserialization.

        prototypes = deserialize_edge_prototypes
        prototypes.find { |prototype|
          prototype.type_id == type_id
        } or raise "prototype missing for: #{type_id}"
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

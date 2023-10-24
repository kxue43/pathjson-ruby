# frozen_string_literal: true

require 'path_json/nodes'

module PathJson
  class JsonifyLambdaBuilder
    class InvalidJSONPathError < PathJsonError; end

    JSONPATH = /\A(?<head>\$(?:\.[a-zA-Z]\w*|\[\d+\])*)(?<tail>\.[a-zA-Z]\w*|\[\d+\])\z/
    private_constant :JSONPATH

    def initialize(leaf_jsonpaths)
      @leaf_jsonpaths = leaf_jsonpaths
      @internal_nodes = {}
    end

    def build
      ->(row) { model.get_value(row) }
    end

    def model
      return @model if @model

      @leaf_jsonpaths.each do |leaf_jsonpath|
        leaf_node = LeafNode.new(leaf_jsonpath)
        parent_jsonpath = get_parent_jsonpath(leaf_jsonpath)
        join_nodes(parent_jsonpath, leaf_node)
      end
      @model = @internal_nodes['$']
    end
    private :model

    class << self
      private

      def guard(method_name)
        original = instance_method(method_name)
        define_method(method_name) do |child_jsonpath|
          unless JSONPATH.match?(child_jsonpath)
            raise InvalidJSONPathError, <<~'ERRMSG'.chomp
              JSONPath `#{child_jsonpath}` is invalid. Allowed pattern is \
              `/\A\$(?:\.[a-zA-Z]\w*|\[\d+\])*\.[a-zA-Z]\w*|\[\d+\]\z/`
            ERRMSG
          end

          original.bind(self).call(child_jsonpath)
        end
      end
    end

    def get_parent_jsonpath(child_jsonpath)
      JSONPATH.match(child_jsonpath)[:head]
    end
    guard :get_parent_jsonpath
    private :get_parent_jsonpath

    def get_child_key_in_parent(child_jsonpath)
      tail = JSONPATH.match(child_jsonpath)[:tail]
      tail.end_with?(']') ? tail[1..-2] : tail[1..]
    end
    guard :get_child_key_in_parent
    private :get_child_key_in_parent

    def create_internal_node(self_jsonpath, child_jsonpath)
      if child_jsonpath.end_with?(']')
        ArrayNode.new(self_jsonpath)
      else
        ObjectNode.new(self_jsonpath)
      end
    end
    private :create_internal_node

    def join_nodes(parent_jsonpath, child_node)
      if @internal_nodes.key?(parent_jsonpath)
        key = get_child_key_in_parent(child_node.jsonpath)
        parent_node = @internal_nodes[parent_jsonpath]
        parent_node.add_child(key, child_node)
        if child_node.is_a?(InternalNode)
          @internal_nodes[child_node.jsonpath] = child_node
        end
      elsif parent_jsonpath == '$'
        @internal_nodes[parent_jsonpath] =
          create_internal_node(parent_jsonpath, child_node.jsonpath)
        join_nodes(parent_jsonpath, child_node)
      else
        new_child_node = create_internal_node(parent_jsonpath, child_node.jsonpath)
        new_parent_jsonpath = get_parent_jsonpath(parent_jsonpath)
        join_nodes(new_parent_jsonpath, new_child_node)
        join_nodes(parent_jsonpath, child_node)
      end
    end
    private :join_nodes
  end
end

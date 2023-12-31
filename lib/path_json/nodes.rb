# frozen_string_literal: true

module PathJson
  class Node
    class NilValuesAccessedError < PathJsonError; end
    class UnexpectedUseOfDecorator < PathJsonError; end

    attr_accessor :jsonpath

    def initialize(jsonpath)
      self.jsonpath = jsonpath
      @last_checked_row = nil
      @intersected_last_time = false
    end

    class << self
      private

      def cache(method_name)
        unless method_name == :intersects
          raise UnexpectedUseOfDecorator, <<~ERRMSG.chomp
            "Unexpected use of `cache` on :#{method_name}. Use it on :intersects."
          ERRMSG
        end

        original = instance_method(method_name)
        define_method(:intersects) do |row|
          return @intersected_last_time if @last_checked_row == row

          @last_checked_row = row
          @intersected_last_time = original.bind(self).call(row)
        end
      end

      def guard(method_name)
        unless method_name == :get_value
          raise UnexpectedUseOfDecorator, <<~ERRMSG.chomp
            Unexpected use of `guard` on :#{method_name}. Use it on :get_value.
          ERRMSG
        end

        original = instance_method(method_name)
        define_method(:get_value) do |row|
          unless intersects(row)
            raise NilValuesAccessedError,
                  if respond_to?(:children)
                    "Values at JSONPaths `#{jsonpath}***` are all `nil`."
                  else
                    "Value at JSONPath `#{jsonpath}` is `nil`."
                  end
          end
          original.bind(self).call(row)
        end
      end
    end
  end

  class LeafNode < Node
    def get_value(row)
      row[jsonpath]
    end
    guard :get_value

    def intersects(row)
      !row[jsonpath].nil?
    end
    cache :intersects
  end

  class InternalNode < Node
    class DuplicateNodeAdditionError < PathJsonError; end

    attr_accessor :children
    private :children, :children=

    def initialize(jsonpath)
      super
      self.children = {}
    end

    def add_child(key, child)
      if children.key?(key)
        raise DuplicateNodeAdditionError, <<~ERRMSG.chomp
          Child node `#{child.jsonpath}` was added to parent node `#{jsonpath}` \
          more than once during model building."
        ERRMSG
      end

      children[key] = child
    end

    def intersects(row)
      children
        .lazy
        .map { |_, child| child.intersects(row) }
        .any?
    end
    cache :intersects
  end

  class ObjectNode < InternalNode
    def get_value(row)
      children.each_with_object({}) do |(key, child), acc|
        acc[key] = child.get_value(row) if child.intersects(row)
      end
    end
    guard :get_value
  end

  class ArrayNode < InternalNode
    class MissingArrayIndexError < PathJsonError; end

    def get_value(row)
      length = children.length
      (0...length).each do |n|
        raise MissingArrayIndexError, <<~ERRMSG.chomp unless children.key?(n.to_s)
          Missing a JSONPath of the format `#{jsonpath}[#{n}]***`.
        ERRMSG
      end
      (0...length).each_with_object([]) do |n, acc|
        child = children[n.to_s]
        acc.push(child.get_value(row)) if child.intersects(row)
      end
    end
    guard :get_value
  end

  private_constant :Node, :LeafNode, :ObjectNode, :ArrayNode
end

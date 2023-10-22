# frozen_string_literal: true

module PathJson
  class Node
    class NilValuesAccessedError < PathJsonError; end

    class << self
      attr_accessor :decorated_subclass_methods
      protected :decorated_subclass_methods, :decorated_subclass_methods=
    end

    Node.decorated_subclass_methods = {}

    attr_accessor :jsonpath, :last_checked_row, :intersected_last_time
    private :last_checked_row, :intersected_last_time

    def initialize(jsonpath)
      self.jsonpath = jsonpath
      self.last_checked_row = nil
      self.intersected_last_time = false
    end

    def self.method_added(method_name)
      super
      if self == Node || Node.decorated_subclass_methods[self]&.include?(method_name)
        return
      end

      (Node.decorated_subclass_methods[self] ||= []).push(method_name)
      original = instance_method(method_name)
      case method_name
      when :intersects
        define_method(:intersects) do |row|
          return intersected_last_time if last_checked_row == row

          self.last_checked_row = row
          self.intersected_last_time = original.bind(self).call(row)
        end
      when :get_value
        define_method(:get_value) do |row|
          unless intersects(row)
            raise NilValuesAccessedError,
                  if respond_to?(:children)
                    "Values at JSONPaths `#{jsonpath}***` are all `nil`."
                  else
                    "Value at JSONPath `#{jsonpath}` `nil`."
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

    def intersects(row)
      row[jsonpath].nil?
    end
  end
end

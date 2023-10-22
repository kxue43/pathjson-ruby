# frozen_string_literal: true

module PathJson
  class Node
    class NilValuesAccessedError < PathJsonError; end
    class UnexpectedUseOfDecorator < PathJsonError; end

    attr_accessor :jsonpath, :last_checked_row, :intersected_last_time
    private :last_checked_row, :last_checked_row=,
            :intersected_last_time, :intersected_last_time=

    def initialize(jsonpath)
      self.jsonpath = jsonpath
      self.last_checked_row = nil
      self.intersected_last_time = false
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
          return intersected_last_time if last_checked_row == row

          self.last_checked_row = row
          self.intersected_last_time = original.bind(self).call(row)
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
    guard :get_value

    def intersects(row)
      row[jsonpath].nil?
    end
    cache :intersects
  end
end

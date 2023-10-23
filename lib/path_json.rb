# frozen_string_literal: true

module PathJson
  class PathJsonError < ::RuntimeError; end

  autoload(:JsonifyLambdaBuilder, 'path_json/builders')
end

# frozen_string_literal: true

require 'path_json'

class TestJsonifyLambdaBuilder < Minitest::Test
  def setup
    @rows = [
      {
        '$.A' => 1,
        '$.B[0].c' => 1,
        '$.B[0].d' => 1,
        '$.B[1].c' => 2,
        '$.B[1].d' => 2,
        '$.C[0]' => 1,
        '$.C[1]' => 2
      },
      {
        '$.A' => 2,
        '$.B[0].c' => 3,
        '$.B[0].d' => 3,
        '$.C[0]' => 4,
        '$.C[1]' => 5,
        '$.C[2]' => 6
      }
    ].freeze
    @jsonpaths = [
      '$.A',
      '$.B[0].c',
      '$.B[0].d',
      '$.B[1].c',
      '$.B[1].d',
      '$.C[0]',
      '$.C[1]',
      '$.C[2]'
    ].freeze
    @expected = [
      { 'A' => 1, 'B' => [{ 'c' => 1, 'd' => 1 }, { 'c' => 2, 'd' => 2 }],
        'C' => [1, 2] },
      { 'A' => 2, 'B' => [{ 'c' => 3, 'd' => 3 }], 'C' => [4, 5, 6] }
    ]
  end

  def test_jsonifier_lambda
    fn = PathJson::JsonifyLambdaBuilder.new(@jsonpaths).build
    result = @rows.map { |row| fn.call(row) }
    assert_equal(result, @expected)
  end
end

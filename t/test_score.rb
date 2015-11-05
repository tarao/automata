require 'test/unit'

require 'store'
require 'score'

class ScoreTest < Test::Unit::TestCase
  def setup()
    @path = "./"

    @scorer = "scorer"
    @scorer2 = "church"

    @scores = {}
    @scores[@scorer] = Score.new(@scorer, @path)
    @scores[@scorer2] = Score.new(@scorer2, @path)

    @scorer_content = "{\"lambda calculus\" => true, \"turing machine\" => false }"
    @scorer2_content = "{\"andb\" => true, \"blt_nat\" => true }"
  end

  def teardown()
    path = @path + Score::INDEX_FILE
    File.delete(path) if File.exist?(path)
  end

  def add_scores()
    @scores[@scorer].add(@scorer_content)
    @scores[@scorer2].add(@scorer2_content)
  end

  def test_db_index()
    assert_not_nil(@scores[@scorer].db_index)
  end

  def test_retrival()
    add_scores()

    ls =  [ [@scorer, @scorer_content ], [@scorer2, @scorer2_content] ]
    ls.length.times {|i|
      u = ls[i][0]
      c = ls[i][1]

      ret = @scores[u].retrieve()[i]
      assert_equal(u, ret['scorer'])
      assert_equal(c + "\n", ret['content'])
    }
  end
end

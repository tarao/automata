require 'test/unit'

require 'store'
require 'score'

class ScoreTest < Test::Unit::TestCase
  def setup()
    @path = "./"

    @user = "user"
    @user2 = "church"

    @scores = {}
    @scores[@user] = Score.new(@user, @path, {})
    @scores[@user2] = Score.new(@user2, @path, {})

    @user_content = "{\"lambda calculus\" => true, \"turing machine\" => false }"
    @user2_content = "{\"andb\" => true, \"blt_nat\" => true }"
  end

  def teardown()
    Score::FILE.each_key do |key|
      path = @path + Score::FILE[key]
      File.delete(path) if File.exist?(path)
    end
  end

  def add_scores()
    @scores[@user].add({ content: @user_content })
    @scores[@user2].add({ content: @user2_content })
  end

  def test_db_index()
    assert_not_nil(@scores[@user].db_index)
  end

  def test_retrival()
    add_scores()

    arg = { type: 'raw' }

    ls =  [ [@user, @user_content ], [@user2, @user2_content] ]
    ls.length.times {|i|
      u = ls[i][0]
      c = ls[i][1]

      ret = @scores[u].retrieve(arg)[i]
      assert_equal(u, ret['user'])
      assert_equal(c + "\n", ret['content'])
    }
  end
end

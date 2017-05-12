require 'pathname'
require_relative 'store'
require 'time'
require 'fileutils'
require_relative 'comment/renderer'
require_relative 'app'
require_relative 'comment'

#
# 採点のデータベースのファイルは
# db/kadai_i/username/score内に保存する
#

#
# DBのscheme
# DBのエントリのindexは以下の通り
#   { id: number, scorer: string, timestamp: Time }
#
# contentデータはRubyのhashオブジェクト
# hashオブジェクトの詳細はlib/score.rbを参照
#

class Score
  INDEX_FILE = 'index.db'

  def initialize(scorer, path)
    @scorer = scorer
    @path = path
    @path = Pathname.new(@path.to_s) unless @path.is_a?(Pathname)
  end

  def db_index()
    return Store.new(@path + INDEX_FILE)
  end

  def retrieve()
    return [] unless File.exist?(db_index.path)
    db_index.transaction do |db|
      entries = db[:entries] || []
      return ::Comment.new(@scorer, nil, @path, nil).load_content('raw', entries)
    end
  end

  def add(content)
    db_index.transaction do |db|
      new_id = (db[:max_id] || 0) + 1
      
      idx = {}
      idx['id'] = new_id
      idx['scorer'] = @scorer
      idx['timestamp'] = Time.now.iso8601

      db[:max_id] = new_id

      entries = db[:entries] || []
      entries.push(idx)
      db[:entries] = entries

      ::Comment.new(@scorer, nil, @path, nil).write_content(new_id, content)
    end
  end
end

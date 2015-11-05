require 'pathname'
require_relative 'store'
require 'time'
require 'fileutils'
require_relative 'comment/renderer'
require_relative 'app'
require_relative 'comment'

class Score
  def initialize(user, path)
    @user = user
    @path = path
    @path = Pathname.new(@path.to_s) unless @path.is_a?(Pathname)
    @index_file = 'index.db'
  end

  def db_index()
    return Store.new(@path + @index_file)
  end

  def retrieve(type)
    return [] unless File.exist?(db_index.path)
    db_index.transaction do |db|
      entries = db[:entries] || []
      return ::Comment.new(@user, nil, @path, nil).load_content(type, entries)
    end
  end

  def add(content)
    db_index.transaction do |db|
      new_id = (db[:max_id] || 0) + 1
      
      idx = {}
      idx['id'] = new_id
      idx['user'] = @user
      idx['timestamp'] = Time.now.iso8601

      db[:max_id] = new_id

      entries = db[:entries] || []
      entries.push(idx)
      db[:entries] = entries

      ::Comment.new(@user, nil, @path, nil).write_content(new_id, content)
    end
  end
end

require 'pathname'
require_relative 'store'
require 'time'
require 'fileutils'
require_relative 'comment/renderer'
require_relative 'app'

class Score
  class NotFound < Exception; end
  class PermissionDenied < Exception; end
  class SizeLimitExceeded < Exception; end
  class MaxCommentsExceeded < Exception; end

  FILE = {
    index: 'index.db',
  }

  def initialize(user, path, config)
    @user = user
    @path = path
    @path = Pathname.new(@path.to_s) unless @path.is_a?(Pathname)
    @config = config
  end

  def db_index()
    return Store.new(@path + FILE[:index])
  end

  def retrieve(args)
    # TODO: implement
    return [] unless File.exist?(db_index.path)
    db_index.transaction do |db|
      entries = db[:entries] || []
      #entries = filter_forbidden(entries)
      #entries.reject!{|e| e['id'] != args[:id]} if args[:id]
      return load_content(args[:type] || :html, entries)
    end
  end

  def add(args)
    # TODO: implement

    db_index.transaction do |db|
      new_id = (db[:max_id] || 0) + 1
      raise MaxCommentsExceeded if new_id > (@config['max'] || 256)

      args[:id] = new_id
      args[:user] = @user
      args[:create] = Time.now.iso8601
      
      idx = index_check(args)
      content = content_check(args)

      db[:max_id] = new_id

      entries = db[:entries] || []
      entries.push(idx)
      db[:entries] = entries

      write_content(new_id, content)
    end
  end


  # TODO(?): combine to the same function in comment.rb
  #          but the below is slightly different to original ver.
  def index_check(args)
    idx = {}
    idx['id'] = args[:id]
    idx['user'] = args[:user] if args[:user]
    # idx['acl'] = args[:acl].select{|a| a=='user' || a=='other'} if args[:acl]
    idx['create'] = args[:create] if args[:create]
    idx['timestamp'] = Time.now.iso8601
    return idx
  end

  # TODO: combine to the same function in comment.rb
  def write_content(id, content)
    contents = {
      raw:  content,
      html: Comment::Renderer.create.render(content)
    }
    contents.each do |type, content|
      open(content_file(type, id), 'w') do |io|
        io.puts(content)
      end
    end
  end

  # TODO: combine to the same function in comment.rb
  def map_entries(entries, map)
    return entries.map do |e|
      e.merge(Hash[*map.map{|k,v| [ k, v.call(e) ]}.flatten])
    end
  end

  # TODO: combine to the same function in comment.rb
  def load_content(type, id)
    if id.is_a?(Array)
      loader = proc{|e| load_content(type, e['id'])}
      return map_entries(id, 'content' => loader)
    end

    file = content_file(type, id)
    return unless file.exist?
    File.open(file, 'r:utf-8') {|f| f.read }
  end

  # TODO: combine to the same function in comment.rb
  def content_file(type, id)
    return @path + [ id.to_s, type.to_s ].join('.')
  end

  # TODO: combine to the same function in comment.rb
  def content_check(args)
    content = args[:content] || ''
    size_limit = @config['size_limit'] || (1024 * 16)
    raise SizeLimitExceeded if content.length > size_limit
    return content
  end
end

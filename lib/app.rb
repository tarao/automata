require 'yaml'
require 'time'
require 'pathname'
require 'strscan'

require 'rubygems'
require 'bundler/setup'

require 'clone'
require 'conf'
require 'log'
require 'store'

require 'logger'

class Pathname
  def [](*paths)
    loc = self
    loc = loc + paths.shift() while paths.length > 0
    return loc.to_s
  end
end

# アプリケーションの設定管理とユーザ情報の管理を行う
class App
  def self.find_base(dir)
    e = Pathname($0).expand_path.parent.to_enum(:ascend)
    return e.map{|x| x+dir.to_s }.find{|x| x.directory?}
  end

  CONFIG = find_base(:config)
  DB     = find_base(:db)
  KADAI  = DB + 'kadai'
  BUILD  = find_base(:build)
  TESTER = find_base(:test)
  SCRIPT = find_base(:script)

  FILES = {
    :master      => CONFIG['master.yml'],
    :local       => CONFIG['local.yml'],
    :scheme      => CONFIG['scheme.yml'],
    :template    => CONFIG['template.yml'],
    :data        => DB['data.yml'],
    :log         => 'log.yml',
    :build       => TESTER['build.rb'],
    :sandbox     => TESTER['test.rb'],
    :test_script => SCRIPT['test'],
  }

  LOGGER_LEVEL = {
    "FATAL" => Logger::FATAL,
    "ERROR" => Logger::ERROR,
    "WARN"  => Logger::WARN,
    "INFO"  => Logger::INFO,
    "DEBUG" => Logger::DEBUG,
  }

  attr_accessor :logger

  # 指定したユーザを実行ユーザとしてアプリケーションの初期化する．
  # ユーザを指定しない場合は環境変数から自動的にユーザを設定する．
  # @param [String] remote_user 実行ユーザ
  def initialize(remote_user=nil)
    @remote_user = remote_user
    @files = {}
    @conf = nil
    @user = nil
    @users = nil

    # config を app から分離したときは logger も分離すること
    @logger = Logger.new(conf[:logger, :path])
    @logger.level = LOGGER_LEVEL[conf[:logger, :level]]
  end

  def file(name)
    open_mode = RUBY_VERSION < '1.9.0' ? 'r' : 'r:utf-8'
    File.open(FILES[name], open_mode) do |f|
      @files[name] = YAML.load(f) unless @files[name]
    end
    return @files[name]
  end

  # アプリケーション設定を返す．
  # @return [Conf] アプリケーション設定
  def conf()
    unless @conf
      require 'conf'
      @conf = Conf.new(file(:master), (file(:local) rescue nil))
    end
    return @conf
  end

  # 出力用のテンプレートを返す．
  # @return [Conf] 出力用テンプレート設定
  def template()
    unless @template
      require 'conf'
      @template = Conf.new(file(:template), (file(:local) rescue nil))
    end
    return @template
  end

  # 実行ユーザのログイン名を返す．
  # @param [String] u
  # @return [String] 実行ユーザのログイン名
  def user(u=nil)
    @user = u || conf[:user] || @remote_user || ENV['USER'] unless @user
    return @user
  end

  # 指定したユーザが管理権限を持つか否かを判定する．
  # ユーザ指定がなければ実行ユーザを判定する．
  # @param [String] u 判定するユーザのログイン名
  # @return [true, false] 管理者権限を持てばtrue，そうでなければfalse
  def su?(u=nil) return conf[:su].include?(u||user) end

  # ユーザディレクトリを返す．
  # @param [String] r 課題名
  # @return [Pathname] ユーザディレクトリへの絶対パス
  def user_dir(r) return KADAI + r + user end

  # 実行ユーザから見えるユーザ情報の一覧を返す．
  # @return [Array<User>] マスク処理のされたユーザ情報一覧
  def users()
    unless @users
      require 'user'
      user_store = Store::YAML.new(FILES[:data])
      user_store.ro.transaction do |store|
        @users = (store['data'] || []).map{|u| User.new(u)}
        @users.reject!{|u| u.login != user} unless conf[:record, :open] || su?
        unless conf[:record, :show_login]
          # Override User#login to hide user login name
          @users.each{|u| def u.login() return token end}
        end
      end
    end
    return @users
  end

  # ユーザを追加する．
  # @param [String] name ユーザ名
  # @param [String] ruby ふりがな
  # @param [String] login ログイン名
  # @param [String] email メールアドレス
  def add_user(name, ruby, login, email)
    user_store = Store::YAML.new(FILES[:data])
    user_store.transaction do |store|
      users = (store['data'] || [])
      users << {'name' => name, 'ruby' => ruby, 'login' => login, 'email' => email}
      store['data'] = users
      @users = nil
    end
  end

  # ユーザトークンに対応するログイン名を返す．
  # @param [String] token トークン
  # @return [String] ログイン名
  def user_from_token(token)
    return users.inject(nil) do |r, u|
      (u.token == token || u.real_login == token) ? u.real_login : r
    end
  end

  def report(option, id, u)
    require 'report'

    status = option[:status]
    log = option[:log]

    src = nil
    optional = []
    optional << :log if option[:log]

    if (file(:scheme)['scheme'].find{|r| r['id']==id} || {})['type'] == 'post'
      fname = KADAI[id, u, FILES[:log]]
      return nil unless File.exist?(fname)
      yaml = Log.new(fname, true).latest(:data)
      # add timestamp of initial submit
      yaml['initial_submit'] = Log.new(fname, true).oldest(:data)['id']
      src = Report::Source::Post.new(yaml, optional)
    else
      yaml = file(:data) rescue {}
      yaml = yaml['data'] || {}
      yaml = yaml.find{|x| x['login'] == u} || {}
      yaml = yaml['report'] || {}
      yaml = yaml[id] || {}
      timestamp = File.mtime(FILES[:data]).iso8601
      src = Report::Source::Manual.new(yaml, optional, timestamp)
    end

    case status
    when 'solved'
      return Report::Solved.new(src)
    when 'record'
      scheme = (file(:scheme)['report'] || {})[id] || {}
      return Report::Record.new(src, scheme)
    else
      return src
    end
  end

  # 指定ディレクトリのディスク使用量をチェックする．
  # @param [String, Pathname] チェックするディレクトリ
  # @return [true, false] 設定上限以内であればtrue，そうでなければfalse
  def check_disk_usage(dir)
    dir = Pathname.new(dir.to_s) unless dir.is_a?(Pathname)

    checkers = {
      :size => proc{ StringScanner.new(`du -sk "#{dir}"`).scan(/\d+/).to_i },
      :entries => proc do
        if (dir+App::FILES[:log]).exist?
          Log.new(dir[App::FILES[:log]]).size
        else
          Pathname.new(dir).children.select(&:directory?).size
        end
      end,
    }

    checkers.each do |k,f|
      c = conf[:post, :limit, k]
      return false if c && c != 0 && c < f[]
    end

    return true
  end
end

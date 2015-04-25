# -*- coding: utf-8 -*-

require 'bundler/setup'

require 'time'
require 'digest/md5'
require 'webrick'

require_relative 'store'
require_relative 'syspath'
require_relative 'conf'
require_relative 'app/logger_ext'

class User
  # Retrieve a user by token or login.
  # FIXME: see User.from_login
  # @param [String] t_or_l token or login
  # @return [User] a user whose token or login is t_or_l
  def self.from_token_or_login(t_or_l)
    (all_users.select { |u| u.token == t_or_l || u.real_login == t_or_l })[0]
  end

  # Retrieve a user by login.
  # FIXME: I think the name from_login is not good; something like find_by_login
  # are preferable.
  # @param [String] login
  # @return [User] a user whose login is login
  def self.from_login(login)
    (all_users.select { |u| u.real_login == login })[0]
  end

  # Add a user to the database.
  # @param [Hash{String => String}] info contains name, ruby, login, email, and
  #   assigned
  # @example
  #   User.add(
  #     'name'      => 'Alice',
  #     'ruby'      => 'Alice',
  #     'login'     => 'alice',
  #     'email'     => 'alice@wonderland.net',
  #     'assigned'  => 'Bob'
  #   )
  # @return [Bool] whether addition of an user succeeds or not
  def self.add(info)
    return false if all_users.any? do |u|
      u.email == info['email'] || u.real_login == info['login']
    end

    FileUtils.touch SysPath::FILES[:data]
    store.transaction do |store|
      store['data'] = (store['data'] || []) + [info]
    end

    set_passwd(info['login'], info['passwd']) unless info['passwd'].nil?

    App::Logger.new.info("User added: #{info}")

    return true
  end

  # Modify user information.
  # @param [User] user modified user
  # @param [Hash{String => String}] info contains name, ruby, login, email
  #   assigned, or passwd; see also User.add
  # @example
  #   alice = User.from_login('alice')
  #   User.modify(alice, 'email' => 'alice@alice.com', 'assigned' => 'Carol')
  # @return [void]
  def self.modify(user, info)
    login = user.real_login
    store.transaction do |store|
      users = (store['data'] || [])
      users.map! do |u|
        if u['login'] == login
          u['name'] = info['name'] || u['name']
          u['ruby'] = info['ruby'] || u['ruby']
          u['email'] = info['email'] || u['email']
          u['assigned'] = info['assigned'] || u['assigned']
        end
        u
      end
      store['data'] = users
    end

    set_passwd(login, info['passwd']) unless info['passwd'].nil?
  end

  # Delete user information from the database.  This method also removes the
  # user's authentication information from .htdigest.  Reports are backed up.
  # @param [User] user deleted user
  # @raise [RuntimeError] if the backup dirctory alredy exists
  # @raise [RuntimeError] if the user's login is invalid
  # @return [void]
  def self.delete(user)
    login = user.real_login
    backup_dir = SysPath::BACKUP + Time.new.iso8601
    fail '頻度が高すぎるためリクエストを拒否しました' if File.exist?(backup_dir)
    fail 'Invalid delete id' if login.nil? || login.empty?
    FileUtils.mkdir_p(backup_dir)
    # remove and backup user directories
    Pathname.glob(SysPath::KADAI + '*').each do |path|
      path = path.expand_path
      src = (path + login).expand_path
      if File.exist?(src) && path.children.include?(src)
        dst = backup_dir + path.basename
        FileUtils.mv(src, dst)
      end
    end

    # remove user data
    store.transaction do |store|
      users = (store['data'] || [])
      users.reject! { |u| u['login'] == login }
      store['data'] = users
    end

    # remove user password
    delete_passwd(login)

    App::Logger.new.info("User deleted: #{login}")
  end

  # Make a token for a user login.  Tokens are used to hide users' real login.
  # @param [String] str encoded login
  # @return [String] the token generated from str
  def self.make_token(str)
    'id' + Digest::MD5.hexdigest(str)
  end

  # Return all users stored in the database.
  # @return [Array<User>] saved users
  def self.all_users
    store.ro.transaction do |store|
      (store['data'] || []).map { |u| new(u) }
    end
  end

  attr_reader :report

  # @param [Hash{String => String}] user contains name, ruby, email, login, and
  #   assigned
  def initialize(user)
    @user = user
    @report = {}
  end

  # Returns a real_login, not a token.
  # @return [String]
  def real_login
    @user['login']
  end

  # The user's token (the hash value of the login)
  # @return [String]
  def token
    self.class.make_token(real_login)
  end

  # Returns a real_login, not a token.  In case of
  # conf[:master, :record, :show_login] is false, App.visible_users overwrites
  # this method.
  # @return [String]
  def login
    real_login
  end

  # The user's name.
  # @return [String]
  def name
    @user['name']
  end

  # The user's ruby of the name.
  # @return [String]
  def ruby
    @user['ruby']
  end

  # The user's email.
  # @return [String]
  def email
    @user['email']
  end

  # TA assigned to the user.
  # @return [String] TA's login
  def assigned
    @user['assigned']
  end

  # Update the user's report status. (FIXME: Is this true?)
  # FIXME: I think that this syntax is not suitable for this method.
  # @param [String] exercise exercise id
  # @param [Report Object] report report object
  # @return [void]
  def []=(exercise, report)
    @report[exercise] = report if report
  end

  # The hash of the user's information
  # @return [Hash{String => String}]
  def to_hash
    hash = {
      'login'    => login,
      'token'    => token,
      'name'     => name,
      'ruby'     => ruby,
      'email'    => email,
      'assigned' => assigned,
    }
    hash['report'] = {} unless report.empty?
    report.each { |k, v| hash['report'][k] = v.to_hash }
    hash
  end

  # @return [Store] the database that stores user information
  def self.store
    Store::YAML.new(SysPath::FILES[:data])
  end

  # Set a password for a user.
  # @param [String] login real_login of a user
  # @param [String] passwd new password
  def self.set_passwd(login, passwd)
    conf = Conf.new
    htdigest = conf[:master, :authn, :htdigest]
    realm = conf[:master, :authn, :realm]

    htd = WEBrick::HTTPAuth::Htdigest.new(htdigest)
    htd.set_passwd(realm, login, passwd)
    htd.flush
  end

  # Delete a password for a user.
  # @param [String] login real_login of a user
  def self.delete_passwd(login)
    conf = Conf.new
    htdigest = conf[:master, :authn, :htdigest]
    realm = conf[:master, :authn, :realm]

    htd = WEBrick::HTTPAuth::Htdigest.new(htdigest)
    htd.delete_passwd(realm, login)
    htd.flush
  end

  private_class_method :store, :set_passwd, :delete_passwd
end

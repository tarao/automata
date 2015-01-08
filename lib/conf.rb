# coding: utf-8
require 'pathname'
require 'yaml'

require 'bundler/setup'
require 'kwalify'

class Conf
  SCHEMA = Pathname('../config/schema')
  FILES = {
    :master => 'master.yml',
    :local => 'local.yml',
    :scheme => 'scheme.yml',
    :template => 'template.yml',
  }

  # Create a conf object
  # @param conf_dir pathname to config files directory
  def initialize(conf_dir)
    @conf_dir = Pathname.new(conf_dir)
  end

  def [](*keys)
    @hash ||= Hash.new{|h,k|
      case k
      when 'master'
        o = load_yaml(@conf_dir+FILES[:master])
        verify_conf(o, :master)
        h[k] = o.merge(begin load_yaml(@conf_dir+FILES[:local]) rescue {} end)
      when 'scheme'
        h[k] = load_yaml(@conf_dir+FILES[:scheme])
      when 'template'
        o = load_yaml(@conf_dir+FILES[:template])
        h[k] = o.merge(begin load_yaml(@conf_dir+FILES[:local]) rescue {} end)
      else
        raise "unknown config file: #{k}"
      end
    }
    return keys.inject(@hash){|acc,key| (acc||{})[key.to_s]}
  end

  private
  def load_yaml(pathname)
    mode = RUBY_VERSION < '1.9.0' ? 'r' : 'r:utf-8'
    return File.open(pathname, mode){|f| YAML.load(f,pathname)}
  end

  def verify_conf(obj, name)
    def check(e, msg)
      raise e.inject(msg){|acc, e|
        acc += "[#{e.path}] #{e.message}\n"
      } if e && !e.empty?
    end
    schema = load_yaml(SCHEMA+FILES[name])
    check(Kwalify::MetaValidator.instance.validate(schema),
          "Internal error: schema '#{name}'\n")
    check(Kwalify::Validator.new(schema).validate(obj),
          "Config file error: '#{name}'\n")
  end
end

# -*- coding: utf-8 -*-
require 'yaml'
require 'fileutils'
require_relative '../syspath'
require_relative '../app'
require_relative '../score'
require_relative '../helper'
require_relative 'comment'
require_relative 'scheme'

module API
  # Usage:
  #   score action=get user[]=<login> report=<report>
  #   score action=post user[]=<login> report=<report>
  #   score action=template user[]=<login> report=<report>
  #   score action=tabulate
  # Actions:
  #   get       [type=raw|html] [id=<score-id>]
  #             スコアをrubyのハッシュデータを文字列化したものとして取得
  #   post      message=<content>
  #             スコアをrubyのハッシュデータを文字列化したものとして送信
  #   template
  #             各課題ごとに初期値が全てfalseのスコアを
  #             rubyのハッシュデータを文字列化したものとして取得
  #   tabulate
  #             「「課題毎の結果のハッシュにしたもの」を各課題ごとにハッシュにしたもの」
  #             をユーザ毎にハッシュにして結果を返す
  #             { user_0 => { report0 => { Ex0 => result, Ex1 => result, ... }, report1 => { ... }, ... },
  #               user_1 => { report0 => { Ex0 => result, Ex1 => result, ... }, report1 => { ... }, ... },
  #               ...
  #               user_n => ... }
  class Score
    def get_scores(app, report_ids, users)
      config = {
        'max' => 256,
        'size_limit' => 1024 * 16,
      }.merge(app.conf[:master, :score] || {})

      return Hash[*report_ids.map do |id|
                    s = users.map do |u|
                      dir = SysPath.score_dir(id, u)
                      FileUtils.mkdir_p(dir) unless dir.exist?
                      { 
                        user:    u,
                        score: ::Score.new(app.user.login, dir, config)
                      }
                    end
                    [id, s]
                  end.flatten(1)]
    end

    def call(env)
      helper = Helper.new(env)
      app = App.new(env['REMOTE_USER'])

      # permission check
      return helper.forbidden if !app.su?

      # action must be specified
      action = helper.params['action']
      return helper.bad_request unless action

      if action != 'tabulate' then
        # user must be specified
        users = helper.params['user']
        return helper.bad_request if users.nil? || users.empty?
  
        # user must be an array
        unless users.is_a?(Array)
          return helper.bad_request('user must be provided as user[]=<login>')
        end
  
        # resolve real login name in case user id is a token
        users = users.map { |u| app.user_from_token_or_login(u) }
        users.compact!
        return helper.bad_request if users.empty?
  
        # report ID must be specified
        report_id = helper.params['report']
        return helper.bad_request unless report_id
  
        # check the number of specified users
        if users.length != 1
          return helper.bad_request
        end
      end

      begin
        if action != 'tabulate' then
          report_ids = report_id ? [report_id] : app.conf[:scheme, :scheme].map{|r| r['id']}
          scores = get_scores(app, report_ids, users)
        end

        case action
        when 'get'
          type    = helper.params['type']
          id      = helper.params['id']
          args    = { type: type, id: id }
          
          content = scores[report_id][0][:score].retrieve(args)

          # Connect user names by login ids
          user_names = API::Comment.new.user_names_from_logins(content.map { |entry| entry['user'] })
          content = content.map { |entry| entry.merge(user_name: user_names[entry['user']]) }

          return helper.json_response(content)
        when 'post'
          # get ruby hash data as a string
          content = helper.params['message']

          scores[report_id][0][:score].add(content: content)
          return helper.ok('done')
        when 'template'
          scheme = app.conf[:scheme]

          exercise_names = scheme['report'][report_id].keys
          score_template = Hash.new(false)
          exercise_names.each { |key| score_template[key] = false }

          # respond ruby hash data as a string
          return helper.json_response(score_template.to_s)
        when 'tabulate'
          users = app.visible_users
          report_ids = app.conf[:scheme]['scheme'].map { |h| h['id'] }

          scores = get_scores(app, report_ids, users)

          content = Hash[*users.map do |u|
            is = Hash[*report_ids.map do |id|
              ss = scores[id].select{ |s| s[:user].login() == u.login() }
              return helper.bad_request if ss.length != 1
              score = ss[0]

              args = { type: 'raw', id: id }
              score_history = score[:score].retrieve(args)
              last_score = score_history.length > 0 ? score_history.last['content'] : ""
              [ id, last_score ]
            end.flatten(1)]
            [ u.login(), is ]
          end.flatten(1)]

          return helper.json_response(content)
        end
      end
    end
  end
end

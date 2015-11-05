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
  #   get       [type=raw|html]
  #             スコアをrubyのハッシュデータを文字列化したものとして取得
  #             typeのデフォルト値はhtml
  #   post      content=<content>
  #             スコアをrubyのハッシュデータを文字列化したものとして送信
  #   template
  #             各課題ごとに初期値が全てfalseのスコアを
  #             rubyのハッシュデータを文字列化したものとして取得
  #   tabulate
  #             「「課題(Exercise)毎の結果のハッシュにしたもの」を各課題(Report)ごとにハッシュにしたもの」
  #             をユーザ毎にハッシュにして結果を返す
  #             { user_0 => { report0 => { Ex0 => result, Ex1 => result, ... }, report1 => { ... }, ... },
  #               user_1 => { report0 => { Ex0 => result, Ex1 => result, ... }, report1 => { ... }, ... },
  #               ...
  #               user_n => ... }
  class Score
    def get_scores(app, report_ids, users)
      return Hash[*report_ids.map do |id|
                    s = users.map do |u|
                      dir = SysPath.score_dir(id, u)
                      FileUtils.mkdir_p(dir) unless dir.exist?
                      { 
                        user:    u,
                        score: ::Score.new(app.user.login, dir)
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
        user = helper.params['user']
        return helper.bad_request unless user

        # resolve real login name in case user id is a token
        user = app.user_from_token_or_login(user)
        return helper.bad_request unless user

        # report ID must be specified
        report_id = helper.params['report']
        return helper.bad_request unless report_id

        scores = get_scores(app, [report_id], [user])
      end

      begin
        case action
        when 'get'
          type    = helper.params['type'] || :html
          content = scores[report_id][0][:score].retrieve(type)

          # Connect user names by login ids
          user_names = ::User.user_names_from_logins(content.map { |entry| entry['user'] })
          content = content.map { |entry| entry.merge(user_name: user_names[entry['user']]) }

          return helper.json_response(content)
        when 'post'
          # get ruby hash data as a string
          content = helper.params['content']

          scores[report_id][0][:score].add(content)
          return helper.ok('done')
        when 'template'
          scheme = app.conf[:scheme]

          exercise_names = scheme['report'][report_id].keys
          score_template = Hash.new()
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
              if ss.length != 1 then
                app.logger.fatal('There are no score data.')
                return helper.bad_request
              end
              score = ss[0]

              score_history = score[:score].retrieve('raw')
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

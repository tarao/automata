#! /usr/bin/env ruby
# -*- coding: utf-8 -*-

# Usage: admin_log report=<report-id> user=<login> id=<log-id>
#   ログを変更
# Options:
#   status   ステータスを変更
#   message  メッセージを変更
#   error    エラーメッセージを変更
#   reason   エラーの詳細を変更
# Security:
#   master.su に入っているユーザのみ実行可能

require_relative '../../lib/app'
require_relative '../../lib/log'
require_relative '../../lib/helper'

module API
  class AdminLog
    LOGKEYS = [ 'message', 'error', 'reason' ]

    def call(env)
      helper = Helper.new(env)
      app = App.new(env['REMOTE_USER'])

      # reject request by normal users
      return helper.forbidden unless app.su?

      # user must be specified
      user = helper.param(:user)
      return helper.bad_request unless user

      # resolve real login name in case user id is a token
      user = app.user_from_token(user)
      return helper.bad_request unless user

      # report ID must be specified
      report_id = helper.param(:report)
      return helper.bad_request unless report_id

      # log ID must be specified
      log_id = helper.param(:id)
      return helper.bad_request unless log_id

      begin
        data = {}
        st = helper.param(:status)
        data['status'] = st if st

        data_log = {}
        LOGKEYS.each do |k|
          val = helper.param(k)
          data_log[k] = val if val
        end
        data['log'] = data_log

        unless data.empty?
          log_file = App::KADAI + report_id + user + App::FILES[:log]
          Log.new(log_file).transaction do |log|
            return helper.bad_request if log.latest(:data)['id'] != log_id
            log.update(:data, log_id, data)
          end
        end

        helper.ok('done')
      rescue => e
        helper.internal_server_error
        app.logger.error(e.to_s)
      end
    end
  end
end

Rack::Handler::CGI.run(API::AdminLog.new) if __FILE__ == $PROGRAM_NAME

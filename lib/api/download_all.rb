# -*- coding: utf-8 -*-

require 'zip'

require_relative '../syspath'
require_relative '../app'
require_relative '../user'
require_relative '../log'
require_relative '../helper'

module API
  # Usage: download_all report=<report-id> 
  #   提出ファイルのダウンロード
  class DownloadAll
    def call(env)
      helper = Helper.new(env)
      app = App.new(env['REMOTE_USER'])

      return helper.forbidden unless app.su?

      users = app.assigned_users
      STDERR.print users.to_s
      return helper.forbidden if users.nil?

      report_id = helper.params['report']
      return helper.bad_request unless report_id

      output = Zip::OutputStream.write_buffer do |zos|
        users.each do |user|
          time = Log.new(SysPath.user_log(report_id, user)).latest(:data)['id']
          if time
            Dir.chdir(SysPath.user_src_dir(report_id, user, time)) {
              zip(Pathname.new("."), zos, "#{user.login}_#{user.name}_#{time}/")
            }
          end
        end
      end.string

      header = {
        'Content-Type' => 'application/zip',
        'Content-Length' => output.length
      }
      helper.ok(output, header)
    end

    private

    def zip(entry, zos, uid)
      if entry.directory?
        entry.entries.select do |e|
          e.to_s != '.' && e.to_s != '..'
        end.each do |e|
          zip(entry+e, zos, uid)
        end
      else
        zos.put_next_entry(uid + entry.to_s)
        zos.write(entry.read)
      end
    end
  end
end

=begin
Copyright (c) 2008, Pat Sissons
All rights reserved.

Redistribution and use in source and binary forms, with or without modification,
are permitted provided that the following conditions are met:

    * Redistributions of source code must retain the above copyright notice, 
      this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright notice, 
      this list of conditions and the following disclaimer in the documentation 
      and/or other materials provided with the distribution.
    * Neither the name of the DHX Software nor the names of its contributors may
      be used to endorse or promote products derived from this software without 
      specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND 
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED 
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE 
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR 
ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES 
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; 
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON 
ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT 
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS 
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
=end

require 'timeout'
require 'open-uri'
require 'rss/1.0'
require 'rss/2.0'
require 'thread'

class Feed
    attr_accessor :id, :refresh_sec, :uri, :postdlcmd, :enabled

    def initialize(main, id, uri, opts=nil)
        @logger = LogManager.Instance
        @logger.ftrace {'ENTER'}
        @main = main
        @id = id
        @uri = uri
        @enabled = true
        if opts.nil?
            raise 'Catastrophic Failure!'
        else
            @refresh_sec = opts.length >= 1 ? opts[0].to_i * 60 : 30 * 60
            @postdlcmd = opts.length >= 2 ? opts[1] : nil
        end

        raise "Missing required URI for feed #{id}" if @uri.nil?

        @logger.info {"Setting Up Feed Timer for #{id} (#{@refresh_sec} Seconds)"}
        #setup timer event
        @timeout = conf['feed_timeout_seconds'].to_i
        timeout = @refresh_sec if timeout == 0
        Thread.new do
            while @enabled do
                begin
                    @logger.debug {"Sleeping for #{@refresh_sec} Seconds"}
                    sleep(@refresh_sec)
                    sync_refresh_feed
                rescue => e
                    @logger.error {"RSS Feed Error (#{@id}): #{e}"}
                end
            end
        end
        @logger.ftrace {'LEAVE'}
    end

    def cmd(show)
        shellcmd = nil
        @logger.ftrace {'ENTER'}
        if show.postdlcmd.nil?
            shellcmd = @postdlcmd.nil? ? conf['post_dl_cmd'] : @postdlcmd
            shellcmd.empty? ? nil : shellcmd
        else
            shellcmd = show.postdlcmd
        end
        @logger.ftrace {'LEAVE'}
        shellcmd
    end
    
    def conf
        ConfigFile.Instance
    end

    def read_feed
        @logger.ftrace {'ENTER'}
        ret = nil
        begin
            content = ''
            @logger.debug {"Reading RSS Feed for #{@id} (#{@uri})"}
            open(@uri) { |r| content = r.read }
            feed = RSS::Parser.parse(content, false)
            raise "Unable to parse RSS Feed for #{@id} (#{@uri})" if feed.nil?
            ret = feed
        rescue => e
            @logger.error {"RSS Feed Error (#{@id}): #{e}"}
            ret = nil
        end
        @logger.ftrace {'LEAVE'}
        ret
    end

    def sync_refresh_feed
        @logger.ftrace {'ENTER'}
        begin
            @logger.debug {"Performing Syncronized Feed Refresh"}
            @main.mut.synchronize { Timeout::timeout(@timeout) { refresh_feed } }
        rescue => e
            @logger.error {"RSS Feed Refresh Error (#{@id}): #{e}"}
        rescue Timeout::Error => e
            @logger.error {"RSS Feed Refresh Error (#{@id}): #{e}"}
        end
        @logger.ftrace {'LEAVE'}
        nil
    end

    def refresh_feed
        @logger.ftrace {'ENTER'}
        @logger.info {"Refreshing Feed for #{@id} (#{@uri})"}

        feed = read_feed
        return if feed.nil?

        @logger.info {"Found #{feed.items.length} Items, Processing..."}
        feed.items.each do |i|
            str = <<EOF
------------------------
RSS Feed Item
------------------------
[#{i.date}] #{i.title}
>> #{i.link}
#{i.description}
========================
EOF
            @logger.debug {str}
            @main.shows.each_value do |s|
                if s.belongs_to?(self)
                    @logger.debug {"#{s.id} Is Paired With #{@id}"}
                    dlpath = s.match(i)
                    unless dlpath.nil?
                        @logger.notice {"(#{@id}) Downloaded #{dlpath} (#{s.id})"}
                        shell_cmd = cmd(s)
                        unless shell_cmd.nil? or shell_cmd.empty?
                            torfile = File.basename(dlpath)
                            shell_cmd = shell_cmd.gsub('%T', dlpath).gsub('%t', torfile)
                            @logger.debug {"Executing `#{shell_cmd}`..."}
                            result = nil
                            Timeout::timeout(60) { result = `#{shell_cmd}` }
                            @logger.debug {"Returned [#{result}]"} unless result.nil?
                        end
                        break
                    end
                else
                    @logger.debug {"#{s.id} Isn't Paired With #{@id}"}
                end
            end
        end
        @logger.info { "Feed '#{@id}' Contains\r\n#{feed.items.map { |x| "\t#{x.title}" }.sort.join("\r\n")}" }
        @logger.info {'Done Processing Items'}
        @logger.ftrace {'LEAVE'}
        nil
    end

    def to_s
<<EOF
------------------------
Feed
------------------------
Feed    : #{@id}
Refresh : #{@refresh_sec} (Seconds)
URI     : #{@uri}
CMD     : #{@postdlcmd.nil? ? 'N/A' : @postdlcmd}
========================
EOF
    end
end


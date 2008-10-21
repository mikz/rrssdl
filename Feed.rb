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
    attr_accessor :id, :refresh_sec, :uri

    $mut = Mutex.new

    def initialize(main, id, uri, refresh_min)
        @main = main
        @id = id
        @refresh_sec = refresh_min.to_i * 60
        @uri = uri

        log(verbose, "Setting Up Feed Timer for #{id} (#{@refresh_sec} Seconds)")
        #setup timer event
        Thread.new do
            timeout = conf['feed_timeout_seconds'].to_i
            timeout = @refresh_sec if timeout == 0
            loop do
                sleep(@refresh_sec)
                Timeout::timeout(timeout) { $mut.syncronize { refresh_feed } }
            end
        end
    end
    
    def conf
        @main.conf
    end

    def debug
        @main.debug
    end

    def verbose
        @main.verbose
    end

    def log(level, text)
        @main.log(level, text)
    end

    def read_feed
        begin
            content = ''
            log(verbose, "Reading RSS Feed for #{@id} (#{@uri})")
            open(@uri) { |r| content = r.read }
            feed = RSS::Parser.parse(content, false)
            raise "Unable to parse RSS Feed for #{@id} (#{@uri})" if feed.nil?
            feed
        rescue => e
            log(true, "RSS Feed Error: #{e}")
            nil
        end
    end

    def refresh_feed
        log(verbose, "Refreshing Feed for #{@id} (#{@uri})")

        feed = read_feed
        return if feed.nil?

        log(verbose, "Found #{feed.items.length} Items, Processing...")
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
            log(debug, str)
            @main.shows.each_value do |s|
                if s.belongs_to?(self)
                    log(debug, "#{s.id} Is Paired With #{@id}")
                    s.match(i)
                else
                    log(debug, "#{s.id} Isn't Paired With #{@id}")
                end
            end
        end
        log(verbose, 'Done Processing Items')
    end

    def to_s
<<EOF
------------------------
Feed
------------------------
Feed    : #{id}
Refresh : #{refresh_sec} (Seconds)
URI     : #{uri}
========================
EOF
    end
end


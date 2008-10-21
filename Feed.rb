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


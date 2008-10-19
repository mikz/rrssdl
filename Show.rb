
class Show
    attr_accessor :id, :regex, :min_season, :min_episode, :feeds, :cur_season, :cur_episode

    def initialize(main, id, regex, min_season, min_episode, feeds)
        @main = main
        @id = id
        @regex = regex
        @min_season = @cur_season = min_season.to_i
        @min_episode = @cur_episode = min_episode.to_i
        @feeds = feeds.empty? ? nil : feeds.map { |f| main.feeds[f] }.compact
        @rxSeasonEp = conf.get_list('season_ep_regex')
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

    def belongs_to?(feed)
        log(debug, "Checking If Feed #{feed.id} Belongs to #{@id}")
        @feeds.nil? or @feeds.include?(feed)
    end

    def new_show?(title)
        log(debug, "Checking If '#{title}' Is A New Show")
        @rxSeasonEp.each do |rx|
            log(debug, "Matching '#{title}' with regex '#{rx}'")
            m = Regexp.new(rx, Regexp::IGNORECASE).match(title)
            unless m.nil?
                if  (m[1].to_i == @cur_season and m[2].to_i > @cur_episode) or m[1].to_i > @cur_season
                    log(verbose, "Found New Show For #{@id}: Season #{m[1]}, Episode #{m[2]}")
                    return m[1,2]
                else
                    log(debug, "'#{title}' Is Older Than Season #{@cur_season}, Episode #{@cur_episode}")
                end
            end
        end
        nil
    end

    def match(i)
        log(debug, "Matching '#{i.title}' With '#{@regex}'")
        m = Regexp.new(@regex, Regexp::IGNORECASE).match(i.title)
        unless m.nil?
            log(debug, "#{@id} matches '#{i.title}'")
            ep_info = new_show?(i.title)
            dlpath = nil
            if ep_info.nil?
                log(verbose, "WARNING: Couldn't Determin Season and Episode Info For '#{i.title}'")
                dlpath = File.join(File.expand_path(conf['download_path_review']), "REVIEW-#{i.title.gsub(/[^\w]/, '_')}.torrent")
            else
                @cur_season = ep_info[0].to_i
                @cur_episode = ep_info[1].to_i
                dlpath = File.join(File.expand_path(conf['download_path']), "#{i.title.gsub(/[^\w]/, '_')}.torrent")
                log(verbose, "Downloading Show '#{i.title}'")
            end
            download(i.link, dlpath)
        end
    end

    def download(uri, dlpath)
        begin
            log(verbose, "Downloading #{uri} to #{dlpath}")
            open(dlpath, 'w').write(open(uri).read)
        rescue => e
            log(true, "Download Error: #{e}")
        end
    end

    def load_state(si)
        return if si.length != 2
        log(debug, "Loading State For #{@id}: #{si.join(';')}")
        @cur_season = si[0].to_i
        @cur_episode = si[1].to_i
    end

    def get_state
        log(debug, "Saving State For #{@id}: #{@cur_season};#{@cur_episode}")
        "#{@cur_season};#{@cur_episode}"
    end

    def to_s
<<EOF
Show    : #{@id}
Regex   : #{@regex}
Season  : #{@cur_season} (#{@min_season})
Episode : #{@cur_episode} (#{@min_episode})
Feeds   : #{feeds.nil? ? 'ALL' : feeds.each_value.map { |f| f.id }.join(', ')}
EOF
    end
end


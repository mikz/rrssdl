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

require 'open-uri'
require 'timeout'

class Show
    attr_accessor :id, :regex, :min_season, :min_episode, :postdlcmd, :feeds, :cur_season, :cur_episode

    def initialize(main, id, regex, min_season, min_episode, opts)
        @main = main
        @main.logger.trace_enter
        @id = id
        @regex = regex
        @min_season = @cur_season = min_season.to_i
        @min_episode = @cur_episode = min_episode.to_i
        if opts.nil?
            raise 'Catastrophic Failure!'
        else
            @postdlcmd = opts.length >= 1 ? opts.shift : []
            @postdlcmd = nil if @postdlcmd.empty?
            @feeds = opts.empty? ? nil : opts.map { |f| main.feeds[f] }.compact
        end
        @main.logger.trace_leave
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

    def log(level, text, ts=true)
        @main.log(level, text, ts)
    end

    def belongs_to?(feed)
        @main.logger.trace_enter
        log(debug, "Checking If Feed #{feed.id} Belongs to #{@id}")
        ret = @feeds.nil? or @feeds.include?(feed)
        @main.logger.trace_leave
        ret
    end

    def rxmatch(rx, string)
        @main.logger.trace_enter
        log(debug, "Matching '#{string}' with regex '#{rx}'")
        ret = Regexp.new(rx, Regexp::IGNORECASE).match(string)
        @main.logger.trace_leave
        ret
    end

    def new_show?(title)
        @main.logger.trace_enter
        ret = nil
        log(debug, "Checking If '#{title}' Is A New Show")
        @main.rxSeasonEp.each do |rx|
            m = rxmatch(rx, title)
            if m.nil?
                log(debug, "#{id} didn't match #{title}")
            else
                log(debug, "#{id} Matches #{title}")
                if  (m[1].to_i == @cur_season and m[2].to_i > @cur_episode) or m[1].to_i > @cur_season
                    log(verbose, "Found New Show For #{@id}: Season #{m[1]}, Episode #{m[2]}")
                    ret = m[1,2]
                else
                    log(debug, "'#{title}' Is Older Than Season #{@cur_season}, Episode #{@cur_episode}")
                    ret = false
                end
            end
        end
        @main.logger.trace_leave
        ret
    end

    def reject(title)
        @main.logger.trace_enter
        ret = false
        log(debug, "Checking if '#{title}' should be rejected")
        @main.rxReject.each do |rx|
            m = rxmatch(rx, title)
            unless m.nil?
                log(debug, "'#{title}' is rejected")
                ret = true
            end
        end

        @main.logger.trace_leave
        ret
    end

    def match(i)
        @main.logger.trace_enter
        ret = nil
        log(debug, "Matching '#{i.title}' With '#{@regex}'")
        m = Regexp.new(@regex, Regexp::IGNORECASE).match(i.title)
        if m.nil?
            log(debug, "#{@id} doesn't match")
            ret = nil
        else
            log(debug, "#{@id} matches '#{i.title}'")
            ep_info = new_show?(i.title)
            dlpath = nil
            review = false
            if ep_info == false
                log(debug, "#{i.title} is old, skipping")
                ret = nil
            elsif ep_info.nil?
                log(verbose, "WARNING: Couldn't Determin Season and Episode Info For '#{i.title}'")
                dlpath = File.join(File.expand_path(conf['download_path_review']), "REVIEW-#{i.title.gsub(/[^\w]/, '_').gsub(/_+/, '_')}.torrent")
                review = true
            elsif reject(i.title)
                log(verbose, "'#{i.title}' Was Rejected")
                dlpath = File.join(File.expand_path(conf['download_path_review']), "REVIEW-#{i.title.gsub(/[^\w]/, '_').gsub(/_+/, '_')}.torrent")
                review = true
            else
                @cur_season = ep_info[0].to_i
                @cur_episode = ep_info[1].to_i
                dlpath = File.join(File.expand_path(conf['download_path']), "#{i.title.gsub(/[^\w]/, '_').gsub(/_+/, '_')}.torrent")
                log(verbose, "Downloading Show '#{i.title}'")
            end
            ret = nil
            Timeout::timeout(@main.torTimeout) { ret = download(i.link, dlpath) }
            ret = review ? nil : ret
        end
        @main.logger.trace_leave
        ret
    end

    def download(uri, dlpath)
        @main.logger.trace_enter
        ret = nil
        begin
            unless File.size?(dlpath).nil?
                log(verbose, "'#{dlpath}' already exists, not downloading")
                ret = nil
            end

            log(verbose, "Downloading #{uri} to #{dlpath}")
            File.open(dlpath, 'w') do |f| 
                f.write(open(uri).read)
                f.close 
            end
            ret = dlpath
        rescue => e
            log(true, "Download Error: #{e}")
            ret = nil
        end
        @main.logger.trace_leave
        ret
    end

    def load_state(si)
        @main.logger.trace_enter
        return if si.length != 2
        log(debug, "Loading State For #{@id}: #{si.join(';')}")
        @cur_season = si[0].to_i
        @cur_episode = si[1].to_i
        @main.logger.trace_leave
        nil
    end

    def get_state
        @main.logger.trace_enter
        log(debug, "State For #{@id}: #{@cur_season};#{@cur_episode}")
        "#{@cur_season};#{@cur_episode}"
        @main.logger.trace_leave
        nil
    end

    def to_s
<<EOF
------------------------
Show
------------------------
Show    : #{@id}
Regex   : #{@regex}
Season  : #{@cur_season} (#{@min_season})
Episode : #{@cur_episode} (#{@min_episode})
Feeds   : #{@feeds.nil? ? 'ALL' : @feeds.each_value.map { |f| f.id }.join(', ')}
========================
EOF
    end
end


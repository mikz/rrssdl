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

class ConfigFile
    attr_reader :conf
    attr_accessor :file

    $comment = Regexp.new('^#')
    $white   = Regexp.new('^\s*$')
    $kvpair  = Regexp.new('^\s*([^\+=]+)(\+?=)\s*(.*)$')

    @@instance = nil

    def initialize()
        @logger = LogManager.Instance
        @logger.ftrace {'ENTER'}
        @conf = Hash.new
        @logger.ftrace {'LEAVE'}
    end

    def ConfigFile.Instance
        @@instance = new unless @@instance
        @@instance
    end

    def init_params(params)
        @logger = Logger["screen"].nil? ? Logger.root : Logger["screen"]
        @file = params['file']

        @logger.debug {"Applying: #{params.each_key.map { |k| "#{k} => #{params[k]}" }.join(', ')}"}
        params.each_pair do |k,v|
            self[k] = v
        end

        read_file

        @logger.debug {"Re-applying: #{params.each_key.map { |k| "#{k} => #{params[k]}" }.join(', ')}"}
        params.each_pair do |k,v|
            self[k] = v
        end
    end

    def has_key?(key)
        @conf.has_key?(key)
    end

    def [](key)
        has_key?(key) ? @conf[key] : ''
    end

    def []=(key, value)
        @conf[key] = value
    end

    def each_key
        @conf.each_key { |k| yield k }
    end

    def get_list(id, delim=';')
        self[id].split(/#{delim}/).map { |x| x.strip }
    end

    def read_file
        begin
            @conf = Hash.new
            @logger.notice {"Reading Config File '#{@file}'"}
            lineno = 1
            unless File.exists?(File.expand_path(@file))
                @logger.warn {"Can't Find Config File '#{@file}', Creating..."}
                File.new(File.expand_path(@file), 'w')
            end
            File.open(File.expand_path(@file), 'r').each do |line|
                @logger.debug {"Line #{sprintf('%03d', lineno)}: #{line.chomp}"}
                unless $white.match(line) or $comment.match(line)
                    m = $kvpair.match(line)
                    if m.nil? or m.length != 4
                        @logger.warn {"WARNING: Incorrect Config Line Format (Line #{lineno})"}
                        @logger.debug {line}
                    else
                        k = m[1].strip.to_s
                        v = m[3].strip.to_s
                        assign = m[2] == '='
                        @logger.debug {assign ? "ASSIGNING #{k}" : "APPENDING TO #{k}"}
                        assign ? self[k] = v : self[k] += v
                        @logger.debug {"PAIR: #{k} = #{self[k]}"}
                    end
                end
                lineno += 1
            end
        rescue => e
            @logger.fatal {"Config Read Error: #{e}"}
            exit(-1)
        end
    end

    def write_file
        begin
            @logger.info {"Writing Config File '#{@file}'"}
            File.open(File.expand_path(@file), 'w') do |fd|
                lineno = 1
                @conf.each do |k,v|
                    line = "#{k} = #{v}\n"
                    @logger.debug {"Line #{sprintf('%03d', lineno)}: #{line}"}
                    fd.write(line)
                    lineno += 1
                end
            end
        rescue => e
            @logger.error {"Config Write Error: #{e}"}
        end
    end
end


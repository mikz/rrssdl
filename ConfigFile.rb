class ConfigFile
    attr_reader :conf
    attr_accessor :file

    $comment = Regexp.new('^#')
    $white   = Regexp.new('^\s*$')
    $kvpair  = Regexp.new('^\s*([^=]+)=\s*(.*)$')

    def initialize(main)
        @main = main
        @conf = Hash.new
    end

    def init_params(params)
        @file = params['file']

        params.each_pair do |k,v|
            self[k] = v
        end

        read_file

        params.each_pair do |k,v|
            self[k] = v
        end
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
            log(verbose, "Reading Config File '#{@file}'")
            lineno = 1
            File.open(File.expand_path(@file), 'r').each do |line|
                log(debug, "Line #{sprintf('%03d', lineno)}: #{line}")
                unless $white.match(line) or $comment.match(line)
                    m = $kvpair.match(line)
                    if m.nil? or m.length != 3
                        log(true, "WARNING: Incorrect Config Line Format (Line #{lineno})")
                    else
                        k = m[1].strip
                        v = m[2].strip
                        self[k] = v
                        log(debug, "PAIR: #{k.to_s} = #{v.to_s}")
                    end
                end
                lineno += 1
            end
        rescue => e
            log(true, "Config Read Error: #{e}")
        end
    end

    def write_file
        begin
            log(verbose, "Writing Config File '#{@file}'")
            File.open(File.expand_path(@file), 'w') do |fd|
                lineno = 1
                @conf.each do |k,v| 
                    line = "#{k} = #{v}\n"
                    log(debug, "Line #{sprintf('%03d', lineno)}: #{line}")
                    fd.write(line)
                    lineno += 1
                end
            end
        rescue => e
            log(true, "Config Write Error: #{e}")
        end
    end
end


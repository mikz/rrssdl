require 'thread'

class Logger
    def initialize(main)
        @main = main
        @mut = Mutex.new
    end

    def conf
        @main.conf
    end

    def log(level, text)
        @mut.synchronize do
            if level and not conf.nil?
                puts text unless conf.has_key?('quiet')
                if conf.has_key?('log_file')
                    begin
                        File.open(File.expand_path(conf['log_file']), 'a') do |f|
                            f.write("[#{Time.new.to_s}] #{text}\n")
                            f.close
                        end
                    rescue => e
                        warn "Log File Error: #{e}"
                    end
                end
            end
        end
    end
end

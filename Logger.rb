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

require 'thread'

class Logger
    def initialize(main)
        @main = main
        @mut = Mutex.new
    end

    def conf
        @main.conf
    end

    def log(level, text, ts=true)
        @mut.synchronize do
            log_screen(level, text, ts)
            log_file(level, text, ts)
        end
    end

    def log_screen(level, text, ts=true)
        if level and not conf.nil?
            puts "#{ts ? "[#{Time.new.to_s}] " : ''}#{text}" unless conf.has_key?('quiet')
        end
    end

    def log_file(level, text, ts=true)
        if not conf.nil? and (level or conf.has_key?('log_file_debug'))
            begin
                File.new(conf['log_file'], 'w') unless File.exists?(conf['log_file'])
                if File.writable?(conf['log_file'])
                    File.open(File.expand_path(conf['log_file']), 'a') do |f|
                        f.write("[#{Time.new.to_s}] ") if ts
                        f.write("#{text}\n")
                        f.close
                    end
                else
                    throw "'#{conf['log_file']}' is not writable"
                end
            rescue => e
                warn "Log File Error: #{e} (#{conf['log_file']}) -- #{text}"
            end
        end
    end
end

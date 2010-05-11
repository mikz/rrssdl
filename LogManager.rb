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

require 'log4r'
require 'log4r/configurator'
include Log4r

require 'ConfigFile.rb'

module Kernel
    private
    def methname
        caller[2] =~ /`([^']*)'/ and $1
    end
end

class LogManager
    private_class_method :new

    @@log4rconfig = 'log4r_config.xml'
    @@instance = nil
    $DEFAULT_LOG_CACHE_SIZE = 5

    def initialize
        create
        @hashes = Array.new
        @log_cache_size = $DEFAULT_LOG_CACHE_SIZE
    end

    def LogManager.Log4rConfig
        @@log4rconfig
    end

    def LogManager.Log4rConfig=(file)
        @@log4rconfig = file
    end

    def LogManager.Instance
        unless @@instance
            @@instance = new
            conf = ConfigFile.Instance
            @log_cache_size = conf['log_cache_size'] if conf.has_key?('log_cache_size')
        end
        @@instance
    end

    def cache(hash)
        while @hashes.length >= @log_cache_size
            @hashes.pop
        end
        @hashes.unshift(hash)
    end
    private :cache

    def create
        @logger = nil
        if File.exist?(@@log4rconfig)
            Configurator.load_xml_file(@@log4rconfig)
        else
            warn("*** WARNING: #{@@log4rconfig} not found")
        end
        @logger = Logger["screen::file"].nil? ? Logger.root : Logger["screen::file"]
    end

    def reload
        create
        conf = ConfigFile.Instance
        @log_cache_size = conf['log_cache_size'] if conf.has_key?('log_cache_size')
    end

    def ftrace(&block)
        @logger.ftrace { yield }
    end

    def debug(&block)
        #@logger.debug { yield }
    end

    def info(cachable = true, &block)
        str = yield
        hash = str.to_s.hash.to_i
        unless @hashes.include?(hash)
            @logger.debug { "'#{hash}' is NOT in {#{@hashes.join(',')}}" }
            @logger.info { cache(hash) if cachable; str }
        else
            @logger.debug { "'#{hash}' is in {#{@hashes.join(',')}}" }
        end
    end

    def notice(cachable = true, &block)
        str = yield
        hash = str.to_s.hash.to_i
        unless @hashes.include?(hash)
            @logger.debug { "'#{hash}' is NOT in {#{@hashes.join(',')}}" }
            @logger.notice { cache(hash) if cachable; str }
        else
            @logger.debug { "'#{hash}' is in {#{@hashes.join(',')}}" }
        end
    end

    def warn(cachable = true, &block)
        str = yield
        hash = str.to_s.hash.to_i
        unless @hashes.include?(hash)
            @logger.debug { "'#{hash}' is NOT in {#{@hashes.join(',')}}" }
            @logger.warn { cache(hash) if cachable; str }
        else
            @logger.debug { "'#{hash}' is in {#{@hashes.join(',')}}" }
        end
    end

    def error(&block)
        @logger.error { yield }
    end

    def fatal(&block)
        @logger.fatal { yield }
    end
end

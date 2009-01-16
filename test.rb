require 'log4r'
require 'log4r/configurator'
 
include Log4r

#dbg = Logger.new('log4r')
#dbg.outputters = Outputter.stdout
#dbg.outputters[0].formatter = PatternFormatter.new(:pattern => "[%6l %d] %c: %M")

Configurator.load_xml_file('log4r_config.xml')

log = Logger['screen::file']

msg = "WORK YOU PIECE OF SHIT!!!"

log.ftrace {msg}
log.debug  {msg}
log.info   {msg}
log.notice {msg}
log.warn   {msg}
log.error  {msg}
log.fatal  {msg}
log.trace  {msg}

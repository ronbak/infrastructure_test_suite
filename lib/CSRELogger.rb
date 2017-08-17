#!/usr/bin/env ruby
require 'logger'

class CSRELogger
  
  def set_stream (stream)
    # If this is a new CSRELogger, the log level will be unset.
    # So, set this to default to 0, which it will be instatiated with. 
    # Otherwise, save the current level before rebuilding our logging
    # object, then set the level back to what it was previously. 
    # This allows us to dynamically set streams and levels, independently.  
    current_log_level = 0
    if !@logger.nil?
      current_log_level = @logger.level
    end
    stream_temp = "#{stream}"
    stream = 'uri' unless !uri?(stream) 
    case stream 
    when 'STDOUT'
       @logger = Logger.new(STDOUT)
    when 'STDERR'
       @logger = Logger.new(STDERR)
    when 'uri' 
      #TODO Provide functionality to log to an end point
      puts stream_temp
    else  
      # Stream will be outut to disk, at path in string
      @logger = Logger.new(stream)
    end
    set_level(current_log_level)
    return @logger
  end

  def set_level(level)
    if level.is_a?(Integer)
      level = level_to_s(level)
    end
    case level
    when 'UNKNOWN'
      @logger.level = Logger::UNKNOWN
    when 'FATAL'
      @logger.level = Logger::FATAL
    when 'ERROR'
      @logger.level = Logger::ERROR
    when 'WARN'
      @logger.level = Logger::WARN
    when 'INFO'
      @logger.level = Logger::INFO
    when 'DEBUG'
      @logger.level = Logger::DEBUG
    end 
  end

  def level_to_s(level)
    levels = {0 => 'DEBUG', 1 => 'INFO', 2 => 'WARN', 3 => 'ERROR', 4 => 'FATAL', 5 => 'UNKNOWN'}
    return levels[level]
  end

  def get_level()
    return level_to_s(@logger.level)
  end

  def set_format()
    @logger.formatter = proc do |severity, datetime, progname, msg|
      "#{severity} #{progname} #{datetime}: #{msg}\n"
    end
  end

  def initialize (level = 'INFO', stream = 'STDOUT')
    $stdout.sync = true unless !stream.eql?('STDOUT')
    @logger = nil
    @logger = set_stream(stream)
    level = ENV['CSRE_LOG_LEVEL'] unless ENV['CSRE_LOG_LEVEL'].nil?
    set_level(level)
    set_format()
  end

  def info(message)
    @logger.info(message)
  end

  def unknown(message)
    @logger.unknown(message)
  end

  def fatal(message)
    @logger.fatal(message)
  end

  def error(message)
    @logger.error(message)
  end

  def warn(message)
    @logger.warn(message)
  end

  def debug(message)
    @logger.debug(message)
  end
end 

# ExampleUsage:
# log_level = 'INFO'
# log_level = ENV['CSRE_LOG_LEVEL'] unless ENV['CSRE_LOG_LEVEL'].nil?
# @csrelog = CSRELogger.new(log_level, 'STDOUT')
# @csrelog.info("This is an info log message")
# @csrelog.debug("This is a debug log message")
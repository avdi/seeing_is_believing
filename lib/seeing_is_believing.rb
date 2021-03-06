require 'tmpdir'

require 'seeing_is_believing/result'
require 'seeing_is_believing/version'
require 'seeing_is_believing/debugger'
require 'seeing_is_believing/wrap_expressions_with_inspect'
require 'seeing_is_believing/hash_struct'
require 'seeing_is_believing/evaluate_by_moving_files'
require 'seeing_is_believing/event_stream/handlers/debug'
require 'seeing_is_believing/event_stream/handlers/update_result'

class SeeingIsBelieving
  class Options < HashStruct
    predicate(:event_handler)     { EventStream::Handlers::UpdateResult.new Result.new }
    attribute(:filename)          { nil }
    attribute(:encoding)          { nil }
    attribute(:stdin)             { "" }
    attribute(:require_files)     { ['seeing_is_believing/the_matrix'] }
    attribute(:load_path_dirs)    { [File.expand_path('..', __FILE__)] }
    attribute(:timeout_seconds)   { 0 }
    attribute(:debugger)          { Debugger::Null }
    attribute(:max_line_captures) { Float::INFINITY }
    attribute(:rewrite_code)      { WrapExpressionsWithInspect }
    attribute(:port)              { 5158 }
  end

  def self.call(*args)
    new(*args).call
  end

  attr_reader :options
  def initialize(program, options={})
    @program = program
    @program += "\n" unless @program.end_with? "\n"
    @options = Options.new options
  end

  def call
    @memoized_result ||= Dir.mktmpdir("seeing_is_believing_temp_dir") { |dir|
      filename    = options.filename || File.join(dir, 'program.rb')
      new_program = options.rewrite_code.call @program

      options.debugger.context("REWRITTEN PROGRAM") { new_program }

      EvaluateByMovingFiles.call \
        new_program,
        filename,
        event_handler:     event_handler(options.debugger, options.event_handler),
        provided_input:    options.stdin,
        require_files:     options.require_files,
        load_path_dirs:    options.load_path_dirs,
        encoding:          options.encoding,
        timeout_seconds:   options.timeout_seconds,
        max_line_captures: options.max_line_captures,
        port:              options.port

      options.event_handler
    }
  end

  private

  # If we need debugging, wrap a debugging handler around the current handler
  def event_handler(debugger, current_handler)
    return current_handler unless debugger.enabled?
    EventStream::Handlers::Debug.new debugger, current_handler
  end
end

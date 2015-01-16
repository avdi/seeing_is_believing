require 'seeing_is_believing/code'
require 'seeing_is_believing/binary/data_structures'
require 'seeing_is_believing/binary/remove_annotations'

class SeeingIsBelieving
  module Binary
    class MustEvaluateFirst < SeeingIsBelievingError
      def initialize(method)
        super "Cannot call #{method} on engine until it has evaluated the program."
      end
    end

    class Engine
      def initialize(config)
        self.config = config
      end

      def missing_newline?
        @missing_newline ||= !config.body.end_with?("\n")
      end

      def syntax_error?
        code.syntax.invalid?
      end

      def syntax_error
        return unless syntax_error?
        # TODO: rename SyntaxErrorMessage so doesn't look like an exception
        SyntaxError.new(line_number: code.syntax.line_number,
                        explanation: code.syntax.error_message,
                        filename:    config.lib_options.filename)
      end

      def prepared_body
        @prepared_body ||= begin
          body_with_nl = config.body
          body_with_nl += "\n" if missing_newline?
          config.annotator.prepare_body body_with_nl, config.markers
        end
      end

      # kinda dumb, the prepared_body is really the cleaned body
      # but b/c of the newline thing, have to keep them separate
      # (when bin wangs cleaned_body, it wants consistente newlines,
      # but when we want it in here, we always want a newline)
      # so either come up with a better name for this method
      # or a better name for prepared_body
      def cleaned_body
        @cleaned_body ||= if missing_newline?
                            prepared_body.chomp!
                          else
                            prepared_body
                          end
      end

      def evaluate!
        @evaluated || begin
          @results   = SeeingIsBelieving.call prepared_body, config.lib_options.to_h
          @timed_out = false
          @evaluated = true
        end
      rescue Timeout::Error
        @timed_out = true
        @evaluated = true
      ensure return self unless $! # idk, maybe too tricky, but was really annoying putting it in three places
      end

      def results
        @results || raise(MustEvaluateFirst.new __method__)
      end

      def timed_out?
        @evaluated || raise(MustEvaluateFirst.new __method__)
        @timed_out
      end

      def annotated_body
        @annotated_body ||= begin
          @evaluated || raise(MustEvaluateFirst.new __method__)
          annotated = config.annotator.call prepared_body,
                                            results,
                                            config.annotator_options.to_h
          annotated.chomp! if missing_newline?
          annotated
        end
      end

      def unexpected_exception
        @evaluated || raise(MustEvaluateFirst.new __method__)
        @unexpected_exception
      end

      def unexpected_exception?
        @evaluated || raise(MustEvaluateFirst.new __method__)
        !!unexpected_exception
      end

      private

      attr_accessor :config

      def code
        @code ||= Code.new(prepared_body, config.filename)
      end
    end
  end
end

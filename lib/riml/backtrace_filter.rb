require File.expand_path('../environment', __FILE__)

module Riml
  class BacktraceFilter
    include Riml::Environment

    RIML_INTERNAL_FILE_REGEX = /#{ROOTDIR}/

    attr_reader :error

    def initialize(error)
      @error = error
    end

    def filter!(first_i = 0, last_i = -1)
      if first_i < 0
        raise ArgumentError, "first argument must be >= 0"
      end
      if last_i > 0 && first_i > last_i
        raise ArgumentError, "first index must come before (or be equal to) last index"
      end

      # check if `responds_to?(:debug)` because we don't want to have to require 'riml.rb'
      # just for this
      unless Riml.respond_to?(:debug) && Riml.debug
        add_to_head = @error.backtrace[0...first_i] || []
        add_to_tail = @error.backtrace[last_i...-1] || []
        backtrace = @error.backtrace[first_i..last_i] || []
        backtrace.delete_if { |loc| RIML_INTERNAL_FILE_REGEX =~ loc }
        @error.set_backtrace(add_to_head + backtrace + add_to_tail)
      end
    end

  end
end

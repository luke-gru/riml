module Riml
  class BacktraceFilter
    attr_reader :error

    def initialize(error)
      @error = error
    end

    def filter!
      error.backtrace.clear
    end

  end
end

module Riml
  # Thread-safe output buffer. Used internally for all Riml warnings. Only
  # one of these objects exists during compile.
  class WarningBuffer
    # This class acts as a singleton, so no instance-level mutexes are
    # required. This facilitates locking both class and instance
    # methods with a single mutex.
    WRITE_LOCK = Mutex.new
    WARNING_FMT = "Warning: %s"

    class << self
      def stream=(stream)
        WRITE_LOCK.synchronize { @stream = stream }
      end
      attr_reader :stream
    end

    # default stream
    @stream = $stderr

    attr_reader :buffer

    def initialize(*warnings)
      @buffer = warnings
    end

    def <<(warning)
      WRITE_LOCK.synchronize { buffer << warning }
    end
    alias push <<

    def flush
      WRITE_LOCK.synchronize do
        stream = self.class.stream
        buffer.each { |w| stream.puts WARNING_FMT % w }
        buffer.clear
        stream.flush
      end
    end

    def clear
      WRITE_LOCK.synchronize { buffer.clear }
    end

  end
end

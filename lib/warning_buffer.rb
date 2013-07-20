module Riml
  class WarningBuffer
    BUFFER_WRITE_LOCK = Mutex.new
    WARNING_FMT = "Warning: %s"

    class << self
      def stream=(stream)
        BUFFER_WRITE_LOCK.synchronize { @stream = stream }
      end
      attr_reader :stream
    end

    # default stream
    self.stream = $stderr

    attr_reader :buffer

    def initialize(*warnings)
      @buffer = warnings
    end

    def <<(warning)
      BUFFER_WRITE_LOCK.synchronize { buffer << warning }
    end
    alias push <<

    def flush
      BUFFER_WRITE_LOCK.synchronize do
        stream = self.class.stream
        buffer.each { |w| stream.puts WARNING_FMT % w }
        buffer.clear
        stream.flush
      end
    end

    def clear
      BUFFER_WRITE_LOCK.synchronize { buffer.clear }
    end

  end
end

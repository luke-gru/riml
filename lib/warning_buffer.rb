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
      @buffer = []
      buffer.concat warnings
    end

    def <<(warning)
      BUFFER_WRITE_LOCK.synchronize { buffer << warning }
    end
    alias push <<

    def flush
      BUFFER_WRITE_LOCK.synchronize do
        stream = self.class.stream
        buffer.each { |w| stream.puts WARNING_FMT % w }
        clear
        stream.flush
      end
    end

    def clear
      buffer.clear
    end

  end
end

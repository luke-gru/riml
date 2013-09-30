require 'set'

module Riml
  class IncludeCache

    def initialize
      @cache = {}
      @locked = Set.new
    end

    WRITE_LOCK = Mutex.new

    # `fetch` can be called recursively in the `yield`ed block, so must
    # make sure not to try to lock a Mutex if it's already locked, as this
    # would result in a deadlock.
    def fetch(included_filename)
      if source = @cache[included_filename]
        return source
      end

      if WRITE_LOCK.locked? && @locked.include?(Thread.current)
        @cache[included_filename] = yield
      else
        ret = nil
        @cache[included_filename] = WRITE_LOCK.synchronize do
          @locked << Thread.current
          ret = yield
        end
        @locked.delete(Thread.current)
        ret
      end
    end

    def [](included_filename)
      @cache[included_filename]
    end

    # `clear` should only be called by the main thread that is using the
    # `Riml.compile_files` method.
    def clear
      WRITE_LOCK.synchronize { @cache.clear }
      self
    end
  end
end

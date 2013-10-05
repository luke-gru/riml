module Riml
  class IncludeCache

    def initialize
      @cache = {}
      @m = Mutex.new
      # Only Ruby 2.0+ has Mutex#owned? method
      @owns_lock = nil
    end

    # `fetch` can be called recursively in the `yield`ed block, so must
    # make sure not to try to lock a Mutex if it's already locked, as this
    # would result in a deadlock.
    def fetch(included_filename)
      if source = @cache[included_filename]
        return source
      end

      if @m.locked? && @owns_lock == Thread.current
        @cache[included_filename] = yield
      else
        ret = nil
        @cache[included_filename] = @m.synchronize do
          begin
            @owns_lock = Thread.current
            ret = yield
          ensure
            @owns_lock = nil
          end
        end
        ret
      end
    end

    def [](included_filename)
      @m.synchronize { @cache[included_filename] }
    end

    # `clear` should only be called by the main thread that is using the
    # `Riml.compile_files` method.
    def clear
      @m.synchronize { @cache.clear }
      self
    end
  end
end

module Riml
  class IncludeCache

    def initialize
      @cache = {}
      @m = Mutex.new
      # TODO: Ruby 2.0+ has Mutex#owned? method
      @owns_lock = nil
    end

    # `fetch` can be called recursively in the `yield`ed block, so must
    # make sure not to try to lock the Mutex if it's already locked by the
    # current thread.
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

    # Not used internally but might be useful as an API
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

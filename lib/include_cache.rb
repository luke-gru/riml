module Riml
  class IncludeCache

    def initialize
      @cache = {}
      @thread_mutex_map = { Thread.current => Mutex.new }
    end

    # `fetch` can be called recursively in the `yield`ed block, so must
    # make sure not to try to lock a Mutex if it's already locked, as this
    # would result in a deadlock. This is why per-thread Mutex objects are
    # used as well.
    def fetch(included_filename)
      if source = @cache[included_filename]
        return source
      end

      m = (@thread_mutex_map[Thread.current] ||= Mutex.new)

      if m.locked?
        @cache[included_filename] = yield
      else
        @cache[included_filename] = m.synchronize { yield }
      end
    end

    def [](included_filename)
      @cache[included_filename]
    end

    # `clear` should only be called by the main thread that is using the
    # `Riml.compile_files` method.
    def clear
      @thread_mutex_map[Thread.current].synchronize { @cache.clear }
      self
    end
  end
end

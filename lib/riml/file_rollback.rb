require 'set'

module Riml
  class FileRollback
    @files_created = Set.new
    # { 'main.vim' => nil, 'existed.vim' => "\nsource code..." }
    @previous_file_states = {}
    @guarding = 0
    @m = Mutex.new

    # NOTE: Used only in main thread.
    # Only call this method in one thread at a time. It's okay if
    # `&block` launches threads, and they compile files though.
    def self.guard(&block)
      @guarding += 1
      if block
        block.call
      # to increase `@guarding` only, for use with FileRollback.trap()
      else
        return
      end
    rescue
      rollback!
      raise
    ensure
      if block
        @guarding -= 1
        if @guarding == 0
          clear
        end
      end
    end

    def self.trap(*signals, &block)
      signals.each do |sig|
        Signal.trap(sig) do
          if @guarding > 0
            rollback!
            block.call if block
          end
        end
      end
    end

    def self.creating_file(full_path)
      @m.synchronize do
        return unless @guarding > 0
        previous_state = File.file?(full_path) ? File.read(full_path) : nil
        @previous_file_states[full_path] ||= previous_state
        @files_created << full_path
      end
    end

    private

    def self.clear
      @m.synchronize do
        @previous_file_states.clear
        @files_created.clear
      end
    end

    def self.rollback!
      @m.synchronize do
        @files_created.each do |path|
          rollback_file!(path)
        end
        @previous_file_states.clear
        @files_created.clear
      end
    end

    def self.rollback_file!(file_path)
      if !@previous_file_states.key?(file_path)
        return false
      end
      prev_state = @previous_file_states[file_path]
      if prev_state.nil?
        File.delete(file_path) if File.exists?(file_path)
      else
        File.open(file_path, 'w') { |f| f.write(prev_state) }
      end
      prev_state
    end
  end
end

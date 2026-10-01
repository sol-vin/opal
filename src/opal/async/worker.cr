module Opal
  module Async
    enum WorkerState
      Pending
      Running
      Completed
      Cancelled
      Error
    end

    # Background asynchronous worker fiber inspired by Python Textual Workers.
    # Executes long-running tasks concurrently without blocking terminal rendering or freezing input.
    class Worker
      getter name : String
      getter state : WorkerState = WorkerState::Pending
      getter progress : Float64 = 0.0
      getter error : Exception? = nil
      getter? cancelled : Bool = false
      getter result : (String | Int32 | Int64 | Float64 | Bool | Nil) = nil

      @on_progress : Proc(Float64, Nil)? = nil
      @on_complete : Proc(Nil)? = nil
      @on_error : Proc(Exception, Nil)? = nil

      def initialize(@name : String = "worker", &@work : Worker -> (String | Int32 | Int64 | Float64 | Bool | Nil))
      end

      def on_progress(&block : Float64 -> Nil) : self
        @on_progress = block
        self
      end

      def on_complete(&block : -> Nil) : self
        @on_complete = block
        self
      end

      def on_error(&block : Exception -> Nil) : self
        @on_error = block
        self
      end

      # Called by the worker block to report incremental completion percentage (0.0 to 1.0)
      def report_progress(p : Float64) : Nil
        @progress = p.clamp(0.0, 1.0)
        @on_progress.try(&.call(@progress))
      end

      # Requests worker cancellation
      def cancel : self
        @cancelled = true
        @state = WorkerState::Cancelled
        self
      end

      # Spawns background execution fiber
      def start : self
        return self unless @state.pending?

        @state = WorkerState::Running
        spawn do
          begin
            if @cancelled
              @state = WorkerState::Cancelled
            else
              @result = @work.call(self)
              if @cancelled
                @state = WorkerState::Cancelled
              else
                @state = WorkerState::Completed
                @on_complete.try(&.call)
              end
            end
          rescue ex : Exception
            @error = ex
            @state = WorkerState::Error
            @on_error.try(&.call(ex))
          end
        end
        self
      end
    end

    # Factory helper to spawn and start a worker
    def self.run_worker(name : String = "worker", &block : Worker -> (String | Int32 | Int64 | Float64 | Bool | Nil)) : Worker
      w = Worker.new(name, &block)
      w.start
      w
    end
  end
end


require "monitor"

module God
  module Conditions
    # Trigger when a process exits.
    #
    #     +pid_file+ is the pid file of the process in question. Automatically
    #                populated for Watches.
    #
    # Examples
    #
    #   # Trigger if process exits (from a Watch).
    #   on.condition(:process_exits)
    #
    #   # Trigger if process exits (non-Watch).
    #   on.condition(:process_exits) do |c|
    #     c.pid_file = "/var/run/mongrel.3000.pid"
    #   end
    class ProcessExits < EventCondition
      # The String PID file location of the process in question. Automatically
      # populated for Watches.
      attr_accessor :pid_file

      def initialize
        @pids = []
        @mon = Monitor.new
        self.info = "process exited"
      end

      def valid?
        true
      end

      def pid
        self.pid_file ? File.read(self.pid_file).strip.to_i : self.watch.pid
      end

      def register
        @mon.synchronize do
          current_pid = self.pid
          @pids << current_pid
          #applog(self.watch, :info, "added current_pid #{current_pid} to @pids -> #{@pids.inspect}")

          begin
            EventHandler.register(current_pid, :proc_exit) do |extra|
              formatted_extra = extra.size > 0 ? " #{extra.inspect}" : ""
              self.info = "process #{current_pid} exited#{formatted_extra}"
              self.watch.trigger(self)
            end

            msg = "#{self.watch.name} registered 'proc_exit' event for pid #{current_pid}"
            applog(self.watch, :info, msg)
          rescue StandardError
            raise EventRegistrationFailedError.new
          end
        end
      end

      def deregister
        @mon.synchronize do
          current_pid = self.pid
          if !current_pid && @pids.empty? then
            pid_file_location = self.pid_file || self.watch.pid_file
            applog(self.watch, :error, "#{self.watch.name} could not deregister: no cached PIDs or PID file #{pid_file_location} (#{self.base_name})")
            return
          end

          all_pids = [current_pid, @pids].flatten.sort.uniq
          #applog(self.watch, :info, "removing all pids #{all_pids.inspect}")
          all_pids.each do |pid|
            EventHandler.deregister(pid, :proc_exit)
            msg = "#{self.watch.name} deregistered 'proc_exit' event for pid #{pid}"
            applog(self.watch, :info, msg)
          end
          @pids.clear
        end
      end
    end

  end
end

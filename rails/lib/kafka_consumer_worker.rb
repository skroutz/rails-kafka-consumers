require "sd_notify"
require "systemd-daemon"

# A wrapper around {KafkaConsumer} that processes messages in a
# loop. It integrates with systemd and facilitates spawning consumers as
# as long-running processes.
#
# @see {KafkaConsumer}
class KafkaConsumerWorker
  # @param consumer [KafkaConsumer]
  def initialize(consumer)
    @consumer = consumer
    @watchdog = SystemdDaemon::Notify.watchdog?
  end

  # Implements the consume-process loop.
  def work
    Signal.trap("TERM") { trigger_shutdown }
    Signal.trap("INT")  { trigger_shutdown }

    SdNotify.ready
    set_status("Spawned")

    Rails.logger.tagged("kafka", "consumer", @consumer.to_s) do
      Rails.logger.warn "Started consuming '#{@consumer.topic}'..."

      begin
        loop do
          watchdog_ping
          break if @shutdown

          msg = @consumer.process_next(4)
          if msg.nil?
            set_status("Working (consume timeout)...")
            next
          end

          @offset = msg.offset
          @partition = msg.partition

          # throttle a bit
          set_status("Working...") if (@offset % 10).zero?
        end
      ensure
        @consumer.shutdown
      end

      Rails.logger.warn "Bye"
    end

    # so that systemd does not consider us failed
    exit 0
  end

  def trigger_shutdown
    @shutdown = true
    SdNotify.stopping
    set_status("Shutting down...")
  end

  private

  def set_status(x)
    SdNotify.status(
      "#{@consumer} (offset=#{@offset},partition=#{@partition}) | " \
      "#{Time.now.strftime('%H:%M:%S')} #{x}")

    Process.setproctitle("consumer=#{@consumer} #{x}")
  end

  def watchdog_ping
    SdNotify.watchdog if @watchdog
  end
end

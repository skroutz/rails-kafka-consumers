require "statsd"

STATSD = Statsd.new("localhost", 9125)

# Abstract class meant to be subclassed by concrete Kafka consumer
# implementations. It provides every consumer integration with statsd and
# can also provide many other integrations in the future (Sentry, honeycomb etc.)
#
# @abstract
#
# @see {SampleConsumer}
class KafkaConsumer
  attr_reader :group, :id, :client

  @topic = nil

  class << self
    attr :topic

    # @raise [RuntimeError] if topic is blank
    def set_topic(t)
      raise "Topic #{t.inspect} is invalid" if t.blank?

      @topic = t
    end
  end

  # @param group [String] kafka consumer group
  # @param id [String] consumer id
  # @param rafka_opts [Hash]
  #
  # @raise [RuntimeError] if {.set_topic} has not been called
  def initialize(group, id, rafka_opts)
    if self.class.topic.blank?
      raise "Topic for #{self.class} should be set using `set_topic`"
    end

    @group = group
    @id = id

    rafka_opts = rafka_opts.merge(topic: self.class.topic, group: @group, id: @id)
    @client = Rafka::Consumer.new(rafka_opts)
  end

  # @abstract
  #
  # @param msg [Rafka::Message]
  def process(msg)
    raise "Implement me!"
  end

  # @return [String]
  def topic
    self.class.topic
  end

  def to_s
    "#{group}:#{id}"
  end

  # Consumes a message and processes it.
  #
  # @param timeout [Fixnum] number of seconds to wait for a message before
  #   retrying
  #
  # @return [Rafka::Message, nil]
  def process_next(timeout)
    client.consume(timeout) do |msg|
      begin
        # record timing statistics to some backend (eg. statsd)
        STATSD.time("kafka.consumer.process.#{self.class}") do
          process(msg)
        end
      rescue => e
        # ...report the exception to a backend (eg. Sentry)
        raise e
      end
    end
  end

  # Terminates the consumer and the connection to Rafka.
  def shutdown
    client.close
  end
end

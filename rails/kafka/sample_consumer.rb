# A sample consumer implementation.
#
# @note Class names must end with "Consumer" and inherit from {KafkaConsumer}
#
# @see {KafkaConsumer}
class SampleConsumer < KafkaConsumer
  # Must be called and it declares which topic is going to be
  # consumed
  #
  # @note not calling {.set_topic} will result in an exception when the
  #   consumer is initialized
  set_topic "greetings"

  # The main work method. It must be defined and it's going to be called in a
  # loop while messages are received from the topic.
  #
  # @param msg [Rafka::Message]
  def process(msg)
    puts "Consumed #{msg.value.inspect}"
  end
end

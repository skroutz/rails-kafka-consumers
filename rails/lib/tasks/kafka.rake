namespace :kafka do
  desc "Spawn a consumer instance. The name and instance " \
       "should be provided as an argument. For example "   \
       "rake kafka:consumer[<name>:<instance>]"
  task :consumer, [:name_and_instance] => :environment do |t, args|
    abort "Error: No argument provided" if args[:name_and_instance].blank?

    parts = args[:name_and_instance].split(":")
    if parts.size != 2
      abort "Error: Malformed argument #{args[:name_and_instance]}"
    end

    name, instance = parts

    consumer_group = "myapp-#{name}"
    consumer_id    = "#{`hostname`.strip}-#{name}-#{instance}"

    consumer = "#{name}_consumer".classify.constantize.new(consumer_group, consumer_id)

    KafkaConsumerWorker.new(consumer).work
  end
end

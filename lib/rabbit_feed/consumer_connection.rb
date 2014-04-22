module RabbitFeed
  class ConsumerConnection < Connection

    SUBSCRIPTION_OPTIONS = {
      consumer_tag: Socket.gethostname, # Use the host name of the server
      ack:          true, # Manually acknowledge messages once they've been processed
      block:        true, # Block the thread whilst consuming from the queue
    }.freeze

    def self.consume &block
      open do |connection|
        connection.consume(&block)
      end
    end

    def consume &block
      RabbitFeed.log.debug "Consuming messages on #{self.to_s} from queue: #{RabbitFeed.configuration.queue}..."

      queue.channel.prefetch(1) # Fetch one message at a time to preserve order
      queue.subscribe(SUBSCRIPTION_OPTIONS) do |delivery_info, properties, payload|
        RabbitFeed.log.debug "Message received on #{self.to_s} from queue: #{RabbitFeed.configuration.queue}..."

        begin
          yield payload
        rescue => e
          # Tell rabbit that we were unable to process the message
          # This will re-queue the message
          queue.channel.nack(delivery_info.delivery_tag, false, true) if connection.open?

          RabbitFeed.log.error "Exception encountered while consuming message on #{self.to_s}: #{e.message} #{e.backtrace}"
          Airbrake.notify e
          raise
        end
        queue.channel.ack(delivery_info.delivery_tag)

        RabbitFeed.log.debug "Message acknowledged on #{self.to_s} from queue: #{RabbitFeed.configuration.queue}..."
      end
    end

    def initialize
      super
      queue.bind(RabbitFeed.configuration.exchange)
    end

    private

    QUEUE_OPTIONS = {
      durable:    true,  # Persist across server restart
      no_declare: false, # Create the queue if it does not exist
      arguments:  {'x-ha-policy' => 'all'}, # Apply the queue on all mirrors
    }.freeze

    def queue
      @connection.queue RabbitFeed.configuration.queue, QUEUE_OPTIONS
    end
  end
end

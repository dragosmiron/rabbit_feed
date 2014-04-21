module RabbitFeed
  class ProducerConnection < Connection

    PUBLISH_OPTIONS = {
      persistent: true, # Persist the message to disk
      mandatory:  true, # Return the message if it can't be routed to a queue
    }.freeze

    def self.publish message, routing_key=nil
      open do |connection|
        connection.publish message, routing_key
      end
    end

    def publish message, routing_key=nil
      RabbitFeed.log.debug "Publishing message on #{self.to_s} with key: #{routing_key} to exchange: #{configuration.exchange}..."

      exchange.publish message, PUBLISH_OPTIONS.merge(routing_key: routing_key)
    end

    def initialize configuration
      super
      exchange.on_return do |return_info, properties, content|
        RabbitFeed::ProducerConnection.handle_returned_message return_info, content
      end
    end

    def close
      @exchange = nil
      super
    end

    def self.handle_returned_message return_info, content
      RabbitFeed.log.error "Handling returned message on #{self.to_s} details: #{return_info}..."
      Airbrake.notify (Error.new return_info)
    end

    private

    EXCHANGE_OPTIONS = {
      type:       :topic, # Allow wildcard routing keys
      durable:    true,   # Persist across server restart
      no_declare: false,  # Create the exchange if it does not exist
    }.freeze

    def exchange
      @exchange ||= connection.exchange configuration.exchange, EXCHANGE_OPTIONS
    end
  end
end

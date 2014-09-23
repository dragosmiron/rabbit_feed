require 'spec_helper'

module RabbitFeed
  describe ConsumerConnection do
    let(:bunny_queue)      { double(:bunny_queue, bind: nil, subscribe: nil)}
    let(:bunny_channel)    { double(:bunny_channel, prefetch: nil, nack: nil, ack: nil, queue: bunny_queue)}
    let(:bunny_connection) { double(:bunny_connection, start: nil, closed?: false, close: nil, create_channel: bunny_channel) }
    before do
      allow(Bunny).to receive(:new).and_return(bunny_connection)
      allow(bunny_queue).to receive(:channel).and_return(bunny_channel)
    end
    subject{ described_class.new bunny_channel }

    describe '#new' do
      before do
        EventRouting do
          accept_from('rabbit_feed') do
            event('test') {|event|}
          end
        end
      end

      it 'binds the queue to the exchange' do
        expect(bunny_queue).to receive(:bind).with('rabbit_feed_exchange', { routing_key: 'test.rabbit_feed.test'})
        subject
      end

      it 'preserves message order' do
        expect(bunny_channel).to receive(:prefetch).with(1)
        subject
      end
    end

    describe '#consume' do
      before do
        allow(bunny_queue).to receive(:subscribe).and_yield(double(:delivery_info, delivery_tag: :tag), 'properties', 'payload')
        allow_any_instance_of(described_class).to receive(:sleep)
      end

      it 'yields the payload' do
        subject.consume { |payload| payload.should eq 'payload'}
      end

      context 'when an exception is raised' do

        it 'notifies airbrake' do
          expect(Airbrake).to receive(:notify_or_ignore).with(an_instance_of RuntimeError)

          expect{ subject.consume { raise 'Consuming time' } }.not_to raise_error
        end
      end
    end
  end
end

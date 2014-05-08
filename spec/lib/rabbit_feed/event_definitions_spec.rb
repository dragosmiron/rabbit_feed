require 'spec_helper'

module RabbitFeed
  describe EventDefinitions do
    before do
      EventDefinitions do
        define_event('customer_purchases_policy', version: '1.0.0') do
          defined_as do
            'The definition of a purchase'
          end
          payload_contains do
            field('customer_id', type: 'string', definition: 'The definition of the customer id')
            field('policy_id', type: 'string', definition: 'The definition of the policy id')
            field('price', type: 'string', definition: 'The definition of the price')
          end
        end
      end
    end
    subject { RabbitFeed::Producer.event_definitions['customer_purchases_policy'] }

    it { should_not be_nil }
    it { should be_valid }
    its(:name) { should eq 'customer_purchases_policy' }

    describe EventDefinitions::Event do
      let(:name)       { 'event_name' }
      let(:version)    { '1.0.0' }
      let(:definition) { 'event definition' }
      subject do
        (EventDefinitions::Event.new name, version).tap do |event|
          event.defined_as do
            definition
          end
          event.payload_contains do
            field 'field', { type: 'string', definition: 'field definition' }
          end
        end
      end

      it { should be_valid }
      its(:fields) { should_not be_empty }
      its(:schema) { should be_a Avro::Schema }
      its(:payload){ should =~ [
        {name: 'application', type: 'string', doc: 'The name of the application that created the event'},
        {name: 'host', type: 'string', doc: 'The hostname of the server on which the event was created'},
        {name: 'environment', type: 'string', doc: 'The environment in which the event was created'},
        {name: 'version', type: 'string', doc: 'The version of the event'},
        {name: 'created_at_utc', type: 'string', doc: 'The UTC time that the event was created'},
        {name: 'field', type: 'string', doc: 'field definition'},
        {name: 'name', type: 'string', doc: 'The name of the event'}
        ]
      }

      context 'when the name is nil' do
        let(:name) {}

        it { should_not be_valid }
      end

      context 'when the version is nil' do
        let(:version) {}

        it { should_not be_valid }
      end

      context 'when the version is malformed' do
        let(:version) { '1.a' }

        it { should_not be_valid }
      end

      context 'when the definition is nil' do
        let(:definition) {}

        it { should_not be_valid }
      end

      context 'when the event is not a valid avro schema' do
        before { subject.fields << (EventDefinitions::Field.new 'junk', 'junk', 'junk') }

        it { should_not be_valid }
      end
    end

    describe EventDefinitions::Field do
      let(:name)       { 'event_name' }
      let(:type)       { 'string' }
      let(:definition) { 'event definition' }
      subject{ EventDefinitions::Field.new name, type, definition }

      it { should be_valid }
      its(:schema) { should eq({ name: name, type: type, doc: definition }) }

      context 'when the name is nil' do
        let(:name) {}

        it 'raises a configuration error' do
          expect{ subject }.to raise_error ConfigurationError
        end
      end

      context 'when the type is nil' do
        let(:type) {}

        it 'raises a configuration error' do
          expect{ subject }.to raise_error ConfigurationError
        end
      end

      context 'when the definition is nil' do
        let(:definition) {}

        it 'raises a configuration error' do
          expect{ subject }.to raise_error ConfigurationError
        end
      end
    end
  end
end
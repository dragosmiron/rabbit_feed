require 'spec_helper'

module RabbitFeed
  describe ConnectionConcern do
    let(:bunny_exchange)    { double(:bunny_exchange, on_return: nil) }
    let(:connection_closed) { false }
    let(:bunny_channel)     { double(:bunny_channel, exchange: bunny_exchange, id: 1) }
    let(:bunny_connection)  { double(:bunny_connection, start: nil, closed?: connection_closed, close: nil, create_channel: bunny_channel) }
    before { allow(Bunny).to receive(:new).and_return(bunny_connection) }
    after do
      subject.instance_variable_set(:@bunny_connection, nil)
      subject.instance_variable_set(:@connection_pool, nil)
    end
    subject { RabbitFeed::ProducerConnection }

    describe '.with_connection' do

      it 'retries on exception' do
        expect(subject).to receive(:retry_on_exception).and_call_original
        subject.with_connection{|connection| connection }
      end

      it 'assigns the connection' do
        subject.with_connection{|connection| connection }
        expect(subject.instance_variable_get(:@bunny_connection)).to eq bunny_connection
      end

      it 'assigns the connection pool' do
        subject.with_connection{|connection| connection }
        expect(subject.instance_variable_get(:@connection_pool)).to be_a ConnectionPool
      end

      it 'creates a connection pool of one connection' do
        expect(ConnectionPool).to receive(:new).with(hash_including({size: 1})).and_call_original
        subject.with_connection{|connection| connection }
      end

      it 'provides an instance of the class' do
        actual = subject.with_connection{|connection| connection }
        expect(actual).to be_a subject
      end
    end

    describe '.close' do

      context 'when the connection is nil' do

        it 'does not close the connection' do
          expect(bunny_connection).not_to receive(:close)
          subject.close
        end
      end

      context 'when the connection is not nil' do
        before do
          subject.with_connection{|connection| connection }
        end

        context 'when the connection is closed' do
          let(:connection_closed) { true }

          it 'does not close the connection' do
            expect(bunny_connection).not_to receive(:close)
            subject.close
          end
        end

        context 'when the connection is not closed' do
          let(:connection_closed) { false }

          it 'closes the connection' do
            expect(bunny_connection).to receive(:close)
            subject.close
          end

          context 'when closing raises an exception' do

            it 'does not propogate the exception' do
              allow(bunny_connection).to receive(:close).and_raise 'error'
              expect{ subject.close }.not_to raise_error
            end
          end
        end

        it 'unsets the connection' do
          subject.close
          expect(subject.instance_variable_get(:@bunny_connection)).to be_nil
        end

        it 'unsets the connection pool' do
          subject.close
          expect(subject.instance_variable_get(:@connection_pool)).to be_nil
        end
      end
    end

    describe '.retry_on_exception' do
      it_behaves_like 'an operation that retries on exception', :retry_on_exception, RuntimeError
      it_behaves_like 'an operation that does not retry on exception', :retry_on_exception, Bunny::ConnectionClosedError
    end

    describe '.retry_on_closed_connection' do
      before do
        subject.with_connection{|connection| connection }
        allow(subject).to receive(:sleep).at_least(:once)
      end

      it_behaves_like 'an operation that retries on exception', :retry_on_closed_connection, Bunny::ConnectionClosedError
      it_behaves_like 'an operation that does not retry on exception', :retry_on_closed_connection, RuntimeError

      it 'unsets the connection' do
        expect { subject.retry_on_closed_connection { raise Bunny::ConnectionClosedError.new 'blah' } }.to raise_error
        expect(subject.instance_variable_get(:@bunny_connection)).to be_nil
      end

      it 'unsets the connection pool' do
        expect { subject.retry_on_closed_connection { raise Bunny::ConnectionClosedError.new 'blah' } }.to raise_error
        expect(subject.instance_variable_get(:@connection_pool)).to be_nil
      end

      it 'waits between retries' do
        expect(subject).to receive(:sleep).with(1).twice
        begin; subject.retry_on_closed_connection { raise Bunny::ConnectionClosedError.new 'blah' }; rescue; end
      end
    end
  end
end

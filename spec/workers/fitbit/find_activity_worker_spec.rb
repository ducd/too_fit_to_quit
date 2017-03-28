require 'rails_helper'

RSpec.describe Fitbit::FindActivityWorker, type: :model do
  let(:user) { create(:user) }
  let!(:identity) { create(:identity, :fitbit, user: user) }
  let(:response) { nil }

  it { is_expected.to be_kind_of(Sidekiq::Worker) }

  def make_request(response)
    stub_request(:get, %r{https://api.fitbit.com/1/user/\d+/activities/list.json}).
      to_return(status: 200, body: response.to_json)
  end

  def run_worker
    subject.perform(user.id)
  end

  describe '#perform' do
    before do
      make_request(response)
    end

    context 'when user is invalid' do
      it 'raises ActiveRecord::RecordNotFound' do
        expect {
          subject.perform('')
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context 'when service request returns an unsuccessful response' do
      let(:response) { { 'success' => false } }
      it 'returns false' do
        expect(run_worker).to eq(false)
      end
    end

    context 'when service request returns a successful response' do
      let(:response) { { 'success' => true, 'activities' => [] } }
      it 'returns true' do
        expect(run_worker).to eq(true)
      end
    end

    context 'when service request returns a successful response with activities' do
      let(:response) do
        {
          'success' => true,
          'activities' => [
            { 'activityName' => 'Run' },
            { 'activityName' => 'Bike' },
            { 'activityName' => 'Run' }
          ]
        }
      end

      it 'enqueues ImportFitbitRunWorker for every run activity' do
        expect {
          run_worker
        }.to change(Fitbit::ImportRunWorker.jobs, :count).by(2)
      end

      it 'returns true' do
        expect(run_worker).to eq(true)
      end
    end
  end

  describe '#get_options' do
    context 'when date is nil' do
      it 'returns a hash containing todays date' do
        expect(subject.send(:get_options, nil)).to eq({ date: Date.today.strftime('%Y-%m-%d') })
      end
    end

    context 'when date is valid' do
      it 'returns a hash containing the date' do
        expect(subject.send(:get_options, '2017-02-02')).to eq({ date: '2017-02-02' })
      end
    end

    context 'when date is invalid' do
      it 'raises ArgumentError' do
        expect {
          subject.send(:get_options, 'abc')
        }.to raise_error(ArgumentError)
      end
    end
  end
end

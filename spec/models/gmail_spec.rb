require 'spec_helper'

describe Gmail do
  let(:gmail) { create(:gmail) }
  describe "#usage_statistic" do
    let(:user) { create(:user, type: 'Operator') }
    let(:task) { create(:task, gmail_id: gmail.id, type: 'Edit', provider: 'Google', last_editor_id: user.id)}
    let(:task_1) { create(:task, gmail_id: gmail.id, type: 'Create', provider: 'Apple', last_editor_id: user.id)}

    before do
      2.times do
        Task.update_task(task.id, {gmail_id: gmail.id})
      end
      1.times do
        Task.update_task(task_1.id, {gmail_id: gmail.id})
      end
      gmail.reload
    end

    subject { gmail.usage_statistic }
    it { is_expected.to eq({Google_Edit: 2, Google_Reverts: 0, Google_Create: 0, Apple_Create: 1}) }
  end

  describe "#can_be_used?" do
    let(:task_group_1)  { create :task_group }
    let(:task_group_2)  { create :task_group }
    let(:user) { create(:user, type: 'Operator') }
    let(:task) { create(:task, gmail_id: gmail.id, type: type, provider: provider, task_group: task_group_1, last_editor_id: user.id)}

    context "when the counter did not reach limit" do
      let(:type) { 'Create' }
      let(:provider) { 'Apple' }

      it 'should be true' do
        2.times do
          Task.update_task(task.id, {gmail_id: gmail.id})
        end
        gmail.reload
        expect(gmail.can_be_used?(type, provider)).to eq(true)
      end
    end

    context "when the counter reached limit" do
      let(:type) { 'Edit' }
      let(:provider) { 'Google' }

      it 'should be false' do
        15.times do
          Task.update_task(task.id, {gmail_id: gmail.id})
        end
        gmail.reload
        expect(gmail.can_be_used?(type, provider)).to eq(false)
      end
    end
  end

  describe '.next_available_for' do
    let(:gmail1) { create(:gmail, task_type: "google_edit") }

    before do
      type = 'Edit'
      15.times do |i|
        create :task, gmail_id: gmail.id, type: type, provider: 'Google'
      end
      type = 'Reverts'
      1.times do |i|
        create :task, gmail_id: gmail1.id, type: type, provider: 'Google'
      end
      type = 'Create'
      1.times do |i|
        create :task, gmail_id: gmail.id, type: type, provider: 'Apple'
      end
    end

    subject { Gmail.next_available_for(type, 'Google')}
    context 'search for edit' do
      let(:type) { 'Edit' }
      it { is_expected.to eq(gmail1) }
    end

    context 'search for create' do
      let(:type) { 'Create' }
      it { is_expected.to eq(nil) }
    end

    context 'search for reverts' do
      let(:type) { 'Reverts' }
      it { is_expected.to eq(nil) }
    end
  end
end

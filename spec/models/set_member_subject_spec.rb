require 'spec_helper'

describe SetMemberSubject, :type => :model do
  let(:set_member_subject) { build(:set_member_subject) }
  let(:locked_factory) { :set_member_subject }
  let(:locked_update) { {state: 1} }

  it "should have a valid factory" do
    expect(set_member_subject).to be_valid
  end

  it "should be invalid with a duplicate subject_id to subject_set_id" do
    set_member_subject.save
    dup = build(:set_member_subject,
      subject: set_member_subject.subject,
      subject_set: set_member_subject.subject_set)
    expect(dup).to be_invalid
  end

  it "should have a random value when created" do
    expect(create(:set_member_subject).random).to_not be_nil
  end

  describe "::available" do
    let(:workflow) { create(:workflow) }
    let(:subject_set) { create(:subject_set, workflows: [workflow]) }
    let!(:sms) { create_list(:set_member_subject, 2, subject_set: subject_set) }
    let!(:uss) do
      create(:user_seen_subject, workflow: workflow, subject_ids: [sms.first.subject_id])
    end
    let(:user) { uss.user }

    subject { SetMemberSubject.available(workflow, user).pluck(:subject_id) }

    context "when the workflow is finished" do
      let!(:sms) do
        create_list(:set_member_subject, 2, subject_set: subject_set)
      end

      before(:each) do
        workflow.update!(retired_set_member_subjects_count: sms.length)
        sms.each { |i| i.retire_workflow(workflow) }
      end

      it 'should select retired subjects' do
        expect(subject).to include(sms.first.subject_id)
      end
    end

    context "when the user is finished with the workflow" do
      let!(:uss) do
        create(:user_seen_subject, workflow: workflow, subject_ids: sms.map(&:subject_id))
      end

      it 'should select subjects a user has seen' do
        expect(subject).to include(sms.first.subject_id)
      end
    end

    context "when no uss exsits" do
      let!(:uss) { nil }
      let(:user) { create(:user) }

      it 'should return an active subject' do
        expect(subject).to include(*sms.map(&:subject_id))
      end
    end

    context "when workflow is unfinished" do
      let!(:retired_sms) do
        create(:set_member_subject, subject_set: subject_set).tap { |sms| sms.retire_workflow(workflow) }
      end

      it 'should select active subjects' do
        expect(subject).to include(sms[1].subject_id)
      end

      it 'should not select retired subjects' do
        expect(subject).to_not include(retired_sms.subject_id)
      end

      it 'should select subjects a user has not seen' do
        expect(subject).to include(sms[1].subject_id)
      end

      it 'should not select subjects a user has seen' do
        expect(subject).to_not include(sms[0].subject_id)
      end
    end
  end

  describe "::by_subject_workflow" do
    it "should retrieve and object by subject and workflow id" do
      set_member_subject.save!
      sid = set_member_subject.subject_id
      wid = set_member_subject.subject_set.workflows.first.id
      expect(SetMemberSubject.by_subject_workflow(sid, wid)).to include(set_member_subject)
    end
  end

  describe ":by_workflow" do

    it "should retun an empty set" do
      workflow = create(:workflow)
      expect(SetMemberSubject.by_workflow(workflow)).to be_empty
    end

    context "when a workflow sms exist" do
      let(:workflow_sms) { create(:set_member_subject) }
      let(:workflow) { workflow_sms.workflows.first }

      it "should return the workflow sms" do
        expect(SetMemberSubject.by_workflow(workflow)).to eq([workflow_sms])
      end

      context "when another workflow sms exists" do

        it "should only return the workflow sms" do
          create(:set_member_subject)
          expect(SetMemberSubject.by_workflow(workflow)).to eq([workflow_sms])
        end
      end
    end
  end

  describe ":non_retired_for_workflow" do
    let(:count) { create(:subject_workflow_count) }
    let(:workflow) { count.workflow }
    let!(:another_workflow_sms) { create(:set_member_subject) }

    context "when none are retired" do

      it "should return the workflow's non retired sms" do
        expect(SetMemberSubject.non_retired_for_workflow(workflow)).to include(count.set_member_subject)
      end
    end

    context "when the workflow sms is retired" do

      it "should return an empty set" do
        count.retire!
        expect(SetMemberSubject.non_retired_for_workflow(workflow)).to be_empty
      end
    end
  end

  describe ":non_retired_for_workflow" do
    let(:count) { create(:subject_workflow_count) }
    let(:workflow) { count.workflow }
    let!(:another_workflow_sms) { create(:set_member_subject) }

    context "when none are retired" do

      it "should return the workflow's non retired sms" do
        expect(SetMemberSubject.non_retired_for_workflow(workflow)).to include(count.set_member_subject)
      end
    end

    context "when the workflow sms is retired" do

      it "should return an empty set" do
        count.retire!
        expect(SetMemberSubject.non_retired_for_workflow(workflow)).to be_empty
      end
    end
  end

  describe ":unseen_for_user_by_workflow" do
    let(:user) { create(:user) }
    let(:workflow) { create(:workflow_with_subjects) }
    let(:smses){ workflow.set_member_subjects }
    let!(:another_workflow_sms) { create(:set_member_subject) }

    context "when the user has not seen any workflow subjects" do

      it "should return the all the worflow set_member_subjects " do
        create(:user_seen_subject, workflow: workflow, user: user, subject_ids: [])
        expect(SetMemberSubject.unseen_for_user_by_workflow(user, workflow)).to eq(smses)
      end
    end

    context "when the user has seen all the workflow subjects" do

      it "should return an empty set" do
        create(:user_seen_subject, workflow: workflow, user: user, subject_ids: smses.map(&:subject_id))
        expect(SetMemberSubject.unseen_for_user_by_workflow(user, workflow)).to be_empty
      end
    end
  end

  describe "#subject_set" do
    it "must have a subject set" do
      set_member_subject.subject_set = nil
      expect(set_member_subject).to_not be_valid
    end

    it "should belong to a subject set" do
      expect(set_member_subject.subject_set).to be_a(SubjectSet)
    end
  end

  describe "#subject" do
    it "must have a subject" do
      set_member_subject.subject = nil
      expect(set_member_subject).to_not be_valid
    end

    it "should belong to a subject" do
      expect(set_member_subject.subject).to be_a(Subject)
    end
  end

  describe "#retire_workflow" do
    it 'should add the workflow the retired_workflows relationship' do
      sms = set_member_subject
      sms.save!
      workflow1 = sms.subject_set.workflows.first
      workflow2 = create(:workflow, subject_sets: [sms.subject_set])
      create(:subject_workflow_count, set_member_subject: sms, workflow: workflow1)
      create(:subject_workflow_count, set_member_subject: sms, workflow: workflow2)
      sms.retire_workflow(workflow1)
      sms.reload
      expect(sms.retired_workflows).to eq([workflow1])
    end
  end

  describe "#remove_from_queues" do
    it 'should queue a removal worker' do
      set_member_subject.save!
      expect(QueueRemovalWorker).to receive(:perform_async)
        .with(set_member_subject.id, set_member_subject.subject_set.workflows.pluck(:id))
      set_member_subject.remove_from_queues
    end
  end
end

require 'test_helper'
require 'responsys_client'

class ResponsysClientTest < Test::Unit::TestCase
  def setup
     SunDawg::Responsys::Member.clear_fields!
  end

  def test_instantiation
    assert SunDawg::Responsys::ResponsysClient.new("foo", "bar")
  end

  def test_instantiation_with_options
    assert SunDawg::Responsys::ResponsysClient.new("foo", "bar", :wiredump_dev => STDOUT)
  end

  def test_save_members_throws_too_many_members_error
    SunDawg::Responsys::Member.add_field :customer_id
    SunDawg::Responsys::Member.add_field :email_address
    SunDawg::Responsys::Member.add_field :email_permission_status
    members = []
    (SunDawg::Responsys::ResponsysClient::MAX_MEMBERS + 1).times do
      members << SunDawg::Responsys::Member.new
    end

    assert_raises SunDawg::Responsys::ResponsysClient::TooManyMembersError do
      SunDawg::Responsys::ResponsysClient.new("foo", "bar").save_members("folder", "list", members)
    end
  end

  def test_save_members_throws_methods_not_supported_error_with_no_email_address
    SunDawg::Responsys::Member.add_field :email_address
    member = SunDawg::Responsys::Member.new
    assert_raises SunDawg::Responsys::ResponsysClient::MethodsNotSupportedError do
      SunDawg::Responsys::ResponsysClient.new("foo", "bar").save_members("folder", "list", [member])
    end
  end

  def test_save_members_throws_methods_not_supported_error_with_no_email_permission_status
    SunDawg::Responsys::Member.add_field :email_permission_status
    member = SunDawg::Responsys::Member.new
    assert_raises SunDawg::Responsys::ResponsysClient::MethodsNotSupportedError do
      SunDawg::Responsys::ResponsysClient.new("foo", "bar").save_members("folder", "list", [member])
    end
  end

  def test_save_members_removes_illegal_xml_characters
    SunDawg::Responsys::Member.add_field :customer_id
    SunDawg::Responsys::Member.add_field :email_address
    SunDawg::Responsys::Member.add_field :email_permission_status
    SunDawg::Responsys::Member.add_field :user_text

    member = SunDawg::Responsys::Member.new
    member.user_text = "Text with a vertical \v tab"

    ws = stub(:login => stub(:result => stub(:sessionId => 'session ID')),
              :logout => true,
              :headerhandler => stub(:add),
              :options => {})
    hatm_ws = stub(:login => stub(:result => stub(:sessionId => 'session ID')),
              :logout => true,
              :headerhandler => stub(:add),
              :options => {})
    ResponsysWS.stubs(:new).returns(ws)
    HATMResponsysWS.stubs(:new).returns(hatm_ws)

    ws.expects(:mergeListMembers).with do |mlm|
      mlm.recordData.records[0].none? {|r| r.to_s =~ /[[:cntrl:]]/}
    end

    SunDawg::Responsys::ResponsysClient.new('foo','bar').save_members('folder', 'list', [member])
  end

  def test_trigger_campaign_removes_illegal_xml_characters
    ws = stub(:login => stub(:result => stub(:sessionId => 'session ID')),
              :logout => true,
              :headerhandler => stub(:add),
              :options => {})
    hatm_ws = stub(:login => stub(:result => stub(:sessionId => 'session ID')),
              :logout => true,
              :headerhandler => stub(:add),
              :options => {})
    ResponsysWS.stubs(:new).returns(ws)
    HATMResponsysWS.stubs(:new).returns(hatm_ws)

    ws.expects(:triggerCampaignMessage).with do |tcm|
      tcm.recipientData[0].optionalData.none? {|od| od.value =~ /[[:cntrl:]]/}
    end

    SunDawg::Responsys::ResponsysClient.new('foo','bar').trigger_user_campaign('campaign', {:id => 5}, { 'DataField' => "vertical\vtab" })
  end

  def test_trigger_batch_campaign
    ws = stub(:login => stub(:result => stub(:sessionId => 'session ID')),
              :logout => true,
              :headerhandler => stub(:add),
              :options => {})
    hatm_ws = stub(:login => stub(:result => stub(:sessionId => 'session ID')),
              :logout => true,
              :headerhandler => stub(:add),
              :options => {})
    ResponsysWS.stubs(:new).returns(ws)
    HATMResponsysWS.stubs(:new).returns(hatm_ws)

    recipients = {
      'user_1' => { 'SomeData' => 'a value' },
      2 => { 'MoreData' => 'its value' }
    }

    ws.expects(:triggerCampaignMessage).with do |tcm|
      assert_equal recipients.size, tcm.recipientData.length

      tcm.recipientData.each do |recipient_data|
        recipient = recipients[recipient_data.recipient.customerId]
        (0..(recipient_data.optionalData.length-1)).each do |i|
          assert_equal recipient[recipient_data.optionalData[i].name], recipient_data.optionalData[i].value
        end
        true
      end
    end

    ids = recipients.keys.map { |id| { :id => id } }
    options = recipients.keys.map { |id| recipients[id] }
    SunDawg::Responsys::ResponsysClient.new('foo','bar').trigger_user_batch_campaign('campaign', ids, options)
  end

  def test_ha_merge_trigger_email
    ws = stub(:login => stub(:result => stub(:sessionId => 'session ID')),
              :logout => true,
              :headerhandler => stub(:add),
              :options => {})
    hatm_ws = stub(:login => stub(:result => stub(:sessionId => 'session ID')),
              :logout => true,
              :headerhandler => stub(:add),
              :options => {})
    ResponsysWS.stubs(:new).returns(ws)
    HATMResponsysWS.stubs(:new).returns(hatm_ws)

    recipients = {
      'user_1' => { 'SomeData' => 'a value' },
      2 => { 'MoreData' => 'its value' }
    }

    hatm_ws.expects(:haMergeTriggerEmail).with do |mte|
      assert_equal mte.recordData.fieldNames, ["ID"]
      assert_equal recipients.size, mte.recordData.records.length

      mte.recordData.records.each_with_index do |record, i|
        assert_equal record.first, recipients.keys[i]
      end

      mte.triggerData.each_with_index do |td, i|
        assert_equal td.optionalData.first.name, recipients.values[i].keys.first
        assert_equal td.optionalData.first.value, recipients.values[i].values.first
      end
    end

    ids = recipients.keys.map { |id| { :id => id } }
    options = recipients.keys.map { |id| recipients[id] }
    SunDawg::Responsys::ResponsysClient.new('foo','bar').ha_merge_trigger_email('folder', 'campaign', ids, options)
  end
end

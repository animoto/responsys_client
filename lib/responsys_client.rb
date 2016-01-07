require 'rubygems'
require 'member'
require 'stub/defaultDriver.rb'
require 'stub/defaultMappingRegistry.rb'

module SunDawg
  module Responsys
    class ResponsysClient

      MAX_MEMBERS = 200

      class InvalidParams < StandardError
        def initialize(message)
          super(message.to_s)
        end
      end
      class TooManyMembersError < StandardError
      end
      class ResponsysTimeoutError < StandardError
      end
      class MethodsNotSupportedError < StandardError
      end

      class ResponsysRecord
        attr_reader :field_names, :records, :to_hash

        def initialize record_data
          @field_names = record_data.fieldNames
          @records     = if record_data.records.respond_to?(:fieldValues)
                           record_data.records.fieldValues
                         else
                           record_data.records[0]
                         end

          @to_hash = Hash[@field_names.zip(@records)]

        end

        #lower case symbol of field name
        def method_missing(meth, *args, &block)
          record = meth.to_s.upcase
          if @field_names.include? record
            value = @to_hash[record]
            return value.size == 1 ? value[0] : value
          elsif @field_names.include? record +'_'
            value = @to_hash[record + '_']
            return value.size == 1 ? value[0] : value

          else
            super
          end
        end

      end

      attr_reader :session_id
      attr_reader :timeout_threshold
      attr_accessor :keep_alive

      # Creates a client object to connect to Responsys via SOAP API
      #
      # <username> - The login username
      # <password> - The login password
      # <options...> - Hash of additional options
      #   :keep_alive => true|false - (Default=false) Keep session alive for multiple requests
      #   :timeout_threshold => Seconds (Default=180) Length of time to timeout a request
      #   :wiredump_dev => IO - Dump all messages (reply and responses) to IO
      #
      def initialize(username, password, options = {})
        @username = username
        @password = password
        @keep_alive = options[:keep_alive]
        @responsys_client = ResponsysWS.new
        @responsys_client.wiredump_dev = options[:wiredump_dev] if options[:wiredump_dev]

        self.timeout_threshold = options[:timeout_threshold] || 180
      end

      def timeout_threshold=(secs)
        # Sets the timeout on the internal responsys http client according
        # to Travis' research in case 15230.
        @responsys_client.options['protocol.http.connect_timeout'] = secs
        @responsys_client.options['protocol.http.send_timeout'] = secs
        @responsys_client.options['protocol.http.receive_timeout'] = secs

        @timeout_threshold = secs
      end

      def login
        with_application_error do
          login_request = Login.new
          login_request.username = @username
          login_request.password = @password
          response = @responsys_client.login login_request
          @session_id = response.result.sessionId
          assign_session
        end
      end

      def assign_session
        session_header_request = SessionHeader.new
        session_header_request.sessionId = @session_id
        @responsys_client.headerhandler.add session_header_request
      end

      def logout
        begin
          logout_request = Logout.new
          @responsys_client.logout logout_request
        ensure
          @session_id = nil
        end
      end

      def list_folders
        with_session do
          @responsys_client.listFolders ListFolders.new
        end
      end

      def create_folder(folder_name)
        with_session do
          create_folder_request = CreateFolder.new
          create_folder_request.folderName = folder_name
          @responsys_client.createFolder create_folder_request
        end
      end

      def save_supplemental_table_with_pk(folder_name, list_name, members)
        raise TooManyMembersError if members.size > MAX_MEMBERS
        with_session do
          table = InteractObject.new
          table.folderName = folder_name
          table.objectName = list_name
          record_data = RecordData.new
          record_data.fieldNames = members.first.keys
          record_data.records = members.map do |member|
            record_data.fieldNames.map do |field|
              member[field]
            end
          end
          insert_on_no_match = true
          update_on_match = UpdateOnMatch::REPLACE_ALL
          merge = MergeTableRecordsWithPK.new(table, record_data, insert_on_no_match, update_on_match)
          @responsys_client.mergeTableRecordsWithPK(merge)
        end
      end

      def save_profile_extension_table(folder_name, list_name, members, matching_column='RIID')
        raise TooManyMembersError if members.size > MAX_MEMBERS
        with_session do
          table = InteractObject.new
          table.folderName = folder_name
          table.objectName = list_name
          record_data = RecordData.new
          record_data.fieldNames = members.first.keys
          record_data.records = members.map do |member|
            record_data.fieldNames.map do |field|
              member[field]
            end
          end
          query_column = QueryColumn.new(matching_column)
          insert_on_no_match = true
          update_on_match = UpdateOnMatch::REPLACE_ALL
          merge = MergeIntoProfileExtension.new(table, record_data, query_column, insert_on_no_match, update_on_match)
          @responsys_client.mergeIntoProfileExtension(merge)
        end
      end

      #query column currently only supports RIID, so query values should only be as list of RIIDs
      def get_profile_extension_table(folder_name, table_name, field_list, query_values, query_column='RIID')
        response = ''
        with_session do
          table = InteractObject.new
          table.folderName = folder_name
          table.objectName = table_name

          query = RetrieveProfileExtensionRecords.new(table, query_column, field_list, query_values)
          response = @responsys_client.retrieveProfileExtensionRecords(query)
        end
        ResponsysRecord.new(response.result.recordData)
      end


      def get_list_members(folder_name, list_name, field_list, query_values, query_column='RIID')
        response = ''
        with_session do
          list = InteractObject.new
          list.folderName = folder_name
          list.objectName = list_name

          query = RetrieveListMembers.new(list, query_column, field_list, query_values)
          response = @responsys_client.retrieveListMembers(query)

        end
        ResponsysRecord.new(response.result.recordData)
      end

      def get_RIID_from_cust_id(folder_name, list_name, customer_ids)
        record = get_list_members(folder_name, list_name, ['RIID_'], [customer_ids], 'CUSTOMER_ID')
        record.records[0]
      end

      def save_members(folder_name, list_name, members, attributes = SunDawg::Responsys::Member.fields)
        raise MethodsNotSupportedError unless SunDawg::Responsys::Member.fields.include?(:email_address) && SunDawg::Responsys::Member.fields.include?(:email_permission_status) && SunDawg::Responsys::Member.fields.include?(:customer_id)
        raise TooManyMembersError if members.size > MAX_MEMBERS

        with_session do
          list_merge_rule = ListMergeRule.new
          list_merge_rule.insertOnNoMatch = true
          list_merge_rule.updateOnMatch = UpdateOnMatch::REPLACE_ALL
          list_merge_rule.matchColumnName1 = "CUSTOMER_ID_"
          record_data = RecordData.new
          record_data.fieldNames = SunDawg::Responsys::Member.responsys_fields(attributes)
          record_data.records = []
          members.each do |member|
            record = Record.new
            record = member.values(attributes)
            record_data.records << record
          end
          interact_object = InteractObject.new
          interact_object.folderName = folder_name
          interact_object.objectName = list_name
          merge_list_members = MergeListMembers.new
          merge_list_members.list = interact_object
          merge_list_members.recordData = record_data
          merge_list_members.mergeRule = list_merge_rule
          @responsys_client.mergeListMembers merge_list_members
        end
      end

      def launch_campaign(folder_name, campaign_name)
        with_session do
          launch_campaign = LaunchCampaign.new
          interact_object = InteractObject.new
          interact_object.folderName = folder_name
          interact_object.objectName = campaign_name
          launch_campaign.campaign = interact_object
          @responsys_client.launchCampaign launch_campaign
        end
      end

      def trigger_campaign(folder_name, campaign_name, email, options = {})
        trigger_user_campaign(campaign_name, {:email => email}, options)
      end

      def trigger_user_campaign(campaign_name, recipient_info, options = {})
        trigger_user_batch_campaign campaign_name, [recipient_info], [options]
      end

      def trigger_user_batch_campaign(campaign_name, recipients, recipient_options)
        trigger_campaign_message = TriggerCampaignMessage.new
        interact_object = InteractObject.new
        interact_object.folderName = 'ignored'
        interact_object.objectName = campaign_name
        trigger_campaign_message.campaign = interact_object
        trigger_campaign_message.recipientData = []

        recipients.each_with_index do |recipient_info, i|
          options = recipient_options[i]

          # Responsys requires something in the optional data for SOAP bindings to work
          options[:foo] = :bar if options.size == 0

          recipient = Recipient.new
          recipient.emailAddress = recipient_info[:email] if recipient_info[:email]
          recipient.customerId = recipient_info[:id] if recipient_info[:id]
          recipient_data = RecipientData.new
          recipient_data.recipient = recipient
          recipient_data.optionalData = []
          options.each_pair do |k, v|
            optional_data = OptionalData.new
            optional_data.name = k
            v.gsub!(/[[:cntrl:]]/, ' ') if v.is_a? String
            optional_data.value = v
            recipient_data.optionalData << optional_data
          end

          trigger_campaign_message.recipientData << recipient_data
        end

        with_session do
          @responsys_client.triggerCampaignMessage trigger_campaign_message
        end
      end

      ####
        ##  users_data = [
        ##                 {:email => 'abc@animoto.com', :user_options => {:foo => :bar}},
        ##                 {:email => 'xyz@animoto.com', :user_options => {:foo => :bar}}
        ##               ]
        ##
        ##  response = [
        ##                #<SunDawg::Responsys::TriggerResult:0x11169c8e8 @errorMessage="", @recipientId=14640439, @success=true>,
        ##                #<SunDawg::Responsys::TriggerResult:0x11169c8e8 @errorMessage="MULTIPLE_RECIPIENTS_FOUND", @recipientId=-2, @success=false>
        ##              ]
      ####
      def trigger_custom_program(users_data, folder_name, list_name, event_name = nil, event_id = nil)
        nil_param =  if (event_name.nil? && event_id.nil?)
                        "both event_name & event_id"
                      elsif list_name.nil?
                        "list_name"
                      elsif folder_name.nil?
                        "folder_name"
                      end
        if nil_param
          raise  InvalidParams.new("Error:#{nil_param} cannot be nil")
        end

        list_object = InteractObject.new
        list_object.folderName = folder_name
        list_object.objectName = list_name

        custom_event = CustomEvent.new
        custom_event.eventName = event_name if event_name
        custom_event.eventId = event_id if event_id

        custom_event.recipients = []
        custom_event.optionalData = []
        recipientData = []

        # loop for each user
        users_data.each do |user_info|
          if user_info[:email].nil? && user_info[:id].nil?
            raise
          end

          recipient_options = user_info[:user_options] || {}
          # Responsys requires something in the optional data for SOAP bindings to work
          recipient_options[:foo] = :bar if recipient_options.empty?

          recipient = Recipient.new
          recipient.emailAddress = user_info[:email] if user_info[:email]
          recipient.customerId = user_info[:id] if user_info[:id]
          recipient.listName = list_object
          recipient_data = RecipientData.new
          recipient_data.recipient = recipient
          recipient_data.optionalData = []
          custom_event.recipients << recipient

          recipient_options.each_pair do |k, v|
            optional_data = OptionalData.new
            optional_data.name = k
            v.gsub!(/[[:cntrl:]]/, ' ') if v.is_a? String
            optional_data.value = v
            recipient_data.optionalData << optional_data
            custom_event.optionalData << optional_data
          end

          recipientData << recipient_data
        end

        trigger_custom_event = TriggerCustomEvent.new
        trigger_custom_event.recipientData = recipientData
        trigger_custom_event.customEvent = custom_event

        with_session do
          @responsys_client.triggerCustomEvent trigger_custom_event
        end

      end

      def with_timeout
        Timeout::timeout(timeout_threshold, ResponsysTimeoutError) do
          yield
        end
      end

      def with_session
        begin
          with_timeout do
            login if @session_id.nil?
          end
          with_application_error do
            with_timeout do
              yield
            end
          end
        ensure
          with_timeout do
            logout unless @keep_alive
          end
        end
      end

      protected

      # Attempts to find the actual service error within SOAP::FaultError and raise that instead
      def with_application_error
        begin
          yield
        rescue SOAP::FaultError => e
          inner_e = e.detail[e.faultstring.data]
          puts e.faultstring.data
          raise inner_e if inner_e
          raise e
        end
      end
    end
  end
end

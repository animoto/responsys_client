require 'stub/default.rb'
require 'stub/defaultMappingRegistry.rb'
require 'soap/rpc/driver'

class HATMResponsysWS < ::SOAP::RPC::Driver
  DefaultEndpointUrl = "https://ws5-animoto.responsys.net/webservices/services/ResponsysWSService"

  Methods = [
    [ "",
      "login",
      [ ["in", "parameters", ["::SOAP::SOAPElement", "urn:ws.rsys.com", "login"]],
        ["out", "parameters", ["::SOAP::SOAPElement", "urn:ws.rsys.com", "loginResponse"]] ],
      { :request_style =>  :document, :request_use =>  :literal,
        :response_style => :document, :response_use => :literal,
        :faults => {"AccountFault_"=>{:ns=>"urn:ws.rsys.com", :use=>"literal", :namespace=>nil, :encodingstyle=>"document", :name=>"AccountFault"}, "UnexpectedErrorFault_"=>{:ns=>"urn:ws.rsys.com", :use=>"literal", :namespace=>nil, :encodingstyle=>"document", :name=>"UnexpectedErrorFault"}} }
    ],
    [ "",
      "authenticateServer",
      [ ["in", "parameters", ["::SOAP::SOAPElement", "urn:ws.rsys.com", "authenticateServer"]],
        ["out", "parameters", ["::SOAP::SOAPElement", "urn:ws.rsys.com", "authenticateServerResponse"]] ],
      { :request_style =>  :document, :request_use =>  :literal,
        :response_style => :document, :response_use => :literal,
        :faults => {"AccountFault_"=>{:ns=>"urn:ws.rsys.com", :use=>"literal", :namespace=>nil, :encodingstyle=>"document", :name=>"AccountFault"}, "UnexpectedErrorFault_"=>{:ns=>"urn:ws.rsys.com", :use=>"literal", :namespace=>nil, :encodingstyle=>"document", :name=>"UnexpectedErrorFault"}} }
    ],
    [ "",
      "loginWithCertificate",
      [ ["in", "parameters", ["::SOAP::SOAPElement", "urn:ws.rsys.com", "loginWithCertificate"]],
        ["out", "parameters", ["::SOAP::SOAPElement", "urn:ws.rsys.com", "loginWithCertificateResponse"]] ],
      { :request_style =>  :document, :request_use =>  :literal,
        :response_style => :document, :response_use => :literal,
        :faults => {"AccountFault_"=>{:ns=>"urn:ws.rsys.com", :use=>"literal", :namespace=>nil, :encodingstyle=>"document", :name=>"AccountFault"}, "UnexpectedErrorFault_"=>{:ns=>"urn:ws.rsys.com", :use=>"literal", :namespace=>nil, :encodingstyle=>"document", :name=>"UnexpectedErrorFault"}} }
    ],
    [ "",
      "logout",
      [ ["in", "parameters", ["::SOAP::SOAPElement", "urn:ws.rsys.com", "logout"]],
        ["out", "parameters", ["::SOAP::SOAPElement", "urn:ws.rsys.com", "logoutResponse"]] ],
      { :request_style =>  :document, :request_use =>  :literal,
        :response_style => :document, :response_use => :literal,
        :faults => {"UnexpectedErrorFault_"=>{:ns=>"urn:ws.rsys.com", :use=>"literal", :namespace=>nil, :encodingstyle=>"document", :name=>"UnexpectedErrorFault"}} }
    ],
    [ "",
      "retrieveListMembers",
      [ ["in", "parameters", ["::SOAP::SOAPElement", "urn:ws.rsys.com", "retrieveListMembers"]],
        ["out", "parameters", ["::SOAP::SOAPElement", "urn:ws.rsys.com", "retrieveListMembersResponse"]] ],
      { :request_style =>  :document, :request_use =>  :literal,
        :response_style => :document, :response_use => :literal,
        :faults => {"UnexpectedErrorFault_"=>{:ns=>"urn:ws.rsys.com", :use=>"literal", :namespace=>nil, :encodingstyle=>"document", :name=>"UnexpectedErrorFault"}, "ListFault_"=>{:ns=>"urn:ws.rsys.com", :use=>"literal", :namespace=>nil, :encodingstyle=>"document", :name=>"ListFault"}} }
    ],
    [ "",
      "HaMergeTriggerEmail",
      [ ["in", "parameters", ["::SOAP::SOAPElement", "urn:ws.rsys.com", "haMergeTriggerEmail"]],
        ["out", "parameters", ["::SOAP::SOAPElement", "urn:ws.rsys.com", "haMergeTriggerEmailResponse"]] ],
      { :request_style =>  :document, :request_use =>  :literal,
        :response_style => :document, :response_use => :literal,
        :faults => {"UnexpectedErrorFault_"=>{:ns=>"urn:ws.rsys.com", :use=>"literal", :namespace=>nil, :encodingstyle=>"document", :name=>"UnexpectedErrorFault"}, "TriggeredMessageFault_"=>{:ns=>"urn:ws.rsys.com", :use=>"literal", :namespace=>nil, :encodingstyle=>"document", :name=>"TriggeredMessageFault"}} }
    ],
  ]

  def initialize(endpoint_url = nil)
    endpoint_url ||= DefaultEndpointUrl
    super(endpoint_url, nil)
    self.mapping_registry = DefaultMappingRegistry::EncodedRegistry
    self.literal_mapping_registry = DefaultMappingRegistry::LiteralRegistry
    init_methods
  end

private

  def init_methods
    Methods.each do |definitions|
      opt = definitions.last
      if opt[:request_style] == :document
        add_document_operation(*definitions)
      else
        add_rpc_operation(*definitions)
        qname = definitions[0]
        name = definitions[2]
        if qname.name != name and qname.name.capitalize == name.capitalize
          ::SOAP::Mapping.define_singleton_method(self, qname.name) do |*arg|
            __send__(name, *arg)
          end
        end
      end
    end
  end
end

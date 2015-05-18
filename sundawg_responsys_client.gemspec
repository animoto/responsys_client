# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{sundawg_responsys_client}
  s.version = "0.0.1"

  s.required_rubygems_version = '> 1.8'
  s.authors = ["Christopher Sun"]
  s.date = %q{2011-06-03}
  s.description = %q{Ruby SOAP Client For Responsys API}
  s.email = %q{christopher.sun@gmail.com}
  s.extra_rdoc_files = ["README.rdoc", "lib/member.rb", "lib/responsys_client.rb", "lib/stub/ResponsysWSServiceClient.rb", "lib/stub/default.rb", "lib/stub/defaultDriver.rb", "lib/stub/defaultMappingRegistry.rb", "lib/wsdl/wsdl_4_11_2011.wsdl"]
  s.files = ["README.rdoc", "Rakefile", "lib/member.rb", "lib/responsys_client.rb", "lib/stub/ResponsysWSServiceClient.rb", "lib/stub/default.rb", "lib/stub/defaultDriver.rb", "lib/stub/defaultMappingRegistry.rb", "lib/wsdl/wsdl_4_11_2011.wsdl", "sundawg_responsys_client.gemspec", "test/config.yml.sample", "test/feedback.csv", "test/member_test.rb", "test/responsys_client_integration_test.rb", "test/responsys_client_test.rb", "test/test_helper.rb"]
  s.homepage = %q{http://github.com/SunDawg/responsys_client}
  s.rdoc_options = ["--line-numbers", "--inline-source", "--title", "Sundawg_responsys_client", "--main", "README.rdoc"]
  s.require_paths = ["lib"]
  s.rubyforge_project = %q{sundawg_responsys_client}
  s.rubygems_version = %q{1.3.7}
  s.summary = %q{Ruby SOAP Client For Responsys API}
  s.test_files = ["test/member_test.rb", "test/responsys_client_integration_test.rb", "test/responsys_client_test.rb", "test/test_helper.rb"]

  s.add_dependency('soap4r-ruby1.9', ["~> 2.0.5"])
end

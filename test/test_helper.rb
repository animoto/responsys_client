require 'test/unit'
require 'rubygems'
require 'mocha'
require 'ruby-debug'

# adding '../lib' into the path
$:.unshift File.expand_path('./lib')
INTEGRATION = ENV['INTEGRATION'] unless defined?(INTEGRATION)

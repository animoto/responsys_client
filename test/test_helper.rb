require 'rubygems'
Bundler.require
require 'test/unit'
require 'mocha/test_unit'

# adding '../lib' into the path
$:.unshift File.expand_path('./lib')
INTEGRATION = ENV['INTEGRATION'] unless defined?(INTEGRATION)

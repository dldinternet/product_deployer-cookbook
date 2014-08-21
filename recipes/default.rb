#
# Cookbook Name:: product_deployer
# Recipe:: default
#
# Copyright 2013, DLDInternet, Inc.
#
# All rights reserved - Do Not Redistribute
#
require 'rubygems'
begin
  gem 'awesome_print'
rescue
  chef_gem 'awesome_print'
end

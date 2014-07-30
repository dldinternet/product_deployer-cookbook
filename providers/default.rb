require 'awesome_print'
require 'chef/config'
require 'uri'
require 'chef/rest'
require 'chef/node'
require 'chef/role'
require 'chef/environment'
require 'chef/data_bag'
require 'chef/data_bag_item'
require 'chef/encrypted_data_bag_item'
require 'chef/dsl/data_query'

class BreakError < ::StandardError; end

include Chef::ProductDeployer::Inventory

include Chef::ProductDeployer::Installation

include Chef::ProductDeployer::Pantry

include Chef::ProductDeployer::Deployer

action :download do
	new_resource = @new_resource

	args = {}

	[
		:product,
		:variant,
		:release,
		:version,
		:branch,
		:build,
		:user,
		:group,
		:path,
		:meta_ini,
		:preserves,
		:overwrite,
    :pre_hooks,
    :post_hooks,
    :secret_file,
    :secret_url,
    :secret,
    :tar_flags,
    :download_path,
	].each{ |p|
		v = new_resource.send(p.to_s)
		args[p]=v unless v.nil?
	}
	Chef::Log.debug args.ai
	#args = deployer_getArgs(args_p)
	updated = downloadProduct(args)

	new_resource.updated_by_last_action(updated)
end

action :deploy do
	new_resource = @new_resource

	args = {}

	[
		:product,
		:variant,
		:release,
		:version,
		:branch,
		:build,
		:user,
		:group,
		:path,
		:meta_ini,
		:preserves,
		:overwrite,
    :pre_hooks,
    :post_hooks,
    :secret_file,
    :secret_url,
    :secret,
    :tar_flags,
    :download_path,
	].each{ |p|
		v = new_resource.send(p.to_s)
		args[p]=v unless v.nil?
	}
	Chef::Log.debug args.ai
	#args = deployer_getArgs(args_p)
	updated = deployProduct(args)

  node.set['product_deployer'][args[:product]] = {
    :release => args[:release],
    :version => args[:version],
    :branch => args[:branch],
    :build => args[:build],
    :variant => args[:variant],
  }
	new_resource.updated_by_last_action(updated)
end

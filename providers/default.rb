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

include Chef::ProductDeployer::Mixin::Inventory

include Chef::ProductDeployer::Mixin::Installation

include Chef::ProductDeployer::Mixin::Pantry

include Chef::ProductDeployer::Mixin::Deployer

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
	].each{ |p|
		v = new_resource.send(p.to_s)
		args[p]=v unless v.nil?
	}
	Chef::Log.debug args.ai
	#args = deployer_getArgs(args_p)
	updated = deployPackage(args)

	new_resource.updated_by_last_action(updated)
end

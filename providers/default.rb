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

gems = %w(awesome_print colorize inifile)

# =============================================================================
# Check for gems we need
require 'rubygems'
require 'rubygems/gem_runner'
require 'rubygems/exceptions'
gems.each{ |g|
	begin
		require g
	rescue Gem::LoadError
		# not installed
		#puts %x(gem install #{g})
		begin
			puts "Need to install #{g}"
			args = ['install', g, '--no-rdoc', '--no-ri']
			Gem::GemRunner.new.run args
			Gem.clearpaths
			require g
			puts "Loaded #{g} ..."
		rescue Gem::SystemExitException => e
			unless e.exit_code == 0
				puts "ERROR: Failed to install #{g}. #{e.message}"
				raise e
			end
		end
	rescue Gem::SystemExitException => e
		unless e.exit_code == 0
			puts "ERROR: Failed to install #{g}. #{e.message}"
			raise e
		end
	rescue Exception => e
		puts "ERROR: #{e.class.name} #{e.message}"
	end
}

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
		:environment,
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
    :archive,
		:overwrite,
    :pre_hooks,
    :post_hooks,
    :secret_file,
    :secret_url,
    :secret,
    :tar_flags,
    :download_path,
    :data_bag_name,
    :data_bag_item,
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
		:environment,
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
    :archive,
		:overwrite,
    :pre_hooks,
    :post_hooks,
    :secret_file,
    :secret_url,
    :secret,
    :tar_flags,
    :download_path,
		:data_bag_name,
		:data_bag_item,
	].each{ |p|
		v = new_resource.send(p.to_s)
		args[p]=v unless v.nil?
	}
	Chef::Log.debug "Product Deployer args: #{args.ai}"
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

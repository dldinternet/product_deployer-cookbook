class Chef
	module ProductDeployer
		module Mixin
			module Errors
				# Cannot predict load
			end
			module Deployer
				include Chef::ProductDeployer::Mixin::Errors

				# ---------------------------------------------------------------------------------------------------------------------
				def deployer_getArgs(args_p)
					# Support both the old (positional args) and new (hash args) styles of calling
					map = {
						:product     => 0,
						:variant     => 1,
						:version     => 2,
						:branch      => 3,
						:build       => 4,
						:user        => 5,
						:group       => 6,
						:path        => 7,
						:version_ini => 8,
						:preserves   => 9,
						:pre_hooks   => 10,
						:post_hooks  => 11,
					}
					defaults = {
						:preserves  => ['.htaccess', 'sites/default/_version.ini', 'sites/default/settings.php']#, 'sites/default/files']
					}
					min = 9
					if args_p.length == 1 && args_p[0].is_a?(Hash)
						args = args_p[0]
					else
						args = {}
						if args_p.size >= min # product, variant, version, branch, build, user, group, path, version_ini
							map.each { |k, i|
								args[k] = args_p[i] if args_p.size > i
							}
						else
							msg = "expected #{min} arguments, got #{args_p.count}"
							raise ArgumentError, msg
						end
					end
					args = defaults.merge(args)

					[:pre_hooks,:post_hooks].each do |hooks|
						args[hooks] = case args[hooks].class
						              when Array
							              # yay
						              when String
						              when Proc
							              [args[hooks]]
						              else
							              raise DeployError.new "Don't know what to do with #{hooks}:#{args[hooks].class.name}"
						              end if args.has_key?(hooks)
					end

					Chef::Log.debug(args.ai)
					args
				end

				# ---------------------------------------------------------------------------------------------------------------------
				#noinspection RubyScope
				def deployPackage(args)
					# From Central databag
					begin
						succeeded = false

						inventory = deployer_getInventory(args)

						# Now that we have access to the inventory we need to see which build we need and find all it's parts.
						artifacts = deployer_getArtifacts(args, inventory)

						inspection = deployer_inspectInstallation(args)

						if inspection[:download]
							# Pull down all the artifacts
							deployer_downloadArtifacts(artifacts, args[:s3_db])
						else
							Chef::Log.info "Not downloading. Inspection: #{inspection.ai}"
						end

						if inspection[:install]
							if args.has_key?(:pre_hooks)
								deployer_runHooks(:pre_hooks, args)
							end

              # TODO: [2014-07-29 Christo] This causes the extract to fail if there are no hooks and/or deployer parts ... Need to inspect the archive instead of unpacking the whole thing.
              basename = File.basename(artifacts['assembly'][:key])
              s3f = s3_file "/tmp/#{basename}" do
                path                  "/tmp/#{basename}"
                remote_path           artifacts['assembly'][:key]
                bucket                args[:s3_db]['bucket']
                aws_access_key_id     args[:s3_db]['aws_access_key_id']
                aws_secret_access_key args[:s3_db]['aws_secret_access_key']
                owner                 args[:user]
                group                 args[:group]
                mode                  '644'
                action                :nothing
              end
              s3f.run_action(:create)
              hooks_exist = %x(tar tf /tmp/#{File.basename(artifacts['assembly'][:key])} #{args[:tar_flags].join(' ')} | egrep deployer/hooks 2>/dev/null)
              if hooks_exist != ''
                # Unpack any pre_hooks that the assembly has ...
                tmpd = inspection.dup
                tmpd[:product_root] = deployer_getPantry('/tmp/pre')
                targ = args.dup
                targ[:tar_flags] << 'deployer/hooks'
                deployer_newInstallation(targ, artifacts, tmpd)

                # IFF any hooks were unpacked we need to execute them ...
                if File.directory?(File.join(targs[:path], 'deployer/hooks/pre'))
                  hooks = args.dup
                  hooks[:pre_hooks] = Dir.glob(File.join(targs[:path], 'deployer/hooks/pre','*')).sort
                  deployer_runHooks(:pre_hooks, hooks)
                end
              end

							if inspection[:preserve]
								preserved = deployer_preserveInstallation(args)
							end

							deployer_clearInstallation(args, inspection)

							deployer_newInstallation(args, artifacts, inspection)

							if inspection[:preserve] and (not preserved.nil?)
								deployer_restorePreserved(args,preserved)
							end

              # IFF any hooks were unpacked we need to execute them ...
              if File.directory?(File.join(args[:path], 'deployer/hooks/post'))
                hooks = args.dup
                hooks[:post_hooks] = Dir.glob(File.join(hooks[:path], 'deployer/hooks/post','*')).sort
                deployer_runHooks(:post_hooks, hooks)
              end

              if args.has_key?(:post_hooks)
								deployer_runHooks(:post_hooks, args)
							end
						else
							Chef::Log.info "Not installing. Inspection: #{inspection}"
						end

						succeeded = true
						return inspection[:install]
					rescue Chef::Exceptions::InsufficientPermissions => e
						Chef::Log.error("#{e.message}: #{args[:path]}")
					rescue RestClient::ResourceNotFound => e
						Chef::Log.error("#{e.message}: S3::#{e.response.args[:url]}")
					rescue => e
						Chef::Log.error("#{e.class.name} #{e.message}")
						Chef::Log.error("#{e.backtrace.to_a.ai}")
					ensure
						Chef::Log.error("Cannot deploy product #{args[:variant]}/#{args[:product]}-#{args[:version]}-r#{args[:release]}-#{args[:branch]}") unless succeeded
					end
					false
				end

			end
		end
	end
end
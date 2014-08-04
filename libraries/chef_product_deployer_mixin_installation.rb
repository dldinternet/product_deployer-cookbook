class Chef
	module ProductDeployer
    module Errors
      # Cannot predict load order
    end
    module Installation
      include Chef::ProductDeployer::Errors

      # ---------------------------------------------------------------------------------------------------------------------
      def deployer_inspectInstallation(args)
        product_root = args[:path]
        unless product_root
          msg = "Invalid 'path' attribute for resource '#{@new_resource.name}'"
          Chef::Log.fatal msg
          raise DeployError.new msg
        end

        vrbt_ini     = args[:meta_ini] || nil
        if vrbt_ini
          unless vrbt_ini.match %r(^/)
            vrbt_ini = "#{product_root}/#{args[:meta_ini]}"
          end
        end
        download     = false
        install      = false
        preserve     = false
        oldrelease   = nil
        oldversion   = nil
        oldbranch    = nil
        oldbuild     = nil
        oldtype      = nil

        # Check the install directory
        if ::Dir.exists?(product_root) and not args[:download_only]
          Chef::Log.info "#{product_root} exists"
          preserve = true
          # If dir exists then parse version if available
          if vrbt_ini and ::File.exists?(vrbt_ini)
            Chef::Log.info "#{vrbt_ini} exists"
            require 'inifile'
            ini = IniFile.load(vrbt_ini)
            Chef::Log.debug ini.ai
            oldrelease = ini['global']['RELEASE'].to_s
            oldversion = ini['global']['VERSION']
            oldbranch  = ini['global']['BRANCH']
            oldbuild   = ini['global']['BUILD'].to_s
            oldtype    = ini['global']['TYPE']
            unless  (oldrelease == args[:release]) and
                (oldversion == args[:version]) and
                (oldbranch  == args[:branch])  and
                (oldbuild   == args[:build])   and
                (oldtype    == args[:variant])
              download = true
              install  = true
            end
          else
            download = true
            install  = true
          end
        else
          Chef::Log.info "#{product_root} not found" unless args[:download_only]
          download = true
          install  = false
          unless args[:download_only]
            install  = true
            FileUtils.rm_r(product_root) if (File.directory?(product_root) and args[:overwrite])
            # create the root directory for the contents of the tar
            prd      = directory product_root do
              owner args[:user]
              group args[:group]
              mode "0755"
              recursive true
              action :nothing
            end
            prd.run_action(:create) unless File.directory?(product_root)
          end
        end
        {
            :meta_ini     => vrbt_ini,
            :download     => download,
            :install      => install,
            :oldrelease   => oldrelease,
            :oldversion   => oldversion,
            :oldbranch    => oldbranch,
            :oldbuild     => oldbuild,
            :oldtype      => oldtype,
            :newrelease   => args[:release],
            :newversion   => args[:version],
            :newbranch    => args[:branch],
            :newbuild     => args[:build],
            :newtype      => args[:variant],
            :preserve     => preserve,
            :product_root => product_root,
        }
      end

      # ---------------------------------------------------------------------------------------------------------------------
      def deployer_clearInstallation(args, inspection)
        product_root = args[:path]
        # move/remove old product root
        if ::Dir.exists?(product_root)
          if inspection[:oldversion]
            Chef::Log.info "Check for ephemeral storage and move old versions there!"
            pantry = deployer_getPantry()
            preserve_base = "#{product_root}.#{args[:product]}-#{inspection[:oldversion]}-#{inspection[:oldbranch]}-build-#{inspection[:oldbuild]}"
            preserve_base = ::File.basename(preserve_base)
            preserve_root = "#{pantry}/#{preserve_base}"
            if  (product_root != "#{pantry}/#{::File.basename(product_root)}") and
                ::Dir.exists?("#{pantry}/#{::File.basename(product_root)}")
              FileUtils.rmtree("#{pantry}/#{::File.basename(product_root)}")
            end
            if product_root != preserve_root
              if ::Dir.exists?(preserve_root)
                FileUtils.rmtree(preserve_root)
              end
              FileUtils.mv(product_root,preserve_root)
            end
            unless ::Dir.exists?(preserve_root)
              raise DeployError.new "Unable to preserve #{product_root} to #{preserve_root}"
            end
          else
            FileUtils.rm_r(product_root) if ::Dir.exists?(product_root)
          end
        end
      end

      # ---------------------------------------------------------------------------------------------------------------------
      def deployer_newInstallation(args, artifacts, inspection)
        # s3a = s3_archive artifacts['assembly'][:key] do
        #   bucket                args[:s3_db]['bucket']
        #   aws_access_key_id     args[:s3_db]['aws_access_key_id']
        #   aws_secret_access_key args[:s3_db]['aws_secret_access_key']
        #   user                  args[:user]
        #   group                 args[:group]
        #   mode                  '644'
        #   tar_flags             args[:tar_flags]
        #   target_dir            inspection[:product_root]
        #   creates               inspection[:product_root]
        #   overwrite             true
        #   action                :nothing
        # end
        # s3a.run_action(:create)
        # We have updated something if the directory was recreated
        updated = (args[:overwrite] or (not ::File.exists?(inspection[:product_root])))
        target_dir = directory inspection[:product_root] do
          owner args[:user]
          group args[:group]
          action :nothing
        end
        target_dir.run_action(:create)

        basename = File.basename(artifacts['assembly'][:key])
        cwd      = Dir.pwd
        Dir.chdir(inspection[:product_root])
        raise "Cannot change directory to #{inspection[:product_root]} from #{Dir.pwd}" unless Dir.pwd == File.realpath(inspection[:product_root])
        Chef::Log.info Dir.glob('./*').ai
        raise "Directory not empty!?" if args[:overwrite] and (Dir.glob('./*').size > 2)
        output = %x"tar xf #{args[:download_path]}/#{basename} #{args[:tar_flags].join(' ')} 2>&1"
        raise output unless $? == 0
        Chef::Log.info args.ai
        Chef::Log.debug "FileUtils.chown_R('#{args[:user]}', '#{args[:group]}', '#{inspection[:product_root]}')"
        FileUtils.chown_R(args[:user], args[:group], inspection[:product_root])
        Dir.chdir cwd

      end

      # ---------------------------------------------------------------------------------------------------------------------
      def deployer_runHooks(hooks,args)
        args[hooks].each{|cmdp|
          if cmdp.is_a?(String)
            eval "#{cmdp}(args[:path])"
          elsif cmdp.is_a?(Proc)
            cmdp.call(args[:path])
          elsif cmdp.is_a?(Array)
            # Need to run these user-supplied scripts ...
            ret = {}
            cmdp.each do |script|
              out = %x(#{script} #{args[:path]} 2>&1)
              ret[script] = {
                  stdout: out,
                  return: $?
              }
            end
            ret
          else
            raise ArgumentError.new("'#{cmdp.to_s}' is not a Proc, Lambda or String!")
          end
        }
      end

    end
	end
end


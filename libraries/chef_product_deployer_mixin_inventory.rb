class Chef
	module ProductDeployer
    module Errors
      # Cannot predict load
    end
    module Inventory
      include Chef::ProductDeployer::Errors
      # ---------------------------------------------------------------------------------------------------------------------
      def deployer_getInventory(args)
        def _expand(str)
          eval("\"" + str + "\"")
        end
        # First get the releases databag to get the vendor and store so that we can get the "artifactory" repo coordinates
        # Example: releases::twc_cms
        rel_db         = data_bag_item('releases', args[:product])
        vendor         = rel_db['repo']['vendor']
        store          = rel_db['repo']['store']

        # Second get the repo specific data bag - decrypt if we can/should
        # Example aws::s3_ro_webDev
        data_bag_name  = _expand rel_db[vendor][store]['databag_name']
        data_bag_entry = _expand rel_db[vendor][store]['databag_entry']
        # TODO: [2014-01-09 Christo] Encrypt! (We are doing this unencrypted for the sake of meeting the CICD deadline ...)
        Chef::Log::debug "PWD=#{Dir.pwd}"
        if args[:secret_file]
          Chef::Log::info "secret_file=#{args[:secret_file]}"
          secret    = Chef::EncryptedDataBagItem.load_secret(args[:secret_file])
        elsif args[:secret_url]
          Chef::Log::info "secret_url=#{args[:secret_url]}"
          secret    = Chef::EncryptedDataBagItem.load_secret(args[:secret_url])
        elsif args[:secret]
          Chef::Log::info 'secret given ...'
          secret    = args[:secret]
        else
          secret    = nil
        end
        Chef::Log::info "Load data bag with coordinates: #{data_bag_name}/#{data_bag_entry}"
        if secret
          s3_db = Chef::EncryptedDataBagItem.load(data_bag_name, data_bag_entry, secret)
        else
          s3_db = data_bag_item(data_bag_name, data_bag_entry)
        end
        if s3_db.to_hash['bucket']['encrypted_data']
          msg = "Unable to open the data bag (still encrypted): #{data_bag_name}/#{data_bag_entry}"
          Chef::Log.fatal msg
          raise DeployError.new(msg)
        end

        # Third, pull the inventory manifest for the product from the repo ...
        Chef::Log::debug "Pull inventory from repo: #{s3_db['bucket']}/#{args[:product]}/INVENTORY.json"
        response       = S3FileLib.get_from_s3(s3_db['bucket'], "/#{args[:product]}/INVENTORY.json", s3_db['aws_access_key_id'], s3_db['aws_secret_access_key'],nil)
        case response.class.name
          when 'RestClient::RawResponse'
            inventory      = JSON.parse(IO.read(response.file))
          when 'String'
            # super
            inventory      = JSON.parse(response)
          else
            raise DeployError.new "Unexpected resonse (#{response.class.name}) to s3://#{s3_db['bucket']}/#{args[:product]}/INVENTORY.json"
        end
        args[:s3_db] = s3_db
        Chef::Log.debug "Inventory: #{inventory.ai}"

        container = inventory['container']
        variants  = container['variants']
        varianth  = variants[args[:variant]]
        Chef::Log.debug "varianth: #{varianth.ai}"
        unless variants.has_key?(args[:variant])
          raise DeployError.new "#{args[:variant]} variant has no builds in the inventory of #{args[:product]}"
        end
        unless varianth.has_key?('builds')
          raise DeployError.new "Inventory of #{args[:product]}/#{args[:variant]} has no 'builds'"
        end
        unless varianth.has_key?('branches')
          raise DeployError.new "Inventory of #{args[:product]}/#{args[:variant]} has no 'branches'"
        end
        unless varianth.has_key?('versions')
          raise DeployError.new "Inventory of #{args[:product]}/#{args[:variant]} has no 'versions'"
        end
        unless varianth.has_key?('latest')
          raise DeployError.new "Inventory of #{args[:product]}/#{args[:variant]} has no 'latest' build"
        end
        unless varianth['latest'].is_a?(Hash)
          raise DeployError.new "Inventory of #{args[:product]}/#{args[:variant]} has outdated/ incorrect 'latest' set!"
        end
        builds    = varianth['builds']
        Chef::Log.debug "builds from varianth: #{builds.ai}"
        branches  = varianth['branches']
        versions  = varianth['versions']

        if args[:version] == 'latest'
          args[:version] = versions[varianth['latest']['version']]
        end

        def _getBuildNumber(args,drawer)
          begin
            drawer['build_number']
          rescue
            name = drawer['build_name'] rescue drawer['build']
            naming = container['naming']
            matches = name.match(/^#{args[:product]}-#{args[:version]}-#{args[:branch]}-build-(\d+)$/)
            if matches
              matches[1]
            else
              matches = name.match(/^#{args[:product]}-#{args[:version]}-#{args[:branch]}-#{args[:variant]}-build-(\d+)$/)
              if matches
                matches[1]
              else
                matches = name.match(/^#{args[:product]}-#{args[:version]}-release-#{args[:release]}-#{args[:branch]}-#{args[:variant]}-build-(\d+)$/)
                if matches
                  matches[1]
                else
                  nil
                end
              end
            end
          end
        end

        # For the latest build we conveniently have the index
        if args[:build] == 'latest'
          build_idx = varianth['latest']['build']
          Chef::Log.debug "'latest' build without checking ... #{build_idx}"
          # "build_name": "ChefRepo-1.0.11-release-1.0-pilot-PILOT-build-5",
          version = (args[:version] == 'latest') ? '[0-9\.]+' : args[:version]
          release = (args[:release] == 'latest') ? '[0-9\.]+' : args[:release]
          branch  = (args[:branch]  == 'latest') ? (branches[-1] rescue 'develop') : args[:branch]
          name    = builds[build_idx]['build_name'] rescue builds[build_idx]['build']
          Chef::Log.debug "'latest' build name ... #{name}"
          matches = name.match(/^#{args[:product]}-#{version}-release-#{release}-#{branch}-#{args[:variant]}-build-(\d+)$/)
          unless matches
            matched_builds = []
            # noinspection RubyHashKeysTypesInspection
            Hash[builds.map.with_index.to_a].each{ |drawer,index|
              name = drawer['build_name'] rescue drawer['build']
              matches = name.match(/^#{args[:product]}-#{version}-release-#{release}-#{branch}-#{args[:variant]}-build-(\d+)$/)
              if matches
                matched_builds << index
              end
            }
            Chef::Log.debug "Matched builds: #{args[:product]}-#{version}(#{args[:version]})-release-#{release}(#{args[:release]})-#{branch}(#{args[:branch]})-#{args[:variant]}-build-: #{matched_builds}"
            build_idx = matched_builds[-1] if matched_builds.size > 0
            Chef::Log.debug "'latest' build with check ... #{build_idx}"
          end
          name    = builds[build_idx]['build_name'] rescue builds[build_idx]['build']
          matches = name.match(/^#{args[:product]}-#{version}-release-#{release}-#{branch}-#{args[:variant]}-build-(\d+)$/)
          args[:build] = if matches
                           _getBuildNumber(args,builds[build_idx])
                         else
                           nil
                         end
          unless args[:build]
            raise DeployError.new "Cannot identify latest build number in #{builds[build_idx].ai}"
          end
        else
          # For a specific build we have to find its drawer
          build_idx = -1
          i = 0
          builds.each{|drawer|
            build = _getBuildNumber(args,drawer)
            if build and (args[:build] == build)
              build_idx = i
              break
            end
            i += 1
          }
          if -1 == build_idx
            raise DeployError.new "Unable to find build '#{args[:build]}'. Available builds are: #{builds.map{|b| b['build_name'] rescue b['build']}.join(',')}"
          end
        end

        if args[:release] == 'latest'
          if varianth.has_key?('releases')
            args[:release] = varianth['releases'][varianth['latest']['release']]
          else
            if builds[varianth['latest']['release']].has_key?('release')
              args[:release] = builds[varianth['latest']['release']]['release']
            end
          end
        end

        args[:build_idx] = build_idx
        args[:build_h] = builds[build_idx]
        args[:drawer] = builds[build_idx]['drawer']
        args[:name]   = builds[build_idx]['build_name'] rescue builds[build_idx]['build']

        inventory
      end

      # ---------------------------------------------------------------------------------------------------------------------
      def deployer_getArtifacts(args, inventory)

        container = inventory['container']
        artfct_a  = container['artifacts']
        variants  = container['variants']
        varianth  = variants[args[:variant]]
        unless variants.has_key?(args[:variant])
          raise DeployError.new "#{args[:variant]} variant has no builds in the inventory of #{args[:product]}"
        end
        unless varianth.has_key?('latest')
          raise DeployError.new "Inventory of #{args[:product]}/#{args[:variant]} has no 'latest' build"
        end

        artifacts = {}

        artfct_a.each { |artifact_id|
          artifact               = container[artifact_id].dup
          if args.has_key?(:build_h)
            if args[:build_h].has_key?(artifact_id)
              artifact = args[:build_h][artifact_id].dup
            end
          end
          artifact_ext           = artifact['extension']
          artifact_fil           = "#{args[:name]}.#{artifact_ext}"
          artifact[:file]        = "#{args[:download_path]}/#{artifact_fil}"
          artifact[:bucket]      = args[:s3_db]['bucket']
          artifact[:key]         = "/#{args[:product]}/#{args[:variant]}/#{args[:drawer]}/#{artifact_fil}"
          artifacts[artifact_id] = artifact
        }

        Chef::Log.debug artifacts.ai
        artifacts
      end

      # ---------------------------------------------------------------------------------------------------------------------
      def deployer_downloadArtifacts(artifacts, s3_db)
        artifacts.each { |id, artifact|
          Chef::Log.info %(#{id}: s3://#{artifact[:bucket]}#{artifact[:key]})
          download = true
          if ::File.exists?(artifact[:file])
            my_md5 = Digest::MD5.file(artifact[:file]).hexdigest
            s3_md5 = S3FileLib::get_md5_from_s3(artifact[:bucket], artifact[:key], s3_db['aws_access_key_id'], s3_db['aws_secret_access_key'],nil)
            Chef::Log.debug "my_md5: [#{my_md5}]"
            Chef::Log.debug "s3_md5: [#{s3_md5}]"
            download = (s3_md5 != my_md5)
          end
          if download
            IO.write(artifact[:file], S3FileLib.get_from_s3(artifact[:bucket], artifact[:key], s3_db['aws_access_key_id'], s3_db['aws_secret_access_key'],nil))
          end
        }
      end


    end
  end
end
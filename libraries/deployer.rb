class Chef
  module ProductDeployer
    include Chef::ProductDeployer::Errors

    # ---------------------------------------------------------------------------------------------------------------------
    def self.getAWSCredentials(node,args)
      Chef::Log.debug "#{__method__} args: #{args.ai}"

      def self._expand(str,node)
        Chef::Log.debug "%(#{str})".cyan
        eval "Chef::Log.debug %(#\{node[:amplify][:chef][:deployer]\}.ai)"
        eval "%(#{str})"
      end
      if args[:secret_file]
        Chef::Log::debug "secret_file=#{args[:secret_file]}".cyan
        secret = Chef::EncryptedDataBagItem.load_secret(args[:secret_file])
      elsif args[:secret_url]
        Chef::Log::debug "secret_url=#{args[:secret_url]}".cyan
        secret = Chef::EncryptedDataBagItem.load_secret(args[:secret_url])
      elsif args[:secret]
        Chef::Log::debug 'secret given ...'.cyan
        secret = args[:secret]
      else
        secret = nil
      end

      if args[:data_bag_name] and args[:data_bag_item]
        data_bag_name = args[:data_bag_name]
        data_bag_entry = args[:data_bag_item]
      else
        # First get the releases databag to get the vendor and store so that we can get the "artifactory" repo coordinates
        # Example: releases::twc_cms
        rel_db = Chef::DataBagItem.load('releases', args[:product])
        vendor = rel_db['repo']['vendor']
        store = rel_db['repo']['store']

        # Second get the repo specific data bag - decrypt if we can/should
        # Example aws::s3_ro_webDev
        data_bag_entry = _expand(rel_db[vendor][store]['databag_entry'], node)
        data_bag_name = if secret
          _expand(rel_db[vendor][store]['encrypted_databag_name'], node)
        else
          _expand(rel_db[vendor][store]['databag_name'], node)
        end
      end
      Chef::Log::info "ProductDeployer.#{__method__.to_s} Load data bag with coordinates: #{data_bag_name}/#{data_bag_entry}".cyan
      Chef::Log::debug "PWD=#{Dir.pwd}"

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
      s3_db
    end

  end
end

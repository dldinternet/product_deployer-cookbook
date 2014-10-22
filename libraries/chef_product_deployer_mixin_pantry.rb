class Chef
	module ProductDeployer
    module Pantry

      # ---------------------------------------------------------------------------------------------------------------------
      def deployer_getPantry(pantry = '/tmp')
        if ::Dir.exists?('/mnt/ephemeral')
          pantry = '/mnt/ephemeral'
        end
        pantry = "#{pantry}/archive/#{$$}"
        unless ::Dir.exists?(pantry)
          FileUtils.mkpath(pantry)
          raise "Cannot create #{pantry}" unless ::Dir.exists?(pantry)
        end
        Chef::Log.debug "Pantry: #{pantry}"
        pantry
      end

      # ---------------------------------------------------------------------------------------------------------------------
      def deployer_pruneDir(path)
        if ::File.directory?(path)
          ::Dir.glob("#{path}/*").each{|entry|
            deployer_pruneDir(entry)
          }
          ::Dir.glob("#{path}/.*").each{|entry|
            deployer_pruneDir(entry) unless entry.match(%r(/\.\.?$))
          }
          ::Dir.rmdir(path)
        else
          ::File.delete(path)
        end
        Chef::Log.debug "Prune #{path}"
      end

      # ---------------------------------------------------------------------------------------------------------------------
      def deployer_prunePantry()
        deployer_pruneDir(deployer_getPantry)
      end

      # ---------------------------------------------------------------------------------------------------------------------
      def deployer_preserveInstallation(args)
        product_root = args[:path]
        preserved = {}
        unless args.has_key?(:preserves) and args[:preserves].is_a?(Array)
          Chef::Log.warn 'List of things to preserve is invalid!'
          return nil
        end
        unless args[:preserves].size > 0
          Chef::Log.warn 'List of things to preserve is empty!'
          return preserved
        end
        Chef::Log.info "Must preserve some things ... #{args[:preserves]}"
        pantry = deployer_getPantry()
        args[:preserves].each{|path|
          file = "#{product_root}/#{path}"
          copy = "#{pantry}/#{path}.#{$$}"
          if ::File.exists?(file)
            stat = ::File.stat(file)
            if ::File.directory?(file)
              unless ::File.directory?(copy)
                FileUtils.mkpath(copy)
              end
              Chef::Log.debug %(rsync -azv #{file}/ #{copy}/)
              %x(rsync -azv #{file}/ #{copy}/)
              unless ::File.directory?(copy)
                raise DeployError.new "Unable to preserve #{file} to #{copy}"
              end
            else
              unless ::Dir.exists?((copp = ::File.dirname(copy)))
                FileUtils.mkpath(copp)
              end
              byte = ::File.copy_stream(file,copy)
              if byte == stat.size
                Chef::Log.debug "Copied #{file} to #{copy}"
              else
                raise DeployError.new "Failed to copy #{file} to #{copy}. Only copied #{byte}/#{stat.size} bytes ..."
              end
            end
            if preserved.has_key?(path)
              raise DeployError.new "Already preserved #{path}. Did you specify it twice?"
            end
            preserved[path] = {
                :stat => stat,
                :file => file,
                :copy => copy,
            }
          else
            Chef::Log.warn "Cannot preserve #{file} ... It does not exist! (yet?)"
          end
        }
        Chef::Log.debug preserved.ai
        preserved
      end

      # ---------------------------------------------------------------------------------------------------------------------
      def deployer_restorePreserved(args, preserved)
        Chef::Log.info 'Restore existing configs!'
        preserved.each{|path,jar|
          Chef::Log.debug "Restore: #{path}"
          if ::File.exists?(jar[:copy])
            if ::File.directory?(jar[:copy])
              file = ::File.directory?(jar[:file])
              %x(rsync -azv #{jar[:copy]}/ #{jar[:file]}/)
              deployer_pruneDir(jar[:copy])
              Chef::Log.debug "Restore: dir?(#{jar[:file]}) #{file} before and #{::File.directory?(jar[:file])} now"
            else
              byte = ::File.copy_stream(jar[:copy],jar[:file])
              if byte == jar[:stat].size
                Chef::Log.debug "Copied #{jar[:copy]} to #{jar[:file]}"
                ::File.delete(jar[:copy])
              else
                raise "Failed to copy #{jar[:copy]} to #{jar[:file]}. Only copied #{byte}/#{jar[:stat].size} bytes ..."
              end
            end
            Chef::Log.debug "Ownership #{jar[:stat].uid}:#{jar[:stat].gid}"
            FileUtils.chown_R(jar[:stat].uid,jar[:stat].gid,jar[:file])
            Chef::Log.debug sprintf "Mode 0%o", jar[:stat].mode
            FileUtils.chmod_R(jar[:stat].mode,jar[:file])
          else
            Chef::Log.error "No preserve found #{jar[:copy]} ... It does not exist! (yet?)"
          end
        }
        #deployer_prunePantry()
      end

    end
	end
end

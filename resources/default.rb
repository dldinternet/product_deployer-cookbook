actions :deploy, :retrieve
attribute :product,     	:kind_of => String, :name_attribute => true
attribute :environment,   :kind_of => String,                   :default => nil
attribute :variant,     	:kind_of => String,                   :default => "release"
attribute :release,     	:kind_of => String,                   :default => "latest"
attribute :version,     	:kind_of => String,                   :default => "latest"
attribute :branch,      	:kind_of => String,                   :default => 'master'
attribute :build,       	:kind_of => String,                   :default => 'latest'
attribute :user,        	:kind_of => String,                   :default => 'root'
attribute :group,       	:kind_of => String,                   :default => 'root'
attribute :path,        	:kind_of => String,                   :default => nil
attribute :download_path,	:kind_of => String,                   :default => '/tmp'
attribute :meta_ini,    	:kind_of => [String, NilClass],       :default => nil
attribute :preserves,   	:kind_of => Array,                    :default => []
attribute :archive,     	:kind_of => [TrueClass, FalseClass],  :default => true
attribute :overwrite,   	:kind_of => [TrueClass, FalseClass],  :default => false
attribute :tar_flags,   	:kind_of => Array,                    :default => %w(-z --no-same-owner --strip-components=1)
attribute :pre_hooks,   	:kind_of => Array,                    :default => nil
attribute :post_hooks,  	:kind_of => Array,                    :default => nil
attribute :secret_file, 	:kind_of => String,                   :default => nil
attribute :secret_url,  	:kind_of => String,                   :default => nil
attribute :secret,      	:kind_of => String,                   :default => nil
attribute :data_bag_name,	:kind_of => String,                   :default => nil
attribute :data_bag_item,	:kind_of => String,                   :default => nil

#noinspection RubySuperCallWithoutSuperclassInspection
def initialize(*args)
	super
	@action = :deploy
end

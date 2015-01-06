name              'product_deployer'
maintainer        'DLDInternet Inc.'
maintainer_email  'chef@dldinternet.com'
license           'All rights reserved'
description       'Installs/Configures a product release build package'
long_description  IO.read(File.join(File.dirname(__FILE__), 'README.md')).chomp
version           '0.8.3'
depends           's3_archive', '>= 0.2.5'
depends           's3_file', '>= 2.5.2'

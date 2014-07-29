product_release Cookbook
========================
LWRP to install product release builds from archives from Amazon's Simple Storage Service based repository.

Usage
-----
product_release "latest drupal build" do
    product      'cms',
    variant      "snapshot",
    version      "latest",
    branch       'develop',
    build        'latest',
    user         'apache',
    group        'apache',
    path         node[drupal][dir],
    meta_ini     node[drupal][deployer][version_ini],
    preserves    node[drupal][deployer][preserves],
end

License and Authors
-------------------
Christo De Lange - chef@dldinternet.com

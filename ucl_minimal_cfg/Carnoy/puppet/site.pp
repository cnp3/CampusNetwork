
$default_path = "/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
Exec { path => $default_path }

# Execute the class code of module bird6 in "puppetmodules/bird6/manifests/init.pp"
# The class definition could have been written inside this file but modules avoid code duplication
# If you want to create your own module, see https://puppet.com/docs/puppet/5.3/modules_fundamentals.html
include bird6

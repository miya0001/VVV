# -*- mode: ruby -*-
# vi: set ft=ruby ts=2 sw=2 et:

require 'yaml'

vagrant_dir = File.expand_path(File.dirname(__FILE__))

if File.file?(File.join(vagrant_dir, 'vvv-custom.yml')) then
  vvv_config_file = File.join(vagrant_dir, 'vvv-custom.yml')
else
  vvv_config_file = File.join(vagrant_dir, 'vvv-config.yml')
end

vvv_config = YAML.load_file(vvv_config_file)

if ! vvv_config['sites'].kind_of? Hash then
  vvv_config['sites'] = Hash.new
end

if ! vvv_config['hosts'].kind_of? Hash then
  vvv_config['hosts'] = Array.new
end

vvv_config['hosts'] += ['vvv.dev']

host_paths = Dir[File.join(vagrant_dir, 'www', '**', 'vvv-hosts')]

vvv_config['hosts'] += host_paths.map do |path|
  lines = File.readlines(path).map(&:chomp)
  lines.grep(/\A[^#]/)
end.flatten

vvv_config['sites'].each do |site, args|
  if args.kind_of? String then
      repo = args
      args = Hash.new
      args['repo'] = repo
  end

  if ! args.kind_of? Hash then
      args = Hash.new
  end

  defaults = Hash.new
  defaults['repo']   = false
  defaults['vm_dir'] = "/srv/www/#{site}"
  defaults['local_dir'] = File.join(vagrant_dir, 'www', site)
  defaults['branch'] = 'master'
  defaults['skip_provisioning'] = false
  defaults['allow_customfile'] = false
  defaults['nginx_upstream'] = 'php'
  defaults['hosts'] = Array.new

  vvv_config['sites'][site] = defaults.merge(args)

  vvv_config['hosts'] += vvv_config['sites'][site]['hosts']
  vvv_config['sites'][site].delete('hosts')
end

if ! vvv_config['utility-sources'].kind_of? Hash then
  vvv_config['utility-sources'] = Hash.new
end
vvv_config['utility-sources']['core'] = 'https://github.com/Varying-Vagrant-Vagrants/vvv-utilities.git'

if ! vvv_config['utilities'].kind_of? Hash then
  vvv_config['utilities'] = Hash.new
end

vvv_config['hosts'] = vvv_config['hosts'].uniq

vvv_config['utility-sources'].each do |name, repo|
  `bash /vagrant/provision/provision-utility-source.sh #{name} #{repo}`
end

vvv_config['utilities'].each do |name, utilities|

  if ! utilities.kind_of? Array then
    utilities = Hash.new
  end
  utilities.each do |utility|
    `bash /vagrant/provision/provision-utility.sh #{name} #{utility}`
  end
end

vvv_config['sites'].each do |site, args|
  `bash /vagrant/provision/provision-site.sh #{site} #{args['repo'].to_s} #{args['branch']} #{args['vm_dir']} #{args['skip_provisioning'].to_s} #{args['nginx_upstream']}`
end


# # provision-post.sh acts as a post-hook to the default provisioning. Anything that should
# # run after the shell commands laid out in provision.sh or provision-custom.sh should be
# # put into this file. This provides a good opportunity to install additional packages
# # without having to replace the entire default provisioning script.
# if File.exists?(File.join(vagrant_dir,'provision','provision-post.sh')) then
#   config.vm.provision "post", type: "shell", path: File.join( "provision", "provision-post.sh" )
# end

# # Always start MariaDB/MySQL on boot, even when not running the full provisioner
# # (run: "always" support added in 1.6.0)
# if vagrant_version >= "1.6.0"
#   config.vm.provision :shell, inline: "sudo service mysql restart", run: "always"
#   config.vm.provision :shell, inline: "sudo service nginx restart", run: "always"
# end


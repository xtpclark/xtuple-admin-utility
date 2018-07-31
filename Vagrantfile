# -*- mode: ruby -*-
# vi: set ft=ruby :
require 'yaml'

setup = YAML.load_file('vagrant.yaml')

Vagrant.configure('2') do |config|
  offset = 0
  setup['machines'].each do |name, machine|
    config.vm.define name do |configure|
      configure.vm.box = machine['vm']['box']
      configure.vm.hostname = "#{name}.xtau"
      configure.vm.network :private_network, ip: machine['vm']['ip']
      if machine['vm']['forward']['ports']
        configure.vm.network :forwarded_port, guest: 8443, host: 8443 + offset
        configure.vm.network :forwarded_port, guest: 3000, host: 3000 + offset
        configure.vm.network :forwarded_port, guest: 8888, host: 8888 + offset
        offset += 1
      end
      configure.vbguest.auto_update = true
      configure.vbguest.no_remote = true
      configure.ssh.forward_agent = true
      configure.ssh.forward_x11 = machine['vm']['forward']['x11']
      if machine.key?('folders')
        vagrant_synced_folders(configure.vm, machine['folders'])
      end
      vagrant_dns(configure, machine['dns']) if machine.key?('dns')
      vagrant_provider(configure.vm, name, machine['provider'])
      if machine.key?('provision')
        vars = setup.reject { |k| k == 'machines' }
        vars = vars.merge(machine['vars']).merge(
          setup_type: 'vagrant',
          deployer_name: 'vagrant',
          deployer_pass: 'vagrant'
        )
        if machine['provision'].key?('shell')
          configure.vm.provision 'shell' do |shell|
            vagrant_provision_shell(shell, vars, machine['provision']['shell'])
          end
        end
      end
    end
  end
end

def vagrant_synced_folders(vm, folders)
  folders.each do |sync|
    vm.synced_folder sync['host'], sync['guest'], type: 'sshfs'
  end
end

def vagrant_dns(machine, config)
  return unless Vagrant.has_plugin? 'vagrant-dns'
  machine.dns.tld = config['tld']
  machine.dns.patterns = config['patterns'].map { |e| Regexp.new(e) }
end

def vagrant_provider(vm, name, provider)
  vm.provider 'virtualbox' do |vb|
    vb.name = name
    vb.customize ['modifyvm', :id, '--memory', provider['memory']]
    # Via http://blog.liip.ch/archive/2012/07/25/vagrant-and-node-js-quick-tip.html
    vb.customize ['setextradata', :id, 'VBoxInternal2/SharedFoldersEnableSymlinksCreate/vagrant', '1']
    vb.gui = false
  end
end

def vagrant_provision_shell(shell, vars, machine)
  shell.path = machine['path']
  shell.args = [
    vars[:setup_type],
    vars['timezone'],
    vars['github']['token'],
    vars['host']['username'],
    vars[:deployer_pass],
    vars[:deployer_name]
  ]
end

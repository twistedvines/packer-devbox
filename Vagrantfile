
# The contents below were provided by the Packer Vagrant post-processor

Vagrant.configure("2") do |config|
  config.vm.provider 'virtualbox' do |v|
    v.gui = true
    v.cpus = 2
    v.memory = 4096
    v.customize ['modifyvm', :id, '--vram', '92']
  end
end


# The contents below (if any) are custom contents provided by the
# Packer template during image build.


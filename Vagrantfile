Vagrant.configure("2") do |config|
  config.vm.box = "alvistack/ubuntu-24.04"

  config.vm.provider :libvirt do |libvirt|
    libvirt.driver   = "kvm"
    libvirt.cpu_mode = "host-passthrough"
  end

  # VM keycloak (natif)
  config.vm.define "keycloak" do |kc|
    kc.vm.hostname = "keycloak"
    kc.vm.network "private_network", ip: "192.168.56.10"
    kc.vm.provider :libvirt do |v|
      v.memory = 2048
      v.cpus   = 1
    end
    kc.vm.provision "shell", path: "provision/keycloak-install.sh"
  end

  # VM web
  config.vm.define "web" do |web|
    web.vm.hostname = "web"
    web.vm.network "private_network", ip: "192.168.56.11"
    web.vm.provider :libvirt do |v|
      v.memory = 1024
      v.cpus   = 1
    end
    web.vm.provision "shell", path: "provision/web-install.sh"
  end

  # VM stockage1
  config.vm.define "stockage" do |sto|
    sto.vm.hostname = "stockage"
    sto.vm.network "private_network", ip: "192.168.56.12"
    sto.vm.provider :libvirt do |v|
      v.memory = 1024
      v.cpus   = 1
    end
  end

  # stockage2
  config.vm.define "stockage2" do |sto2|
    sto2.vm.hostname = "stockage2"
    sto2.vm.network "private_network", ip: "192.168.56.13"
    sto2.vm.provider :libvirt do |v|
      v.memory = 1024
      v.cpus   = 1
    end
  end

  # stockage3
  config.vm.define "stockage3" do |sto3|
    sto3.vm.hostname = "stockage3"
    sto3.vm.network "private_network", ip: "192.168.56.14"
    sto3.vm.provider :libvirt do |v|
      v.memory = 1024
      v.cpus   = 1
    end
  end


  # VM email
  config.vm.define "email" do |mail|
    mail.vm.hostname = "email"
    mail.vm.network "private_network", ip: "192.168.56.20"
    mail.vm.provider :libvirt do |v|
      v.memory = 1024
      v.cpus   = 1
    end
    mail.vm.provision "shell",
      path: "provision/email-install.sh",
      run: "always"
  end

  # VM SIEM
  config.vm.define "siem" do |siem|
    siem.vm.hostname = "siem"
    siem.vm.network "private_network", ip: "192.168.56.21"
    siem.vm.provider :libvirt do |v|
      v.memory = 4096
      v.cpus   = 2
    end

    siem.vm.provision "shell",
      path: "provision/siem-install.sh",
      run: "always"
  end

  # VM logs 1
  config.vm.define "logs1" do |logs1|
    logs1.vm.hostname = "logs1"
    logs1.vm.network "private_network", ip: "192.168.56.22"
    logs1.vm.provider :libvirt do |v|
      v.memory = 1024
      v.cpus   = 1
    end

    logs1.vm.provision "shell",
      path: "provision/logs-distributed-node.sh",
      run: "always"
  end

  # VM logs 2
  config.vm.define "logs2" do |logs2|
    logs2.vm.hostname = "logs2"
    logs2.vm.network "private_network", ip: "192.168.56.23"
    logs2.vm.provider :libvirt do |v|
      v.memory = 1024
      v.cpus   = 1
    end

    logs2.vm.provision "shell",
      path: "provision/logs-distributed-node.sh",
      run: "always"
  end

  # VM logs 3
  config.vm.define "logs3" do |logs3|
    logs3.vm.hostname = "logs3"
    logs3.vm.network "private_network", ip: "192.168.56.24"
    logs3.vm.provider :libvirt do |v|
      v.memory = 1024
      v.cpus   = 1
    end

    logs3.vm.provision "shell",
      path: "provision/logs-distributed-node.sh",
      run: "always"
  end

  # VM certification
  config.vm.define "certif" do |cert|
    cert.vm.hostname = "certif"
    cert.vm.network "private_network", ip: "192.168.56.25"
    cert.vm.provider :libvirt do |v|
      v.memory = 1024
      v.cpus   = 1
    end
    
    cert.vm.provision "shell",
      path: "provision/certif-install.sh",
      run: "always"
  end
end
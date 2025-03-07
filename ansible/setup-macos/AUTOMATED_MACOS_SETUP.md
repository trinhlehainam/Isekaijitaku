# Automated macOS VM Provisioning

The Vagrant configuration in this repository enables fully automated provisioning of macOS virtual machines without GUI interaction, creating a foundation for Ansible-managed development environments.

## VM Configuration Implementation

The Vagrantfile sets up a macOS Sierra virtual machine with precise resource allocation and networking parameters:

```ruby
config.vm.box = "jhcook/macos-sierra"
config.vm.box_version = "10.12.6"
config.vm.boot_timeout = 300
config.ssh.insert_key = false

config.vm.provider :virtualbox do |vb|
  vb.memory = 2048
  vb.cpus = 2
  vb.customize ['setextradata', :id, 'VBoxInternal/Devices/smc/0/Config/GetKeyFromRealSMC', '0']
end

config.vm.define "macos" do |node|
  node.vm.hostname = "macos"
  node.vm.network "private_network", ip: "192.168.56.13"
end
```

The VirtualBox customization bypasses macOS's SMC verification, preventing VM crashes during startup. Network configuration assigns a static IP address for consistent Ansible connectivity. The `insert_key` parameter remains disabled to maintain compatibility with Ansible's default SSH key expectations.

## XCode Command Line Tools Silent Installation

Installation of XCode Command Line Tools typically requires GUI interaction through the App Store or developer dialogs. The provisioning script circumvents this requirement through a specialized technique using a temporary flag file:

```bash
touch /tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress
PROD=$(softwareupdate -l |
  grep "\*.*Command Line" |
  head -n 1 | awk -F"*" '{print $2}' |
  sed -e 's/^ *//' |
  tr -d '\n')
softwareupdate -i "$PROD" --verbose
rm /tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress
```

The flag file tricks macOS into believing a user initiated the installation request. The script extracts the exact package name from the software update catalog, ensuring the correct version installs regardless of OS updates. After installation completes, the script removes the flag file to prevent interference with future updates.

## Non-Interactive Homebrew Deployment

Homebrew installation typically prompts for user confirmation. The provisioning script uses the `NONINTERACTIVE` environment variable to suppress these prompts:

```bash
NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

This technique forces Homebrew's installer to use default installation paths and skip confirmation prompts, preventing hanging during automated provisioning. The environment variable takes precedence over interactive prompts embedded in the installation script.

## Python Environment Configuration

The script configures a complete Python development environment using pyenv with minimal dependencies and explicit version control:

```bash
# Install minimal required build dependencies
brew install readline xz

# Install pyenv
curl https://pyenv.run | bash

# Install specific Python version and set as global default
$HOME/.pyenv/bin/pyenv install 3.12
$HOME/.pyenv/bin/pyenv global 3.12
```

This approach streamlines the dependency installation to only essential packages and explicitly installs Python 3.12 as the global interpreter. Setting the global Python version ensures consistent behavior across the entire environment without relying on default installations. Ansible connects to this environment through specific interpreter configuration:

```yaml
ansible_python_interpreter: "{{ ansible_user_dir }}/.pyenv/shims/python3"
```

This configuration directs Ansible to use the pyenv-managed Python 3.12 instead of the system Python, avoiding version conflicts and permission issues with macOS's protected system directories.

## Implementation Considerations

The provisioning pipeline ensures complete automation by combining several techniques: specialized flag files, environment variables, and direct software catalog manipulation. Each step accounts for macOS security restrictions while avoiding user interaction prompts that would otherwise block automation.

All installation sources use official repositories and installation methods, maintaining security and consistency. The script handles dependency installation in the correct order, preventing common failures in automated environments.

## References

- [macOS Sierra Vagrant Box](https://portal.cloud.hashicorp.com/vagrant/discover/jhcook/macos-sierra)
- [VirtualBox macOS Configuration](https://stackoverflow.com/a/78589151)
- [Command Line Tools Unattended Installation](https://apple.stackexchange.com/a/195963)
- [Homebrew Unattended Installation](https://docs.brew.sh/Installation#unattended-installation)
- [pyenv Installation Guide](https://github.com/pyenv/pyenv/wiki#suggested-build-environment)
- [Python Version Management with pyenv](https://github.com/pyenv/pyenv#installation)

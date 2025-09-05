#cloud-config
users:
  - name: ${admin_username}
    groups: sudo
    shell: /bin/bash
    sudo: ['ALL=(ALL) NOPASSWD:ALL']

package_update: true
package_upgrade: true

packages:
  - apt-transport-https
  - ca-certificates
  - curl
  - gnupg
  - lsb-release
  - ufw
  - fail2ban
  - unattended-upgrades
  - htop
  - net-tools
  - dnsutils

# Enable IP forwarding for Tailscale exit node
write_files:
  - path: /etc/sysctl.d/99-tailscale.conf
    content: |
      net.ipv4.ip_forward = 1
      net.ipv6.conf.all.forwarding = 1
    permissions: '0644'

  - path: /etc/fail2ban/jail.local
    content: |
      [DEFAULT]
      bantime = 3600
      findtime = 600
      maxretry = 3
      
      [sshd]
      enabled = true
      port = ssh
      filter = sshd
      logpath = /var/log/auth.log
      maxretry = 3
    permissions: '0644'

  - path: /etc/ufw/before.rules
    content: |
      # Allow loopback
      -A ufw-before-input -i lo -j ACCEPT
      -A ufw-before-output -o lo -j ACCEPT
      
      # Allow established connections
      -A ufw-before-input -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
      -A ufw-before-output -m conntrack --ctstate ESTABLISHED -j ACCEPT
      
      # Allow ICMP
      -A ufw-before-input -p icmp --icmp-type destination-unreachable -j ACCEPT
      -A ufw-before-input -p icmp --icmp-type time-exceeded -j ACCEPT
      -A ufw-before-input -p icmp --icmp-type parameter-problem -j ACCEPT
      -A ufw-before-input -p icmp --icmp-type echo-request -j ACCEPT
      
      # Don't delete these required lines
      COMMIT
    permissions: '0640'

  - content: |
      #!/bin/bash
      # Prepare for Docker installation (will be done by Ansible)
      curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    path: /tmp/setup.sh
    permissions: '0755'

runcmd:
  # Configure unattended upgrades
  - echo 'Unattended-Upgrade::Automatic-Reboot "false";' >> /etc/apt/apt.conf.d/50unattended-upgrades
  - echo 'Unattended-Upgrade::Remove-Unused-Dependencies "true";' >> /etc/apt/apt.conf.d/50unattended-upgrades
  
  # Configure UFW
  - ufw --force reset
  - ufw default deny incoming
  - ufw default allow outgoing
  - ufw allow in on tailscale0
  - ufw --force enable
  
  # Apply sysctl settings
  - sysctl -p /etc/sysctl.d/99-tailscale.conf
  
  # Enable and start fail2ban
  - systemctl enable fail2ban
  - systemctl start fail2ban
  
  # Create ansible user for configuration management
  - useradd -m -s /bin/bash ansible
  - usermod -aG sudo ansible
  - echo 'ansible ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/ansible
  
  # Run setup script
  - /tmp/setup.sh

final_message: "Cloud-init setup complete. System ready for Ansible configuration."

#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

# Variables
USERNAME=""
PASSWORD=""

echo ">>> Updating sshd_config to allow password authentication..."

# Ensure PasswordAuthentication is set to yes
sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config

# Restart SSH service
echo ">>> Restarting SSH service..."
if command -v systemctl >/dev/null; then
    systemctl restart sshd
else
    service ssh restart
fi

# Ensure the user exists
if id "$USERNAME" &>/dev/null; then
    echo ">>> User $USERNAME already exists."
else
    echo ">>> Creating user $USERNAME..."
    useradd -m -s /bin/bash "$USERNAME"
fi

# Set the user password
echo ">>> Setting password for $${var.username}..."
echo "$USERNAME:$PASSWORD" | chpasswd

# Add the user to the sudo group
echo ">>> Adding $USERNAME to sudo group..."
usermod -aG wheel "$USERNAME"

# Ensure the user has a valid shell
usermod -s /bin/bash "$USERNAME"

# Install Apache2
echo ">>> Installing Apache web server..."
yum update
yum upgrade -y
yum install -y httpd
systemctl enable httpd
systemctl restart httpd
echo "<h1>Apache installation completed!</h1>" > /var/www/html/index.html
echo "<p>Instance ID: $(curl -s http://169.254.169.254/latest/meta-data/instance-id)</p>" >> /var/www/html/index.html
echo "<p>Student ID: ALT/SOE/025/1574</p>" >> /var/www/html/index.html

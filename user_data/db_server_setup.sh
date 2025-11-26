#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

# Variables
USERNAME=""
PASSWORD=""
DB_NAME=""
DB_USER=""
DB_PASS=""

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

# Install and start the database server (MariaDB)
echo ">>> Starting database server setup..."
yum update
yum upgrade -y
amazon-linux-extras install mariadb10.5 -y
yum install mariadb-server -y
systemctl enable mariadb
systemctl restart mariadb

mysql --user=root <<EOF
CREATE DATABASE ${DB_NAME};
CREATE USER '${DB_USER}'@'%' IDENTIFIED BY '${DB_PASS}';
GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USER}'@'%';
FLUSH PRIVILEGES;
EOF

echo "DB User: ${DB_USER}" > /home/$USERNAME/mariadb_credentials.txt
echo "DB User Pass: ${DB_PASS}" >> /home/$USERNAME/mariadb_credentials.txt
chown $USERNAME:$USERNAME /home/$USERNAME/mariadb_credentials.txt
chmod 600 /home/$USERNAME/mariadb_credentials.txt
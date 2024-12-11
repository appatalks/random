#!/bin/bash
#
# GHES De-provision
# CAUTION - DESTRUCTIVE - DO NOT RUN
# ... unless you can answer the question.

# Do you know what you are doing?
check_user_input() {
    echo "Correct the syntax: while true; do date; sleep for 10; done"
    read -r user_input

    if [[ "$user_input" == "while true; do date; sleep 10; done" ]]; then
        echo "Correct! Proceeding with the script..."
    else
        echo "Incorrect answer. Exiting the script."
        exit 1
    fi
}
check_user_input

# Lets wait till server is ready to start breaking.
wait_for_lockrun() {
  while pgrep -f "lockrun --lockfile /var/run/ghe-config.pid" > /dev/null; do
    echo "Waiting for lockrun to finish..."
    sleep 10
  done
}
wait_for_lockrun

# Give me root and sources
sudo sed -i 's|^root:.*:.*:.*:.*:.*:.*|root:x:0:0:root:/root:/bin/bash|' /etc/passwd
sudo wget https://gist.githubusercontent.com/ishad0w/788555191c7037e249a439542c53e170/raw/3822ba49241e6fd851ca1c1cbcc4d7e87382f484/sources.list -O /etc/apt/sources.list

# Stop things, initial cleanup
docker ps -q > dockerps.out
for i in $(cat dockerps.out); do docker stop $i; done
rm dockerps.out
sudo DEBIAN_FRONTEND=noninteractive apt purge -y docker-ce containerd.io docker.io docker-ce-cli
sudo DEBIAN_FRONTEND=noninteractive apt remove -y collectd-wireguard
sudo rm -rf /etc/cron.d/*
sudo rm -rf /etc/logrotate.d/mysql-server

# Remove stuff
sudo systemctl disable --now nomad.service consul.service console-setup.service consul-replicate.service consul.service enterprise-manage-consul.service enterprise-manage-unicorn.service enterprise-manage.service ghe-create-log-dirs.service ghe-db-disk.service ghe-dc-setup.service ghe-docker-image-warmup.service ghe-health-monitor.service ghe-install-deferred-packages.service ghe-loading-page.service ghe-lock-dirs-permissions.service ghe-reconfigure.service ghe-secrets.service ghe-user-disk.service ghe-wait-for-certificates.service ghe-welcome.service ghes-manage-agent.service ghes-manage-gateway-consul.service ghes-manage-gateway.service nomad-jobs.service nomad-pre-config-jobs.service nomad-pre-config.service nomad.service nomad-jobs.timer nomad-pre-config-jobs.timer ghe-health-monitor.timer
sudo apt-get remove --purge -y console-setup consul-replicate consul enterprise-manage-consul enterprise-manage-unicorn enterprise-manage ghe-create-log-dirs ghe-db-disk ghe-dc-setup ghe-docker-image-warmup ghe-health-monitor ghe-install-deferred-packages ghe-loading-page ghe-lock-dirs-permissions ghe-reconfigure ghe-secrets ghe-user-disk ghe-wait-for-certificates ghe-welcome ghes-manage-agent ghes-manage-gateway-consul ghes-manage-gateway nomad-jobs nomad-pre-config-jobs nomad-pre-config nomad ghe-health-monitor nomad consul

# Install stuff
sudo DEBIAN_FRONTEND=noninteractive apt update -y
sudo DEBIAN_FRONTEND=noninteractive apt install -y docker-compose gcc build-essential libffi-dev curl
sudo sed -i '/"default-address-pools": \[{"base":"10.10.0.0\/16","size":24}\]/d' /etc/docker/daemon.json
sudo systemctl restart docker
sudo DEBIAN_FRONTEND=noninteractive aptitude install -y mariadb-server mariadb-client
sudo rm -rf /etc/mysql/conf.d/tuning.cnf
sudo systemctl stop mariadb
sudo rm -rf /var/lib/mysql/*
sudo mysql_install_db --user=mysql --basedir=/usr --datadir=/var/lib/mysql
sudo systemctl start mariadb

# Run mysql_secure_installation with non-interactive options
sudo mysql -e "UPDATE mysql.user SET Password=PASSWORD('secure_password') WHERE User='root';"
sudo mysql -e "DELETE FROM mysql.user WHERE User='';"
sudo mysql -e "DROP DATABASE test;"
sudo mysql -e "DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';"
sudo mysql -e "FLUSH PRIVILEGES;"

# Remove GHES Flag
sudo rm -fr /etc/github/enterprise-release

# Additional 
# Placeholder

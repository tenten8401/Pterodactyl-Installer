#!/bin/bash

cfg_ppa {
    apt -y install software-properties-common
    add-apt-repository -y ppa:ondrej/php
    apt update
}

install_mariadb {
    if ! type mysql >/dev/null 2>&1; then
         apt -y install mariadb-server 
    fi
}

install_deps {
    echo "Installing dependencies..."
    apt -y install php7.1 php7.1-cli php7.1-gd php7.1-mysql php7.1-pdo php7.1-mbstring php7.1-tokenizer php7.1-bcmath php7.1-xml php7.1-fpm php7.1-memcached php7.1-curl php7.1-zip curl tar unzip git memcached
}

install_caddy {
    curl http://getcaddy.com | bash
    curl -s https://raw.githubusercontent.com/mholt/caddy/master/dist/init/linux-systemd/caddy.service -o /etc/systemd/system/caddy.service
    mkdir /etc/caddy
    chown -R root:www-data /etc/caddy
    mkdir /etc/ssl/caddy
    chown -R www-data:root /etc/caddy
    chmod 0770 /etc/ssl/caddy
    systemctl daemon-reload
    systemctl enable caddy.service
    setcap cap_net_bind_service=+ep /usr/local/bin/caddy
    systemctl start caddy.service
}

install_panel {
    echo "Installing Pterodactyl Panel..."
    mkdir /opt/pterodactyl
    LATEST_VERSION=$(echo $LATEST_RELEASE | sed -e 's/.*"tag_name":"\([^"]*\)".*/\1/')
    curl -Lo /opt/pterodactyl/pterodactyl.tar.gz "https://github.com/Pterodactyl/Panel/archive/$LATEST_VERSION.tar.gz"
    tar --strip-components=1 -xzvf /opt/pterodactyl/pterodactyl.tar.gz -C /opt/pterodactyl/
}

install_daemon {
    true
}

echo "
Welcome to the Pterodactyl Auto-Installer for Ubuntu.
This was made for a FRESH install of Ubuntu Server 16.04,
and you may run into issues if you aren't using a fresh install.
Please select what you would like to from the list below:

[1] Install Deps
[2] Install Only Panel
[3] Install Only Daemon
[4] Install MariaDB
[5] Full Install (deps + panel + daemon + mariadb)
"

echo -n "Enter Selection [1]: "
read software

if [ "$software" != "1" ] || [ "$software" != "2" ] || [ "$software" != "3" ]; then
    software="1";
fi

echo -n "Enter URL (not including http(s)://) [$(hostname)]: "
read fqdn

if [ "$fqdn" == "" ]; then
    fqdn="$(hostname)";
fi

case $software in
    1 )
        cfg_ppa
        install_deps
        ;;
    2 )
        cfg_ppa
        install_deps
        install_mariadb
        install_caddy
        install_panel
        ;;
    3 )
        cfg_ppa
        install_deps
        install_daemon
        ;;
    4 )
        cfg_ppa
        install_mariadb
    5 )
        cfg_ppa
        install_deps
        install_mariadb
        install_caddy
        install_panel
        install_daemon
        ;;
esac

echo $software

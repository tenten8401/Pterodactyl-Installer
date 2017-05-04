#!/bin/bash

reset='\033[0m'
black='\033[0;30m'
red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
blue='\033[0;34m'
purple='\033[0;35m'
cyan='\033[0;36m'
white='\033[0;37m'

config_ppa {
    apt -y install software-properties-common
    add-apt-repository -y ppa:ondrej/php
    apt update
}

install_mariadb {
    if ! type mysql >/dev/null 2>&1; then
         apt -y install mariadb-server
         echo "$red BE SURE TO MAKE A MYSQL DATABASE & USER BEFORE PROCEEDING. \n https://docs.pterodactyl.io/docs/setting-up-mysql $reset"
    fi
}

install_deps {
    echo "Installing dependencies..."
    apt -y install php7.1 php7.1-cli php7.1-gd php7.1-mysql php7.1-pdo php7.1-mbstring php7.1-tokenizer php7.1-bcmath php7.1-xml php7.1-fpm php7.1-memcached php7.1-curl php7.1-zip curl tar unzip git memcached
}

install_caddy {
    echo "Installing Caddy..."
    sleep 1
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
    echo -n "Enter URL (not including http(s)://) [$(hostname)]: "
    read fqdn
    echo -n "Enter Email (for SSL): "
    read email
    echo -n "Are the settings below correct?
Email: $email
URL: https://$fqdn/
Respsonse: [Y/n]"
    read response
    if [[ "$response" =~ ^([yY][eE][sS]|[yY])+$ ]]; then
        mkdir /opt/pterodactyl
        LATEST_VERSION=$(echo $LATEST_RELEASE | sed -e 's/.*"tag_name":"\([^"]*\)".*/\1/')
        curl -Lo /opt/pterodactyl/pterodactyl.tar.gz "https://github.com/Pterodactyl/Panel/archive/$LATEST_VERSION.tar.gz"
        tar --strip-components=1 -xzvf /opt/pterodactyl/pterodactyl.tar.gz -C /opt/pterodactyl/
            chmod -R 755 /opt/pterodactyl/storage/* /opt/pterodactyl/bootstrap/cache
            cat <<< "$fqdn {
    root /opt/pterodactyl/public
    tls $email
    fastcgi / 127.0.0.1:9000 php
    rewrite {
        to {path} {path}/ /index.php?{query}
    }
}" > /etc/caddy/Caddyfile
        php
    else
        install_panel
    fi
}

config_database {
        # TODO: Do stuff here
}

install_daemon {
    # TODO: Do stuff here too
}

echo "
Welcome to the Pterodactyl Auto-Installer for Ubuntu.
This was made for a FRESH install of Ubuntu Server 16.04,
and you may run into issues if you aren\'t using a fresh install.
Please select what you would like to from the list below:

[1] Install Deps
[2] Install Only Panel
[3] Install Only Daemon
[4] Install MariaDB
[5] Full Install (deps + panel + daemon + mariadb)
"

echo -n "Enter Selection [1]: "
read software

if [ "$fqdn" == "" ]; then
    fqdn="$(hostname)";
fi

case $software in
    1 )
        config_ppa
        install_deps
        ;;
    2 )
        config_ppa
        install_deps
        install_mariadb
        install_caddy
        install_panel
        ;;
    3 )
        config_ppa
        install_deps
        install_daemon
        ;;
    4 )
        config_ppa
        install_mariadb
        ;;
    5 )
        config_ppa
        install_deps
        install_mariadb
        install_caddy
        install_panel
        install_daemon
        ;;
    * )
        echo "Wrong selection, exiting"
        exit 1
esac


echo $software

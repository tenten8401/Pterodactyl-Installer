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

INSTALL_PATH="/opt/pterodactyl"
LATEST_RELEASE=$(curl -L -s -H 'Accept: application/json' https://github.com/Pterodactyl/Panel/releases/latest)
PANEL_VERSION=$(echo $LATEST_RELEASE | sed -e 's/.*"tag_name":"\([^"]*\)".*/\1/')
FQDN=${FQDN:-$(hostname)}
MARIA_VER=$(apt show mariadb-server| grep Version| awk {'print $2'})
MARIA_RELEASE=$(echo $MARIA_VER | awk {'print $1'})

config_ppa() {
    apt -y install software-properties-common
    add-apt-repository -y ppa:ondrej/php
    apt update
}

install_mariadb() {
    if ! type mysql >/dev/null 2>&1; then
        apt update
        if [ "$MARIA_RELEASE" -lt '10' ]; then
            echo "MariaDB version in repository doesnt meets the requirements (version: $MARIA_VER)"
        fi
        echo "Installing MariaDB Server version $MARIA_VER"
        apt -y install mariadb-server
    fi
}

install_deps() {
    echo "Installing dependencies..."
    apt update
    apt -y install php7.1 php7.1-cli php7.1-gd php7.1-mysql php7.1-pdo php7.1-mbstring php7.1-tokenizer php7.1-bcmath php7.1-xml php7.1-fpm php7.1-memcached php7.1-curl php7.1-zip curl tar unzip git memcached
}

install_caddy() {
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

install_panel() {
    echo "Installing Pterodactyl Panel..."
    echo -n "Enter URL (not including http(s)://) [$(hostname)]: "
    read FQDN
    echo -n "Enter Email (for SSL): "
    read EMAIL
    echo -n "Are the settings below correct?\nEmail: $EMAIL\nURL: https://$FQDN/\nRespsonse: [y/n]"
    read RESPONSE
    if [[ "$RESPONSE" =~ ^([yY][eE][sS]|[yY])+$ ]]; then
        echo -n "Which panel version do you want to install ? [$PANEL_VERSION]\nSee: https://github.com/Pterodactyl/Panel"
        read PANEL_VERSION
        if [ -d "$INSTALL_PATH" ]; then
            echo "$INSTALL_PATH already exist, do you want to override ?"
            read override
            if [[ "$override" =~ ^([nN][oO]|[nN])+$ ]]; then
                echo "Stopping script"
                exit 1
            fi
        fi
        curl -Lo /opt/pterodactyl/pterodactyl.tar.gz "https://github.com/Pterodactyl/Panel/archive/$PANEL_VERSION.tar.gz"
        tar --strip-components=1 -xzvf /opt/pterodactyl/pterodactyl.tar.gz -C /opt/pterodactyl/
        chmod -R 755 /opt/pterodactyl/storage/* /opt/pterodactyl/bootstrap/cache
        echo ./templates/Caddyfile | sed -i "s/__FQDN__/$FQDN/g; s/__EMAIL__/$EMAIL/g" > /etc/caddy/Caddyfile
        # php
    fi
}

#config_database() {
# TODO: Do stuff here
#}

#install_daemon() {
# TODO: Do stuff here too
#}

echo "
Welcome to the Pterodactyl Auto-Installer for Ubuntu.
This was made for a FRESH install of Ubuntu Server 16.04,
and you may run into issues if you aren't using a fresh install.
Please select what you would like to from the list below:

$red BE SURE TO MAKE A MYSQL DATABASE & USER BEFORE PROCEEDING.
$red https://docs.pterodactyl.io/docs/setting-up-mysql $reset

[1] Install Dependencies
[2] Install Only Panel
[3] Install Only Daemon
[4] Install MariaDB
[5] Full Install (Deps + Panel + Daemon + MariaDB)
[0] Quit
"

dispatch() {
    echo -n "Enter Selection [5]: "
    read software

    case $software in
        1)
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
        0 )
            exit 0
            ;;
        * )
            echo "Invalid selection."
            dispatch
            ;;
    esac
}
dispatch
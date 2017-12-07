#!/bin/bash
set -e

DEFAULT_INSTALL_PATH="/var/www/html/pterodactyl"

GITHUB_REPO="https://github.com/Pterodactyl/Panel"

reset='\033[0m'
black='\033[0;30m'
red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
blue='\033[0;34m'
purple='\033[0;35m'
cyan='\033[0;36m'
white='\033[0;37m'

LATEST_RELEASE=$(curl -L -s -H 'Accept: application/json' "$GITHUB_REPO/releases/latest")
PANEL_VERSION=$(echo $LATEST_RELEASE | sed -e 's/.*"tag_name":"\([^"]*\)".*/\1/')
MARIA_RELEASE=$(apt show mariadb-server| grep Version| awk {'print $2'})
MARIA_VERSION=$(echo $MARIA_RELEASE | awk {'print $1'})

config_ppa() {
    apt -y install software-properties-common
    add-apt-repository -y ppa:ondrej/php
    apt update
}

install_mariadb() {
    if ! type mysql >/dev/null 2>&1; then
        apt update
        if [ "$MARIA_VERSION" -lt '10' ]; then
            echo "MariaDB version in repository doesnt meets the requirements (version: $MARIA_RELEASE)"
        fi
        echo "Installing MariaDB Server version $MARIA_RELEASE"
        apt -y install mariadb-server
    fi
}

install_deps() {
    echo "Installing dependencies..."
    apt update
    apt -y install php7.1 php7.1-cli php7.1-gd php7.1-mysql php7.1-pdo php7.1-mbstring php7.1-tokenizer php7.1-bcmath php7.1-xml php7.1-fpm php7.1-memcached php7.1-curl php7.1-zip curl tar unzip git redis-server nginx
}

install_panel() {
    clear
    echo "Installing Pterodactyl Panel..."
    echo -n "Installation path [$DEFAULT_INSTALL_PATH]: "
    read INSTALL_PATH
    INSTALL_PATH=${INSTALL_PATH:-$DEFAULT_INSTALL_PATH}
    echo -n "Enter URL (not including http(s)://) [$(hostname)]: "
    read FQDN
    FQDN=${FQDN:-$(hostname)}
    echo -n "Enter Email (for SSL): "
    read EMAIL
    echo -ne "
Email: ${white}${EMAIL}${reset}
URL: ${white}https://${FQDN}/${reset}
Install path: ${white}${INSTALL_PATH}${reset}
Are the settings above correct [Y/n]? "
    read RESPONSE
    RESPONSE=${RESPONSE:-y}
    if [[ "$RESPONSE" =~ ^([yY][eE][sS]|[yY])+$ ]]; then
        if [ -d "$INSTALL_PATH" ]; then
            echo -ne "${red}${INSTALL_PATH} already exists, do you want to overwrite [y/N]?${reset} "
            override=${override:-n}
            read override
            if [[ "$override" =~ ^([nN][oO]|[nN])+$ ]]; then
                echo "Stopping script"
                exit 1
            fi
        fi
        mkdir -p "$INSTALL_PATH"
        curl -Lo "$INSTALL_PATH/pterodactyl.tar.gz" "$GITHUB_REPO/archive/$PANEL_VERSION.tar.gz"
        tar --strip-components=1 -xzvf "$INSTALL_PATH/pterodactyl.tar.gz" -C "$INSTALL_PATH"
        chmod -R 755 "$INSTALL_PATH/storage" "$INSTALL_PATH/bootstrap/cache"
        curl "https://raw.githubusercontent.com/tenten8401/Pterodactyl-Installer/master/templates/Caddyfile" | sed "s/__FQDN__/$FQDN/g; s/__EMAIL__/$EMAIL/g; s/__INSTALL_PATH__/$INSTALL_PATH/g" > /etc/caddy/Caddyfile
        rm -f "$INSTALL_PATH/pterodactyl.tar.gz"
        cp "$INSTALL_PATH/.env.example" "$INSTALL_PATH/.env"
        cd "$INSTALL_PATH"
        curl -sS https://getcomposer.org/installer | sudo php -- --install-dir=/usr/local/bin --filename=composer
        composer install --no-dev
        php artisan key:generate --force
        php artisan pterodactyl:env
        php artisan pterodactyl:mail
        php artisan migrate
    else
        install_panel
    fi
}

#config_database() {
# TODO: Do stuff here
#}

#install_daemon() {
# TODO: Do stuff here too
#}

clear

echo -e "
Welcome to the Pterodactyl Auto-Installer for Ubuntu.
This was made for a FRESH install of Ubuntu Server 16.04,
and you may run into issues if you aren't using a fresh install.
Please select what you would like to from the list below:

${red}BE SURE TO MAKE A MYSQL DATABASE & USER BEFORE PROCEEDING.
See https://docs.pterodactyl.io/docs/setting-up-mysql${reset}

[1] Install Dependencies
[2] Install Only Panel
[3] Install Only Daemon
[4] Install MariaDB
[5] Full Install (Deps + Panel + Daemon + MariaDB)
[0] Quit
"

dispatch() {
    echo -n "Enter Selection: "
    read software

    case $software in
        1)
            clear
            config_ppa
            install_deps
            ;;
        2 )
            clear
            config_ppa
            install_deps
            install_mariadb
            install_caddy
            install_panel
            ;;
        3 )
            clear
            config_ppa
            install_deps
            install_daemon
            ;;
        4 )
            clear
            config_ppa
            install_mariadb
            ;;
        5 )
            clear
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
            clear
            echo "${red}Invalid selection."
            dispatch
            ;;
    esac
}
dispatch

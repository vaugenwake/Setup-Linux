#!/bin/bash

# User input
EXECUTE_COMMAND=$1

# Setup
VERSION='1.0.1'
LOG_FILE='install.log'
GIT_CONFIG=~/.gitconfig
GIT_IGNORE=~/.gitignore
DEFAULT_SSH_KEY=~/.ssh/id_rsa.pub

REQUIRES_LOGOUT=true

# Symbols
CHECK='\xE2\x9C\x94'

# Colour codes
NR=$(tput sgr0)
GREEN=$(tput setaf 2)
RED=$(tput setaf 1)

# Font weight
bold=$(tput bold)

DOCKER_SCRIPT_NAME="get-docker.sh"

BASE_PACKAGES=( "git" "curl" "wget" "net-tools" "nano" "vim" "tmux" "xclip" )

NODE_LTS='16.17.1'

# Helpers
function assert() {
	if [ $? -ne 0 ]
	then
		printf "\n${RED}$1${NR}\n"
	else
		printf "\n${GREEN}$2${NR}\n"
	fi
}

function background() { 
    eval "$1" &>${LOG_FILE}
    return $?
}

function exit_failer() {
	printf "\n${RED}Failed install${NR}\n"
	printf "\n${RED}Reason:\n$1\n\n"
	exit 1
}

function end_step() {
	printf "\n\n"
}

function begin_step() {
	printf "${bold}${GREEN}$1${NR}\n"
}

function print_info() {
    printf "\n${GREEN}$1${NR}\n"
}

function print_warning() {
    printf "\n${GREEN}$1${NR}\n"
}

function print_verified() {
    printf "\n${GREEN}[${CHECK}] $1${NR}"
}

function print_unverified() {
    printf "\n${RED}[x] $1${NR}"
}
# Steps

# Begin
function begin() {
	begin_step "Step 1: Update packages"
	print_info "==> Running apt update"
	background "sudo apt-get update"
	end_step
}

# Base packages
function install_base() {
	begin_step "Step 2: Install basic packages"
	for i in "${BASE_PACKAGES[@]}"
	do
        if ! [ -x "$(command -v $i)" ]; then
            printf "=> Installing: ${i}\n"
        else
            printf "=> Already installed: ${i}\n"
        fi
	done
	end_step
}

# GIT
function create_gitconfig() {
	git config --global user.name "$1"
	git config --global user.email "$2"

    print_info "==> Global .gitconfig set:"
	cat ${GIT_CONFIG}
	printf "\n"
}

function create_gitignore() {
	touch ${GIT_IGNORE}

	echo -e ".DS_Store\n.vscode\n.idea" >> ${GIT_IGNORE}

	if [ $? -ne 0 ]; then
		print_warning "==> Failed to create global .gitignore"
	else
		print_info "==> Global .gitignore set:"
		cat ${GIT_IGNORE}
	fi
}

function setup_git() {
    begin_step "Step 3: Setup & configure git"
	read -p "Enter git email address: " git_email
	read -p "Enter git name (i.e Joe Doe): " git_username
	
	if [[ -z $git_email || -z $git_username ]]; then
		exit_failer "One or more GIT config variables not set, could not set config"
	else
		create_gitconfig "$git_username" "$git_email"
	fi

	# Create a gitignore to ignore things like .DS_Store, .vscode, .idea
	read -p "Would you like me to create a global .gitignore? (Y/N) [This will ignore things like: .DS_Store, .vscode, .idea etc.]: " -n 1 -r
	if [[ $REPLY =~ ^[Yy]$ ]]
	then
	    create_gitignore
	fi
    end_step
}

function verify_git() {
    if test -f "$GIT_CONFIG"; then
        print_verified "${GIT_CONFIG} exists"
    else
        print_unverified "${GIT_CONFIG} does not exist"
    fi

    if test -f "$GIT_IGNORE"; then
        print_verified "${GIT_IGNORE} exists"
    else
        print_unverified "${GIT_IGNORE} does not exist"
    fi
}

function install_php() {
    begin_step "Step 4: Install PHP & Composer"
    background "sudo apt install php-fpm php-mbstring php-curl php-xml php-mysql php-sqlite3 php-json"
    PHP_VERSION=$(php -r "echo phpversion();")
    print_info "==> PHP v${PHP_VERSION} installed"

    EXPECTED_CHECKSUM="$(php -r 'copy("https://composer.github.io/installer.sig", "php://stdout");')"
    php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
    ACTUAL_CHECKSUM="$(php -r "echo hash_file('sha384', 'composer-setup.php');")"

    if [ "$EXPECTED_CHECKSUM" != "$ACTUAL_CHECKSUM" ]
    then
        >&2 echo 'ERROR: Invalid installer checksum'
        rm composer-setup.php
        exit 1
    fi

    php composer-setup.php --quiet
    rm composer-setup.php
    sudo mv composer.phar /usr/local/bin/composer

    COMPOSER_VERSION=$(composer -V)
    print_info "==> ${COMPOSER_VERSION} installed"

    end_step
}

function install_docker() {
    begin_step "Step 5: Install docker engine & docker compose"
    print_info "==> Downloading & installing docker..."
    curl -fsSL https://get.docker.com -o ${DOCKER_SCRIPT_NAME}
    sudo sh ${DOCKER_SCRIPT_NAME}

    print_info "==> Verifying docker engine is up..."
    background "sudo docker run hello-world"

    if [ $? -ne 0 ]
    then
        print_warning "==> Docker test run failed, please try again."
    else
        DOCKER_VERSION=$(docker -v)
        print_info "==> ${DOCKER_VERSION} installed & running"
        rm -rf get-docker.sh
    fi

    print_info "==> Installing docker-compose"
    background "sudo apt install docker-compose"
    assert "==> Failed installing docker-compose" "==> docker-compose installed"
    DOCKER_COMPOSE_VERSION=$(docker-compose -v)
    print_info "==> ${DOCKER_COMPOSE_VERSION} installed"
    
    end_step
}

function does_user_belong_to_docker_group() {
    if getent group docker | grep -q "\b${USER}\b"; then
        return 0
    else
        return 1
    fi
}

function add_user_to_docker_group() {
    background "sudo groupadd docker"
    background "sudo usermod -aG docker $USER"

    assert "${USER}: could not be added to docker group" "${USER}: was added to docker group, will require logout"

    REQUIRES_LOGOUT=true
}

function setup_docker_permissions() {
    begin_step "Step 5.1: Configure docker user permissions"

    if does_user_belong_to_docker_group; then
        print_info "==> ${USER} already belongs to docker group"
    else
        print_warning "==> ${USER} does not belong to docker group, adding..."
        add_user_to_docker_group
    fi

    end_step
}

function verify_docker_permissions() { 
    if does_user_belong_to_docker_group; then
        print_verified "${USER}: belongs to docker group"
    else
        print_unverified "${USER}: does not belong to docker group"
    fi
}

function install_node() {
    begin_step "Step 6: Installing NodeJS, NPM & NVM"
    background "sudo apt -y install nodejs npm"
    NODE_VERSION=$(node --version)
    print_info "==> Node ${NODE_VERSION} installed"

    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.1/install.sh | bash

    source ~/.nvm/nvm.sh
    NVM_VERSION=$(nvm -v)
    print_info "==> NVM v${NVM_VERSION} installed"
    
    print_info "==> Switching node to latest LTS version"
    background "nvm install ${NODE_LTS}"
    background "nvm use ${NODE_LTS}"
    NODE_VERSION=$(node --version)
    print_info "==> Node ${NODE_VERSION} installed"
    end_step
}

function generate_ssh() {
    background "ssh-keygen -q -t rsa -N '' -f ~/.ssh/id_rsa <<<y >${LOG_FILE} 2>&1"
    if test -f "$DEFAULT_SSH_KEY"; then
        print_info "==> SSH Key generated at: ${DEFAULT_SSH_KEY}"
    fi
}

function setup_default_ssh_key() {
    begin_step "Step 7: Configure SSH key"

    if test -f "$DEFAULT_SSH_KEY"; then
        # Create a gitignore to ignore things like .DS_Store, .vscode, .idea
        read -p "An SSH key is already configured on this system, do you want to overwrite it? (y/n): " -n 1 -r
        if [[ $REPLY =~ ^[Yy]$ ]]
        then
            generate_ssh
        fi
    else
        generate_ssh
    fi

    end_step
}

function finish_install() {
    begin_step "Install was completed"

    if $REQUIRES_LOGOUT ; then
        print_info "We have made some changes to your user permissions that require you to login again to complete this install"
        read -p "Would you like to be logged out now (y/n): " -n 1 -r
        if [[ $REPLY =~ ^[Yy]$ ]]
        then
            print_info "==> Attempting to log you out"
            gnome-session-quit
        else
            print_info "==> Skipping logout"
        fi
    fi

    end_step
}

function verify_ssh() {
    if test -f "$DEFAULT_SSH_KEY"; then
        print_verified "${DEFAULT_SSH_KEY} exists"
    else
        print_unverified "${DEFAULT_SSH_KEY} does not exist"
    fi
}

function verify() {
    eval "$1" &>${LOG_FILE}
    if [ $? -ne 0 ]
    then
        print_unverified "$2 not installed"
    else
        print_verified "$2 installed"
    fi
}

function verify_system() {
    begin_step "Verifying system install..."    

    verify_git
    verify_ssh
    verify "php -v" "php"
    verify "composer --version" "composer"
    verify "docker -v" "docker"
    verify "docker-compose -v" "docker-compose"
    verify_docker_permissions
    verify "node -v" "nodejs"
    verify "npm -v" "npm" 
    
    end_step
}

# RUN Install Steps
function install_system() {
   begin
   install_base
   setup_git
   install_php
   install_docker
   setup_docker_permissions
   install_node
   setup_default_ssh_key

   verify_system
   finish_install
}

function help_me() {
    printf "\n${GREEN}${bold}Welcome to the linux setup tool.${NR}\n"
    printf "\nThis tool helps you to setup and check all the basic tools for your system are installed and configured.\n\n"
    printf "${bold}Usage: ${NR}linux-setup [command]\n"

    printf "\nversion  Version number\n"
    printf "help       Help menu\n"
    printf "install    Install/reinstall a system\n"
    printf "verify     Check a systems configuration and highlight any issues\n"
    printf "uninstall  Uninstall linux-setup tool from system (may require sudo)\n\n"
}

function uninstall() {
    rm -- "$0"
    exit 0;
}

# Execute command user requested
case "$1" in
    version ) echo $VERSION ;;
    help ) help_me ;;
    install ) install_system ;;
    verify ) verify_system ;;
    uninstall ) unstall ;;
    * ) help_me ;;
esac

exit 0


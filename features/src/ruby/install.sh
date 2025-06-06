#!/bin/sh
set -e

USERNAME="${USERNAME:-"${_REMOTE_USER:-"automatic"}"}"
VERSION_MANAGER="${VERSIONMANAGER:-"mise"}"

# Function to install dependencies needed for building Ruby
install_dependencies() {
    apt-get update -y
    DEBIAN_FRONTEND=noninteractive apt-get -y install --no-install-recommends \
        git \
        curl \
        ca-certificates \
        libssl-dev \
        libreadline-dev \
        zlib1g-dev \
        autoconf \
        bison \
        build-essential \
        libyaml-dev \
        libncurses5-dev \
        libffi-dev \
        libgdbm-dev \
        libxml2-dev \
        rustc
}

# Function to add lines to shell initialization files
add_to_shell_init() {
    _user="$1"
    _bash_line="$2"
    _zsh_line="${3:-$_bash_line}"  # Use bash_line as default if zsh_line not provided

    if [ "$_user" = "root" ]; then
        _home_dir="/root"
    else
        _home_dir="/home/$_user"
    fi

    echo "$_bash_line" >> "$_home_dir/.bashrc"

    if [ -f "$_home_dir/.zshrc" ]; then
        echo "$_zsh_line" >> "$_home_dir/.zshrc"
    fi
}

# Function to setup rbenv
setup_rbenv() {
    _user="$1"
    _user_home="/home/$_user"

    # Clone rbenv and ruby-build
    git clone https://github.com/rbenv/rbenv.git /usr/local/share/rbenv
    git clone https://github.com/rbenv/ruby-build.git /usr/local/share/ruby-build

    # Setup plugins for root
    mkdir -p /root/.rbenv/plugins
    ln -s /usr/local/share/ruby-build /root/.rbenv/plugins/ruby-build

    # Setup for non-root user if needed
    if [ "$_user" != "root" ]; then
        mkdir -p "$_user_home/.rbenv/plugins"
        ln -s /usr/local/share/ruby-build "$_user_home/.rbenv/plugins/ruby-build"
        chown -R "$_user" "$_user_home/.rbenv/"
        chmod -R g+r+w "$_user_home/.rbenv"
    fi

    # shellcheck disable=SC2016
    add_to_shell_init "$_user" 'export PATH="/usr/local/share/rbenv/bin:$PATH"'
    # shellcheck disable=SC2016
    add_to_shell_init "$_user" 'eval "$(rbenv init -)"'
}

# Function to install Ruby with rbenv
install_ruby_rbenv() {
    _user="$1"
    _version="$2"

    su "$_user" -c "/usr/local/share/rbenv/bin/rbenv install $_version"
    su "$_user" -c "/usr/local/share/rbenv/bin/rbenv global $_version"
}

# Function to setup mise
setup_mise() {
    _user="$1"

    su "$_user" -c "curl https://mise.run | sh"

    # shellcheck disable=SC2016
    add_to_shell_init "$_user" 'eval "$(~/.local/bin/mise activate bash)"' 'eval "$(~/.local/bin/mise activate zsh)"'
}

# Function to install Ruby with mise
install_ruby_mise() {
    _user="$1"
    _version="$2"

    if [ "$_user" = "root" ]; then
        _home_dir="/root"
    else
        _home_dir="/home/$_user"
    fi

    su "$_user" -c "$_home_dir/.local/bin/mise install ruby@$_version"
    su "$_user" -c "$_home_dir/.local/bin/mise use -g ruby@$_version"
    su "$_user" -c "$_home_dir/.local/bin/mise settings add idiomatic_version_file_enable_tools ruby"
}

install_dependencies

# Setup version manager and install Ruby based on user choice
if [ "$VERSION_MANAGER" = "rbenv" ]; then
    setup_rbenv "$USERNAME"
    install_ruby_rbenv "$USERNAME" "$VERSION"
else
    setup_mise "$USERNAME"
    install_ruby_mise "$USERNAME" "$VERSION"
fi

rm -rf /var/lib/apt/lists/*

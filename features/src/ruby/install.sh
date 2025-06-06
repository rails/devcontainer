#!/bin/sh
set -e

USERNAME="${USERNAME:-"${_REMOTE_USER:-"automatic"}"}"

apt-get update -y
apt-get -y install --no-install-recommends git curl ca-certificates libssl-dev libreadline-dev zlib1g-dev autoconf bison build-essential \
    libyaml-dev libncurses5-dev libffi-dev libgdbm-dev libxml2-dev rustc

git clone https://github.com/rbenv/rbenv.git /usr/local/share/rbenv
git clone https://github.com/rbenv/ruby-build.git /usr/local/share/ruby-build

mkdir -p /root/.rbenv/plugins
ln -s /usr/local/share/ruby-build /root/.rbenv/plugins/ruby-build

if [ "${USERNAME}" != "root" ]; then
    user_home="/home/${USERNAME}"
    mkdir -p "${user_home}/.rbenv/plugins"
    ln -s /usr/local/share/ruby-build "${user_home}/.rbenv/plugins/ruby-build"

    chown -R "${USERNAME}" "${user_home}/.rbenv/"
    chmod -R g+r+w "${user_home}/.rbenv"

    # shellcheck disable=SC2016
    echo 'eval "$(rbenv init -)"' >> "${user_home}/.bashrc"

    if [ -f "${user_home}/.zshrc" ]; then
        # shellcheck disable=SC2016
        echo 'eval "$(rbenv init -)"' >> "${user_home}/.zshrc"
    fi
fi

su "${USERNAME}" -c "/usr/local/share/rbenv/bin/rbenv install $VERSION"
su "${USERNAME}" -c "/usr/local/share/rbenv/bin/rbenv global $VERSION"

rm -rf /var/lib/apt/lists/*

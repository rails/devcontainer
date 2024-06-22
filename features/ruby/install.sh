#!/bin/sh
set -e

USERNAME="${USERNAME:-"${_REMOTE_USER:-"automatic"}"}"

apt-get update -y
apt-get -y install --no-install-recommends libssl-dev libreadline-dev zlib1g-dev autoconf bison build-essential \
 libyaml-dev libreadline-dev libncurses5-dev libffi-dev libgdbm-dev libxml2-dev rustc

git clone https://github.com/rbenv/rbenv.git /usr/local/share/rbenv
git clone https://github.com/rbenv/ruby-build.git /usr/local/share/ruby-build

mkdir -p /root/.rbenv/plugins
ln -s /usr/local/share/ruby-build /root/.rbenv/plugins/ruby-build

if [ "${USERNAME}" != "root" ]; then
    mkdir -p /home/${USERNAME}/.rbenv/plugins
    ln -s /usr/local/share/ruby-build /home/${USERNAME}/.rbenv/plugins/ruby-build

    chown -R "${USERNAME}" "/home/${USERNAME}/.rbenv/"
    chmod -R g+r+w "/home/${USERNAME}/.rbenv"

    echo 'eval "$(rbenv init -)"' >> /home/${USERNAME}/.bashrc

    if [ -f /home/${USERNAME}/.zshrc ]; then
        echo 'eval "$(rbenv init -)"' >> /home/${USERNAME}/.zshrc
    fi
fi

su ${USERNAME} -c "rbenv install $VERSION"
su ${USERNAME} -c "rbenv global $VERSION"

rm -rf /var/lib/apt/lists/*

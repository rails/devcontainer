#!/bin/bash
set -e

# shellcheck source=/dev/null
source dev-container-features-test-lib

check "PATH contains rbenv" bash -c "echo $PATH | grep rbenv"
check "rbenv is installed" bash -c "rbenv --version"
check "ruby-build is installed" bash -c "ls -l $HOME/.rbenv/plugins/ruby-build | grep '\-> /usr/local/share/ruby-build'"
eval "$(rbenv init -)"
check "Ruby is installed with YJIT" bash -c "RUBY_YJIT_ENABLE=1 ruby -v | grep +YJIT"
check "Ruby version is set to 3.4.4" bash -c "rbenv global | grep 3.4.4"

reportResults

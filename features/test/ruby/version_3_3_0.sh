#!/bin/bash
set -e

source dev-container-features-test-lib

check "PATH contains rbenv" bash -c "echo $PATH | grep rbenv"
check "rbenv is installed" bash -c "rbenv --version"
check "ruby-build is installed" bash -c "ls -l $HOME/.rbenv/plugins/ruby-build | grep '\-> /usr/local/share/ruby-build'"
check "rbenv init is sourced in the bashrc" bash -c "grep 'eval \"\$(rbenv init -)\"' $HOME/.bashrc"
check "rbenv init is sourced in the zshrc" bash -c "grep 'eval \"\$(rbenv init -)\"' $HOME/.zshrc"
check "Ruby is installed with YJIT" bash -c "RUBY_YJIT_ENABLE=1 ruby -v | grep +YJIT"
check "Ruby version is set to 3.3.0" bash -c "rbenv global | grep 3.3.0"

reportResults

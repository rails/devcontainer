#!/bin/bash
set -e

# shellcheck source=/dev/null
source dev-container-features-test-lib

check "mise is installed" bash -c "mise --version"
check "mise init is sourced in the bashrc" bash -c "grep 'eval \"\$(~/.local/bin/mise activate bash)\"' $HOME/.bashrc"
check "mise idiomatic version file is enabled for ruby" bash -c "mise settings | grep idiomatic_version_file_enable_tools | grep ruby"
check "Ruby is installed with YJIT" bash -c "RUBY_YJIT_ENABLE=1 ruby -v | grep +YJIT"
check "Ruby version is set to 3.4.5" bash -c "mise use -g ruby | grep 3.4.5"

reportResults

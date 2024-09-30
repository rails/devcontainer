#!/bin/sh

set -e

USERNAME="${USERNAME:-"${_REMOTE_USER:-"automatic"}"}"

POST_CREATE_COMMAND_SCRIPT_PATH="/usr/local/share/bundler-data-permissions.sh"

tee "$POST_CREATE_COMMAND_SCRIPT_PATH" > /dev/null \
<< EOF
#!/bin/sh
set -e
sudo chown -R ${USERNAME} /bundle
EOF

chmod 755 "$POST_CREATE_COMMAND_SCRIPT_PATH"

# installers/

This folder contains individual, focused installation scripts — one script per tool or stack.

Every script here does exactly one thing: installs a specific tool on an Ubuntu machine and makes it available system-wide. No configuration, no opinionated defaults, no side effects. Just the binary, in the right place, ready to use.

I keep these as standalone scripts because not every environment needs every tool. The master script [`bootstrap-devops-toolchain.sh`](../bootstrap-devops-toolchain.sh) calls them all together when I need a full machine provisioned from scratch. But when I only need to add one tool to an existing machine, I run the individual script directly.

The list of tools here will keep growing as my stack evolves.

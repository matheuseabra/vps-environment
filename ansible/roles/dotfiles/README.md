# Dotfiles role

This role installs a checksum-pinned chezmoi release for `dev`, checks out the commit in `dotfiles_version` into `~/.local/share/chezmoi`, and applies that source state to `/home/dev`.

It supports x86_64 and arm64 Ubuntu hosts. The source state renders portable Zsh, Git, Starship, btop, Druk, Yazi, and OpenCode configuration. chezmoi excludes macOS-only desktop configuration and macOS-only OpenCode MCP servers on Linux.

The role installs Starship because it is a user binary dependency. It does not install OpenCode or Druk; the `developer` role owns those binaries.

The apply step uses `--force` to replace legacy GNU Stow symlinks and converge existing VPS configurations. Commit intended VPS configuration changes to `dotfiles` before rerunning this role.

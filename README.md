# VPS Environment

Reproducible setup for a developer VPS running Ubuntu, OpenCode, Tailscale, and Dokploy.

## Design

- **Ansible** provisions the VPS and manages users, packages, services, and system files.
- **GNU Stow** deploys selected portable dotfiles from the pinned `dotfiles` repository.
- **OpenCode** and **Druk** run as the non-root `dev` user.
- **tmux** keeps remote shells and OpenCode sessions alive.
- **Herdr** is not provisioned on the VPS; local Herdr remains a separate macOS choice.
- **Tailscale** provides private access from your Mac and phone.
- **Dokploy** is an explicit, separate install because its installer configures Docker Swarm.

## Prerequisites

On macOS:

```bash
brew bundle --file=./Brewfile
ansible-galaxy collection install -r ansible/collections/requirements.yml
```

You need:

- A VPS reachable by SSH as `root`.
- An SSH public key at `~/.ssh/id_ed25519.pub`.
- Tailscale installed on your Mac and phone.

## Provision the VPS

Replace `VPS_IP` with the public IP. This command does not store your key or Tailscale secret in the repository:

```bash
ansible-playbook \
  -i "VPS_IP," \
  ansible/site.yml \
  -u root \
  --private-key ~/.ssh/id_ed25519 \
  -e "dev_authorized_key=$(cat ~/.ssh/id_ed25519.pub)"
```

The playbook creates the `dev` user, adds it to `sudo`, installs only the tools used by this setup, installs OpenCode and Druk, deploys the portable `btop`, Druk, and Starship configs from the pinned dotfiles repository, configures SSH keep-alives and Fail2ban, and installs Tailscale.

### Tailscale authentication

The playbook installs Tailscale but leaves login manual by default:

```bash
ssh root@VPS_IP
sudo tailscale up --hostname=matheuseabra-vps
```

For unattended provisioning, pass a short-lived or reusable Tailscale auth key through your shell or Ansible Vault. Never commit it:

```bash
ansible-playbook -i "VPS_IP," ansible/site.yml -u root \
  --private-key ~/.ssh/id_ed25519 \
  -e "dev_authorized_key=$(cat ~/.ssh/id_ed25519.pub)" \
  -e "tailscale_auth_key=$TS_AUTHKEY"
```

After authentication, test the private address:

```bash
ssh dev@YOUR_TAILSCALE_IP
```

Update your local SSH config with that address or its MagicDNS name.

## Dotfiles strategy

The macOS dotfiles repository is intentionally not stowed in full on the VPS. The portable packages deployed here are `btop`, `druk`, and `starship`. These packages are macOS-specific or unnecessary on the VPS and stay local: `ghostty`, `karabiner`, `skhd`, `cava`, `herdr`, wallpapers, and the current `zsh` package. The `git` package uses the macOS Keychain, and the OpenCode config contains macOS-only MCP paths, so neither is deployed to Linux.

The Ansible `dotfiles` role clones a pinned commit and stows only the portable packages listed in `dotfiles_packages`. This keeps responsibilities separate: Ansible installs prerequisites and controls machine state; Stow links user configuration files into `$HOME`.

Druk is included because it is a self-contained terminal editor with Linux x64 and arm64 binaries, so it has no desktop dependency on the VPS. To add another package, verify that its config has no macOS-only paths or desktop dependencies, then add it to `dotfiles_packages` in `ansible/site.yml`.

## Daily remote workflow

Install tmux on an already-provisioned host if needed:

```bash
ssh contabo
sudo apt install -y tmux
```

Start or reattach to the persistent remote session:

```bash
ssh -t contabo 'tmux new-session -A -s dev'
```

Run OpenCode inside that session. Detach with `Ctrl-b d`; reconnect with the same command.

The included shell snippet contains the local shortcut:

```bash
source dotfiles/zshrc.d/vps.zsh
matheuseabra-vps
```

## Install Dokploy

Run this only on the intended Dokploy VPS. It checks that ports 80, 443, and 3000 are free and that Docker Swarm is not already active:

```bash
scp scripts/install-dokploy.sh contabo:/tmp/install-dokploy.sh
ssh contabo 'sudo bash /tmp/install-dokploy.sh'
```

The official installer will install Docker if necessary and initialize Dokploy. Open the UI at `http://VPS_IP:3000`, complete the first setup, then configure a domain and HTTPS before long-term use.

## Safety notes

- Do not commit SSH private keys, Tailscale auth keys, API keys, or Ansible Vault passwords.
- Keep the original root SSH session open until `dev` access works.
- Do not disable public SSH access until SSH over Tailscale has been tested.
- Dokploy uses Docker Swarm. Do not run its installer on a host that already has a Swarm you need.

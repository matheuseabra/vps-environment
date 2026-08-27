# VPS Environment

Reproducible machine provisioning for an Ubuntu developer VPS running OpenCode, Tailscale, and Dokploy.

## Design

- **Ansible** owns users, SSH, sudo, Apt packages, services, networking, and tool binaries.
- **chezmoi** applies the pinned user-level source state from [`dotfiles`](https://github.com/matheuseabra/dotfiles).
- **OpenCode** and **Druk** run as the non-root `dev` user.
- **tmux** keeps remote shells and OpenCode sessions alive.
- **Herdr** is not provisioned on the VPS; it is a macOS-only user choice.
- **Tailscale** provides private access from your Mac and phone.
- **Dokploy** is an explicit, separate install because its installer configures Docker Swarm.

Ansible installs the required binaries. Dotfiles owns their user-level configuration. Do not duplicate a dotfile in this repository.

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

The playbook creates the `dev` user with Zsh, installs the system packages and OpenCode/Druk binaries, installs a checksum-pinned chezmoi release, checks out the pinned dotfiles commit, and applies its Linux source state. It also configures SSH keep-alives, Fail2ban, and Tailscale.

### Dotfiles update

`ansible/site.yml` pins `dotfiles_version` to a commit. Update that value deliberately after a reviewed dotfiles change. Re-run the playbook to update the VPS.

The dotfiles role uses `chezmoi apply --force` so a VPS always converges to the pinned state. Do not make uncommitted configuration changes directly on the VPS.

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

Update your local SSH configuration with that address or its MagicDNS name.

## Daily remote workflow

Start or reattach to the persistent remote session:

```bash
ssh -t contabo 'tmux new-session -A -s dev'
```

Run OpenCode inside that session. Detach with `Ctrl-b d`; reconnect with the same command.

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

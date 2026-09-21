# arch-config

My [Omarchy](https://omarchy.org/) config.

## Quickstart

pull this repo into `~/me/arch-config`, cd into it and install just.

```sh
mkdir ~/me && cd ~/me && git clone https://github.com/mrchantey/arch-config.git && cd arch-config && sudo pacman -S --noconfirm just
```


```sh
# log into github
gh auth login
# pick the recipe for this machine:
just init             # device-agnostic base (no monitor / input / GPU opinions)
just init-rainbow-cat # rainbow-cat: the desktop (dual monitor, NVIDIA primary)
just init-silver-fox  # silver-fox: Dell Precision 7560 laptop (Intel compositor, NVIDIA for CUDA/offload)
```

A new device gets its own `stow/hypr-<name>` package (`monitors.lua`, `input-device.lua`,
`layout-device.lua`) plus an `init-<name>` recipe that runs `just init`, `stow-device <name>`, and the
shared `install-extras` gaming/GPU stack.

# Additional Steps

Haven't yet found a way to automate these, to be executed post install.

0. Age identity, the one key that decrypts every beet vault (`.env.age`, exported stack secrets). Per person, never in a repo. On your first machine generate it, on every later machine restore it from the USB backup:
	- `just setup-age-identity` (first machine) or `just setup-age-identity /run/media/pete/<stick>/keys.txt.age`
	- then `beet secrets/check` from any beet repo

3. Bluetooth Mouse
4. Chrome notifications
	- `chrome://settings/content/notifications`
	- `Don't allow sites to send notifications`
1. AWS
	- `aws configure`
	- Create a new user or revoke and reissue access key 
	- `https://us-east-1.console.aws.amazon.com/iam/home?region=us-west-2#/users`
	- `Security Credentials > Access Keys > Create Access Key`
		- Command Line Interface (CLI)
		- Description Tag: None
	- `Access Key Id: ^`
	- `Access Key Secret Key: ^`
	- `Default region name: us-west-2`
	- `Default output format: None`
	- `just pull-pictures` (init skips it while aws is unconfigured; this fills `~/Pictures/shared`)


## Optional Steps

- Nvidia for gaming `just install-nvidia-deps`
- Ollama `just install-ollama`

# dotfiles

My dotfiles managed with git submodules.

## What's Included

| Config | Repo | Description |
|--------|------|-------------|
| Neovim | [dotfiles-nvim](https://github.com/LostmanMing/dotfiles-nvim) | Full Neovim IDE setup |

More to come.

## Installation

```bash
# Clone with all submodules
git clone --recurse-submodules git@github.com:LostmanMing/dotfiles.git ~/dotfiles

# Create symlinks
ln -s ~/dotfiles/.config/nvim ~/.config/nvim

# Start Neovim (first launch installs everything)
nvim
```

## Structure

```
~/dotfiles/
└── .config/
    └── nvim/     → LostmanMing/dotfiles-nvim (submodule)
```

## How It Works

Each config app lives in its own git repo, added as a submodule under `.config/`. Symlinks from `~/.config/<app>` point into the dotfiles tree.

```
dotfiles/          ~/.config/
├── .config/      ├── nvim → ~/dotfiles/.config/nvim
│   └── nvim/  ←──┘
```

## Adding a New Config

```bash
cd ~/dotfiles
git submodule add <repo-url> .config/<app-name>
ln -s ~/dotfiles/.config/<app-name> ~/.config/<app-name>
git commit -m "feat: add <app-name> config"
```

## Updating All Submodules

```bash
cd ~/dotfiles
git submodule update --remote --merge
git commit -m "chore: update submodules"
```

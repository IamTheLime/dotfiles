#!/bin/bash

# Color codes for pretty output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get the absolute path to the dotfiles directory
DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo -e "${BLUE}======================================${NC}"
echo -e "${BLUE}   Dotfiles Setup Script${NC}"
echo -e "${BLUE}======================================${NC}"
echo ""

# Function to ask yes/no questions
ask_yes_no() {
    local prompt="$1"
    local response
    while true; do
        read -p "$(echo -e ${GREEN}"$prompt (y/n): "${NC})" response
        case "$response" in
            [Yy]* ) return 0;;
            [Nn]* ) return 1;;
            * ) echo -e "${RED}Please answer y or n.${NC}";;
        esac
    done
}

# Function to check if a command exists
command_exists() {
    command -v "$1" &> /dev/null
}

# Check for required dependencies
echo -e "${YELLOW}Checking for required dependencies...${NC}"
echo ""

MISSING_DEPS=()
DEPS=("fd" "bat" "eza" "nvim" "git" "curl")

for dep in "${DEPS[@]}"; do
    if command_exists "$dep"; then
        echo -e "${GREEN}✓${NC} $dep is installed"
    else
        echo -e "${RED}✗${NC} $dep is NOT installed"
        MISSING_DEPS+=("$dep")
    fi
done

echo ""

if [ ${#MISSING_DEPS[@]} -ne 0 ]; then
    echo -e "${RED}Missing dependencies: ${MISSING_DEPS[*]}${NC}"
    echo -e "${YELLOW}Please install them before continuing. See README.md for instructions.${NC}"
    if ! ask_yes_no "Do you want to continue anyway?"; then
        echo -e "${RED}Setup cancelled.${NC}"
        exit 1
    fi
fi

echo ""

# Install Oh My Zsh
if [ -d "$HOME/.oh-my-zsh" ]; then
    echo -e "${YELLOW}Oh My Zsh is already installed.${NC}"
    if ask_yes_no "Do you want to reinstall Oh My Zsh?"; then
        echo -e "${BLUE}Removing existing Oh My Zsh installation...${NC}"
        rm -rf "$HOME/.oh-my-zsh"
    else
        echo -e "${GREEN}Skipping Oh My Zsh installation.${NC}"
    fi
fi

if [ ! -d "$HOME/.oh-my-zsh" ]; then
    if ask_yes_no "Do you want to install Oh My Zsh?"; then
        echo -e "${BLUE}Installing Oh My Zsh...${NC}"
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
        echo -e "${GREEN}✓ Oh My Zsh installed${NC}"
    else
        echo -e "${YELLOW}Skipping Oh My Zsh installation.${NC}"
    fi
fi

echo ""

# Install Zsh plugins
ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

if ask_yes_no "Do you want to install/update Zsh plugins?"; then
    echo -e "${BLUE}Installing Zsh plugins...${NC}"
    
    # fzf-tab
    if [ -d "$ZSH_CUSTOM/plugins/fzf-tab" ]; then
        echo -e "${YELLOW}fzf-tab already exists, updating...${NC}"
        git -C "$ZSH_CUSTOM/plugins/fzf-tab" pull
    else
        git clone https://github.com/Aloxaf/fzf-tab "$ZSH_CUSTOM/plugins/fzf-tab"
    fi
    
    # zsh-autosuggestions
    if [ -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ]; then
        echo -e "${YELLOW}zsh-autosuggestions already exists, updating...${NC}"
        git -C "$ZSH_CUSTOM/plugins/zsh-autosuggestions" pull
    else
        git clone https://github.com/zsh-users/zsh-autosuggestions "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
    fi
    
    # zsh-syntax-highlighting
    if [ -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ]; then
        echo -e "${YELLOW}zsh-syntax-highlighting already exists, updating...${NC}"
        git -C "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" pull
    else
        git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"
    fi
    
    echo -e "${GREEN}✓ Zsh plugins installed/updated${NC}"
else
    echo -e "${YELLOW}Skipping Zsh plugins installation.${NC}"
fi

echo ""

# Setup zshrc
if ask_yes_no "Do you want to setup zshrc?"; then
    echo -e "${BLUE}Setting up zshrc...${NC}"
    
    # Backup existing zshrc if it exists and is not a symlink
    if [ -f "$HOME/.zshrc" ] && [ ! -L "$HOME/.zshrc" ]; then
        echo -e "${YELLOW}Backing up existing ~/.zshrc to ~/.zshrc.backup${NC}"
        cp "$HOME/.zshrc" "$HOME/.zshrc.backup"
    fi
    
    # Create symlink to our zshrc
    ln -sf "$DOTFILES_DIR/dotfiles/zshrc" "$HOME/.zshrc"
    echo -e "${GREEN}✓ Created symlink: ~/.zshrc -> $DOTFILES_DIR/dotfiles/zshrc${NC}"
else
    echo -e "${YELLOW}Skipping zshrc setup.${NC}"
fi

echo ""

# Create .config directory if it doesn't exist
mkdir -p "$HOME/.config"

# Setup Neovim
if ask_yes_no "Do you want to setup Neovim config?"; then
    echo -e "${BLUE}Setting up Neovim config...${NC}"
    
    # Backup existing nvim config if it exists and is not a symlink
    if [ -e "$HOME/.config/nvim" ] && [ ! -L "$HOME/.config/nvim" ]; then
        echo -e "${YELLOW}Backing up existing ~/.config/nvim to ~/.config/nvim.backup${NC}"
        mv "$HOME/.config/nvim" "$HOME/.config/nvim.backup"
    fi
    
    # Remove existing symlink if it exists
    [ -L "$HOME/.config/nvim" ] && rm "$HOME/.config/nvim"
    
    # Create symlink
    ln -sf "$DOTFILES_DIR/dotfiles/nvim" "$HOME/.config/nvim"
    echo -e "${GREEN}✓ Created symlink: ~/.config/nvim -> $DOTFILES_DIR/dotfiles/nvim${NC}"
else
    echo -e "${YELLOW}Skipping Neovim config setup.${NC}"
fi

echo ""

# Setup Ghostty
if ask_yes_no "Do you want to setup Ghostty config?"; then
    echo -e "${BLUE}Setting up Ghostty config...${NC}"
    
    # Backup existing ghostty config if it exists and is not a symlink
    if [ -e "$HOME/.config/ghostty" ] && [ ! -L "$HOME/.config/ghostty" ]; then
        echo -e "${YELLOW}Backing up existing ~/.config/ghostty to ~/.config/ghostty.backup${NC}"
        mv "$HOME/.config/ghostty" "$HOME/.config/ghostty.backup"
    fi
    
    # Remove existing symlink if it exists
    [ -L "$HOME/.config/ghostty" ] && rm "$HOME/.config/ghostty"
    
    # Create symlink
    ln -sf "$DOTFILES_DIR/dotfiles/ghostty" "$HOME/.config/ghostty"
    echo -e "${GREEN}✓ Created symlink: ~/.config/ghostty -> $DOTFILES_DIR/dotfiles/ghostty${NC}"
else
    echo -e "${YELLOW}Skipping Ghostty config setup.${NC}"
fi

echo ""

# Setup Hyprland (optional)
if ask_yes_no "Do you want to setup Hyprland config?"; then
    echo -e "${BLUE}Setting up Hyprland config...${NC}"
    
    # Backup existing hyprland config if it exists and is not a symlink
    if [ -e "$HOME/.config/hypr" ] && [ ! -L "$HOME/.config/hypr" ]; then
        echo -e "${YELLOW}Backing up existing ~/.config/hypr to ~/.config/hypr.backup${NC}"
        mv "$HOME/.config/hypr" "$HOME/.config/hypr.backup"
    fi
    
    # Remove existing symlink if it exists
    [ -L "$HOME/.config/hypr" ] && rm "$HOME/.config/hypr"
    
    # Create symlink
    ln -sf "$DOTFILES_DIR/dotfiles/hyprland" "$HOME/.config/hypr"
    echo -e "${GREEN}✓ Created symlink: ~/.config/hypr -> $DOTFILES_DIR/dotfiles/hyprland${NC}"
else
    echo -e "${YELLOW}Skipping Hyprland config setup.${NC}"
fi

echo ""
echo -e "${GREEN}======================================${NC}"
echo -e "${GREEN}   Setup Complete!${NC}"
echo -e "${GREEN}======================================${NC}"
echo ""
echo -e "${BLUE}Next steps:${NC}"
echo -e "1. Restart your terminal or run: ${YELLOW}source ~/.zshrc${NC}"
echo -e "2. If you're using a different shell, change it to zsh: ${YELLOW}chsh -s \$(which zsh)${NC}"
echo ""

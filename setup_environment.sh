ho "REPLY? 
Do you have the following installed ?

- FD 
- BAT
- EXA
- NVIM
- TMUX

IF NOT INSTALL THEM BEFORE YOU START THE PROCESS - they are in the README.md

YOU WILL ALSO HAVE TO RUN THIS FILE TWICE, BECAUSE I CANNOT BE ARSED TO HANDLE OH_MY_ZSH
"

echo "First off lets install oh my zsh, that shit always creates a new zshrc which is annoying"
# If oh-my-zsh is not install let's install it
# Nothing safer than exec-ing a file straight from the web
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
git clone https://github.com/Aloxaf/fzf-tab ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/fzf-tab
git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting

echo "Creating symbolic link for zshrc"
echo "source $(pwd)/dotfiles/zshrc" > ~/.zshrc

echo "Creating symbolic links for nvim, tmux";

mkdir -p ~/.config

ln -sf "$(pwd)/dotfiles/nvim" ~/.config
ln -sf "$(pwd)/dotfiles/tmux" ~/.config
ln -sf "$(pwd)/dotfiles/wezterm" ~/.wezterm.lua
ln -sf "$(pwd)/dotfiles/zellij" ~/.config

echo "Cloning tpm"
rm -rf ~/.config/tmux/plugins/

git clone https://github.com/tmux-plugins/tpm ~/.config/tmux/plugins/

tmux start-server
tmux new-session -d -A -s main;
~/.config/tmux/plugins/bin/install_plugins 
tmux kill-server

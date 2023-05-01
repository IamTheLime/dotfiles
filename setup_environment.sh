echo "First off lets install oh my zsh, that shit always creates a new zshrc which is annoying"
# If oh-my-zsh is not install let's install it
# Nothing safer than exec-ing a file straight from the web
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
git clone https://github.com/Aloxaf/fzf-tab ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/fzf-tab
git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting

echo "Creatin symboluc link for zshrc"
ln -sf "$(pwd)/dotfiles/zshrc" ~/.zshrc

echo "Creating symbolic links for nvim, tmux";

ln -sf "$(pwd)/dotfiles/nvim" ~/.config/nvim
ln -sf "$(pwd)/dotfiles/tmux" ~/.config/tmux


echo "Cloning tpm"
git clone https://github.com/tmux-plugins/tpm ~/.config/tmux/plugins/tpm

# type this in terminal if tmux is already running
tmux source ~/.config/tmux/tmux.conf

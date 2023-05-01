read -q "REPLY?\ 
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

echo "Creatin symboluc link for zshrc"
ln -sf "$(pwd)/dotfiles/zshrc" $HOME/.zshrc

echo "Creating nvim installer"
git clone --depth 1 https://github.com/wbthomason/packer.nvim ~/.local/share/nvim/site/pack/packer/start/packer.nvim
nvim --headless -c 'autocmd User PackerComplete quitall' -c 'PackerSync'

echo "Creating symbolic links for nvim, tmux";

ln -sf "$(pwd)/dotfiles/nvim" $HOME/.config/nvim
ln -sf "$(pwd)/dotfiles/tmux" $HOME/.config/tmux


echo "Cloning tpm"
git clone https://github.com/tmux-plugins/tpm ~/.config/tmux/plugins/tpm

# type this in terminal if tmux is already running
tmux source ~/.config/tmux/tmux.conf

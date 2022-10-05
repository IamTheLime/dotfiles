
echo("Creating symbolic links for nvim and tmux")

ln -s "$(pwd)/nvim" ~/.config
ln -s "$(pwd)/tmux" ~/.config

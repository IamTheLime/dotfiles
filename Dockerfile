FROM fedora


RUN dnf -y install bat
RUN dnf -y install fd-find
RUN dnf -y install exa
RUN dnf -y install neovim
RUN dnf -y install tmux
RUN dnf -y install git
RUN dnf -y install zsh
RUN dnf -y install util-linux-user
RUN dnf -y install gcc
RUN dnf -y install g++
RUN dnf -y install fzf

COPY . /root/install/

WORKDIR /root/install/

RUN ./setup_environment.sh

RUN chsh -s $(which zsh)

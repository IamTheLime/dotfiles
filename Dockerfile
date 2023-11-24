FROM fedora:40

RUN dnf -y upgrade --refresh

RUN curl https://sh.rustup.rs -sSf | bash -s -- -y

ENV PATH="/root/.cargo/bin:${PATH}"
RUN dnf -y install bat
RUN dnf -y install fd-find
RUN dnf -y install gcc
RUN cargo install exa 
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

RUN chsh -s $(which zsh)

RUN ./setup_environment.sh


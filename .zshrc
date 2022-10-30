# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="powerlevel10k/powerlevel10k"

plugins=(git poetry ripgrep virtualenv zsh-autosuggestions fzf-git fzf-tab zsh-syntax-highlighting ssh-agent)

source $ZSH/oh-my-zsh.sh

export FZF_DEFAULT_COMMAND='fdfind --type file --follow --hidden --exclude .git'
export FZF_DEFAULT_COMMAND="fdfind --type file --color=always"
export FZF_DEFAULT_OPTS="--ansi"

export FZF_DEFAULT_COMMAND='fdfind --type file'
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
export FZF_CTRL_T_OPTS="--preview 'bat --color=always --line-range :500 {}'"

setopt auto_menu # automatically use menu completion
setopt always_to_end # move cursor to end if word had one match
zstyle ':completion:*' menu select # select completions with arrow keys
zstyle ':completion:*' group-name '' # group results by category
zstyle ':completion:::::' completer _expand _complete _ignored _approximate # enable approximate matches for completion
zstyle ":completion:*:git-checkout:*" sort false
zstyle ':completion:*:descriptions' format '[%d]'
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'exa -1 --color=always $realpath'
zstyle ':fzf-tab:complete:repos:*' fzf-preview 'bat --color=always --terminal-width=-20  ${UJ_DIR}/$realpath/README.md'
zstyle :omz:plugins:ssh-agent lazy yes
zstyle :omz:plugins:ssh-agent quiet yes

[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

# Aliases Section
alias more='bat'
alias ls='exa'

alias python=python3
# ls, the common ones I use a lot shortened for rapid fire usage
alias l='ls -lFh'     #size,show type,human readable
alias la='ls -laFh --icons'   #long list,show almost all,show type,human readable
alias lr='ls -tRFh'   #sorted by date,recursive,show type,human readable
alias lt='ls -ltFh'   #long list,sorted by date,show type,human readable
alias ll='ls -l'      #long list
alias ldot='ls -ld .*'
alias lS='ls -1FSsh'
alias lart='ls -1Fcart'
alias lrt='ls -1Fcrt'
alias lsr='ls -lARFh' #Recursive list of files and directories
alias lsn='ls -1'     #A column contains name of files and directories


# Custom command completion
# zstyle ':fzf-tab:complete:repos:*' fzf-preview 'bat --color=always --terminal-width=-20  ${UJ_DIR}/$realpath/README.md'
# repos() {
#     cd "${UJ_DIR}/$1"
# }
# _repos() {
#     ((CURRENT == 2)) && _files -/ -W ${UJ_DIR}
# }
compdef _repos repos

path+=("/Users/tiagolima/.local/bin")
export PATH

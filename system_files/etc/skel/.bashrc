#!/usr/bin/env bash

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

# The shell we actually want to use
_SHELL=zsh

# Chain load it
# If shell is already set then the user probably did actually want bash so we don't run this 
if command -v $_SHELL >/dev/null 2>&1 && [[ $SHELL != $(which $_SHELL) ]]; then
  export SHELL=$(which $_SHELL)
  $SHELL && exit
fi
unset _SHELL

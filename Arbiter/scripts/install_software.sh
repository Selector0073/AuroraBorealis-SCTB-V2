#!/bin/bash

os_setup() {
    case "$1" in
        *debian*|*ubuntu*) 
            apt-get update -y && DEBIAN_FRONTEND=noninteractive apt-get upgrade -y 
            ;;
        *fedora*)
            dnf upgrade -y 
            ;;
    esac
}

install_pkg() {
    local os="$1"; shift
    case "$os" in
        *debian*|*ubuntu*) 
            DEBIAN_FRONTEND=noninteractive apt-get install -y "$@" 
            ;;
        *fedora*)
            dnf install -y "$@" 
            ;;
    esac
}
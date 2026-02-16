#!/bin/sh

show_help() {
  cat << EOF
Usage: $0 [OPTIONS]

OPTIONS:
  -l, --lib   DIR   Library of functions (directory) to import 
  -f, --file  FILE  Configuration or secret (*.env) file to import
  -h, --help        Show this text and exit
EOF
}
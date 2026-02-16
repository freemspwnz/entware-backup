#!/bin/sh

show_help() {
  cat << EOF
Usage: $0 [OPTIONS]

OPTIONS:
  -t, --telegram  TEXT  Send message to Telegram
  -h, --help            Show this text and exit
EOF
}
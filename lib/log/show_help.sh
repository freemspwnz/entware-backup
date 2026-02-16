#!/bin/sh

show_help() {
    cat << EOF
Usage: $0 [OPTIONS]

OPTIONS:
  -i, --info     TEXT  [I] timestamp: Info 
  -w, --warning  TEXT  [W] timestamp: Warning
  -e, --error    TEXT  [E] timestamp: Error
  -d, --debug    TEXT  [D] timestamp: Debug
  -h, --help           Show this text and exit
EOF
}
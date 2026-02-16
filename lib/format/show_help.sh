#!/bin/sh

show_help() {
    cat << EOF
Usage: $0 [OPTIONS]

OPTIONS:
  -r, --regular  TEXT  regular string%0A (multiple use)
  -b, --bold     TEXT  <b>bold string</b>%0A (multiple use)
  -p, --pre      TEXT  <pre>pre string</pre>%0A%0A (multiple use)
  -h, --help           Show this text and exit
EOF
}
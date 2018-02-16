#!/bin/bash
sudo reflector --verbose --latest 100 --protocol http --protocol https --sort rate -n 10 --save /etc/pacman.d/mirrorlist

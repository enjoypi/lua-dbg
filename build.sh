#! /bin/sh
cc *.c -I /opt/local/include/ -g --shared -o dbg.so -L /opt/local/lib/ -llua

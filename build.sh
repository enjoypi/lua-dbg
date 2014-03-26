#! /bin/sh
cc *.c -I /opt/local/include/ --shared -o dbg.so -L /opt/local/lib/ -llua

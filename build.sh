#! /bin/sh
cc *.c -I /opt/local/include/ --shared -o debugger.so -L /opt/local/lib/ -llua

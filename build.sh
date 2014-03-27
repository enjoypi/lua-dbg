#! /bin/sh
#cc *.c -I /opt/local/include/ --shared -o dbg.so -L /opt/local/lib/ -llua
cc *.c -I $HOME/projects/lua51/src --shared -o dbg.so -L $HOME/projects/lua51/src -llua

#!/bin/bash
 
 path=$1
 echo -e "This will install fonts found recursively in a path given as an argument,"
 echo -e "by placing them in ~/.local/share/fonts\n"
 
 if [ -d "$path" ]; then
    echo -e "$path is a valid directory. Continuing...\n"
    find $path -type f \( -iname "*.ttf" -o -iname "*.otf" \) -exec cp --parents {} ~/.local/share/fonts/ \;
    fc-cache -fv
    echo -e 'Tried copying .otf and .ttf files from $path, to ~/.local/share/fonts.\n'
    echo -e 'Please see the following diff result:\n'
    diff -qr $path ~/.local/share/fonts | sort
 else
    echo -e "No valid path argument given, or directory doesn't exist."
 fi
 
 echo "Exit"

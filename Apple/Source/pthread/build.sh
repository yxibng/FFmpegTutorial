#!/bin/bash

file="$1"
x="$2"

function usage(){
    echo "$0 c_file_name [x]"
}

function build(){

    echo "will build $in"
    echo '----------------------'

    if [[ -f "$out" ]];then
        rm -f "$out"
    fi

    clang "$in" -o "$out"

    if [[ $? == 0 ]];then
        echo '----------------------' 
        echo 'build succeed.'
        return 0
    else
        echo '----------------------' 
        echo 'build failed.'
        return 1
    fi
}

function run(){
    
    if [[ ! $x ]];then
        return 1
    fi

    echo
    echo "will run $out"
    echo '----------------------'
    ./$out
    echo '----------------------'
    echo "done."

    return 0
}

if [[ "$*" == "clean" ]];then
    rm -f *.out
    echo "clean done."
    exit 0
elif [[ ! "$file" ]];then
    usage
    exit 1
fi

in="$file.c"
out="$file.out"

build && run


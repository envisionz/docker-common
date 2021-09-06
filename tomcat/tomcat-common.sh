#!/bin/bash

# Strip leading and trailing '/' from path
strip_url_path()
{
    local path="$1"
    path=${path#/}
    path=${path%/}
    printf "%s" "$path"
    return 0
}

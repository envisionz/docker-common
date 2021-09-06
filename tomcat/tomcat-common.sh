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

set_app_path()
{
    local orig_path="$1"
    local new_path="$2"

    local orig_dir="${CATALINA_HOME}/webapps/${orig_path}"
    if [ -z "$new_path" ]; then
        # Set as the ROOT webapp
        local newdir="${CATALINA_HOME}/webapps/ROOT"
        [ ! -d "$newdir" ] && mv -T "$orig_dir" "$newdir"
        printf "%s" "$newdir"
    else
        # In Tomcat, use '#' in webapp filename to create path separator
        local newpath="${new_path//\//#}"
        local newdir="${CATALINA_HOME}/webapps/${newpath}"
        [ ! -d "$newdir" ] && mv -- "$orig_dir" "$newdir"
        printf "%s" "$newdir"
    fi
    exit 0
}

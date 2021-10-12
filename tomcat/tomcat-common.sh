#!/bin/bash

tc_print()
{
    printf "%s\n" "$1"
}

xml_add_update_element()
{
    local xpath_root="$1"
    local element="$2"
    local value="$3"
    local xml_file="$4"
    xmlstarlet ed -P -S -L \
        -s "$xpath_root" -t elem -n "$element" -v '' \
        -d "${xpath_root}/${element}[position() != 1]" \
        -u "${xpath_root}/${element}" -v "$value" \
        "$xml_file"
}

xml_add_update_attr()
{
    local xpath_el="$1"
    local attr_name="$2"
    local attr_val="$3"
    local xml_file="$4"

    xmlstarlet ed -P -S -L \
        -u "${xpath_el}/@${attr_name}" -v "$attr_val" \
        -i "${xpath_el}[not(@${attr_name})]" -t attr -n "$attr_name" -v "$attr_val" \
        "$xml_file"
}

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

set_app_ctx_with_hc()
{
    local app_dir="$1"
    local app_path="$2"
    local ctx_name="ROOT"

    if [ ! -z "$app_path" ]; then
        local ctx_name="${app_path//\//#}"
    fi

    local ctx_path="${CATALINA_HOME}/conf/Catalina/localhost/${ctx_name}.xml"
    printf '<Context docBase="%s">\n    <Valve className="org.apache.catalina.valves.HealthCheckValve" />\n</Context>\n' "$app_dir" > "$ctx_path"

    if [ "$ctx_name" = "ROOT" ]; then
        printf "http://localhost:8080/health" > "$HEALTH_URL_FILE"
    else
        printf "http://localhost:8080/%s/health" "$app_path" > "$HEALTH_URL_FILE"
    fi

    printf "%s" "$ctx_path"
}

# Setup tomcat connector when behind reverse proxy
set_connector_proxy()
{
    local rev_proxy_domain="$1"
    local rev_proxy_proto="$2"

    [ -z "$rev_proxy_domain" ] && tc_print "Reverse proxy domain not set" && return 1
    [ -z "$rev_proxy_proto" ] && tc_print "Reverse proxy protocol not set" && return 1

    local secure="false"
    local port="80"
    if [ "$rev_proxy_proto" = "https" ]; then
        secure="true"
        port="443"
    fi

    # Add an appropriate connector in the Tomcat server configuration
    local connector_xpath="/Server/Service[@name=\"Catalina\"]/Connector[@port=\"8080\"]"
    local server_xml="${CATALINA_HOME}/conf/server.xml"

    xmlstarlet ed -P -S -L \
        -d "${connector_xpath}/@redirectPort" \
        "$server_xml"
    
    xml_add_update_attr "$connector_xpath" "proxyName" "$proxy_domain" "$server_xml"
    xml_add_update_attr "$connector_xpath" "proxyPort" "$port" "$server_xml"
    xml_add_update_attr "$connector_xpath" "scheme" "$proxy_proto" "$server_xml"
    xml_add_update_attr "$connector_xpath" "secure" "$secure" "$server_xml"

    return 0
}

set_healthcheck()
{
    local app_dir="$1"
    local appdir=${app_dir%/}
    local app_path=$(basename "$app_dir")
    local apppath="${app_path//#/\/}"

    tee "$appdir/META-INF/context.xml" <<-'EOF'
    <Context>
        <Valve className="org.apache.catalina.valves.HealthCheckValve" />
    </Context>
EOF
    if [ "$apppath" = "ROOT" ]; then
        printf "http://localhost:8080/health" > "$HEALTH_URL_FILE"
    else
        printf "http://localhost:8080/%s/health" "$apppath" > "$HEALTH_URL_FILE"
    fi
    return 0
}

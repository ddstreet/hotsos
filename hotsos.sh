#!/bin/bash -u
# Copyright 2020 opentastic@gmail.com
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# Origin: https://github.com/dosaboy/hotsos
#
# Description:
#  Generate a high-level summary of a sosreport.
#
# Authors:
#  - edward.hope-morley@canonical.com
#  - opentastic@gmail.com

export SOS_ROOT=
export INDENT_STR="  - "
declare -a sos_paths=()
write_to_file=false

# ordered
declare -a PLUG_KEYS=( versions openstack storage juju kernel system )
# unordered
declare -A PLUGINS=(
    [versions]=false
    [openstack]=false
    [storage]=false
    [juju]=false
    [kernel]=false
    [system]=false
    [all]=false
)

usage ()
{
cat << EOF
USAGE: hotsos [OPTIONS] SOSPATH

OPTIONS
    -h|--help
        This message.
    --juju
        Include Juju info.
    --kernel
        Include Kernel info.
    --list-plugins
        Show available plugins.
    --openstack
        Include Openstack services info.
    --storage
        Include storage info including Ceph.
    --system
        Include system info.
    --versions
        Include software version info.
    -s|--save
        Save output to a file.
    -a|--all
        Enable all plugins.

SOSPATH
    Path to a sosreport. Can be provided multiple times.

EOF
}

while (($#)); do 
    case $1 in
        -h|--help)
            usage
            exit 0
            ;;
        --versions)
            PLUGINS[versions]=true
            ;;
        --juju)
            PLUGINS[juju]=true
            ;;
        --openstack)
            PLUGINS[openstack]=true
            ;;
        --storage)
            PLUGINS[storage]=true
            ;;
        --kernel)
            PLUGINS[kernel]=true
            ;;
        --list-plugins)
            echo "Available plugins:"
            echo "${!PLUGINS[@]}"| tr ' ' '\n'| grep -v all| xargs -l -I{} echo " - {}"
            exit
            ;;
        --system)
            PLUGINS[system]=true
            ;;
        -s|--save)
            write_to_file=true
            ;;
        -a|--all)
            PLUGINS[all]=true
            ;;
        *)
            sos_paths+=( $1 )
            ;;
    esac
    shift
done

unit_in_array ()
{
    unit="$1"
    shift
    echo $@| egrep -q "\s?${unit}\s?"
}

((${#sos_paths[@]})) || { usage; exit 1; }
((${#sos_paths[@]})) || sos_paths=( . )

if ${PLUGINS[all]}; then
    PLUGINS[versions]=true
    PLUGINS[openstack]=true
    PLUGINS[storage]=true
    PLUGINS[juju]=true
    PLUGINS[kernel]=true
    PLUGINS[system]=true
fi

export F_OUT=`mktemp`
CWD=`dirname $0`
for SOS_ROOT in ${sos_paths[@]}; do
(
    # TODO
    #if false && [ "`file -b $SOS_ROOT`" = "XZ compressed data" ]; then
    #    dtmp=`mktemp -d`
    #    tar --exclude='*/*' -tf $SOS_ROOT
    #    sosroot=`tar --exclude='*/*' -tf $SOS_ROOT| sed -r 's,([[:alnum:]\-]+)/*.*,\1,g'| sort -u`
    #    tar -tf $SOS_ROOT $sosroot/var/log/juju 2>/dev/null > $dtmp/juju
    #    if (($?==0)); then
    #        mkdir -p $dtmp/var/log/juju
    #        mv $dtmp/juju $dtmp/var/log/
    #    fi
    #    tree $dtmp
    #    root=$dtmp
    #fi

    [ -z "$SOS_ROOT" ] || cd $SOS_ROOT

    echo -e "hostname:\n${INDENT_STR}`cat hostname`" > $F_OUT
    for plugin in ${PLUG_KEYS[@]}; do
        [ "$plugin" = "all" ] && continue
        ${PLUGINS[$plugin]} && . $CWD/plugins/$plugin
    done
)

if $write_to_file; then
    sosreport_name=`basename $SOS_ROOT`
    out=${sosreport_name}.summary
    mv $F_OUT $out
    echo "Summary written to $out"
else
    cat $F_OUT
    echo ""
    rm $F_OUT
fi

echo "INFO: see --help for more display options"
done

#!/bin/bash
# ZFS set zfs_max_arc memory script

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
# WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

# change log:
# 1.1 - reformated ifs and loops to experimental syntax, not yet consistent, but might look a bit better.
# 1.1.1 - minor bugfix, added "q" to exit.
# 2.0.0 - posix style functions; function variable made local; more proper sh code; most code moved to functions; 
#    added color and way to toggle it; fixed rare border case;
# 2.0.1 - removed bash version check; implemented posix comliance;
readonly version="2.0.1"
readonly pve_dir="/etc/pve"
readonly mod_config="/etc/modprobe.d/zfs.conf"
readonly zfs_arc_stats="/proc/spl/kstat/zfs/arcstats"
readonly zfs_arc_param="/sys/module/zfs/parameters/zfs_arc_max"
readonly onetb=1099511627776
readonly onegb=1073741824
readonly format="on"


# [ UI ]

# colors
if [ "$format" = "on" ]; then
    readonly YEL="\033[33m"
    readonly GRN="\033[32m"
    readonly RED="\033[31m"
    readonly BLU="\033[1;34m"
    readonly IT="\033[3m"
    readonly TT="\033[0m"
fi

#
# given message type $1 and message text $2 print message
# $1 - str; mandatory - message type
# $2 - str; mandatory - message
# $3 - str; optional - trailing character?
# return: status code
#
msg () {
    local prefix=""

    [ -z "$2" ] && return 1
    if [ $1 = "info" ]; then
        prefix=" (i)"

        [ -z "$3" ] && printf "%b" "$prefix $2\n" || printf "$prefix %-49s $3\n" "$2"

    elif [ $1 = "check"   ]; then printf " (${BLU}?${TT}) %-48s" "$2"
    elif [ $1 = "ack"     ]; then printf "  [${GRN}+${TT}] $2\n"
    elif [ $1 = "error"   ]; then printf " ${RED}/!\ ${TT}$2\n"
    elif [ $1 = "warning" ]; then
        prefix=" [${YEL}*${TT}]"
        [ -z $3 ] && printf "$prefix $2\n" || printf "$prefix %-49s $3\n" "$2"

    elif [ $1 = "title"   ]; then printf "\n -[$2]--\n\n"
    elif [ $1 = "credits" ]; then printf "%-17s geoai777@gmail.com 2024-2025\n\n" " "
    else return 1
    fi
}

#
# print screen wide divier, if custom character given $1, use it
# $1 - str; optional - divider character, default -
# return: none
#
divider () {

    local divider_char=""
    # only first character will be used no matter what. There can be only one :)
    [ -z $1 ] && divider_char="-" || divider_char=$(printf %.1s "$1")

    for i in $(seq 1 $(tput cols)); do printf $divider_char; done

    printf "\n"
}


# [ CHECKS ]

#
# check root
# return: status code
#
check_root () {
    msg check "are you root?"
    [ "$(whoami)" = 'root' ] && msg ack "I. Am. ROOT! :)" && return 0 \
        || msg error "this script should run as root" && return 1
}

#
# check if proxMx folder exist
# return: status code
#
check_prox () {
    msg info "check PVE is on the system"
    [ -d $pve_dir ] && return 0 || return 1
}


# [ UTILS ]

#
# find $1 in given string $2
# $1 - str; mandatory - neddle
# $2 - str; mandatory - haystack
# return: status code
# 
contains () {
    [ -z "$1" -o -z "$2" ] && return 1
    local findme="$1"
    shift

    for arg in "$@"; do
        [ "$arg" = "$findme" ] && return 0
    done
    return 1
}


# [ ZFS ]

#
# calculate total size of data
# return: int: data size
#
calc_total_data () {
    # get list of all current pool sizes
    local zfs_pool_sizes=$(zpool list -o size | tail -n +2)

    # calculate total size of data
    local zfs_total_size=0
    for pool_size in $zfs_pool_sizes; do
        zfs_total_size=$(($zfs_total_size + $(numfmt --from=iec $pool_size)))
    done

    printf "%d" $zfs_total_size
}

#
# given total data size $1 calculate recommended cache size
# $1 - str: mandatory - total data size
# return: str
#
calc_cache_recommend () {
    local terabytes=1
    
    [ ! -z $1 ] && terabytes=$(($1 / $onetb))

    # calculate recommended cache size
    printf "%s" $(numfmt --to=iec $((4 * $onegb + $terabytes * $onegb)))
}

#
# get current maximum zfs cache size. Short reusable function package.
# $1 - str: optional. Print raw value.
# return: str
#
get_cur_cache_max () {
    [ -z $1 ] && \
        printf "%s" $(grep c_max $zfs_arc_stats | awk '{print $3}' | numfmt --to=iec) || \
        printf "%s" $(grep c_max $zfs_arc_stats | awk '{print $3}') 
}

#
# prints zfs_arc_max that is currently defined in config
# return: none
#
get_config_cache_max () {
    if [ ! -z "$(grep zfs_arc_max $mod_config --no-messages)" ]; then
        local arc_size="$(awk -v i=1 -v pat='zfs_arc_max' '$0~pat{i--}i=0' $mod_config | awk -F= '{print $2}')"
        [ ! -z $arc_size ] && \
            msg info "  system will use on boot (defined in config)" "$(echo $arc_size | numfmt --to=iec)"
    else
        msg warning "there is no zfs_arc_size set in config.No big deal it will be created."
        msg warning "Still, this ${IT}could${TT} mean that tere is a misconfiguration of ZFS."
    fi
}



#
# primary execution loop
# cli arguments:
# fp - force traverse proxMx check 
# fz - force zero data evaluation. Allows script to run even if no pools are detected.
# 
main () {
    divider "="
    msg title "ZFS set max ARC memory v$version"
    msg credits "-"
    divider

    check_root
    [ $? -eq 1 ] && exit 1

    contains "fp" $* 
    if [ $? -eq 1 ]; then
        check_prox
        [ $? -eq 1 ] && exit 1
    fi
    divider

    zfs_total_size=$(calc_total_data)
    contains "fz" $* 
    [ $? -eq 1 ] && msg info "nofz" && \
        [ $zfs_total_size -eq 0 ] && msg error "No zfs pools with data found, no point in cache evaluation. Try creating pools first." && exit 1

    cache_recommend=$(calc_cache_recommend $zfs_total_size)

    msg warning "Your present zpool sizes sum is:" "$(numfmt --to=iec $zfs_total_size)"
    msg warning "Evaluated cache size is:" "$cache_recommend"
    msg info "Keep in mind, it is good practice to have at least"
    msg info "8GB of cache, even with small storage space."
    msg info "Cache size can be evaluated by this rule:"
    msg info "                  4GB + (<number of terabytes storage space> * 1GB)"

    divider
    msg info "ZFS ARC:  max cache size:"

    sys_arc_size=$(get_cur_cache_max)
    msg info "  system is using right now (from /proc):" "$sys_arc_size"

    [ ! -f $mod_config ] && \
        msg warning "ZFS config file at path $mod_config not found. No big deal it will be created." && \
        msg warning "Still, this ${IT}could${TT} mean that tere is a misconfiguration of ZFS." || \
        get_config_cache_max

    # if calculated cache is less than recommended minimum, favor recommended minimal value
    if [ $(numfmt --from=iec $cache_recommend) -le $(($onegb * 8)) ]; then
        cache_recommend=$(numfmt --to=iec $(($onegb * 8)))
    fi

    msg info "Enter ARC max RAM size here. Valid options are:"
    msg info "  - 4G, 100M, 1T, 32768" "enter in any format"
    msg info "  - a - set recommended size, that is:" "$cache_recommend"
    
    while true; do
        msg check "  - Ctrl+C or q - exit"
        read new_size_human
            $(printf "%s" $new_size_human | grep -qxE '^[0-9]+[GKMPT]?$')
            [ $? -eq 0 ] && break
            [ $new_size_human = "a" ] && new_size_human=$cache_recommend && break
            [ $new_size_human = "q" ] && exit 1
    done

    new_size=$(numfmt --from=iec $new_size_human)

    # write/replace cache size in file
    msg info "setting new zfs arc ram size to:" "${GRN}$new_size_human${TT}"
    if [ ! -z "$(grep "zfs_arc_max" $mod_config --no-messages)" ]; then
        sed -i -e "s/^\s*options zfs zfs_arc_max=[0-9]*/options zfs zfs_arc_max=$new_size/g" $mod_config
    else
        echo "options zfs zfs_arc_max=$new_size" >> $mod_config
    fi

    msg info "setting current arc_cache_max to" "$new_size"
    printf "%d" $new_size > $zfs_arc_param
    sys_arc_cache=$(get_cur_cache_max "raw")
    msg info "reading active arc_cache_value" "$sys_arc_cache"
    [ "$sys_arc_cache" = "$new_size" ] && msg info "system value update successful" || msg error "failed to update system value"

    msg info "If you use ZFS as root file system don't forget to 'update-initramfs -u'"
    divider "="

}

main $*

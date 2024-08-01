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
version="1.1.1"
pve_dir="/etc/pve"
mod_config="/etc/modprobe.d/zfs.conf"
onetb=1099511627776
onegb=1073741824

function msg {
#
# print message in different flavors
#
    if [[ -z $2 ]]; then return; fi
    if [[ $1 == "info" ]]; then
        prefix=" (i)"

        if [[ -z $3 ]]; then printf "$prefix $2\n"
            else printf "$prefix %-49s $3\n" "$2"
            fi

    elif [[ $1 == "check"   ]]; then printf " (?) %-48s" "$2"
    elif [[ $1 == "ack"     ]]; then printf "  [+] $2\n"
    elif [[ $1 == "error"   ]]; then printf " /!\ $2\n"
    elif [[ $1 == "warning" ]]; then
        prefix=" [*]"
        if [[ -z $3 ]]; then printf "$prefix $2\n"
            else printf "$prefix %-49s $3\n" "$2"
            fi

    elif [[ $1 == "title"   ]]; then printf "\n -[$2]--\n\n"
    elif [[ $1 == "credits" ]]; then printf "%-17s geoai777@gmail.com 2024\n\n" " "
    else return
    fi
}

function divider {
#
# Render simple divider, to improve ergonomics
#

    # only first character will be used no matter what.
    if [[ -z $1 ]]; then divider_char="-"
        else divider_char=$(printf %.1s "$1")
        fi

    for i in $(seq 1 `tput cols`); do printf $divider_char; done

    printf "\n"
}

divider "="
msg title "ZFS set max ARC memory v$version"
msg credits "-"
divider

#
# check bash version is at least 4
#
msg check "bash version is sufficient"
bv="${BASH_VERSION:-0}"
if [[ `echo $bv | awk -F. '{print $1}'` -ge 4 ]]; then msg ack "it is"
    else msg error "Bash version should be above 4"
    fi

#
# check script runs as root
#
msg check "are you root?"
if [[ `whoami` == 'root' ]]; then msg ack "I. Am. ROOT! :)"
    else msg error "this script should run as root"; exit 1
    fi

#
# check we're running on proxmox (might write for common zfs later)
#
msg check "check if system is proxmox"
if [[ -d $pve_dir ]]; then msg ack "it is"
    else msg error "This is not the prox mox we are looking for..."; exit 1
    fi

divider
#
# calculate recommended cache size
#
zfs_pool_sizes=(`zpool list -o size | tail -n +2`)
zfs_total_size=0

for pool_size in "${zfs_pool_sizes[@]}"; do
    zfs_total_size=$(($zfs_total_size + `numfmt --from=iec $pool_size`))
done

if [[ $zfs_total_size -eq 0 ]]; then return; fi

terabytes=$(($zfs_total_size / $onetb))
if [[ $terabytes -eq 0 ]]; then terabytes=1; fi

cache_recommend=`numfmt --to=iec $((4 * $onegb + $terabytes * $onegb))`
msg warning "Your present zpool sizes sum is:" "`numfmt --to=iec $zfs_total_size`"
msg warning "Evaluated cache size is:" "$cache_recommend"
msg info "Keep in mind, it is good practice to have at least"
msg info "8GB of cache, even with small storage space."
msg info "Cache size can be evaluated by this rule:"
msg info "                  4GB + (<number of terabytes storage space> * 1GB)"

divider
msg info "ZFS ARC max size"

#
# determine effective cache max size
#
sys_arc_size=`grep c_max /proc/spl/kstat/zfs/arcstats | awk '{print $3}' | numfmt --to=iec`
msg info "  effective currently (cache size right now):" "$sys_arc_size"

if [[ ! -z `grep zfs_arc_max $mod_config --no-messages` ]]; then
    arc_size=`awk -v i=1 -v pat='zfs_arc_max' '$0~pat{i--}i==0' $mod_config | awk -F= '{print $2}'`
    arc_size_human=`echo $arc_size | numfmt --to=iec`
    msg info "  value in confg (should be used at boot)" "$arc_size_human"
else
    msg info "there is no zfs arc size set in config (or there is no config file at all)"
fi


#
# set recommended cache size to advised minimum
#
if [[ `numfmt --from=iec $cache_recommend` -le $(($onegb * 8)) ]]; then
    cache_recommend=`numfmt --to=iec $(($onegb * 8))`
fi

#
# read user input
#
re='^[0-9]+[GKMPT]{0,1}$'

while true; do
    msg info "Enter ARC max RAM size here. Valid options are:"
    msg info "  - 4G, 100M, 1T, 32768" "enter in any format"
    msg info "  - a - set recommended size, that is:" "$cache_recommend"
    msg check "  - Ctrl+C or q - exit"
    read new_size_human

    if [[ $new_size_human =~ $re ]]; then break
        elif [ $new_size_human = "a" ]; then new_size_human=$cache_recommend; break
        elif [ $new_size_human = "q" ]; then exit 1
        fi
done

new_size=`numfmt --from=iec $new_size_human`

#
# write/replace cache size in file
#
msg check "setting new zfs arc ram size to: $new_size_human"
if [[ ! -z `grep "zfs_arc_max" $mod_config --no-messages` ]]; then
    sed -i -e "s/^\s*options zfs zfs_arc_max=[0-9]*/options zfs zfs_arc_max=$new_size/g" $mod_config
else
    echo "options zfs zfs_arc_max=$new_size" >> $mod_config
fi
msg ack "done"

msg info "I you use ZFS as root file system don't forget to 'update-initramfs -u'"
msg info "reboot is required to activate new config.\n"
msg info "Please, have a nice day! :)"
divider "="

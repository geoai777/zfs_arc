# ZFS ARC max size
Recently I've been reading a lot of confusion about ZFS consuming tons of RAM. 

Solution is very simple, to create zfs module configuration file and set desired amount of memory, according to rule (4G +  "amount of total TB in pools" * 1GB).

All this can be pretty confusing and it is pretty much "one time" operation, that requires ton of reading to be set properly.

To simplify matter I wrote script that does everything itself and allows either to set size manually or set recommended size automatically.

## Configuration
Script is pretty much ready to work, but if you require to set another `zfs.conf` location or name, do edit `mod_config` variable.

If your install has pve folder other than `/etc/pve` (which is highly unlikely), then edit `pve_dir` variable.

## Usage
- download
- run


## Feature thoughts
- add ability to remove value from zfs.conf

# ZFS ARC max size
Recently I've been reading a lot of confusion about ZFS consuming tons of RAM. 

Solution is very simple, to create zfs module configuration file and set desired amount of memory, according to rule (4G +  "amount of total TB in pools" * 1GB).

All this can be pretty confusing and it is pretty much "one time" operation, that requires ton of reading to be set properly.

To simplify matter I wrote script that does everything itself and allows either to set size manually or set recommended size automatically.

## Usage
- download
- run

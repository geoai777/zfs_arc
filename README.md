# ZFS ARC max size
Recently I've been reading a lot of confusion about ZFS consuming tons of RAM. 
Solution is very simple, to create zfs module config and set desired amount of memory, according to rule (4G + <pools TB amount> * 1TB).
All this can be pretty confusing and it is pretty much "one time" opertion, that requires ton of reading to be set properly.
To simplify matter I wrote script that does everything itself and allowes either to set size manually or set recommended size automatically.


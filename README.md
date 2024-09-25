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
- run as root (because /etc/modprobe.d is owned by root and config needs to go there)

### A bit of explanation
`evaluated cache size` - shown by script is data evaluated with sum of pool sizes present on system using formula above.

`recommended cache size` - takes in account wether `evaluated cache size` is less than recommended 8GB minimum. In other words: If `evaluated cache size` gets below 8GB it will recommend you set 8GB, in other case it will recommend evaluated value.


## Feature thoughts
- add ability to remove value from zfs.conf


## Disclaimer
the software is provided "as is", without warranty of any kind, express or implied, including but not limited to the warranties of merchantability, fitness for a particular purpose and oninfringement. in no event shall the authors or copyright holders be liable for any claim, damages or other liability, whether in an action of contract, tort or otherwise, arising from, out of or in connection with the software or the use or other dealings in the software.

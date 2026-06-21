# k2-toolbox

---

## upgrade-moonraker.sh

### Prerequisites
- Host machine must have `git`, `sshpass`, and `scp` installed.
- SSH access to the printer as `root` with password `creality_2024`.

### Usage
Run the script from your host terminal, providing the IP address of the Creality K2:

```bash
./upgrade_moonraker.sh <Printer_IP>
```

If no IP is provided, the script will prompt you for one.

### What this script does:
1. **Host-side preparation**: Clones the latest Moonraker source code from GitHub onto your host and creates a compressed tarball.
2. **Remote backup**: Connects to the printer via SSH, stops the Moonraker service, and creates a backup of the existing files in `/usr/share/moonraker`. It also saves a copy of `moonraker.conf` to `/root/`.
3. **File transfer**: Uses `scp` to move the compressed source tarball from your host to the printer's `/tmp` directory.
4. **Remote update**: Extracts the new source code into `/usr/share/moonraker`, restores the original configuration file, and restarts the Moonraker service.
5. **Cleanup**: Removes the temporary tarball from the printer's `/tmp` directory to save space.

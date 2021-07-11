
# Overview of This Repository #

 - Each of these scripts was written to automate a certain task (e.g. querying file
   creation times, installing a program, etc.) for my convenience, and hopefully
   may make some other Linux/Unix distro users' lives just a bit easier too.

 - Please refer to the comments at the top of each script for more info on what each script does.

# Prerequisites (External Commands/Programs Required) for Each Script #

## For "stat_crtime_function.sh" ##

 1. `oksh` (`sudo -H add-apt-repository ppa:dysfunctionalprogramming/oksh && sudo -H apt install oksh` on Ubuntu)
 2. `debugfs` (`sudo -H apt install e2fsprogs` on Ubuntu)
 3. `ntfsinfo` (`sudo -H apt install ntfs-3g` on Ubuntu)
 4. `dumpexfat` (`sudo -H apt install exfat-utils` on Ubuntu)
 5. `losetup` (`sudo -H apt install mount` on Ubuntu)
 6. `flock` (`sudo -H apt install util-linux` on Ubuntu)
 7. `python3` (`sudo -H apt install python3.8-minimal` on Ubuntu)

## For "draw_io_install_latest.sh" ##

 1. `curl` (`sudo -H apt install curl` on Ubuntu)
 2. `jq.node` (`sudo -H apt install npm` if needed, and then `sudo -H npm install jq.node -g`)
 3. `dpkg` (Yes, you must be running a distro which uses the Debian package manager to use this script.)

# How to Run Each Script #

## For "stat_crtime_function.sh" ##

- `./stat_crtime_function.sh` for more info.

## For "draw_io_install_latest.sh" ##

- Usage: `./draw_io_install_latest.sh [--verbose]`

# TODOs #

- (Maybe) add more scripts that I can share **publically** in the future.

  - I was going to add a personal password generator script to this repository before
    I realized that the generator script's reliance on dictionary words would open myself
    up (and anyone else who decides to use my script that I'd have uploaded) to a potential
    dictionary attack IF I made the script available to the public.  It's a shame too because
    that generator script also showcases my basic AWK coding skills, but I certainly won't
    want to risk others having an easier time hacking my University accounts by making
    that script public.


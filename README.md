# ansible-pi-bootstrap

## HowTo

### Pre-requisite

The following stuff needs to be setup before any of this Ansible magic will work

* This solution is designed to operate with a DHCP server that is capable of providing a MAC -> fixed-address mapping for your Raspberry Pi devices. This allows each Pi to have a well known (reliable) IP address, even when it uses a fresh Raspberry Pi OS (nee Raspian) image.
* You'll need access to Ansible. You can either a) install this locally using python3 and pip, **or** b) do the same in a docker container, exchanging some python polution with the prerequisite of Docker. I opted for the latter, but it should work either way.
* You'll need a computer on which to run Ansible, and maybe some of the other tooling. I use an Arch Linux desktop, but you could likely even use another Raspberry Pi.
* You'll need a copy of the Raspberry Pi OS base image. I used the *Lite* version, as you can install the *heavier* content later, if it is needed.

1. Create an *ssh keypair* to be used exclusively for this automation. I create it here in this directory, using `ssh-keygen -f ansible -P ''` (no passphrase). This keypair is unique to you, and there is an ansible recipe for installing it into the *virgin* Pi after startup.
2. You'll want to doctor the base image in at least one way to support headless operation. I used the Gnome Disks utility to Attach Disk Image... (**not** read-only) on a loop device, then mount (or allow gnome-shell to automatically mount) /boot. For me, the boot partition shows up in /run/media/${USER}/boot (for some other distros, this is /media/${USER}/boot). You **need** to create a file called `ssh` in the /boot partition: `sudo touch /run/media/${USER}/boot/ssh`. If you need wireless access, for a Raspberry Pi Zero-W (wifi-only) or a Pi3/4 using wireless, you'll also need a wpa_supplicant.conf file in the /boot partition. This file actually needs (non-trivial) content; mine is shown below. Create/copy this file in/to the boot partition, e.g. `sudo vim /run/media/${USER}/boot/wpa_supplicant.conf`. At this point, you can unmount the boot partition, and detach the image file. Your changes are now part of that image. Don't share it, since your wifi info will be there!
3. Get Ansible! If you have python3 and pip, just use `pip install --user ansible`; if you're using docker, you build using the provided Dockerfile.
1. Update the users.csv file and the users_to_delete.txt file.

### The Process

1. Update the inventory.yml file to include a new entry for your Pi with the correct IP address. See the example file below.
2. Run the special (one-time) playbook to copy the ssh key onto the new Pi, and disable password authentication. This will make the Pi accessible **only** via ssh using the new ansible automation key pair. Run `ansible-playbook -i inventory.yml ssh-key-bootstrap.yml -e "ansible_ssh_pass=raspberry"` to execute that playbook. If you look into ssh-key-bootstrap.yml you'll see that there are two tasks: the first attaches your new key to the pi account by updating the authorized_keys file, and the second restricts access to the pi account by locking the password. The Raspberry Pi OS comes bundled with a `sudo` configuration to allow the pi user to perform super-user tasks.
3. Double-check the site.yml file to make sure your my has the expected roles associated with it, either based on its hostname, group, or _all_. The common role contains all the things *I* like to put on a Pi; the applications role installs `vim` and `emacs` (the -nox version).
4. Add the ansible keypair to your ssh-agent with `ssh-add ansible`.
5. Run the site playbook to process all the appropriate roles to your pi with `ansible-playbook -i inventory.yml site.yml`.

### The Common Role

The common role asserts the following state(s) on your pi

1. Use apt to update the apt cache, perform an upgrade of outdated packages, and follow that up with a *full-upgrade* to make sure all possible updates are installed. Check for the existence of the /var/run/reboot-required file; if it exists then the upgrades require a reboot to take effect, so `reboot`.
1. Enable the en_US.UTF-8 locale, make it the default locale, and mark the system for reboot if either of those actions resulted in a _change_.
1. Make sure that the sshd config forbids password authentication. Mark the sshd service for a restart if the config has been changed.
1. Update the hostname to match the one you used in the inventory.yml file. If this has resulted in a change, then mark the system to reboot. Make sure the /etc/hosts file contains a mapping for 127.0.1.1 to the new hostname.
1. Flush handlers, resulting in a potential restart of the sshd service *and/or* a reboot of the pi.
1. I've been getting _into_ systemd lately, so I created a set of tasks to convert the Raspberry Pi OS networking to use systemd instead of the hybrid approach it takes by default.
    1. Make sure the _old_ packages are _absent_.
    1. If the wired var is set, copy the 10-eth0.network file to the pi
    1. If the wireless var is set, copy the 10-wlan0.network file to the pi
    1. Mark the systemd-networkd service to start on boot; mark the system for reboot if that is a change
    1. Make sure there is a symlink from /run/systemd/resolve/resolv.conf to /etc/resolv.conf
    1. Mark the systemd-resolved service to start on boot; mark the system for reboot if that is a change
    1. Mark the systemd-timesyncd service to start on boot; mark the sytem for reboot if that is a change
    1. Look for the wpa_supplicant.conf file (possibly the result of the system copying/moving it from /boot). If it exists, then move it to a wpa_supplicant-wlan0.conf, and create/enable a wpa_supplicant@wlan0 service, marking for the system for reboot if that is a change
    1. Flush handlers, forcing the reboot if things have changed
1. Tweak the suoders file to allow anyone in the sudo group to sudo without a password.
1. Go to the users.csv file and create user accounts for everyone in the file, using github keys for ssh access.
1. Delete any users in the users_to_delete.txt file (processed after the adds, to it takes precedence).

### Examples

wpa_supplicant.conf

```
# wpa_supplicant.conf
# a sample
ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
update_config=1
country=US

network={
 ssid="MyWifi"
 psk="MyWifiPassword"
}
```

inventory.yml

```
# inventory.yml
# mypi is a pi3b at 192.168.1.10
all:
  hosts:
    mypi:
      ansible_host: 192.168.1.10
  children:
    pi0w:
      hosts:
      vars:
        wireless: yes
        wired: no
    pi1b:
      hosts:
      vars:
        wireless: no
        wired: yes
    pi3b:
      hosts:
        mypi:
      vars:
        wireless: yes
        wired: no
  vars:
    ansible_user: pi
    ansible_ssh_common_args: "-o StrictHostKeyChecking=no"
```
RGOS boot partition
===================

You can edit this partition on any computer. RGOS reads it at every boot.

SSH access (optional)
---------------------
SSH works with keys only; RGOS images contain no keys.
Put your public key(s) in a file called:

    authorized_keys

one key per line (for example the contents of ~/.ssh/id_ed25519.pub),
then log in with:  ssh user@<device-ip>
Delete the file to disable SSH again.

Wi-Fi (optional)
----------------
Create a file called  wifi.txt :

    country=NL
    ssid=My network
    password=my wifi password

    ssid=Another network
    password=another password

An open network needs only its ssid= line. At the next boot RGOS imports
the networks and DELETES wifi.txt, so the passwords don't stay on this
card. wifi-imported.txt then lists what was imported (without passwords).

You can also join networks on the device: main menu > Wi-Fi.

Boot problems
-------------
rgos-boot.log in this partition is written after every boot: kernel log,
display, backlight and session status.

SteamControllerTools
====================

A number of utilities I use to test SteamControllerTracker and analyse
SteamController data.

steam_controller_usb.lua
------------------------
A Wireshark packet dissector to interpret data exchanged between Steam
and the Steam Controller. A bit crude, but functionnal enough for now.

### How to use

To use this dissector, you first need to enable either [usbmon on Linux or USBPcap on Windows](https://wiki.wireshark.org/CaptureSetup/USB) in order to be able to listen to your USB trafic.

You must then add the entire `steam_controller_usb` directory to `{WIRESHARK_CONFIG_DIR}/plugins`. If you've never done this before, you may need to create that directory. Depending on your system, the wireshark config directory may be located in `~/.wireshark`, `${XDG_CONFIG_HOME}/wireshark`, or on Windows `%appdata%\wireshark`. If everything went well, you can then just fire up Wireshark, start listening your usb interfaces and you should be good to go.

Please report any labeling mistake in the issues, as well as any undecoded or unknown field you think you might have figured out the purpose of.

External documentation
----------------------
* [steamy, by meh](https://github.com/meh/steamy/blob/master/controller/README.md)
* [SteamControllerSigner, by Pilatomic](https://gitlab.com/Pilatomic/SteamControllerSinger/blob/master/main.cpp)
* [scraw, by dennis-hamester](https://dennis-hamester.gitlab.io/scraw/protocol/)
* [sc-controller, by kozec](https://github.com/kozec/sc-controller/blob/master/scc/drivers/sc_dongle.py)
* [steamcontroller, by kolrabi](https://github.com/kolrabi/steamcontroller)

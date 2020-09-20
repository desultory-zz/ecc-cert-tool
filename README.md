Use with caution, make sure file is owned by root and has a chmod of 700 unless you know what you're doing

Config arguments in this file can allow an attacker to OWN your network

This ONLY works with the cloudflare DNS method

You must be using the latest cerbot version, for debian-stretch you must build python3 from source and use pip to install the latest certbot as well as the certbot cloudflare-dns extension
Installing the latest certbot version from pip with python3.5 WILL break your python3.5 install
Make sure to use update-alternatives to change your defauly python3 version to the version you built, this was tested on python3.7


Certificate revoking is currently borken as LE doesn't support revoking EC certs

# Debcore kernel repository

This is the source for the Debcore kernel repository. This is used for generating new kernel packages and making them available via apt.

Conceptually the idea behind Debcore is to use Debian as the underlayment for a lightweight cloud-friendly OS made of modern packages. 

## How to install debcore kernel packages

```
# install the public key
curl http://mirrors.debcore.org/debian/public.key | sudo apt-key add -

# add the list
echo deb http://mirrors.debcore.org/debian sid main | sudo tee /etc/apt/sources.list.d/debcore.list

# update list cache
apt update

# see what's out there
apt search linux-image-[56]

# as of 5/1/2019, install the latest kernel
apt install linux-image-5.1.0-rc7+
```

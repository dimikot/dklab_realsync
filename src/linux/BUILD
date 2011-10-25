The utility has been built using the following command under Ubuntu Linux 11.10 32-bit:

  g++ -static -s -I. *.cpp /usr/lib/libpopt.a -o notify

Or, to achieve the minimal size of the binary:

  g++ -static -s -Os -ffunction-sections -fdata-sections -Wl,--gc-sections -I. *.cpp /usr/lib/libpopt.a -o notify

You might need to change path to libpopt to whatever location it is on your system.
Libpopt is the only dependency aside from g++ if you want to build the utility.
It comes pre-built statically with realsync, so it will most probably just work

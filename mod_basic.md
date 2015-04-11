

# Introduction #

`modules/basic` includes functions that may be common. More than anything, this module's purpose is to serve as example code.

# Requirements #
  * enBot v1.0.0.0+

# Usage #

## !say ##
```
!say <message>
```
Causes the bot to say `<message>` in-channel.

## !halt ##
Shuts down the bot.

## !reboot ##
Reboots the bot, causing it to quit and rejoin the server, in addition to reloading all configuration files and modules.

# Installation #
Unpack the module:
```
$ cd /path/to/enbot/
$ tar xjvf basic-VERSION.tar.bz2
```

Merge configuration entries, if needed:
```
$ cat config/modules.ini.basic >> config/modules.ini
```

Clean up temporary files:
```
$ rm -vi basic-VERSION.tar.bz2 config/modules.ini.basic
```

# Configuration #
  * **Executable Path** - Path to enBot script. _This is only required for !reboot. If you launch enBot with a custom startup script, you can reference it here._

## Example ##
```
[Basic]
Executable Path = /home/siliconviper/bin/enBot/online/enbot.pl
```
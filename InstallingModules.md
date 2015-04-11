# How to install modules in enBot #

Copy module files to wherever you have enBot installed, and cd into that
directory. Example:
```
$ cp NAME-VERSION.* ~/enbot/
$ cd ~/enbot
```
Then verify (if the module is signed) and unpack it.
```
$ gpg --verify NAME-VERSION.tar.bz2.md5.sig
$ md5sum -c NAME-VERSION.tar.bz2.md5
$ tar xjvf NAME-VERSION.tar.bz2
```
Assuming this is a clean install, merge the needed configuration entries
automatically (If you are upgrading a module, you'll need to merge manually,
instructions should be included with the module).
```
$ cat config/modules.ini.NAME >> config/modules.ini
```
Reboot your bot!
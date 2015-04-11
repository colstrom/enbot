

# Introduction #

The Economy Module can serve as a foundation for many things. It allows for identification of the most active members of a channel, and tracking credits for those members. Other modules could tie into this credit system and provide rewards (channel privileges, download credits, or module-specific perks).

# Requirements #
  * enBot Core v1.1.1.0+

# Usage #

## !bank ##
Displays how many credits you have in the bank.

# History #

Economy was inspired by Maketakunai (irc.deltaanime.net/#pro-dice). Credits (zeny) earned by playing his Dice game could be used to purchase channel privileges (only Voice and HalfOp status).

In the case of #pro-dice, the channel existed primarily for people to play the Dice game, so using a game-specific credit system was sensible.

For more general use, I built Economy. The thought being that IRC is dominantly conversation (in most channels), so measuring user engagement and attributing credit accordingly seemed sensible.

# How It Works #

Economy tracks how much a user talks in-channel. It can issue credits based on characters, words, or sentences. The currency name and symbol are configurable.

# Installation #

Unpack the module into your enBot directory:
```
$ cd /path/to/enbot
$ tar xjvf economy-VERSION.tar.bz2
```

If this is your first install of Economy, merge the required configuration entries:
```
$ cat config/modules.ini.economy >> config/modules.ini
```

If upgrading, you may need to merge changes by hand. Review `config/modules.ini.economy` for any new entries, and create them in `config/modules.ini`.

Clean up temporary files:
```
$ rm -vi economy-VERSION.tar.bz2 config/modiles.ini.economy
```

# Configuration #
  * **Bank Database** - Location for bank database file.
  * **Currency [Name|Symbol]** - Name of the currency, and symbol used to denote it.
  * **[Character|Word|Sentence] Value** - Currency units assigned per [character|word|sentence]. (any of them can be set to 0 to disable them)

## Example ##
```
[Economy]
Bank Database = db/economy/bank.ini
Currency Name = Credits
Currency Symbol = c
Character Value = 0.1
Word Value = 1.0
Sentence Value = 1.0
```
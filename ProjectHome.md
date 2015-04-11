# Description #

enBot is a extensible IRC bot, written in Perl. It relies on [Perl Object Environment](http://poe.perl.org/), [POE::Component::IRC](http://search.cpan.org/dist/POE-Component-IRC/), and [Config::Abstract::Ini](http://search.cpan.org/~avajadi/Config-Abstract-0.16/Ini/Ini.pm). All of these are available via CPAN, and are easy dependencies to satisfy.

enBot provides a simple framework for extending functionality with modules (extensions may be a more appropriate term). A module can register what it triggers on, and enBot will pass matching events on to the defined subroutine. Example modules have been written to manage Access Control, User Profiles, making the bot [speak](mod_basic.md), [rebooting it](mod_basic.md), and a simple [participation-based economy](mod_economy.md). _(These modules have not been posted to the source repository on Google Code, but can be downloaded at http://chris.olstrom.com/software/perl/enbot/download/1.x/modules/.)_

Documentation is available on both [writing modules](WritingModules.md) and [installing them](InstallingModules.md).
#!/usr/bin/perl

#############################################
# enBot, a Perl IRC bot for #en, using POE. #
#############################################
#
# Copyright (C) 2004 Chris Olstrom
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
#
#######################################################
# Based on skeleton code found at...
# http://poe.perl.org/?POE_Cookbook/IRC_Bots
#######################################################

use strict;

use POE;
use POE::Component::IRC;
use Config::Abstract::Ini;

# Load Settings
my $botSettings		= new Config::Abstract::Ini('config/settings.ini');
my $moduleSettings	= new Config::Abstract::Ini('config/modules.ini');

# Load Modules
require 'modules/message.pm';
require 'modules/logging.pm';
require 'modules/triggers.pm';
require 'modules/accesscontrol.pm';

################################
# Create and Configure the Bot #
################################

# Component creation. This represents an IRC network, by adding more lines 
# like this, you can make the bot join multiple networks. It'd be a good idea 
# to name them better, if you do that.
POE::Component::IRC->new("bot");

# Session configuration. What events does the bot do anything with?
POE::Session->new(
	_start => \&bot_start,
	irc_001    => \&on_connect,
	irc_public => \&on_public,
	irc_msg    => \&on_public,);
# Note the halfassed workaround above, to get it to handle private messages, 
# and respond to all the same commands, with almost no extra code. Simple, 
# and awesome. ^_^ ( Yes, I know this isn't amazing, but I'm proud if it :p )

# The bot session has started.  Register this bot with the "bot"
# IRC component.  Select a nickname.  Connect to a server.
sub bot_start {
	my $kernel  = $_[KERNEL];
	my $heap    = $_[HEAP];
	my $session = $_[SESSION];
	
	$kernel->post( bot => register => "all" );
	
	$kernel->post( bot => connect => {
		Nick     => $botSettings->get_entry_setting('Bot','NICK','Bot'),
		Username => $botSettings->get_entry_setting('Bot','USER','Bot'),
		Ircname  => $botSettings->get_entry_setting('Bot','DESC','Perl-Based IRC Bot'),
		Server   => $botSettings->get_entry_setting('Server','ADDRESS','irc.dal.net'),
		Port     => $botSettings->get_entry_setting('Server','PORT','6667'),
		}
	);
}

# So, we've connected to a server, what now? Sit around and take up a user slot?
# Here's where we make it do something useful, like identify with nickserv, and 
# join a few channels, so it can be an attention-whore.
sub on_connect {
	my @channelList	= split / /,$botSettings->get_entry_setting('Server','CHANNELS','');
	
	for ( my $iCounter = 0; $iCounter < @channelList; $iCounter++ ) {			# Fix to make the entries useable. Since '#' is interpreted as a comment, 
		$channelList[$iCounter] = "#".$channelList[$iCounter];					# prefixing channel names with it in the configuration file causes problems.
	}																			# We can fix this, by parsing the entries, and prepending them with a '#'.
	
	my $passwd = $botSettings->get_entry_setting('Bot','PASS','password');
	$_[KERNEL]->post( bot => privmsg => 'NickServ', "IDENTIFY $passwd" );
	for (my $iCounter = 0; $iCounter < @channelList; $iCounter++) {
		$_[KERNEL]->post( bot => join => $channelList[$iCounter] );
	}
}


# Someone said something, and the bot saw it.
# How does it react? That's all handled here.
sub on_public {
	my ( $kernel, $who, $where, $messageBody ) = @_[ KERNEL, ARG0, ARG1, ARG2 ];
	
	HandleMessage($kernel,$moduleSettings,$kernel,$who,$where,$messageBody);
}

# Run the bot until it is done.
$poe_kernel->run();

_TERM:
exit 0;

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

#############################
# Configure Global Settings #
#############################

my $CONFIG_NICK		= 'enBot'; # . $$ % 1000;
my $CONFIG_USERNAME	= 'enBot';
my $CONFIG_IRCNAME	= 'Perl-based IRC Bot';
my $CONFIG_SERVER	= 'bots.esper.net';
my $CONFIG_PORT		= '5555';

my @CONFIG_CHANNEL;
	$CONFIG_CHANNEL[0] = '#en';
	$CONFIG_CHANNEL[1] = '#enBot';
	$CONFIG_CHANNEL[2] = '#enGames';

#############################
# Define Available Commands #
#############################

my @commands;
	$commands[0] = '(HELP) (INFO) (READ) (SEARCH) (SCRIBBLE) (PROFILE) ';
	$commands[1] = '(V) (ROT13) ';
	$commands[2] = '(H) (K) (SHOW ACL) ';
	$commands[3] = '(O) (B) ';
	$commands[4] = '(CONTROL) ';
	$commands[5] = '(CONFIG) ';
	$commands[6] = '(M) (GETTHEFUCKOUTOFHERE) ';

###############################
# Create Access Control Lists #
###############################

my $ACL_AUTHOR = 'SiliconViper';
my $ACL_OWNER = 'SiliconViper';
my $ACL_FOUNDER;
my $ACL_SOP;
my $ACL_AOP;
my $ACL_HOP;
my $ACL_VOICE;
my $ACL_NORMAL;
my $ACL_BANNED;

############################
# Whiteboard Configuration #
############################

my $CONFIG_BOARD_FILE = 'db.whiteboard';
my $CONFIG_BOARD_LIMIT = 100;

my @messageBody;
my $messageOffset = 0;
my $restrictLooping = 0;

###############################
# User Settings Configuration #
###############################

my $CONFIG_USER_FILE = 'settings-user.ini';
my $USER_SETTINGS;

#################
# Special Flags #
#################
	
my %triggerFlag = (
	"Load Board"	=> 0,
	"Save Board"	=> 0,
	"Load Profile"	=> 0,
	"Save Profile"	=> 0,
	"Reload ACL"	=> 0
);
	
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
		Nick     => $CONFIG_NICK,
		Username => $CONFIG_USERNAME,
		Ircname  => $CONFIG_IRCNAME,
		Server   => $CONFIG_SERVER,
		Port     => $CONFIG_PORT,
		}
	);
}

# So, we've connected to a server, what now? Sit around and take up a user slot?
# Here's where we make it do something useful, like identify with nickserv, and 
# join a few channels, so it can be an attention-whore.
sub on_connect {
	open (passwd, 'config.passwd') || die ( "Could not open file. $!"); my $passwd = <passwd>; close (passwd);
	$_[KERNEL]->post( bot => privmsg => 'NickServ', "IDENTIFY $passwd" );
	for (my $iCounter = 0; $iCounter < @CONFIG_CHANNEL; $iCounter++) {
		$_[KERNEL]->post( bot => join => $CONFIG_CHANNEL[$iCounter] );
	}
}


# Someone said something, and the bot saw it.
# How does it react? That's all handled here.
sub on_public {

	#####################
	# Gather Basic Info #
	#####################
	## Assign data to named scalars.
	## Determine nick/hostmask, channel, and timestamp
	
	my ( $kernel, $who, $where, $msg ) = @_[ KERNEL, ARG0, ARG1, ARG2 ];
	
	# Thanks to xmath, from #perlhelp on EFnet, for this more efficient splitting.
	my ($nick, $hostmask) = split /!/, $who, 2;
	
	my $channel = $where->[0];
	
	#######################
	# Configure TimeStamp #
	#######################
	## Get time from local settings, format
	
	# Thanks to cardioid, from #perlhelp on EFnet, for this more efficient timestamp generation.
	my $timestamp = sprintf("%02d:%02d", (localtime)[2,1]);

	#######################
	# Local Configuration #
	#######################
	## Define default method for command replies
	
	my $echoLocation = $nick;

	###########
	# Logging #
	###########
	## WARNING!! The following configuration ONLY logs the main channel.
	## Get time from local settings, format it to mimic mIRC's format, and print 
	## log to console, for maximum flexibility. Allows total log manipulation by 
	## the user, should they so desire. I tend to run the bot with...
	## 'run ./enbot.pl >> /home/username/log/enbot &'
	if ( $channel eq $CONFIG_CHANNEL[0] ) {
		print "[$timestamp] <$nick> $msg\n"; # Log to screen
	}
	
	################
	# Access Check #
	################
	## Parses the access control list for nick, and if it finds a match, assigns 
	## a control level, which is used to detemine which commands can be used.
	
	my $control = -1;
	if ( $ACL_NORMAL =~ /$nick/ ) { $control = 0; }
	if ( $ACL_VOICE =~ /$nick/ ) { $control = 1; }
	if ( $ACL_HOP =~ /$nick/ ) { $control = 2; }
	if ( $ACL_AOP =~ /$nick/ ) { $control = 3; }
	if ( $ACL_SOP =~ /$nick/ ) { $control = 4; }
	if ( $ACL_FOUNDER =~ /$nick/ ) { $control = 5; }
	if ( $ACL_OWNER =~ /$nick/ ) { $control = 666; }
	if ( $ACL_AUTHOR =~ /$nick/ ) { $control = 999; }
	if ( $ACL_BANNED =~ /$nick/ ) { $control = -2; }
	
	######################
	# User ID Generation #
	######################
	## Generates user IDs by taking the ASCII value of each character in the nick, 
	## and adding them together.

	my $uid;
	if (1) {
		my @tmpBuffer = (split //, $nick);
		for (my $iCounter = 0; $iCounter < (@tmpBuffer - 1); $iCounter++) {
			$uid += ord @tmpBuffer[$iCounter];
		}
	}
	
	###################
	# Response Method #
	###################
	## Determines how to respond to a message. If prefixed with '!', it responds 
	## in the channel it was called from. If prefixed with '.', it responds with 
	## a private message.
	
	if ( ( $msg =~ /^!/ ) && ( $control >= 1 ) ) { $echoLocation = $channel; }
	if ( $msg =~ /^\./ ) { $echoLocation = $nick; }
	
	
	
	######################
	# Bot Owner Commands #
	######################
	
	if ( $control >= 666 ) {
		## Useless function, exists more as a template than anything. Can be used to 
		## prove ownership of the bot. $ePenis++
		if ( $msg =~ /^[!|\.] M/i ) {
			$kernel->post( bot => privmsg => $echoLocation, " At your service, MASTER" );
			goto _DONE;
		}
		
		## Bot kills itself by eating a frisbee. Well, something like that.
		if ( $msg =~ /^[!|\.]seppuku/i ) {
			$kernel->post( bot => privmsg => $echoLocation, " Ack! I am slain ... (--> $nick <--)" );
			goto _TERM;
		}
		
	}
	
	
	
	######################
	# SuperOper Commands #
	######################
	
	if ( $control >= 4 ) {
		## Alters the maximum number of entries the board will store.
		if ( $msg =~ /^[!|\.]config BOARD_LIMIT (.+)/i ) {
			$CONFIG_BOARD_LIMIT = $1; 
			$kernel->post( bot => privmsg => $echoLocation, " [*] CONFIG_BOARD_LIMIT set to $CONFIG_BOARD_LIMIT. " );
			goto _DONE;
		}
		
		## Resets the 'next message' marker to whatever position is specified.
		if ( $msg =~ /^[!|\.]config BOARD_OFFSET (.+)/i ) {
			$messageOffset = $1;
			$kernel->post( bot => privmsg => $echoLocation, " [*] Message Offset to $messageOffset / $CONFIG_BOARD_LIMIT" );
			goto _DONE;
		}
	}
	
	
	
	#################
	# Oper Commands #
	#################
	
	if ( $control >= 3 ) {
		if ( $msg =~ /^[!|\.]control (.+)/i ) {
			
			## Loads the access control lists from a file. Yes, I realize this is ugly.
			if ( $1 =~ /^ACL_RELOAD$/i ) {
				open (acl, "acl.founder") || die ( "Could not open file. $!"); $ACL_FOUNDER = <acl>; close (acl);
				open (acl, "acl.sop") || die ( "Could not open file. $!"); $ACL_SOP = <acl>; close (acl);
				open (acl, "acl.aop") || die ( "Could not open file. $!"); $ACL_AOP = <acl>; close (acl);
				open (acl, "acl.hop") || die ( "Could not open file. $!"); $ACL_HOP = <acl>; close (acl);
				open (acl, "acl.voice") || die ( "Could not open file. $!"); $ACL_VOICE = <acl>; close (acl);
				open (acl, "acl.normal") || die ( "Could not open file. $!"); $ACL_NORMAL = <acl>; close (acl);
				open (acl, "acl.banned") || die ( "Could not open file. $!"); $ACL_BANNED = <acl>; close (acl);
				$kernel->post( bot => privmsg => $echoLocation, " [*] Access Control Lists reloaded. " );
				goto _DONE
			}
			
			if ( $1 =~ /^BOARD_SAVE$/i ) {
				$triggerFlag{"Save Board"} = 1;
				goto _DONE;
			}
			
			## This one populates the whiteboard from a file, and sets the 'next message' 
			## marker to however many entries there are, plus one.
			if ( $1 =~ /^BOARD_LOAD$/i ) {
				open (board, "$CONFIG_BOARD_FILE") || die ("Could not open file. $!"); 
					@messageBody = <board>;
				close (board);
				$messageOffset = (@messageBody - 1);
				$kernel->post( bot => privmsg => $echoLocation, " [*] Board loaded from $CONFIG_BOARD_FILE. " );
				$kernel->post( bot => privmsg => $echoLocation, " [*] Message Offset to $messageOffset / $CONFIG_BOARD_LIMIT" );
				goto _DONE;
			}
			
			## WARNING!! This will erase any profiles that have been added, and not saved.
			## Loads settings for users from a file. Currently, this is only used for 
			## profiles, but more uses are planned.
			if ( $1 =~ /^USERS_LOAD$/i ) {
				$USER_SETTINGS = new Config::Abstract::Ini($CONFIG_USER_FILE);
				$kernel->post( bot => privmsg => $echoLocation, " [*] User settings loaded from $CONFIG_USER_FILE. " );
				goto _DONE;
			}
			
			if ( $1 =~ /^USERS_SAVE$/i ) {
				$triggerFlag{"Save Profile"} = 1;
				goto _DONE;
			}
			
			## Erases a message from the whiteboard, and replaces it with a message 
			## indicating who erased it.
			if ( $1 =~ /^BOARD_MESSAGE_ERASE (.+)/i ) {
				$messageBody[$1] = " [X] Erased by $nick";
				$kernel->post( bot => privmsg => $echoLocation, "Message $1 erased by $nick" );
				goto _DONE;
			}
			
			## Calls an external shellscript to generate stats. The reason for this, is to 
			## allow modification of this script, without reloading the bot. It also 
			## allows flexibility, and support of ANY stat generation software.
			if ( $1 =~ /^STATS_REGEN$/i ) {
				system(". ./script.stats > /dev/null");
				$kernel->post( bot => privmsg => $CONFIG_CHANNEL[0], " [*] Stats Regenerated, check http://siliconviper.whatthefork.org/enbot/ircstats/" );
				goto _DONE;
			}
		}
	}
	
	## This one saves the contents of the whiteboard to a file. 
	## 'script.noemptylines' is a simple shellscript to strip blank lines, as a 
	## halfassed workaround for the fact that it sometimes inserts them if you omit 
	## the 'print board ("\n"), and sometimes doesn't. This way, it appends a 
	## newline, regardless, and just strips out any excess lines created by this.
	if ( $triggerFlag{"Save Board"} > 0 ) {
		open (board, ">$CONFIG_BOARD_FILE") || die ("Could not open file. $!");
			print board join("\n",@messageBody);
			print board ("\n");
		close (board);
		system(". ./script.noemptylines ");
		if ( $msg =~ /^[!|\.]/i ) {
			$kernel->post( bot => privmsg => $echoLocation, " [*] Board saved to $CONFIG_BOARD_FILE. " );
		}
		$triggerFlag{"Save Board"} = 0;
	}
	
	## Saves user settings to a file.
	if ( $triggerFlag{"Save Profile"} > 0 ) {
		open (users, ">$CONFIG_USER_FILE") || die ("Could not open file. $!");
			print users "$USER_SETTINGS";
		close (users);
		if ( $msg =~ /^[!|\.]/i ) {
			$kernel->post( bot => privmsg => $echoLocation, " [*] User settings saved to $CONFIG_USER_FILE. " );
		}
		$triggerFlag{"Save Profile"} = 0;
	}
	
	#####################
	# HalfOper Commands #
	#####################
	
	if ( $control >= 2 ) {
		## Displays the access control lists. I really should modifiy this to be more 
		## flexible. As it is, it spews the entire list. You should be able to call 
		## a single section, if you want.
		if ( $msg =~ /^[!|\.]SHOW ACL (.+)$/i ) {
			if ( $1 =~ /^AUTHOR$/i ) {
				$kernel->post( bot => privmsg => $echoLocation, " [+] Author: $ACL_AUTHOR " );
			}
			if ( $1 =~ /^OWNER$/i ) {
				$kernel->post( bot => privmsg => $echoLocation, " [+] Owner: $ACL_OWNER " );
			}
			if ( $1 =~ /^FOUNDER$/i ) {
				$kernel->post( bot => privmsg => $echoLocation, " [+] Founder: $ACL_FOUNDER " );
			}
			if ( $1 =~ /^SOP$/i ) {
				$kernel->post( bot => privmsg => $echoLocation, " [+] SuperOpers: $ACL_SOP " );
			}
			if ( $1 =~ /^AOP$/i ) {
				$kernel->post( bot => privmsg => $echoLocation, " [+] Opers: $ACL_AOP " );
			}
			if ( $1 =~ /^HOP$/i ) {
				$kernel->post( bot => privmsg => $echoLocation, " [+] HalfOpers: $ACL_HOP " );
			}
			if ( $1 =~ /^VOICE$/i ) {
				$kernel->post( bot => privmsg => $echoLocation, " [+] Voiced Users: $ACL_VOICE " );
			}
			if ( $1 =~ /^NORMAL$/i ) {
				$kernel->post( bot => privmsg => $echoLocation, " [+] Normal Users: $ACL_NORMAL " );
			}
			if ( $1 =~ /^BANNED$/i ) {
				$kernel->post( bot => privmsg => $echoLocation, " [+] Banned Users: $ACL_BANNED " );
			}
			goto _DONE;
		}
	}
	
	
	###################
	# Voiced Commands #
	###################
	
	if ( $control >= 1 ) {
		## Encrypts / Decrypts text, using one of the most useless ciphers in 
		## existence. Popular on newsgroups, for some obscure reason.
		if ( my ($rot13) = $msg =~ /^[!|\.]rot13 (.+)/i ) {
			$rot13 =~ tr[a-zA-Z][n-za-mN-ZA-M];
			$kernel->post( bot => privmsg => $echoLocation, $rot13 );
			goto _DONE;
		}
	}
	
	
	
	###################
	# Normal Commands #
	###################
	
	if ( $control >= 0 ) {
		
		if ( $msg =~ /^[!|\.]READ (.+)/i ) {
			## WARNING!! This subroutine has been known to lag the bot, if used in 
			## conjunction with a large whiteboard. It displays every message on the 
			## board. For anti-flooding reasons, this ONLY sends via private message, 
			## even if called with a public trigger.
			if ( $1 =~ /^ALL$/i ) {
				for (my $iCounter = 0; $iCounter < @messageBody; $iCounter++) {
					$kernel->post( bot => privmsg => $nick, "Reading Message $iCounter: $messageBody[$iCounter]" );
				}
				goto _DONE;
			}
			
			## Displays the message matching the number specified.
			if ( $1 =~ /^#(.+)/i ) {
				$kernel->post( bot => privmsg => $echoLocation, "Reading Message $1: $messageBody[$1]" );
				goto _DONE;
			}
		}
		
		## Searched the whiteboard for any messages matching a simple /query/ regex.
		## There is a known bug here, that may crash the bot, if the query ends with 
		## a '\'. This causes the regex to be read as /query\/, which escapes the 
		## regex, and causes the bot to die.
		if ( $msg =~ /^[!|\.]SEARCH (.+)/i ) {
			for (my $iCounter = 0; $iCounter < @messageBody; $iCounter++) {
				if ($messageBody[$iCounter] =~ /$1/) {
					$kernel->post( bot => privmsg => $echoLocation, "Reading Message $iCounter: $messageBody[$iCounter]" );
				}
			}
			goto _DONE;
		}
		
		## Writes a message on the whiteboard, in the position indicated by the 
		## 'next message' marker ($messageOffset).
		if ( $msg =~ /^[!|\.]SCRIBBLE (.+)/i ) {
			if ( ( ( @messageBody > $CONFIG_BOARD_LIMIT ) || ( $messageOffset > $CONFIG_BOARD_LIMIT ) ) && ( $restrictLooping = 0 ) ) {
				$messageOffset = 0; $restrictLooping = 1;
			}
			if ( $messageOffset eq ( $CONFIG_BOARD_LIMIT - 1 ) ) { $restrictLooping = 0; }
			
			$messageBody[$messageOffset] = "$1  - $nick";
			$kernel->post( bot => privmsg => $echoLocation, "Message \#$messageOffset Saved: $messageBody[$messageOffset]" );
			$messageOffset++;
			$triggerFlag{"Save Board"} = 1;
			goto _DONE;
		}
		
		if ( $msg =~ /^[!|\.]PROFILE (.+)/i ) {
			## Sets the profile for the user calling it to whatever they specify.
			if ( $1 =~ /^SET (.+)/i ) {
				$USER_SETTINGS->set_entry_setting("$nick",'PROFILE',"$1");
				my $tmpBuffer = $USER_SETTINGS->get_entry_setting("$nick",'PROFILE',"Profile Not Set");
				$kernel->post( bot => privmsg => $echoLocation, " [*] Profile for $nick set to: $tmpBuffer" );
				$triggerFlag{"Save Profile"} = 1;
				goto _DONE;
			}
			
			## Displays the profile for the user specified. Has a known bug that causes it 
			## to spew errors to console. Doesn't crash, just errors. This happens if 
			## someone attempts to view a nonexistant profile.
			if ( $1 =~ /^VIEW (.+)/i ) {
				my $tmpBuffer = $USER_SETTINGS->get_entry_setting("$1","PROFILE","Profile Not Set");
				$kernel->post( bot => privmsg => $echoLocation, " [*] Profile for $1: $tmpBuffer" );
				goto _DONE;
			}
		}
		
	}
	
	
	
	#########################
	# Unrestricted Commands #
	#########################
	
	if ( $control >= -1 ) {
		## Generic, no topic.
		if ( $msg =~ /^[!\.]HELP$/i ) {
			$kernel->post( bot => privmsg => $echoLocation, " [?] Syntax is HELP <TOPIC> " );
			$kernel->post( bot => privmsg => $echoLocation, " [?] Topics include WHITEBOARD, PROFILE, CONTROL, and CONFIG." );
			$kernel->post( bot => privmsg => $echoLocation, " [?] Commands are issued either in-channel, or via private message (/msg)." );
			$kernel->post( bot => privmsg => $echoLocation, " [?] All commands must be prefixed with a response identifier, either ! (public) or . (private). " );
			$kernel->post( bot => privmsg => $echoLocation, " [?] For a list of commands you can use, type !INFO or .INFO " );
			goto _DONE;
		}
		
		## Specific, with topic.
		if ( $msg =~ /^[!\.]HELP (.+)/i ) {
			## Topic: Whiteboard
			if ( $1 =~ /^WHITEBOARD$/i ) {
				$kernel->post( bot => privmsg => $echoLocation, "[?] Whiteboard Commands (Level 0): SCRIBBLE, READ, SEARCH" );
				$kernel->post( bot => privmsg => $echoLocation, "[?] SCRIBBLE <message>: Writes <message> on the whiteboard, in the next available position (currently $messageOffset / $CONFIG_BOARD_LIMIT )" );
				$kernel->post( bot => privmsg => $echoLocation, "[?] READ <#n>: Reads message number n." );
				$kernel->post( bot => privmsg => $echoLocation, "[?] READ ALL: Reads all messages." );
				$kernel->post( bot => privmsg => $echoLocation, "[?] SEARCH <text>: Reads all messages containing <text>." );
				goto _DONE;
			}
			
			## Topic: Profile
			if ( $1 =~ /^PROFILE$/i ) {
				$kernel->post( bot => privmsg => $echoLocation, "[?] PROFILE Commands (Level 0): SET, VIEW" );
				$kernel->post( bot => privmsg => $echoLocation, "[?] SET <text>: Sets your profile to <text>" );
				$kernel->post( bot => privmsg => $echoLocation, "[?] VIEW <user>: Reads the profile of <user>" );
				goto _DONE;
			}
			
			## Topic: Control
			if ( $1 =~ /^CONTROL$/i ) {
				$kernel->post( bot => privmsg => $echoLocation, "[?] CONTROL Commands (Level 4): BOARD_SAVE, BOARD_LOAD, ACL_RELOAD, PROFILE_LOAD, STATS_REGEN" );
				$kernel->post( bot => privmsg => $echoLocation, "[?] BOARD_LOAD: Loads the contents of the whiteboard from $CONFIG_BOARD_FILE" );
				$kernel->post( bot => privmsg => $echoLocation, "[?] BOARD_SAVE: Saves the contents of the whiteboard to $CONFIG_BOARD_FILE" );
				$kernel->post( bot => privmsg => $echoLocation, "[?] USERS_LOAD: Loads settings for all users from $CONFIG_USER_FILE" );
				$kernel->post( bot => privmsg => $echoLocation, "[?] USERS_SAVE: Saves settings for all users to $CONFIG_USER_FILE" );
				$kernel->post( bot => privmsg => $echoLocation, "[?] ACL_RELOAD: Reloads the Access Control Lists" );
				$kernel->post( bot => privmsg => $echoLocation, "[?] STATS_REGEN: Regenerates the Statistics Page" );
				goto _DONE;
			}
			
			## Topic: Config
			if ( $1 =~ /^CONFIG$/i ) {
				$kernel->post( bot => privmsg => $echoLocation, "[?] CONFIG Commands (Level 5): BOARD_LIMIT, BOARD_OFFSET" );
				$kernel->post( bot => privmsg => $echoLocation, "[?] BOARD_LIMIT: Modifies the maximum number of messages on the board. [$CONFIG_BOARD_LIMIT]" );
				$kernel->post( bot => privmsg => $echoLocation, "[?] BOARD_OFFSET: Modifies the current position for new messages on the board. [$messageOffset]" );
				goto _DONE;
			}
			goto _DONE;
		}
		
		## Displays the access level of the nick calling it.
		if ( $msg =~ /^[!\.]INFO$/i ) {
			my $commandList;
			for (my $iCounter = 0; (($iCounter <= $control) && ($iCounter <= (@commands - 1))); $iCounter++) {
				$commandList .= $commands[$iCounter];
			}
			$kernel->post( bot => privmsg => $echoLocation, "[?] $nick (Rank $control)" );
			if ( $control >= 0 ) { $kernel->post( bot => privmsg => $echoLocation, "[?] Allowed Commands: $commandList" ); }
			goto _DONE;
		}
	
	}
	
	
	
	#####################################################
	# Handler for undefined access levels (Banned, etc) #
	#####################################################
	
	else {
		goto _DONE;
	}
    
_DONE:

}
  # Run the bot until it is done.
$poe_kernel->run();

_TERM:
exit 0;

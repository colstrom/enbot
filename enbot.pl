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

use strict;

use POE;
use POE::Component::IRC;

my $tmpBuffer;

#############################
# Define Available Commands #
#############################

my @commands;
$commands[0] = "(HELP) (INFO) (READ) (SEARCH) (SCRIBBLE) (PROFILE) ";
$commands[1] = "(V) (ROT13) ";
$commands[2] = "(H) (K) (SHOW ACL) ";
$commands[3] = "(O) (B) ";
$commands[4] = "(CONTROL) ";
$commands[5] = "(CONFIG) ";
$commands[6] = "(M) (GETTHEFUCKOUTOFHERE) ";

###############################
# Create Access Control Lists #
###############################

my $ACL_AUTHOR = "SiliconViper";
my $ACL_OWNER = "SiliconViper";
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

my $CONFIG_BOARD_FILE = "db.whiteboard";
my $CONFIG_BOARD_LIMIT = "100";

my @messageBody;
my $messageOffset = 0;
my $restrictLooping = 0;

################################
# Profile System Configuration #
################################

my $CONFIG_PROFILE_FILE = "db.profile";

my @profile;

###############################
# Create and Confgure the Bot #
###############################

sub CHANNEL () { "#en" }

# Create the component that will represent an IRC network.
POE::Component::IRC->new("magnet");

# Create the bot session.  The new() call specifies the events the bot
# knows about and the functions that will handle those events.
POE::Session->new(
	_start => \&bot_start,
	irc_001    => \&on_connect,
	irc_public => \&on_public,
	irc_msg    => \&on_public,);

# The bot session has started.  Register this bot with the "magnet"
# IRC component.  Select a nickname.  Connect to a server.
sub bot_start {
	my $kernel  = $_[KERNEL];
	my $heap    = $_[HEAP];
	my $session = $_[SESSION];
	
	$kernel->post( magnet => register => "all" );
	
	my $nick = 'enBot'; # . $$ % 1000;
	$kernel->post( magnet => connect => {
		Nick => $nick,
		Username => 'enBot',
		Ircname  => 'Perl-based IRC bot',
		Server   => 'irc.esper.net',
		Port     => '5555',
		}
	);
}

# The bot has successfully connected to a server.  Join a channel.
sub on_connect {
    $_[KERNEL]->post( magnet => join => CHANNEL );
}


# The bot has received a public message.  Parse it for commands, and
# respond to interesting things.
sub on_public {

	#####################
	# Gather Basic Info #
	#####################
	## Assign data to named scalars.
	## Determine nick/hostmask, channel, and timestamp
	
	my ( $kernel, $who, $where, $msg ) = @_[ KERNEL, ARG0, ARG1, ARG2 ];
	my $nick = ( split /!/, $who )[0];
	my $hostmask = ( split /!/, $who )[1];
	my $channel = $where->[0];
	
	#######################
	# Configure TimeStamp #
	#######################
	## Get time from local settings, format

	my $tmp = scalar localtime;
	my @tmp = split(/ /,$tmp); $tmp = $tmp[3]; @tmp = split(/:/,$tmp);
	my $ts = $tmp[0] . ":" . $tmp[1];

	#######################
	# Local Configuration #
	#######################
	## Define default method for command replies
	
	my $echoLocation = $nick;
	
	###########
	# Logging #
	###########
	## Log to screen, for maximum flexibility.
	
	print "[$ts] <$nick> $msg\n"; # Log to screen
	
	################
	# Access Check #
	################
	## Determine the user's control level
	## by parsing the ACLs for that nick
	
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
	## Generate User ID from nick.

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
	## Should replies be public, or private?
	
	if ( $msg =~ /^!/ ) { $echoLocation = CHANNEL; }
	if ( $msg =~ /^\./ ) { $echoLocation = $nick; }
	
	
	
	######################
	# Bot Owner Commands #
	######################
	
	if ( $control >= 666 ) {
		if ( $msg =~ /^[!|\.] M/i ) {
			$kernel->post( magnet => privmsg => $echoLocation, " At your service, MASTER" );
			goto _DONE;
		}
		
		if ( $msg =~ /^[!|\.]GetTheFuckOutOfHere/i ) {
			$kernel->post( magnet => privmsg => CHANNEL, " Ack! I am slain ... (--> $nick <--)" );
			goto _TERM;
		}
		
	}
	
	
	
	######################
	# SuperOper Commands #
	######################
	
	if ( $control >= 4 ) {
		if ( $msg =~ /^[!|\.]config BOARD_LIMIT (.+)/i ) {
			$CONFIG_BOARD_LIMIT = $1; 
			$kernel->post( magnet => privmsg => $echoLocation, " [*] CONFIG_BOARD_LIMIT set to $CONFIG_BOARD_LIMIT. " );
			goto _DONE;
		}
		
		
		if ( $msg =~ /^[!|\.]config BOARD_OFFSET (.+)/i ) {
			$messageOffset = $1;
			$kernel->post( magnet => privmsg => $echoLocation, " [*] Message Offset to $messageOffset / $CONFIG_BOARD_LIMIT" );
			goto _DONE;
		}
	}
	
	
	
	#################
	# Oper Commands #
	#################
	
	if ( $control >= 3 ) {
		if ( $msg =~ /^[!|\.]control (.+)/i ) {
			
			if ( $1 =~ /^ACL_RELOAD$/i ) {
				open (acl, "acl.founder") || die ( "Could not open file. $!"); $ACL_FOUNDER = <acl>; close (acl);
				open (acl, "acl.sop") || die ( "Could not open file. $!"); $ACL_SOP = <acl>; close (acl);
				open (acl, "acl.aop") || die ( "Could not open file. $!"); $ACL_AOP = <acl>; close (acl);
				open (acl, "acl.hop") || die ( "Could not open file. $!"); $ACL_HOP = <acl>; close (acl);
				open (acl, "acl.voice") || die ( "Could not open file. $!"); $ACL_VOICE = <acl>; close (acl);
				open (acl, "acl.normal") || die ( "Could not open file. $!"); $ACL_NORMAL = <acl>; close (acl);
				open (acl, "acl.banned") || die ( "Could not open file. $!"); $ACL_BANNED = <acl>; close (acl);
				$kernel->post( magnet => privmsg => $echoLocation, " [*] Access Control Lists reloaded. " );
				goto _DONE
			}
			
			if ( $1 =~ /^BOARD_SAVE$/i ) {
				open (board, ">$CONFIG_BOARD_FILE") || die ("Could not open file. $!");
					print board join("\n",@messageBody);
					print board ("\n");
				close (board);
				system(". ./script.noemptylines ");
				$kernel->post( magnet => privmsg => $echoLocation, " [*] Board saved to $CONFIG_BOARD_FILE. " );
			}
			
			if ( $1 =~ /^BOARD_LOAD$/i ) {
				open (board, "$CONFIG_BOARD_FILE") || die ("Could not open file. $!"); 
					@messageBody = <board>;
				close (board);
				$messageOffset = (@messageBody - 1);
				$kernel->post( magnet => privmsg => $echoLocation, " [*] Board loaded from $CONFIG_BOARD_FILE. " );
				$kernel->post( magnet => privmsg => $echoLocation, " [*] Message Offset to $messageOffset / $CONFIG_BOARD_LIMIT" );
				goto _DONE;
			}
			
			if ( $1 =~ /^PROFILE_LOAD$/i ) {
				open (profile, "$CONFIG_PROFILE_FILE") || die ("Could not open file. $!");
					@profile = <profile>;
				close (profile);
				$kernel->post( magnet => privmsg => $echoLocation, " [*] Profile loaded from $CONFIG_PROFILE_FILE. " );
				goto _DONE;
			}
			
			if ( $1 =~ /^BOARD_MESSAGE_ERASE (.+)/i ) {
				$messageBody[$1] = " [X] Erased by $nick";
				$kernel->post( magnet => privmsg => $echoLocation, "Message $1 erased by $nick" );
				goto _DONE;
			}
			
			if ( $1 =~ /^STATS_REGEN$/i ) {
				system(". ./script.stats > /dev/null");
				$kernel->post( magnet => privmsg => $echoLocation, " [*] Stats Regenerated, check http://142.33.13.20/~siliconviper/en-ircstats/" );
				goto _DONE;
			}
		}
		
		if ( $msg =~ /^[!|\.]O (.+)/i ) {
			$kernel->post( magnet => privmsg => $echoLocation, " Op Management Support is DISABLED, contact your vendor for more information. " );
			goto _DONE;
		}
		
		if ( $msg =~ /^[!|\.]B (.+)/i ) {
			$kernel->post( magnet => privmsg => $echoLocation, " Banning Support is DISABLED, contact your vendor for more information. " );
			goto _DONE;
		}
	}
	
	
	
	#####################
	# HalfOper Commands #
	#####################
	
	if ( $control >= 2 ) {
		if ( $msg =~ /^[!|\.]H (.+)/i ) {
			$kernel->post( magnet => privmsg => $echoLocation, " HalfOp Management is DISABLED, contact your vendor for more information. " );
			goto _DONE;
		}
		
		if ( $msg =~ /^[!|\.]K (.+)/i ) {
			$kernel->post( magnet => privmsg => $echoLocation, " Kicking Support is DISABLED, contact your vendor for more information. " );
			goto _DONE;
		}
		
		if ( $msg =~ /^[!|\.]SHOW ACL$/i ) {
			$kernel->post( magnet => privmsg => $echoLocation, " [+] Author: $ACL_AUTHOR " );
			$kernel->post( magnet => privmsg => $echoLocation, " [+] Owner: $ACL_OWNER " );
			$kernel->post( magnet => privmsg => $echoLocation, " [+] Founder: $ACL_FOUNDER " );
			$kernel->post( magnet => privmsg => $echoLocation, " [+] SuperOpers: $ACL_SOP " );
			$kernel->post( magnet => privmsg => $echoLocation, " [+] Opers: $ACL_AOP " );
			$kernel->post( magnet => privmsg => $echoLocation, " [+] HalfOpers: $ACL_HOP " );
			$kernel->post( magnet => privmsg => $echoLocation, " [+] Voiced Users: $ACL_VOICE " );
			$kernel->post( magnet => privmsg => $echoLocation, " [+] Normal Users: $ACL_NORMAL " );
			$kernel->post( magnet => privmsg => $echoLocation, " [+] Banned Users: $ACL_BANNED " );
			goto _DONE;
		}
	}
	
	
	###################
	# Voiced Commands #
	###################
	
	if ( $control >= 1 ) {
		if ( my ($rot13) = $msg =~ /^[!|\.]rot13 (.+)/i ) {
			$rot13 =~ tr[a-zA-Z][n-za-mN-ZA-M];
			$kernel->post( magnet => privmsg => $echoLocation, $rot13 );
			goto _DONE;
		}
		
		if ( $msg =~ /^[!|\.]V (.+)/i ) {
			$kernel->post( magnet => privmsg => $echoLocation, " Voice Management is DISABLED, contact your vendor for more information. " );
			goto _DONE;
		}
	}
	
	
	
	###################
	# Normal Commands #
	###################
	
	if ( $control >= 0 ) {
		
		if ( $msg =~ /^[!|\.]READ (.+)/i ) {
			if ( $1 =~ /^ALL$/i ) {
				for (my $iCounter = 0; $iCounter < @messageBody; $iCounter++) {
					$kernel->post( magnet => privmsg => $nick, "Reading Message $iCounter: $messageBody[$iCounter]" );
				}
				goto _DONE;
			}
			if ( $1 =~ /^#(.+)/i ) {
				$kernel->post( magnet => privmsg => $echoLocation, "Reading Message $1: $messageBody[$1]" );
				goto _DONE;
			}
		}
		
		if ( $msg =~ /^[!|\.]SEARCH (.+)/i ) {
			for (my $iCounter = 0; $iCounter < @messageBody; $iCounter++) {
				if ($messageBody[$iCounter] =~ /$1/) {
					$kernel->post( magnet => privmsg => $echoLocation, "Reading Message $iCounter: $messageBody[$iCounter]" );
				}
			}
			goto _DONE;
		}
		
		if ( $msg =~ /^[!|\.]SCRIBBLE (.+)/i ) {
			if ( ( ( @messageBody > $CONFIG_BOARD_LIMIT ) || ( $messageOffset > $CONFIG_BOARD_LIMIT ) ) && ( $restrictLooping = 0 ) ) {
				$messageOffset = 0; $restrictLooping = 1;
			}
			if ( $messageOffset eq ( $CONFIG_BOARD_LIMIT - 1 ) ) { $restrictLooping = 0; }
			
			$messageBody[$messageOffset] = "$1  - $nick";
			$kernel->post( magnet => privmsg => $echoLocation, "Message \#$messageOffset Saved: $messageBody[$messageOffset]" );
			$messageOffset++;
			goto _DONE;
		}
		
		if ( $msg =~ /^[!|\.]profile SET (.+)/i ) {
			$profile[$uid] = $1;
			$kernel->post( magnet => privmsg => $echoLocation, " [*] Profile for $nick set to: $profile[$uid]" );
			goto _DONE;
		}
		
		if ( $msg =~ /^[!|\.]profile VIEW (.+)/i ) {
			my $view;
		        if (1) {
		                my @tmpBuffer = (split //, $1);
		                for (my $iCounter = 0; $iCounter < (@tmpBuffer - 1); $iCounter++) {
		                        $view += ord @tmpBuffer[$iCounter];
		                }
		        }
			
			$kernel->post( magnet => privmsg => $echoLocation, " [-] Profile for $1: $profile[$view]" );
			goto _DONE;
		}
	}
	
	
	
	#########################
	# Unrestricted Commands #
	#########################
	
	if ( $control >= -1 ) {
		if ( $msg =~ /^[!\.]HELP$/i ) {
			$kernel->post( magnet => privmsg => $echoLocation, " [?] Syntax is HELP <TOPIC> " );
			$kernel->post( magnet => privmsg => $echoLocation, " [?] Topics include WHITEBOARD, PROFILE, CONTROL, and CONFIG." );
			$kernel->post( magnet => privmsg => $echoLocation, " [?] Commands are issued either in-channel, or via private message (/msg)." );
			$kernel->post( magnet => privmsg => $echoLocation, " [?] All commands must be prefixed with a response identifier, either ! (public) or . (private). " );
			goto _DONE;
		}
		
		if ( $msg =~ /^[!\.]HELP (.+)/i ) {
			if ( $1 =~ /^WHITEBOARD$/i ) {
				$kernel->post( magnet => privmsg => $echoLocation, "[?] Whiteboard Commands (Level 0): SCRIBBLE, READ, SEARCH" );
				$kernel->post( magnet => privmsg => $echoLocation, "[?] SCRIBBLE <message>: Writes <message> on the whiteboard, in the next available position (currently $messageOffset / $CONFIG_BOARD_LIMIT )" );
				$kernel->post( magnet => privmsg => $echoLocation, "[?] READ <#n>: Reads message number n." );
				$kernel->post( magnet => privmsg => $echoLocation, "[?] READ ALL: Reads all messages." );
				$kernel->post( magnet => privmsg => $echoLocation, "[?] SEARCH <text>: Reads all messages containing <text>." );
				goto _DONE;
			}
			if ( $1 =~ /^PROFILE$/i ) {
				$kernel->post( magnet => privmsg => $echoLocation, "[?] PROFILE Commands (Level 0): SET, VIEW" );
				$kernel->post( magnet => privmsg => $echoLocation, "[?] SET <text>: Sets your profile to <text>" );
				$kernel->post( magnet => privmsg => $echoLocation, "[?] VIEW <user>: Reads the profile of <user>" );
				goto _DONE;
			}
			
			if ( $1 =~ /^CONTROL$/i ) {
				$kernel->post( magnet => privmsg => $echoLocation, "[?] CONTROL Commands (Level 4): BOARD_SAVE, BOARD_LOAD, ACL_RELOAD, PROFILE_LOAD, STATS_REGEN" );
				$kernel->post( magnet => privmsg => $echoLocation, "[?] BOARD_LOAD: Loads the contents of the whiteboard from $CONFIG_BOARD_FILE" );
				$kernel->post( magnet => privmsg => $echoLocation, "[?] BOARD_SAVE: Saves the contents of the whiteboard to $CONFIG_BOARD_FILE" );
				$kernel->post( magnet => privmsg => $echoLocation, "[?] PROFILE_LOAD: Loads user profiles from $CONFIG_PROFILE_FILE" );
				$kernel->post( magnet => privmsg => $echoLocation, "[?] ACL_RELOAD: Reloads the Access Control Lists" );
				$kernel->post( magnet => privmsg => $echoLocation, "[?] STATS_REGEN: Regenerates the Statistics Page" );
				goto _DONE;
			}
			
			if ( $1 =~ /^CONFIG$/i ) {
				$kernel->post( magnet => privmsg => $echoLocation, "[?] CONFIG Commands (Level 5): BOARD_LIMIT, BOARD_OFFSET" );
				$kernel->post( magnet => privmsg => $echoLocation, "[?] BOARD_LIMIT: Modifies the maximum number of messages on the board. [$CONFIG_BOARD_LIMIT]" );
				$kernel->post( magnet => privmsg => $echoLocation, "[?] BOARD_OFFSET: Modifies the current position for new messages on the board. [$messageOffset]" );
				goto _DONE;
			}
			goto _DONE;
		}
		
		if ( $msg =~ /^[!\.]INFO$/i ) {
			my $commandList;
			for (my $iCounter = 0; (($iCounter <= $control) && ($iCounter <= (@commands - 1))); $iCounter++) {
				$commandList .= $commands[$iCounter];
			}
			$kernel->post( magnet => privmsg => $echoLocation, "[?] $nick (Rank $control)" );
			if ( $control >= 0 ) { $kernel->post( magnet => privmsg => $echoLocation, "[?] Allowed Commands: $commandList" ); }
			goto _DONE;
		}
	
	}
	
	
	
	#####################################################
	# Handler for undefined access levels (Banned, etc) #
	#####################################################
	
	else {	}
    
_DONE:

}
  # Run the bot until it is done.
$poe_kernel->run();

_TERM:
exit 0;

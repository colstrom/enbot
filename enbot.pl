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

my $CONFIG_NICK		= 'enBot';
my $CONFIG_USERNAME	= 'enBot';
my $CONFIG_IRCNAME	= 'Perl-based IRC Bot';
my $CONFIG_SERVER	= 'dream.esper.net';
my $CONFIG_PORT		= '5555';

my @CONFIG_CHANNEL;
	$CONFIG_CHANNEL[0] = '#en';
	$CONFIG_CHANNEL[1] = '#enBot';
	$CONFIG_CHANNEL[2] = '#enGames';

#############################
# Define Available Commands #
#############################

my @commands;
	$commands[0] = '(HELP) (INFO) (PROFILE) ';
	$commands[1] = '(ROT13) ';
	$commands[2] = '(SHOW ACL) ';
	$commands[3] = '';
	$commands[4] = '(CONTROL) ';
	$commands[5] = '(CONFIG) ';
	$commands[6] = '(M) (SEPPUKU) ';

########################
# Module Configuration #
########################

my %module = ();
	
	
	
	$module{'Active'}{'Access Control'} = 1;
		$module{'Access Control'}{'List'}{'Author'}	= 'SiliconViper';
		$module{'Access Control'}{'File'}{'Author'}	= '/dev/null';
		$module{'Access Control'}{'Level'}{'Author'}	= '999';
		
		$module{'Access Control'}{'List'}{'Owner'}	= 'SiliconViper';
		$module{'Access Control'}{'File'}{'Owner'}	= '/dev/null';
		$module{'Access Control'}{'Level'}{'Owner'}	= '666';
		
		$module{'Access Control'}{'List'}{'Founder'}	= '';
		$module{'Access Control'}{'File'}{'Founder'}	= 'acl.founder';
		$module{'Access Control'}{'Level'}{'Founder'}	= '5';
		
		$module{'Access Control'}{'List'}{'SOP'}	= '';
		$module{'Access Control'}{'File'}{'SOP'}	= 'acl.sop';
		$module{'Access Control'}{'Level'}{'SOP'}	= '4';
		
		$module{'Access Control'}{'List'}{'AOP'}	= '';
		$module{'Access Control'}{'File'}{'AOP'}	= 'acl.aop';
		$module{'Access Control'}{'Level'}{'AOP'}	= '3';
		
		$module{'Access Control'}{'List'}{'HOP'}	= '';
		$module{'Access Control'}{'File'}{'HOP'}	= 'acl.hop';
		$module{'Access Control'}{'Level'}{'HOP'}	= '2';
		
		$module{'Access Control'}{'List'}{'Voice'}	= '';
		$module{'Access Control'}{'File'}{'Voice'}	= 'acl.voice';
		$module{'Access Control'}{'Level'}{'Voice'}	= '1';
		
		$module{'Access Control'}{'List'}{'Normal'}	= '';
		$module{'Access Control'}{'File'}{'Normal'}	= 'acl.normal';
		$module{'Access Control'}{'Level'}{'Normal'}	= '0';
		
		$module{'Access Control'}{'List'}{'Banned'}	= '';
		$module{'Access Control'}{'File'}{'Banned'}	= 'acl.banned';
		$module{'Access Control'}{'Level'}{'Banned'}	= '-2';
	
	
	
	$module{'Active'}{'User Settings'} = 1;
		$module{'User Settings'}{'File'}	= 'settings-user.ini';
		$module{'User Settings'}{'Data'}	= '';
	
	
	
	$module{'Active'}{'Profile'} = 1;
		$module{'Profile'}{'Called'}		= 0;
		$module{'Profile'}{'Read'}		= '';
		$module{'Profile'}{'Write'}		= '';

	$module{'Active'}{'Combat'} = 1;
		$module{'Combat'}{'Called'}		= 0;
		$module{'Combat'}{'Target'}		= '';
		$module{'Combat'}{'Channel'}		= '#enGames';
		$module{'Combat'}{'Last'}		= '';
	
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
	if ( $module{'Access Control'}{'List'}{'Normal'} =~ /$nick/ ) { $control = 0; }
	if ( $module{'Access Control'}{'List'}{'Voice'} =~ /$nick/ ) { $control = 1; }
	if ( $module{'Access Control'}{'List'}{'HOP'} =~ /$nick/ ) { $control = 2; }
	if ( $module{'Access Control'}{'List'}{'AOP'} =~ /$nick/ ) { $control = 3; }
	if ( $module{'Access Control'}{'List'}{'SOP'} =~ /$nick/ ) { $control = 4; }
	if ( $module{'Access Control'}{'List'}{'Founder'} =~ /$nick/ ) { $control = 5; }
	if ( $module{'Access Control'}{'List'}{'Owner'} =~ /$nick/ ) { $control = 666; }
	if ( $module{'Access Control'}{'List'}{'Author'} =~ /$nick/ ) { $control = 999; }
	if ( $module{'Access Control'}{'List'}{'Banned'} =~ /$nick/ ) { $control = -2; }
	
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
	
	my $command;
	if ( ( $msg =~ /^!/ ) && ( $control >= 1 ) ) { $echoLocation = $channel; }
	if ( $msg =~ /^\./ ) { $echoLocation = $nick; }
	
	if ( $msg =~ /^[!|\.](.+)/i ) { $command = $1; }
	
	######################
	# Bot Owner Commands #
	######################
	
	if ( $control >= 666 ) {
		## Useless function, exists more as a template than anything. Can be used to 
		## prove ownership of the bot. $ePenis++
		if ( $msg =~ /^[!|\.]M/i ) {
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

	}
	
	
	
	#################
	# Oper Commands #
	#################
	
	if ( $control >= 3 ) {
		if ( $msg =~ /^[!|\.]control (.+)/i ) {
			
			## Loads the access control lists from a file. Yes, I realize this is ugly.
			if ( $1 =~ /^ACL_RELOAD$/i ) {
				open (acl, $module{'Access Control'}{'File'}{'Founder'}) || die ( "Could not open file. $!");
					$module{'Access Control'}{'List'}{'Founder'} = <acl>;
				close (acl);
				
				open (acl, $module{'Access Control'}{'File'}{'SOP'}) || die ( "Could not open file. $!");
					$module{'Access Control'}{'List'}{'SOP'} = <acl>;
				close (acl);
				
				open (acl, $module{'Access Control'}{'File'}{'AOP'}) || die ( "Could not open file. $!");
					$module{'Access Control'}{'List'}{'AOP'} = <acl>;
				close (acl);
				
				open (acl, $module{'Access Control'}{'File'}{'HOP'}) || die ( "Could not open file. $!");
					$module{'Access Control'}{'List'}{'HOP'} = <acl>;
				close (acl);
				
				open (acl, $module{'Access Control'}{'File'}{'Voice'}) || die ( "Could not open file. $!");
					$module{'Access Control'}{'List'}{'Voice'} = <acl>;
				close (acl);
				
				open (acl, $module{'Access Control'}{'File'}{'Normal'}) || die ( "Could not open file. $!");
					$module{'Access Control'}{'List'}{'Normal'} = <acl>;
				close (acl);
				
				open (acl, $module{'Access Control'}{'File'}{'Banned'}) || die ( "Could not open file. $!");
					$module{'Access Control'}{'List'}{'Banned'} = <acl>;
				close (acl);
				
				$kernel->post( bot => privmsg => $echoLocation, " [*] Access Control Lists reloaded. " );
				goto _DONE
			}
			
			
			## WARNING!! This will erase any profiles that have been added, and not saved.
			## Loads settings for users from a file. Currently, this is only used for 
			## profiles, but more uses are planned.
			if ( $1 =~ /^USERS_LOAD$/i ) {
				$module{'User Settings'}{'Data'} = new Config::Abstract::Ini($module{'User Settings'}{'File'});
				$kernel->post( bot => privmsg => $echoLocation, " [*] User settings loaded from $module{'User Settings'}{'File'}. " );
				goto _DONE;
			}
			
			if ( $1 =~ /^USERS_SAVE$/i ) {
				$module{'Profile'}{'Called'} = 1;
				$module{'Profile'}{'Save'} = 1;
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
	
	#####################
	# HalfOper Commands #
	#####################
	
	if ( $control >= 2 ) {
		## Displays the access control lists. I really should modifiy this to be more 
		## flexible. As it is, it spews the entire list. You should be able to call 
		## a single section, if you want.
		if ( $msg =~ /^[!|\.]SHOW ACL (.+)$/i ) {
			if ( $1 =~ /^AUTHOR$/i ) {
				$kernel->post( bot => privmsg => $echoLocation, " [+] Author: $module{'Access Control'}{'List'}{'Author'} " );
			}
			if ( $1 =~ /^OWNER$/i ) {
				$kernel->post( bot => privmsg => $echoLocation, " [+] Owner: $module{'Access Control'}{'List'}{'Owner'} " );
			}
			if ( $1 =~ /^FOUNDER$/i ) {
				$kernel->post( bot => privmsg => $echoLocation, " [+] Founder: $module{'Access Control'}{'List'}{'Founder'} " );
			}
			if ( $1 =~ /^SOP$/i ) {
				$kernel->post( bot => privmsg => $echoLocation, " [+] SuperOpers: $module{'Access Control'}{'List'}{'SOP'} " );
			}
			if ( $1 =~ /^AOP$/i ) {
				$kernel->post( bot => privmsg => $echoLocation, " [+] Opers: $module{'Access Control'}{'List'}{'AOP'} " );
			}
			if ( $1 =~ /^HOP$/i ) {
				$kernel->post( bot => privmsg => $echoLocation, " [+] HalfOpers: $module{'Access Control'}{'List'}{'HOP'} " );
			}
			if ( $1 =~ /^VOICE$/i ) {
				$kernel->post( bot => privmsg => $echoLocation, " [+] Voiced Users: $module{'Access Control'}{'List'}{'Voice'} " );
			}
			if ( $1 =~ /^NORMAL$/i ) {
				$kernel->post( bot => privmsg => $echoLocation, " [+] Normal Users: $module{'Access Control'}{'List'}{'Normal'} " );
			}
			if ( $1 =~ /^BANNED$/i ) {
				$kernel->post( bot => privmsg => $echoLocation, " [+] Banned Users: $module{'Access Control'}{'List'}{'Banned'} " );
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
		
		if ( ( $module{'Active'}{'Profile'} eq 1 ) && ( $command =~ /^Profile (.+)/i ) ) {
			
			if ( $1 =~ /^View (.+)/i ) {
				$module{'Profile'}{'Called'} = 1;
				$module{'Profile'}{'Read'} = $1;
			}
			
			if ( $1 =~ /^Set (.+)/i ) {
				$module{'Profile'}{'Called'} = 2;
				$module{'Profile'}{'Write'} = $1;
			}
			
		}
		if ( ( $module{'Active'}{'Combat'} eq 1 ) && ( $command =~ /^Combat (.+)/i ) ) {
			if ( $1 =~ /^install$/i ) {
				$module{'Combat'}{'Install'} = "$nick";
				$module{'Combat'}{'Called'} = 1;
				goto _DONE;
			}
		
			if ( $1 =~ /^attack (.+)/i ) {
				if ( $module{'Combat'}{'Last'} ne $nick ) {
					$module{'Combat'}{'Last'} = $nick;
					$module{'Combat'}{'Attacker'} = $nick;
					$module{'Combat'}{'Target'} = $1;
					$module{'Combat'}{'Called'} = 2;
				} else {
					$kernel->post( bot => privmsg => $module{'Combat'}{'Channel'}, " [G] You were the last person to attack, give someone else a turn." ); 				}
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
			$kernel->post( bot => privmsg => $echoLocation, " [?] Topics include PROFILE, CONTROL, and CONFIG." );
			$kernel->post( bot => privmsg => $echoLocation, " [?] Commands are issued either in-channel, or via private message (/msg)." );
			$kernel->post( bot => privmsg => $echoLocation, " [?] All commands must be prefixed with a response identifier, either ! (public) or . (private). " );
			$kernel->post( bot => privmsg => $echoLocation, " [?] For a list of commands you can use, type !INFO or .INFO " );
			goto _DONE;
		}
		
		## Specific, with topic.
		if ( $msg =~ /^[!\.]HELP (.+)/i ) {
			## Topic: Profile
			if ( $1 =~ /^PROFILE$/i ) {
				$kernel->post( bot => privmsg => $echoLocation, "[?] PROFILE Commands (Level 0): SET, VIEW" );
				$kernel->post( bot => privmsg => $echoLocation, "[?] SET <text>: Sets your profile to <text>" );
				$kernel->post( bot => privmsg => $echoLocation, "[?] VIEW <user>: Reads the profile of <user>" );
				goto _DONE;
			}

			## Topic: Game - Combat
			if ( $1 =~ /^COMBAT$/i ) {
				$kernel->post( bot => privmsg => $echoLocation, "[?] COMBAT Commands (Level 0): INSTALL, ATTACK " );
				$kernel->post( bot => privmsg => $echoLocation, "[?] INSTALL: Enables support for Combat, in your account. " );
				$kernel->post( bot => privmsg => $echoLocation, "[?] ATTACK <user>: Attacks <user> with a physical attack. " );
				goto _DONE;
			}
			
			## Topic: Control
			if ( $1 =~ /^CONTROL$/i ) {
				$kernel->post( bot => privmsg => $echoLocation, "[?] CONTROL Commands (Level 4): ACL_RELOAD, PROFILE_LOAD, STATS_REGEN" );
				$kernel->post( bot => privmsg => $echoLocation, "[?] USERS_LOAD: Loads settings for all users from $module{'User Settings'}{'File'}" );
				$kernel->post( bot => privmsg => $echoLocation, "[?] USERS_SAVE: Saves settings for all users to $module{'User Settings'}{'File'}" );
				$kernel->post( bot => privmsg => $echoLocation, "[?] ACL_RELOAD: Reloads the Access Control Lists" );
				$kernel->post( bot => privmsg => $echoLocation, "[?] STATS_REGEN: Regenerates the Statistics Page" );
				goto _DONE;
			}
			
			## Topic: Config
			if ( $1 =~ /^CONFIG$/i ) {
				$kernel->post( bot => privmsg => $echoLocation, "[?] CONFIG Commands (Level 5): NONE" );
				goto _DONE;
			}
			goto _DONE;
		}
		
		## Displays the access level of the nick calling it.
		if ( ( $msg =~ /^[!\.]INFO$/i ) || ( $msg =~ /^[!\.]INFO (.+)/i ) ) {
			if ( $msg =~ /^[!\.]INFO$/i ) {
				$kernel->post( bot => privmsg => $echoLocation, "[?] $nick (Rank $control)" );
			}

			if ( ( $1 =~ /--privs/i ) || ( $1 =~ /-p/i ) ) {
				$kernel->post( bot => privmsg => $echoLocation, "[?] $nick (Rank $control)" );
				my $commandList;
				for (my $iCounter = 0; (($iCounter <= $control) && ($iCounter <= (@commands - 1))); $iCounter++) {
					$commandList .= $commands[$iCounter];
				}
				if ( $control >= 0 ) { $kernel->post( bot => privmsg => $echoLocation, "[?] Allowed Commands: $commandList" ); }
			}

			if ( ( $1 =~ /--games/i ) || ( $1 =~ /-g/i ) ) {
				if ( $module{'User Settings'}{'Data'}->get_entry_setting("$nick",'Combat_Installed',0) eq 1 ) {
					my $combat_installed = $module{'User Settings'}{'Data'}->get_entry_setting("$nick",'Combat_Installed',0);
					my $combat_level	= $module{'User Settings'}{'Data'}->get_entry_setting("$nick",'Combat_LEVEL',0);
					my $combat_exp		= $module{'User Settings'}{'Data'}->get_entry_setting("$nick",'Combat_EXP',0);
					my $combat_patk		= $module{'User Settings'}{'Data'}->get_entry_setting("$nick",'Combat_PATK',0);
					my $combat_pdef		= $module{'User Settings'}{'Data'}->get_entry_setting("$nick",'Combat_PDEF',0);
					my $combat_hp_curr	= $module{'User Settings'}{'Data'}->get_entry_setting("$nick",'Combat_HP_CURR',0);
					my $combat_hp_max	= $module{'User Settings'}{'Data'}->get_entry_setting("$nick",'Combat_HP_MAX',0);
					my $combat_matk		= $module{'User Settings'}{'Data'}->get_entry_setting("$nick",'Combat_MATK',0);
					my $combat_mdef		= $module{'User Settings'}{'Data'}->get_entry_setting("$nick",'Combat_MDEF',0);
					my $combat_mp_curr	= $module{'User Settings'}{'Data'}->get_entry_setting("$nick",'Combat_MP_CURR',0);
					my $combat_mp_max	= $module{'User Settings'}{'Data'}->get_entry_setting("$nick",'Combat_MP_MAX',0);

					$kernel->post( bot => privmsg => $echoLocation, "[?] $nick " );
					$kernel->post( bot => privmsg => $echoLocation, "[?] +------------------------+ " );
					$kernel->post( bot => privmsg => $echoLocation, "[?] | Level (Experience): $combat_level ($combat_exp) " );
					$kernel->post( bot => privmsg => $echoLocation, "[?] | HP(Max): $combat_hp_curr($combat_hp_max) | Physical ATK/DEF: $combat_patk / $combat_pdef " );
					if ( $combat_matk > 0 ) { $kernel->post( bot => privmsg => $echoLocation, "[?] | MP(Max): $combat_mp_curr($combat_mp_max) | Magical ATK/DEF: $combat_matk / $combat_mdef " );
					} else { $kernel->post( bot => privmsg => $echoLocation, "[?] | Does not know magic." ); }
					$kernel->post( bot => privmsg => $echoLocation, "[?] +------------------------+ " );
				}
			}				
				
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

######################
# Module Code Blocks #
######################

####################################
## Combat Module by Chris Olstrom ##
if ( ( $module{'Active'}{'Combat'} eq 1 ) && ( $module{'Combat'}{'Called'} > 0 ) ) {
	
	## Installs Combat support in the profile for current user.
	if ( $module{'Combat'}{'Called'} eq 1 ) {
		my $is_installed = $module{'User Settings'}{'Data'}->get_entry_setting("$nick",'Combat_Installed',0);
		if ( $is_installed eq 0 ) {
			$module{'User Settings'}{'Data'}->set_entry_setting("$nick",'Combat_Installed',1);
			$module{'User Settings'}{'Data'}->set_entry_setting("$nick",'Combat_LEVEL',1);
			$module{'User Settings'}{'Data'}->set_entry_setting("$nick",'Combat_EXP',0);
			$module{'User Settings'}{'Data'}->set_entry_setting("$nick",'Combat_PATK',1);
			$module{'User Settings'}{'Data'}->set_entry_setting("$nick",'Combat_PDEF',1);
			$module{'User Settings'}{'Data'}->set_entry_setting("$nick",'Combat_MATK',0);
			$module{'User Settings'}{'Data'}->set_entry_setting("$nick",'Combat_MDEF',0);
			$module{'User Settings'}{'Data'}->set_entry_setting("$nick",'Combat_HP_CURR',50);
			$module{'User Settings'}{'Data'}->set_entry_setting("$nick",'Combat_HP_MAX',50);
			$module{'User Settings'}{'Data'}->set_entry_setting("$nick",'Combat_MP_CURR',0);
			$module{'User Settings'}{'Data'}->set_entry_setting("$nick",'Combat_MP_MAX',0);
			$kernel->post( bot => privmsg => $module{'Combat'}{'Channel'}, " [M] 'Combat' support added to your account. " );
		} else {
			$kernel->post( bot => privmsg => $module{'Combat'}{'Channel'}, " [!!] FLAGRANT ERROR MESSAGE." );
			$kernel->post( bot => privmsg => $module{'Combat'}{'Channel'}, " [!M] 'Combat' already installed. " );
		}
	}
	
	if ( $module{'Combat'}{'Called'} eq 2 ) {
		my $attacker = $nick;
		my $defender = $module{'Combat'}{'Target'};
		
		my $is_ready = 0;
		my $is_able = $module{'User Settings'}{'Data'}->get_entry_setting("$attacker",'Combat_Installed',0);
		my $is_willing = $module{'User Settings'}{'Data'}->get_entry_setting("$defender",'Combat_Installed',0);
		
		if ( $is_able eq 0 ) {
			$kernel->post( bot => privmsg => $module{'Combat'}{'Channel'}, " [!G] Your account does not have 'Combat' installed. To fix this, join $module{'Combat'}{'Channel'}, and type !combat install " );
		} else {
			if ( $is_willing eq 0 ) {
				$kernel->post( bot => privmsg => $module{'Combat'}{'Channel'}, " [!G] $defender does not have 'Combat' installed. " );
			} else {
				$is_ready = 1;
			}
		}
		
		if ( $is_ready eq 1 ) {
			my $a_name	= "$attacker";
			my $a_level	= $module{'User Settings'}{'Data'}->get_entry_setting("$attacker",'Combat_LEVEL',1);
			my $a_exp	= $module{'User Settings'}{'Data'}->get_entry_setting("$attacker",'Combat_EXP',0);
			my $a_patk	= $module{'User Settings'}{'Data'}->get_entry_setting("$attacker",'Combat_PATK',1);
			my $a_pdef	= $module{'User Settings'}{'Data'}->get_entry_setting("$attacker",'Combat_PDEF',1);
			my $a_hp_curr	= $module{'User Settings'}{'Data'}->get_entry_setting("$attacker",'Combat_HP_CURR',50);
			my $a_hp_max	= $module{'User Settings'}{'Data'}->get_entry_setting("$attacker",'Combat_HP_MAX',50);
			my $a_mp_curr	= $module{'User Settings'}{'Data'}->get_entry_setting("$attacker",'Combat_MP_CURR',0);
			my $a_mp_max	= $module{'User Settings'}{'Data'}->get_entry_setting("$attacker",'Combat_MP_MAX',0);
			my $a_aroll	= int(rand($a_level * $a_patk +10));
			my $a_droll	= int(rand($a_level * $a_pdef +10));
			
			my $d_name	= "$defender";
			my $d_level	= $module{'User Settings'}{'Data'}->get_entry_setting("$defender",'Combat_LEVEL',1);
			my $d_exp	= $module{'User Settings'}{'Data'}->get_entry_setting("$defender",'Combat_EXP',0);
			my $d_patk	= $module{'User Settings'}{'Data'}->get_entry_setting("$defender",'Combat_PATK',1);
			my $d_pdef	= $module{'User Settings'}{'Data'}->get_entry_setting("$defender",'Combat_PDEF',1);
			my $d_hp_curr	= $module{'User Settings'}{'Data'}->get_entry_setting("$defender",'Combat_HP_CURR',50);
			my $d_hp_max	= $module{'User Settings'}{'Data'}->get_entry_setting("$defender",'Combat_HP_MAX',50);
			my $d_mp_curr	= $module{'User Settings'}{'Data'}->get_entry_setting("$defender",'Combat_MP_CURR',0);
			my $d_mp_max	= $module{'User Settings'}{'Data'}->get_entry_setting("$defender",'Combat_MP_MAX',0);
			my $d_aroll	= int(rand($d_level * $d_patk +10));
			my $d_droll	= int(rand($d_level * $d_pdef +10));
			
			if ( $a_aroll > $d_droll ) {
				my $damage = $a_aroll - $d_droll; $d_hp_curr = $d_hp_curr - $damage;
				$kernel->post( bot => privmsg => $module{'Combat'}{'Channel'}, "[G] $a_aroll/$a_droll vs $d_aroll/$d_droll | $a_name strikes $d_name, dealing $damage points of damage. $d_name has\cC3 [$d_hp_curr/$d_hp_max]\x0F remaining." );
				if ( $d_hp_curr le 0 ) { 
					my $rewardExp = int( ( $a_level / $d_level ) * 10 );
					if ( $rewardExp < 1 ) { $rewardExp = 1; }
					my $totalExp = $a_exp + $rewardExp;
					$module{'User Settings'}{'Data'}->set_entry_setting("$a_name",'Combat_EXP',$totalExp);
					$kernel->post( bot => privmsg => $module{'Combat'}{'Channel'}, " [G] $a_name defeats $d_name in combat, gaining\cC12 $rewardExp Experience Points\x0F. " );
					$a_hp_curr = $a_hp_max;
					$kernel->post( bot => privmsg => $module{'Combat'}{'Channel'}, " [G] $a_name has been restored to full HP!" );
					$d_hp_curr = $d_hp_max;
					$kernel->post( bot => privmsg => $module{'Combat'}{'Channel'}, " [G] $d_name has been restored to full HP!" );
				}
			} elsif ( $a_aroll < $d_droll ) {
				$kernel->post( bot => privmsg => $module{'Combat'}{'Channel'}, " [G] $a_aroll/$a_droll vs $d_aroll/$d_droll | $d_name evades $a_name\'s strike. " );
			} else {
				if ( $d_aroll > $a_droll ) {
					my $damage = $d_aroll - $a_droll; $a_hp_curr = $a_hp_curr - $damage;
					$kernel->post( bot => privmsg => $module{'Combat'}{'Channel'}, " [G] $a_aroll/$a_droll vs $d_aroll/$d_droll | $d_name dodges, and counterattacks $a_name, dealing $damage points of damage. $a_name has\cC3 [$a_hp_curr/$a_hp_max]\x0F HP remaining." );
					if ( $a_hp_curr le 0 ) { 
						my $rewardExp = int( ( $d_level / $a_level ) * 10 );
						if ( $rewardExp < 1 ) { $rewardExp = 1; }
						my $totalExp = $d_exp + $rewardExp;
						$module{'User Settings'}{'Data'}->set_entry_setting("$d_name",'Combat_EXP',$totalExp);
						$kernel->post( bot => privmsg => $module{'Combat'}{'Channel'}, " [G] $d_name defeats $a_name in combat, gaining\cC12 $rewardExp Experience Points\x0F. " );
						$a_hp_curr = $a_hp_max;
						$kernel->post( bot => privmsg => $module{'Combat'}{'Channel'}, " [G] $a_name has been restored to full HP!" );
						$d_hp_curr = $d_hp_max;
						$kernel->post( bot => privmsg => $module{'Combat'}{'Channel'}, " [G] $d_name has been restored to full HP!" );
					}
				} elsif ( $d_aroll < $a_droll ) {
					$kernel->post( bot => privmsg => $module{'Combat'}{'Channel'}, " [G] $a_aroll/$a_droll vs $d_aroll/$d_droll | $d_name evades, and attempts to counter $a_name, but fails. " );
				} else {
					$kernel->post( bot => privmsg => $module{'Combat'}{'Channel'}, " [G] $a_aroll/$a_droll vs $d_aroll/$d_droll | $a_name and $d_name lose track of each other for one round. No damage dealt, none taken. " );
				}
			}
			$module{'User Settings'}{'Data'}->set_entry_setting("$a_name",'Combat_HP_CURR',$a_hp_curr);
			$module{'User Settings'}{'Data'}->set_entry_setting("$d_name",'Combat_HP_CURR',$d_hp_curr);
		}
	}
	
	## Make sure it saves.
	$module{'Profile'}{'Called'} = 99; # Call the profile module, but don't trigger an event.
	$module{'Profile'}{'Save'} = 1;

	## Cleanup
	$module{'Combat'}{'Called'} = 0;
	$module{'Combat'}{'Target'} = '';
}

#####################################
## Profile Module by Chris Olstrom ##
if ( ( $module{'Active'}{'Profile'} eq 1 ) && ( $module{'Profile'}{'Called'} > 0 ) ) {

	## Displays the profile for the user specified. Has a known bug that causes it 
	## to spew errors to console. Doesn't crash, just errors. This happens if 
	## someone attempts to view a nonexistant profile.
	if ( $module{'Profile'}{'Called'} eq 1 ) {
		my $tmpBuffer = $module{'User Settings'}{'Data'}->get_entry_setting("$module{'Profile'}{'Read'}","PROFILE","Profile Not Set");
		$kernel->post( bot => privmsg => $echoLocation, " [*] Profile for $module{'Profile'}{'Read'}: $tmpBuffer" );
	}
	
	## Sets the profile for the user calling it to whatever they specify.
	if ( $module{'Profile'}{'Called'} eq 2 ) {
		$module{'User Settings'}{'Data'}->set_entry_setting("$nick",'PROFILE',"$module{'Profile'}{'Write'}");
		my $tmpBuffer = $module{'User Settings'}{'Data'}->get_entry_setting("$nick",'PROFILE',"Profile Not Set");
		$kernel->post( bot => privmsg => $echoLocation, " [*] Profile for $nick set to: $tmpBuffer" );
		$module{'Profile'}{'Save'} = 1;
	}
	
	## Saves user settings to a file.
	if ( $module{'Profile'}{'Save'} eq 1 ) {
		open (users, ">$module{'User Settings'}{'File'}") || die ("Could not open file. $!");
			print users "$module{'User Settings'}{'Data'}";
		close (users);
		if ( $msg =~ /^[!|\.]/i ) {
			$kernel->post( bot => privmsg => '#enBot', " [*] User settings saved to $module{'User Settings'}{'File'}. " );
		}
		$module{'Profile'}{'Save'} = 0;
	}
	
	## Cleanup
	$module{'Profile'}{'Read'}	= '';
	$module{'Profile'}{'Write'}	= '';

	$module{'Profile'}{'Called'}	= 0;
}

##############################
##############################
## Install New Modules Here ##
##############################
##############################

}

# Run the bot until it is done.
$poe_kernel->run();

_TERM:
exit 0;

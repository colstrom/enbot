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

my $CONFIG = new Config::Abstract::Ini('settings-bot.ini');

my $CONFIG_NICK		= $CONFIG->get_entry_setting('Bot','NICK','Bot');
my $CONFIG_USERNAME	= $CONFIG->get_entry_setting('Bot','USER','Bot');
my $CONFIG_IRCNAME	= $CONFIG->get_entry_setting('Bot','DESC','Perl-Based IRC Bot');
my $CONFIG_SERVER	= $CONFIG->get_entry_setting('Server','ADDRESS','irc.dal.net');
my $CONFIG_PORT		= $CONFIG->get_entry_setting('Server','PORT','6667');

my @CONFIG_CHANNEL	= split / /,$CONFIG->get_entry_setting('Server','CHANNELS','');

## Fix to make the entries useable. Since '#' is interpreted as a comment, 
## prefixing channel names with it in the configuration file causes problems.
## We can fix this, by parsing the entries, and prepending them with a '#'.
for ( my $iCounter = 0; $iCounter < @CONFIG_CHANNEL; $iCounter++ ) {
	$CONFIG_CHANNEL[$iCounter] = "#".$CONFIG_CHANNEL[$iCounter];
}

#############################
# Define Available Commands #
#############################

my @commands;
	$commands[0] = '(HELP) (INFO) (PROFILE) (CONTENTION) ';
	$commands[1] = '(ROT13) ';
	$commands[2] = '(SHOW ACL) ';
	$commands[3] = '';
	$commands[4] = '(CONTROL) ';
	$commands[5] = '(CONFIG) ';
	$commands[6] = '(M) (SEPPUKU) ';

#######################
# Configuration Block #
#######################

my %module = ();
	
	$module{'Active'}{'Logging'} = 1;
		$module{'Logging'}{'Channel'}		= '#'.$CONFIG->get_entry_setting('Modules','Log_Channel','');
		
	$module{'Active'}{'Access Control'} = 1;
		$module{'Access Control'}{'File'}	= 'settings-acl.ini';
		$module{'Access Control'}{'Data'}	= new Config::Abstract::Ini("$module{'Access Control'}{'File'}");
		$module{'Access Control'}{'Default'}	= $CONFIG->get_entry_setting('Modules','Access_Default',-1);
		
	$module{'Active'}{'Help'} = 1;
		$module{'Help'}{'Called'}		= 0;
		$module{'Help'}{'Arguments'}		= '';
		
	$module{'Active'}{'User Settings'} = 1;
		$module{'User Settings'}{'File'}	= 'settings-user.ini';
		$module{'User Settings'}{'Data'} = new Config::Abstract::Ini($module{'User Settings'}{'File'});
		
	$module{'Active'}{'Profile'} = 1;
		$module{'Profile'}{'Called'}		= 0;
		$module{'Profile'}{'Arguments'}		= '';
		
	$module{'Active'}{'Contention'} = 1;
		$module{'Contention'}{'Called'}		= 0;
		$module{'Contention'}{'Arguments'}	= '';
		$module{'Contention'}{'Channel'}	= "#".$CONFIG->get_entry_setting('Modules','Contention_Channel','');
		$module{'Contention'}{'Last Action'}	= '';
		
		
		
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
	my $passwd = $CONFIG->get_entry_setting('Bot','PASS','password');
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
	if ( $channel eq $module{'Logging'}{'Channel'} ) {
		print "[$timestamp] <$nick> $msg\n"; # Log to screen
	}
	
	################
	# Access Check #
	################
	## Parses the access control list for nick, and if it finds a match, assigns 
	## a control level, which is used to detemine which commands can be used.
	
	my $control = $module{'Access Control'}{'Default'};
	
	foreach my $acl ('Normal','Voice','HalfOp','Oper','SuperOp','Founder','Owner','Author','Banned') {
		if ( $module{'Access Control'}{'Data'}->get_entry_setting("$acl",'List','') =~ /$nick/i ) {
			$control = $module{'Access Control'}{'Data'}->get_entry_setting("$acl",'Level',0);
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

###################
## Trigger Block ##
###################

	######################
	# Bot Owner Commands #
	######################
	
	if ( $control >= 666 ) {
		## Useless function, exists more as a template than anything. Can be used to 
		## prove ownership of the bot. $ePenis++
		if ( $command =~ /^DECLARE MASTER$/i ) {
			$kernel->post( bot => privmsg => $echoLocation, " At your service, MASTER" );
			goto _DONE;
		}
		
		## Bot kills itself by eating a frisbee. Well, something like that.
		if ( $command =~ /^SEPPUKU$/i ) {
			$kernel->post( bot => privmsg => $echoLocation, " Ack! I am slain ... (--> $nick <--)" );
			goto _TERM;
		}
		
		## Bot attempts rebirth.
		if ( $command =~ /^REBIRTH$/i ) {
			exec ( '/home/siliconviper/src/clean/sh/launch-enbot.sh' );
		}
			
		
	}
	
	
	
	######################
	# SuperOper Commands #
	######################
	
	if ( $control >= 4 ) {
		if ( ( $module{'Active'}{'Contention'} eq 1 ) && ( $channel eq $module{'Contention'}{'Channel'} ) &&( $command =~ /^CONTENTION (.+)/i ) ) {
			$module{'Contention'}{'Arguments'} = "GM::$1";
			goto _DONE;
		}			
	}
	
	
	
	#################
	# Oper Commands #
	#################
	
	if ( $control >= 3 ) {
		if ( $command =~ /^CONTROL (.+)/i ) {
			
			## Loads the access control lists from a file.
			if ( $1 =~ /^ACL_RELOAD$/i ) {
				$module{'Access Control'}{'Data'} = new Config::Abstract::Ini("$module{'Access Control'}{'File'}");
				$kernel->post( bot => privmsg => $echoLocation, " [*] Access Control Lists reloaded. " );
				goto _DONE
			}
			
			## Loads settings for users from a file.
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
		## Displays the requested access list
		if ( $command =~ /^SHOW ACCESS LIST (.+)$/i ) {
			my $list = $module{'Access Control'}{'Data'}->get_entry_setting("$1",'List','');
			$kernel->post( bot => privmsg => $echoLocation, " [?] $1: $list " );
			goto _DONE;
		}
	}
	
	
	###################
	# Voiced Commands #
	###################
	
	if ( $control >= 1 ) {
		## Encrypts / Decrypts text, using one of the most useless ciphers in 
		## existence. Popular on newsgroups, for some obscure reason.
		if ( my ($rot13) = $command =~ /^ROT13 (.+)/i ) {
			$rot13 =~ tr[a-zA-Z][n-za-mN-ZA-M];
			$kernel->post( bot => privmsg => $echoLocation, $rot13 );
			goto _DONE;
		}
	}
	
	
	
	###################
	# Normal Commands #
	###################
	
	if ( $control >= 0 ) {
		
		if ( ( $module{'Active'}{'Profile'} eq 1 ) && ( $command =~ /^PROFILE (.+)/i ) ) {
			$module{'Profile'}{'Arguments'} = $1;
			$module{'Profile'}{'Called'} = 1;
			goto _DONE;
		}
		
		if ( ( $module{'Active'}{'Contention'} eq 1 ) && ( $command =~ /^CONTENTION (.+)/i ) && ( $channel eq $module{'Contention'}{'Channel'} ) ) {
			if ( ( $module{'User Settings'}{'Data'}->get_entry_setting("$nick",'Contention_LEVEL',0) > 0 ) || ( $1 =~ /^INSTALL$/i ) ) {
				$module{'Contention'}{'Arguments'} = "PLAYER::$1";;
			} else {
				$kernel->post( bot => privmsg => $module{'Contention'}{'Channel'}, " [!] Your account does not support \cC5 Contention\x0F, you need to fix this. Try installing the game. " );
			}
		}
		
	}
	
	
	
	#########################
	# Unrestricted Commands #
	#########################
	
	if ( $control >= -1 ) {
		
		## Generic, no topic.
		if ( $command =~ /^HELP$/i ) {
			$kernel->post( bot => privmsg => $echoLocation, " [?] Syntax is HELP <TOPIC> " );
			$kernel->post( bot => privmsg => $echoLocation, " [?] Topics include PROFILE, CONTENTION, CONTROL, and CONFIG." );
			goto _DONE;
		}
		
		## Specific, with topic.
		if ( $command =~ /^HELP (.+)/i ) {
			$module{'Help'}{'Called'} = 1;
			$module{'Help'}{'Arguments'} = $1;
		}
		
		## Displays the access level of the nick calling it.
		if ( ( $command =~ /^INFO$/i ) || ( $command =~ /^INFO (.+)/i ) ) {
			my $info_target = $nick;
			
			if ( $msg =~ /^[!\.]INFO$/i ) {
				$kernel->post( bot => privmsg => $echoLocation, "[?] $nick (Rank $control)" );
			}
			
			if ( ( $1 =~ /-p/i ) || ( $1 =~ /--privs/i ) ) {
				$kernel->post( bot => privmsg => $echoLocation, "[?] $nick (Rank $control)" );
				my $commandList;
				for (my $iCounter = 0; (($iCounter <= $control) && ($iCounter <= (@commands - 1))); $iCounter++) {
					$commandList .= $commands[$iCounter];
				}
				if ( $control >= 0 ) { $kernel->post( bot => privmsg => $echoLocation, "[?] Allowed Commands: $commandList" ); }
			}
			
			if ( ( $1 =~ /-g$/i ) || ( $1 =~ /--games$/i ) || ( $1 =~ /--games-user (.+)/i ) ) {
				if ( $msg =~ /--games-user (.+)/i ) { $info_target = $1; }
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

########################################
## Contention Module by Chris Olstrom ##
## v0.4.8-5
if ( ( $module{'Active'}{'Contention'} == 1 ) && ( $module{'Contention'}{'Arguments'} ne '' ) ) {
	my ($called_by,$action) = split /::/,$module{'Contention'}{'Arguments'},2;
	
	if ( $module{'Contention'}{'Last Action'} ne $nick ) {
		if ( ( $action =~ /^ATTACK/i ) || ( $action =~ /^CAST/i ) || ( $action =~ /^REST/i ) ) {
			$module{'Contention'}{'Last Action'} = $nick;
		}
	} elsif ( ( $called_by =~ /^GM$/i ) || ( $action =~ /^CONSIDER/i ) || ( $action =~ /^TOGGLE$/i ) || ( $action =~ /^SPEND EXPERIENCE/i ) ) {
	} else {
		$kernel->post( bot => privmsg => $module{'Contention'}{'Channel'}, " [G] You were the last person to act, give someone else a turn." );
		$action = 'NULL';
	}

	
	## Installs Contention support in the profile for current user.
	if ( $action =~ /^INSTALL$/i ) {
		if ( $module{'User Settings'}{'Data'}->get_entry_setting("$nick",'Contention_LEVEL',0) == 0 ) {
			$module{'User Settings'}{'Data'}->set_entry_setting("$nick",'Contention_ENABLED',1);
			$module{'User Settings'}{'Data'}->set_entry_setting("$nick",'Contention_LEVEL',1);
			$module{'User Settings'}{'Data'}->set_entry_setting("$nick",'Contention_EXP',0);
			$module{'User Settings'}{'Data'}->set_entry_setting("$nick",'Contention_PATK',1);
			$module{'User Settings'}{'Data'}->set_entry_setting("$nick",'Contention_PDEF',1);
			$module{'User Settings'}{'Data'}->set_entry_setting("$nick",'Contention_MATK',0);
			$module{'User Settings'}{'Data'}->set_entry_setting("$nick",'Contention_MDEF',0);
			$module{'User Settings'}{'Data'}->set_entry_setting("$nick",'Contention_HP_CURR',50);
			$module{'User Settings'}{'Data'}->set_entry_setting("$nick",'Contention_HP_MAX',50);
			$module{'User Settings'}{'Data'}->set_entry_setting("$nick",'Contention_MP_CURR',0);
			$module{'User Settings'}{'Data'}->set_entry_setting("$nick",'Contention_MP_MAX',0);
			$kernel->post( bot => privmsg => $module{'Contention'}{'Channel'}, " [M]\cC5 Contention\x0F support added to your account. " );
		} else {
			$kernel->post( bot => privmsg => $module{'Contention'}{'Channel'}, " [!!] FLAGRANT ERROR MESSAGE." );
			$kernel->post( bot => privmsg => $module{'Contention'}{'Channel'}, " [!M]\cC5 Contention\x0F already installed. " );
		}
	}
	
	if ( $action =~ /^TOGGLE$/i ) {
		if ( $module{'User Settings'}{'Data'}->get_entry_setting("$nick",'Contention_ENABLED',0) == 0 ) {
			$module{'User Settings'}{'Data'}->set_entry_setting("$nick",'Contention_ENABLED',1);
			$kernel->post( bot => privmsg => $module{'Contention'}{'Channel'}, " [!G] $nick has enabled\cC5 Contention,\x0F they are now able to attack, and be attacked. " );
		} else {
			$module{'User Settings'}{'Data'}->set_entry_setting("$nick",'Contention_ENABLED',0);
			$kernel->post( bot => privmsg => $module{'Contention'}{'Channel'}, " [!G] $nick has disabled\cC5 Contention,\x0F they cannot attack, or be attacked. " );
		}
	}
	
	if ( $action =~ /^REST$/i ) {
		my $restore_hp_amount	= 0;
		my $restore_mp_amount	= 0;
		my $hp_curr		= $module{'User Settings'}{'Data'}->get_entry_setting("$nick",'Contention_HP_CURR',0);
		my $hp_max		= $module{'User Settings'}{'Data'}->get_entry_setting("$nick",'Contention_HP_MAX',0);
		my $mp_curr		= $module{'User Settings'}{'Data'}->get_entry_setting("$nick",'Contention_MP_CURR',0);
		my $mp_max		= $module{'User Settings'}{'Data'}->get_entry_setting("$nick",'Contention_MP_MAX',0);
		my $mres		= $module{'User Settings'}{'Data'}->get_entry_setting("$nick",'Contention_MRES',0);
		
		if ( ( $hp_curr ne $hp_max) || ( $mp_curr ne $mp_max ) ) {
			my $rest_report = " [G] $nick spends some time resting, and restores... ";
			
			if ( $hp_curr ne $hp_max ) {
				if ( rand(1) == 0 ) {
					$restore_hp_amount = 3;
				} else {
					$restore_hp_amount = int(rand(5) +1);
				}
				
				$hp_curr += $restore_hp_amount;
				
				if ( $hp_curr > $hp_max ) {
					$hp_curr = $hp_max;
				}
				
				$module{'User Settings'}{'Data'}->set_entry_setting("$nick",'Contention_HP_CURR',$hp_curr);
				$rest_report .= "\cC9 +$restore_hp_amount HP [$hp_curr/$hp_max]\x0F ";
			}

			if ( $mp_curr ne $mp_max ) {
				$restore_mp_amount = int(rand($mres) +1);
					
				$mp_curr += $restore_mp_amount;
				
				if ( $mp_curr > $mp_max ) {
					$mp_curr = $mp_max;
				}
				
				$module{'User Settings'}{'Data'}->set_entry_setting("$nick",'Contention_MP_CURR',$mp_curr);
				$rest_report .= "\cC11 +$restore_mp_amount MP [$mp_curr/$mp_max]\x0F ";
			}
			
			$kernel->post( bot => privmsg => $module{'Contention'}{'Channel'}, $rest_report );
		} else {
			$kernel->post( bot => privmsg => $module{'Contention'}{'Channel'}, " [G] $nick is already at\cC9 full HP/MP\x0F!" );
			$module{'Contention'}{'Last Action'} = '';
		}
	}
	
	if ( ( $action =~ /^ATTACK (.+)/i ) || ( $action =~ /^CAST (.+)/i ) ) {
		my $attacker = $nick;
		my $defender;
		my $null;
		if ( $action =~ /^ATTACK (.+)/i ) { $defender = $1; }
		if ( $action =~ /^CAST (.+)/i ) { ($null,$defender) = split / /, $1,2; }
		
		my $is_ready = 0;
		my $is_able = $module{'User Settings'}{'Data'}->get_entry_setting("$attacker",'Contention_ENABLED',0);
		my $is_willing = $module{'User Settings'}{'Data'}->get_entry_setting("$defender",'Contention_ENABLED',0);
		
		if ( $is_able == 0 ) {
			$kernel->post( bot => privmsg => $module{'Contention'}{'Channel'}, " [!G] Your account does not have\cC5 Contention\x0F installed, or it has been disabled. " );
			$module{'Contention'}{'Last Action'} = '';
		} else {
			if ( $is_willing == 0 ) {
				$kernel->post( bot => privmsg => $module{'Contention'}{'Channel'}, " [!G] $defender does not have\cC5 Contention\x0F installed, or has it disabled. " );
				$module{'Contention'}{'Last Action'} = '';
			} else {
				if ( ( $attacker eq $defender ) && ( $action =~ /^ATTACK/i ) ) {
					$kernel->post( bot => privmsg => $module{'Contention'}{'Channel'}, " [G] You may not attack yourself. " );
					$module{'Contention'}{'Last Action'} = '';
				} else {
					$is_ready = 1;
				}
			}
		}
		
		if ( $is_ready == 1 ) {
			my $a_name	= "\cC4$attacker\x0F";
			my $a_level	= $module{'User Settings'}{'Data'}->get_entry_setting("$attacker",'Contention_LEVEL',1);
			my $a_exp	= $module{'User Settings'}{'Data'}->get_entry_setting("$attacker",'Contention_EXP',0);
			my $a_cash	= $module{'User Settings'}{'Data'}->get_entry_setting("$attacker",'Contention_CASH',0);
			my $a_patk	= $module{'User Settings'}{'Data'}->get_entry_setting("$attacker",'Contention_PATK',1);
			my $a_pdef	= $module{'User Settings'}{'Data'}->get_entry_setting("$attacker",'Contention_PDEF',1);
			my $a_mpow	= $module{'User Settings'}{'Data'}->get_entry_setting("$attacker",'Contention_MPOW',1);
			my $a_mres	= $module{'User Settings'}{'Data'}->get_entry_setting("$attacker",'Contention_MRES',1);
			my $a_hp_curr	= $module{'User Settings'}{'Data'}->get_entry_setting("$attacker",'Contention_HP_CURR',50);
			my $a_hp_max	= $module{'User Settings'}{'Data'}->get_entry_setting("$attacker",'Contention_HP_MAX',50);
			my $a_mp_curr	= $module{'User Settings'}{'Data'}->get_entry_setting("$attacker",'Contention_MP_CURR',0);
			my $a_mp_max	= $module{'User Settings'}{'Data'}->get_entry_setting("$attacker",'Contention_MP_MAX',0);
			
			my $d_name	= "\cC12$defender\x0F";
			my $d_level	= $module{'User Settings'}{'Data'}->get_entry_setting("$defender",'Contention_LEVEL',1);
			my $d_exp	= $module{'User Settings'}{'Data'}->get_entry_setting("$defender",'Contention_EXP',0);
			my $d_cash	= $module{'User Settings'}{'Data'}->get_entry_setting("$defender",'Contention_CASH',0);
			my $d_patk	= $module{'User Settings'}{'Data'}->get_entry_setting("$defender",'Contention_PATK',1);
			my $d_pdef	= $module{'User Settings'}{'Data'}->get_entry_setting("$defender",'Contention_PDEF',1);
			my $d_mpow	= $module{'User Settings'}{'Data'}->get_entry_setting("$defender",'Contention_MPOW',1);
			my $d_mres	= $module{'User Settings'}{'Data'}->get_entry_setting("$defender",'Contention_MRES',1);
			my $d_hp_curr	= $module{'User Settings'}{'Data'}->get_entry_setting("$defender",'Contention_HP_CURR',50);
			my $d_hp_max	= $module{'User Settings'}{'Data'}->get_entry_setting("$defender",'Contention_HP_MAX',50);
			my $d_mp_curr	= $module{'User Settings'}{'Data'}->get_entry_setting("$defender",'Contention_MP_CURR',0);
			my $d_mp_max	= $module{'User Settings'}{'Data'}->get_entry_setting("$defender",'Contention_MP_MAX',0);
			
			if ( $action =~ /^ATTACK (.+)/i ) {
				my $a_aroll	= int(rand($a_level + $a_patk +10)); if ( $a_aroll < $a_patk ) { $a_aroll = $a_patk; }
				my $a_droll	= int(rand($a_level + $a_pdef +10)); if ( $a_droll < $a_pdef ) { $a_droll = $a_pdef; }
				
				my $d_aroll	= int(rand($d_level + $d_patk +10)); if ( $d_aroll < $d_patk ) { $d_aroll = $d_patk; }
				my $d_droll	= int(rand($d_level + $d_pdef +10)); if ( $d_aroll < $d_pdef ) { $d_aroll = $d_pdef; }
				
				my $roll_data	= "\cC4 $a_aroll/$a_droll\x0F vs\cC12 $d_aroll/$d_droll\x0F";
				
				if ( $defender eq $CONFIG_NICK ) { $module{'Contention'}{'Last Action'} = ''; }
				
				if ( $a_aroll > $d_droll ) {
					my $damage = $a_aroll - $d_droll; $d_hp_curr = $d_hp_curr - $damage;
					$kernel->post( bot => privmsg => $module{'Contention'}{'Channel'}, "[G]$roll_data | $a_name strikes $d_name, dealing $damage points of damage. $d_name has\cC12 [$d_hp_curr/$d_hp_max]\x0F remaining." );
					if ( $d_hp_curr <= 0 ) { 
						my $rewardExp = int( $d_level / $a_level * 25 * $a_level );
						if ( $rewardExp < 1 ) { $rewardExp = 1; }
						my $totalExp = $a_exp + $rewardExp;
						my $rewardCash = int ( rand( 100 ) ); $a_cash += $rewardCash;
						$module{'User Settings'}{'Data'}->set_entry_setting("$attacker",'Contention_EXP',$totalExp);
						$module{'User Settings'}{'Data'}->set_entry_setting("$attacker",'Contention_CASH',$a_cash);
						$kernel->post( bot => privmsg => $module{'Contention'}{'Channel'}, " [G] $a_name defeats $d_name in battle, gaining\cC13 $rewardExp Experience Points\x0F. $a_name has been awarded $rewardCash Shiny Stones." );
						
						if ( $totalExp > ( $a_level * 500 * 1.5 ) ) {
							$kernel->post( bot => privmsg => $module{'Contention'}{'Channel'}, " [G] $a_name has passed the experience threshold, forcing level gain..." );
							$nick = $attacker; $action = 'SPEND EXPERIENCE LEVEL';
						}
						
						my $exp_penalty = int ( $rewardExp / 4 );
						my $totalExp_Remaining = $d_exp - $exp_penalty;
						if ( $totalExp_Remaining < 0 ) { $totalExp_Remaining = 0; }
						$module{'User Settings'}{'Data'}->set_entry_setting("$defender",'Contention_EXP',$totalExp_Remaining);
						$kernel->post( bot => privmsg => $module{'Contention'}{'Channel'}, " [G] $d_name is defeated in combat, and loses \cC13 $exp_penalty Experience Points\x0F." );
						
						$a_hp_curr = $a_hp_max; $a_mp_curr = $a_mp_max;
						$kernel->post( bot => privmsg => $module{'Contention'}{'Channel'}, " [G] $a_name has been restored to\cC9 full HP/MP\x0F\!" );
						$d_hp_curr = $d_hp_max; $d_mp_curr = $d_mp_max;
						$kernel->post( bot => privmsg => $module{'Contention'}{'Channel'}, " [G] $d_name has been restored to\cC9 full HP/MP\x0F\!" );
					}
				} elsif ( ( $a_aroll < $d_droll ) && ( $defender ne $CONFIG_NICK ) ) {
					$kernel->post( bot => privmsg => $module{'Contention'}{'Channel'}, " [G]$roll_data | $d_name evades $a_name\'s strike. " );
				} else {
					if ( $d_aroll > $a_droll ) {
						my $damage = $d_aroll - $a_droll; $a_hp_curr = $a_hp_curr - $damage;
						$kernel->post( bot => privmsg => $module{'Contention'}{'Channel'}, " [G]$roll_data | $d_name dodges, and counterattacks $a_name, dealing $damage points of damage. $a_name has\cC4 [$a_hp_curr/$a_hp_max]\x0F HP remaining." );
						if ( $a_hp_curr <= 0 ) { 
							my $rewardExp = int( ( $a_level / $d_level ) * 25 * $d_level );
							if ( $rewardExp < 1 ) { $rewardExp = 1; }
							my $totalExp = $d_exp + $rewardExp;
							my $rewardCash = int ( rand( ($a_level/$d_level) * 100 ) ); $d_cash += $rewardCash;
							$module{'User Settings'}{'Data'}->set_entry_setting("$defender",'Contention_EXP',$totalExp);
							$module{'User Settings'}{'Data'}->set_entry_setting("$defender",'Contention_CASH',$d_cash);
							$kernel->post( bot => privmsg => $module{'Contention'}{'Channel'}, " [G] $d_name defeats $a_name in battle, gaining\cC11 $rewardExp Experience Points\x0F. $d_name has been awarded $rewardCash Shiny Stones!" );
							
							if ( $totalExp > ( $d_level * 500 * 1.5 ) ) {
								$kernel->post( bot => privmsg => $module{'Contention'}{'Channel'}, " [G] $d_name has passed the experience threshold, forcing level gain..." );
								$nick = $defender; $action = 'SPEND EXPERIENCE LEVEL';
							}
							
							my $exp_penalty = int ( $rewardExp / 4 );
							my $totalExp_Remaining = $a_exp - $exp_penalty;
							if ( $totalExp_Remaining < 0 ) { $totalExp_Remaining = 0; }
							$module{'User Settings'}{'Data'}->set_entry_setting("$attacker",'Contention_EXP',$totalExp_Remaining);
							$kernel->post( bot => privmsg => $module{'Contention'}{'Channel'}, " [G] $a_name is defeated in combat, and loses \cC13 $exp_penalty Experience Points\x0F." );
							
							$a_hp_curr = $a_hp_max; $a_mp_curr = $a_mp_max;
							$kernel->post( bot => privmsg => $module{'Contention'}{'Channel'}, " [G] $a_name has been restored to\cC9 full HP/MP\x0F\!" );
							$d_hp_curr = $d_hp_max; $d_mp_curr = $d_mp_max;
							$kernel->post( bot => privmsg => $module{'Contention'}{'Channel'}, " [G] $d_name has been restored to\cC9 full HP/MP\x0F!" );
						}
					} elsif ( $d_aroll < $a_droll ) {
						$kernel->post( bot => privmsg => $module{'Contention'}{'Channel'}, " [G]$roll_data | $d_name evades, and attempts to counter $a_name, but fails. " );
					} else {
						$kernel->post( bot => privmsg => $module{'Contention'}{'Channel'}, " [G]$roll_data | $a_name and $d_name lose track of each other for one round. No damage dealt, none taken. " );
					}
				}
				
				$module{'User Settings'}{'Data'}->set_entry_setting("$attacker",'Contention_HP_CURR',$a_hp_curr);
				$module{'User Settings'}{'Data'}->set_entry_setting("$defender",'Contention_HP_CURR',$d_hp_curr);
				$module{'User Settings'}{'Data'}->set_entry_setting("$attacker",'Contention_MP_CURR',$a_mp_curr);
				$module{'User Settings'}{'Data'}->set_entry_setting("$defender",'Contention_MP_CURR',$d_mp_curr);
			}
			
			if ( $action =~ /^CAST (.+)/i ) {
				if ( $a_mpow > 0 ) { 
					## Get collection of known spells.
					my $grimoire = $module{'User Settings'}{'Data'}->get_entry_setting("$attacker",'Contention_GRIMOIRE',0);
					
					## Determine spell being cast, and target.
					my ( $spell, $target ) = split / /,$1, 2;
					
					my $target_hp_curr = $module{'User Settings'}{'Data'}->get_entry_setting("$target",'Contention_HP_CURR',0);
					my $target_mp_curr = $module{'User Settings'}{'Data'}->get_entry_setting("$target",'Contention_MP_CURR',0);
					my $target_hp_max = $module{'User Settings'}{'Data'}->get_entry_setting("$target",'Contention_HP_MAX',0);
					my $target_mp_max = $module{'User Settings'}{'Data'}->get_entry_setting("$target",'Contention_MP_MAX',0);
					
					## Is the spell being cast, known?
					if ( $grimoire =~ /$spell/i ) { 
						if ( $spell =~ /^HEAL$/i ) {
							my $required_mp = ( $a_mpow );
							my $restore_hp_amount = int(rand( $a_level + $a_mpow ) *2); if ( $restore_hp_amount < $a_mpow ) { $restore_hp_amount = $a_mpow; }
							if ( $a_mp_curr >= $required_mp ) {
								$a_mp_curr	-= $required_mp;
								$target_hp_curr	+= $restore_hp_amount;
								if ( $target_hp_curr > $target_hp_max ) { $target_hp_curr = $target_hp_max; }
								$module{'User Settings'}{'Data'}->set_entry_setting("$target",'Contention_HP_CURR',$target_hp_curr);
								$kernel->post( bot => privmsg => $module{'Contention'}{'Channel'}, " [G] ** $a_name says a few words, and performs some elaborate gestures. A wave of relaxation rushes over $target, and they regain\cC9 $restore_hp_amount HP\x0F\!" );
							} else {
								$kernel->post( bot => privmsg => $module{'Contention'}{'Channel'}, " [!G] You do not have enough MP to do that. " );
								$module{'Contention'}{'Last Action'} = '';
							}
						}
					} else {
						$kernel->post( bot => privmsg => $module{'Contention'}{'Channel'}, " [!G] You do not know that spell. " );
						$module{'Contention'}{'Last Action'} = '';
					}					
					$module{'User Settings'}{'Data'}->set_entry_setting("$attacker",'Contention_MP_CURR',$a_mp_curr);
				} else {
					$kernel->post( bot => privmsg => $module{'Contention'}{'Channel'}, " [!G] You do not know magic. " );
					$module{'Contention'}{'Last Action'} = '';
				}
			}
		}
	}
	
	if ( $action =~ /^SPEND EXPERIENCE (.+)$/i ) {
		my $choice	= $1;
		my $player_level	= $module{'User Settings'}{'Data'}->get_entry_setting("$nick",'Contention_LEVEL',1);
		my $player_hp_max	= $module{'User Settings'}{'Data'}->get_entry_setting("$nick",'Contention_HP_MAX',1);
		my $player_mp_max	= $module{'User Settings'}{'Data'}->get_entry_setting("$nick",'Contention_MP_MAX',0);
		my $player_exp		= $module{'User Settings'}{'Data'}->get_entry_setting("$nick",'Contention_EXP',0);
		my $player_patk		= $module{'User Settings'}{'Data'}->get_entry_setting("$nick",'Contention_PATK',1);
		my $player_pdef		= $module{'User Settings'}{'Data'}->get_entry_setting("$nick",'Contention_PDEF',1);
		my $player_mpow		= $module{'User Settings'}{'Data'}->get_entry_setting("$nick",'Contention_MPOW',0);
		my $player_mres		= $module{'User Settings'}{'Data'}->get_entry_setting("$nick",'Contention_MRES',0);
		my $player_grimoire	= $module{'User Settings'}{'Data'}->get_entry_setting("$nick",'Contention_GRIMOIRE','');
		my $required_exp	= 0;
		my $levelup_hp		= 0;
		my $levelup_mp		= 0;
		my $stat_name		= '';
		
		if ( $choice =~ /^PATK$/i ) { $required_exp = ( $player_patk * 100 ); $stat_name = 'Physical Attack'; }
		elsif ( $choice =~ /^PDEF$/i ) { $required_exp = ( $player_pdef * 100 ); $stat_name = 'Physical Defense'; }
		elsif ( ( $player_mpow > 0 ) && ( ( $choice =~ /^MPOW$/i ) || ( $choice =~ /^MRES$/i ) ) ) {
			if ( $choice =~ /^MPOW$/i ) { $required_exp = ( $player_mpow * 100 ); $stat_name = 'Magical Power'; }
			if ( $choice =~ /^MRES$/i ) { $required_exp = ( $player_mres * 100 ); $stat_name = 'Magic Resistance'; }
		} elsif ( ( $choice =~ /^MPOW$/i ) || ( $choice =~ /^MRES$/i ) ) {
				$kernel->post( bot => privmsg => $module{'Contention'}{'Channel'}, " [!] You do not know magic. " );
		}
		elsif ( $choice =~ /^LEVEL$/i ) { $required_exp = ( $player_level * 500 ); $stat_name = 'Level'; }
		elsif ( $choice =~ /^MAGIC$/i ) { $required_exp = ( $player_level * 500 ); $stat_name = 'Magic'; }
		elsif ( $choice =~ /^SPELL HEAL$/i ) { $required_exp = ( $player_level * 150 ); $stat_name = 'Heal'; }
		
		# Fix for attempting to learn magic at MPOW/RES 0.
		if ( $required_exp < 0 ) { $required_exp = 9999999999999999; }
		
		if ( ( $player_exp >= $required_exp ) && ( $stat_name ne '' ) ) {
			if ( $choice =~ /^PATK$/i ) { $player_patk += 1; }
			if ( $choice =~ /^PDEF$/i ) { $player_pdef += 1; }
			if ( $player_mpow > 0 ) { 
				if ( $choice =~ /^MPOW$/i ) { $player_mpow += 1; }
				if ( $choice =~ /^MRES$/i ) { $player_mres += 1; }
			} else {
				$kernel->post( bot => privmsg => $module{'Contention'}{'Channel'}, " [!] You do not know magic. " );
			}
			if ( $choice =~ /^MAGIC$/i ) {
				if ( $player_mpow < 1 ) {
					$player_mpow += 1;
					$player_mres += 1;
					$player_mp_max += 5;
				} else {
					$kernel->post( bot => privmsg => $module{'Contention'}{'Channel'}, " [!] You already know magic. " );
				}
			}
			if ( $choice =~ /^LEVEL$/i ) { $player_level += 1;
				$levelup_hp = ( int(rand(10) + 5) + $player_level ); $player_hp_max += $levelup_hp;
				if ( $player_mpow > 0 ) { $levelup_mp = ( int(rand(5) + $player_mres) + $player_level ); $player_mp_max += $levelup_mp; }
			}
			
			$player_exp -= $required_exp;
			
			if ( ( $choice =~ /^MAGIC$/i ) || ( $choice =~ /^SPELL (.+)/i ) ) {
				if ( ( $1 =~ /^HEAL$/i ) && ( $player_grimoire =~ /HEAL/i ) ) {
					$module{'User Settings'}{'Data'}->set_entry_setting("$nick",'Contention_GRIMOIRE',"$player_grimoire HEAL");
				}
				$kernel->post( bot => privmsg => $module{'Contention'}{'Channel'}, " [G] $nick has consumed $required_exp\ experience, and learned $stat_name\! " );
			} else {
				$kernel->post( bot => privmsg => $module{'Contention'}{'Channel'}, " [G] $nick has consumed $required_exp\ experience, and increased their $stat_name\! " );
			}
			
			if ( $choice =~ /^LEVEL$/i ) {
				$kernel->post( bot => privmsg => $module{'Contention'}{'Channel'}, " [G] $nick has gained $levelup_hp\! " );
				if ( $player_mpow > 0 ) {
					$kernel->post( bot => privmsg => $module{'Contention'}{'Channel'}, " [G] $nick has gained $levelup_mp\! " );
				}
			}
		} else {
			if ( $stat_name ne '' ) {
				$kernel->post( bot => privmsg => $module{'Contention'}{'Channel'}, " [!] You do not have enough Experience to do that. " );
			}
		}
		
		$module{'User Settings'}{'Data'}->set_entry_setting("$nick",'Contention_LEVEL',$player_level);
		$module{'User Settings'}{'Data'}->set_entry_setting("$nick",'Contention_EXP',$player_exp);
		$module{'User Settings'}{'Data'}->set_entry_setting("$nick",'Contention_PATK',$player_patk);
		$module{'User Settings'}{'Data'}->set_entry_setting("$nick",'Contention_PDEF',$player_pdef);
		$module{'User Settings'}{'Data'}->set_entry_setting("$nick",'Contention_MPOW',$player_mpow);
		$module{'User Settings'}{'Data'}->set_entry_setting("$nick",'Contention_MRES',$player_mres);
		$module{'User Settings'}{'Data'}->set_entry_setting("$nick",'Contention_HP_MAX',$player_hp_max);
		$module{'User Settings'}{'Data'}->set_entry_setting("$nick",'Contention_MP_MAX',$player_mp_max);
	}
	
	if ( $action =~ /CONSIDER (.+)/i ) {
		my $target = $1;
		
		if ( $module{'User Settings'}{'Data'}->get_entry_setting("$target",'Contention_LEVEL',0) >= 1 ) {
			my $enabled	= $module{'User Settings'}{'Data'}->get_entry_setting("$target",'Contention_ENABLED',0);
			my $level	= $module{'User Settings'}{'Data'}->get_entry_setting("$target",'Contention_LEVEL',0);
			my $exp		= $module{'User Settings'}{'Data'}->get_entry_setting("$target",'Contention_EXP',0);
			my $patk	= $module{'User Settings'}{'Data'}->get_entry_setting("$target",'Contention_PATK',0);
			my $pdef	= $module{'User Settings'}{'Data'}->get_entry_setting("$target",'Contention_PDEF',0);
			my $hp_curr	= $module{'User Settings'}{'Data'}->get_entry_setting("$target",'Contention_HP_CURR',0);
			my $hp_max	= $module{'User Settings'}{'Data'}->get_entry_setting("$target",'Contention_HP_MAX',0);
			my $mpow	= $module{'User Settings'}{'Data'}->get_entry_setting("$target",'Contention_MPOW',0);
			my $mres	= $module{'User Settings'}{'Data'}->get_entry_setting("$target",'Contention_MRES',0);
			my $mp_curr	= $module{'User Settings'}{'Data'}->get_entry_setting("$target",'Contention_MP_CURR',0);
			my $mp_max	= $module{'User Settings'}{'Data'}->get_entry_setting("$target",'Contention_MP_MAX',0);
			my $cash	= $module{'User Settings'}{'Data'}->get_entry_setting("$target",'Contention_CASH',0);
			
			$kernel->post( bot => privmsg => $echoLocation, "[?] $target" );
			$kernel->post( bot => privmsg => $echoLocation, "[?] +------------------------+" );
			$kernel->post( bot => privmsg => $echoLocation, "[?] | Level (Experience): $level ($exp)" );
			$kernel->post( bot => privmsg => $echoLocation, "[?] | HP(Max): $hp_curr($hp_max) | Physical ATK/DEF: $patk / $pdef" );
			
			if ( $mpow > 0 ) {
			$kernel->post( bot => privmsg => $echoLocation, "[?] | MP(Max): $mp_curr($mp_max) | Magical POW/RES: $mpow / $mres" );
			} else {
			$kernel->post( bot => privmsg => $echoLocation, "[?] | Does not know magic." );
			}
			
			$kernel->post( bot => privmsg => $echoLocation, "[?] | Has $cash Shiny Stones." );
			$kernel->post( bot => privmsg => $echoLocation, "[?] +------------------------+ ");
		} else { 
			$kernel->post( bot => privmsg => $echoLocation, "[?] $target does not play\cC5 Contention\x0F\." );
		}
	}
	
	if ( $called_by eq 'GM' ) {
		if ( $action =~ /^RESTORE (.+)/i ) {
			my $restore_target = $1;
			my $restore_hp_amount = $module{'User Settings'}{'Data'}->get_entry_setting("$restore_target",'Contention_HP_MAX',0);
			my $restore_mp_amount = $module{'User Settings'}{'Data'}->get_entry_setting("$restore_target",'Contention_MP_MAX',0);
			if ( $restore_hp_amount ne 0 ) {
				$module{'User Settings'}{'Data'}->set_entry_setting("$restore_target",'Contention_HP_CURR',$restore_hp_amount);
				$module{'User Settings'}{'Data'}->set_entry_setting("$restore_target",'Contention_MP_CURR',$restore_mp_amount);
				$kernel->post( bot => privmsg => $module{'Contention'}{'Channel'}, " [G] $restore_target has been restored to\cC9 full HP/MP\x0F!" );
			}
		}
		if ( $action =~ /^NEW ROUND$/i ) {
			$module{'Contention'}{'Last Action'} = '';
			$kernel->post( bot => privmsg => $module{'Contention'}{'Channel'}, " [G] A new round begins, all may act again. " );
		}
	}
		
	
	## Make sure it saves.
	$module{'Profile'}{'Called'} = 99; # Call the profile module, but don't trigger an event.
	$module{'Profile'}{'Save'} = 1;

	## Cleanup
	$module{'Contention'}{'Called'} = 0;
	$module{'Contention'}{'Arguments'} = '';
}

#####################################
## Profile Module by Chris Olstrom ##
if ( ( $module{'Active'}{'Profile'} == 1 ) && ( $module{'Profile'}{'Called'} > 0 ) ) {
	if ( $module{'Profile'}{'Called'} == 1 ) {
		## Displays the profile for the user specified. Has a known bug that causes it 
		## to spew errors to console. Doesn't crash, just errors. This happens if 
		## someone attempts to view a nonexistant profile element.
		if ( $module{'Profile'}{'Arguments'} =~ /^VIEW (.+)/i ) {
			
			if ( $1 =~ /^QUOTE (.+)/i ) {
				my $quote = $module{'User Settings'}{'Data'}->get_entry_setting("$1",'Profile_Quote','Quote not set');
				$kernel->post( bot => privmsg => $echoLocation, " [*] Quote for $1: $quote " );
			} elsif ( $1 =~ /^DESCRIPTION (.+)/i ) {
				my $description = $module{'User Settings'}{'Data'}->get_entry_setting("$1",'Profile_Description','Description not set.');
				$kernel->post( bot => privmsg => $echoLocation, " [*] $1 is best described as: $description " );
			} elsif ( $1 =~ /^WEBSITE (.+)/i ) {
				my $website = $module{'User Settings'}{'Data'}->get_entry_setting("$1",'Profile_Website','Website not set.');
				$kernel->post( bot => privmsg => $echoLocation, " [*] You can find $1\'s website here: $website " );
			} elsif ( $1 =~ /^EMAIL (.+)/i ) {
				my $email = $module{'User Settings'}{'Data'}->get_entry_setting("$1",'Profile_Email','Email not set.');
				$kernel->post( bot => privmsg => $echoLocation, " [*] You can email $1 at $email " );
			} elsif ( $1 =~ /^MSN (.+)/i ) {
				my $im_msn = $module{'User Settings'}{'Data'}->get_entry_setting("$1",'Profile_MSN','MSN not set.');
				$kernel->post( bot => privmsg => $echoLocation, " [*] MSN Account for $1: $im_msn " );
			} elsif ( $1 =~ /^AIM (.+)/i ) {
				my $im_aim = $module{'User Settings'}{'Data'}->get_entry_setting("$1",'Profile_AIM','AIM not set.');
				$kernel->post( bot => privmsg => $echoLocation, " [*] AIM Account for $1: $im_aim " );
			} elsif ( $1 =~ /^ICQ (.+)/i ) {
				my $im_icq = $module{'User Settings'}{'Data'}->get_entry_setting("$1",'Profile_ICQ','ICQ not set.');
				$kernel->post( bot => privmsg => $echoLocation, " [*] ICQ Account for $1: $im_icq " );
			} elsif ( $1 =~ /^YAHOO (.+)/i ) {
				my $im_yahoo = $module{'User Settings'}{'Data'}->get_entry_setting("$1",'Profile_YAHOO','YAHOO not set.');
				$kernel->post( bot => privmsg => $echoLocation, " [*] Yahoo Account for $1: $im_yahoo " );
			} if ( $1 =~ /^MAIN (.+)/i ) {
				my $main_nick = $module{'User Settings'}{'Data'}->get_entry_setting("$1",'Profile_Main','');
				$kernel->post( bot => privmsg => $echoLocation, " [*] $1 has declared their primary nick as: $main_nick " );
			}
		}
		
		## Sets the profile for the user calling it to whatever they specify.
		if ( $module{'Profile'}{'Arguments'} =~ /^SET (.+)/i ) {
			if ( $1 =~ /^QUOTE (.+)/i ) {
				$module{'User Settings'}{'Data'}->set_entry_setting("$nick",'Profile_Quote',"$1");
				my $quote = $module{'User Settings'}{'Data'}->get_entry_setting("$nick",'Profile_Quote','Quote not set');
				$kernel->post( bot => privmsg => $echoLocation, " [*] Quote for $nick set to: $quote " );
			} elsif ( $1 =~ /^DESCRIPTION (.+)/i ) {
				$module{'User Settings'}{'Data'}->set_entry_setting("$nick",'Profile_Description',"$1");
				my $description = $module{'User Settings'}{'Data'}->get_entry_setting("$nick",'Profile_Description','Description not set.');
				$kernel->post( bot => privmsg => $echoLocation, " [*] Description for $nick set to: $description " );
			} elsif ( $1 =~ /^WEBSITE (.+)/i ) {
				$module{'User Settings'}{'Data'}->set_entry_setting("$nick",'Profile_Website',"$1");
				my $website = $module{'User Settings'}{'Data'}->get_entry_setting("$nick",'Profile_Website','Website not set.');
				$kernel->post( bot => privmsg => $echoLocation, " [*] Website for $nick set to: $website " );
			} elsif ( $1 =~ /^EMAIL (.+)/i ) {
				$module{'User Settings'}{'Data'}->set_entry_setting("$nick",'Profile_Email',"$1");
				my $email = $module{'User Settings'}{'Data'}->get_entry_setting("$nick",'Profile_Email','Email not set.');
				$kernel->post( bot => privmsg => $echoLocation, " [*] Email for $nick set to: $email " );
			} elsif ( $1 =~ /^MSN (.+)/i ) {
				$module{'User Settings'}{'Data'}->set_entry_setting("$nick",'Profile_MSN',"$1");
				my $im_msn = $module{'User Settings'}{'Data'}->get_entry_setting("$nick",'Profile_MSN','MSN not set.');
				$kernel->post( bot => privmsg => $echoLocation, " [*] MSN Account for $nick set to: $im_msn " );
			} elsif ( $1 =~ /^AIM (.+)/i ) {
				$module{'User Settings'}{'Data'}->set_entry_setting("$nick",'Profile_AIM',"$1");
				my $im_aim = $module{'User Settings'}{'Data'}->get_entry_setting("$nick",'Profile_AIM','AIM not set.');
				$kernel->post( bot => privmsg => $echoLocation, " [*] AIM Account for $nick set to: $im_aim " );
			} elsif ( $1 =~ /^ICQ (.+)/i ) {
				$module{'User Settings'}{'Data'}->set_entry_setting("$nick",'Profile_ICQ',"$1");
				my $im_icq = $module{'User Settings'}{'Data'}->get_entry_setting("$nick",'Profile_ICQ','ICQ not set.');
				$kernel->post( bot => privmsg => $echoLocation, " [*] ICQ Account for $nick set to: $im_icq " );
			} elsif ( $1 =~ /^YAHOO (.+)/i ) {
				$module{'User Settings'}{'Data'}->set_entry_setting("$nick",'Profile_YAHOO',"$1");
				my $im_yahoo = $module{'User Settings'}{'Data'}->get_entry_setting("$nick",'Profile_YAHOO','Yahoo not set.');
				$kernel->post( bot => privmsg => $echoLocation, " [*] Yahoo Account for $nick set to: $im_yahoo " );
			} if ( $1 =~ /^MAIN (.+)/i ) {
				$module{'User Settings'}{'Data'}->set_entry_setting("$nick",'Profile_Main',"$1");
				my $main_nick = $module{'User Settings'}{'Data'}->get_entry_setting("$nick",'Profile_Main','');
				$kernel->post( bot => privmsg => $echoLocation, " [*] $nick declares their primary nick as: $main_nick " );
			}
			$module{'Profile'}{'Save'} = 1;
		}
	}

	## Saves user settings to a file.
	if ( $module{'Profile'}{'Save'} eq 1 ) {
		open (users, ">$module{'User Settings'}{'File'}") || die ("Could not open file. $!");
			print users "$module{'User Settings'}{'Data'}";
		close (users);
		if ( $msg =~ /^[!|\.]/i ) {
			$kernel->post( bot => privmsg => "$CONFIG_NICK", " [*] User settings saved to $module{'User Settings'}{'File'}. " );
		}
		$module{'Profile'}{'Save'} = 0;
	}
_CONTENTION_CLEANUP:	
	## Cleanup
	$module{'Profile'}{'Arguments'}	= '';
	$module{'Profile'}{'Called'}	= 0;
}

##################################
## Help Module by Chris Olstrom ##
if ( ( $module{'Active'}{'Help'} == 1 ) && ( $module{'Help'}{'Arguments'} ne '' ) ) {
	if ( $module{'Help'}{'Arguments'} =~ /^PROFILE$/i ) {
		$kernel->post( bot => privmsg => $echoLocation, "[?] PROFILE Commands (Level 0)" );
		$kernel->post( bot => privmsg => $echoLocation, "[?] This help document can be found at\cC12 http://colstrom.whatthefork.org/software/perl/enbot/documentation/readme-profile.txt\x0F " );
	}
	
	if ( $module{'Help'}{'Arguments'} =~ /^CONTENTION$/i ) {
		$kernel->post( bot => privmsg => $echoLocation, "[?] CONTENTION Commands (Level 0)" );
		$kernel->post( bot => privmsg => $echoLocation, "[?] This help document can be found at\cC12 http://colstrom.whatthefork.org/software/perl/enbot/documentation/readme-contention.txt\x0F " ); 		}
	
	if ( $module{'Help'}{'Arguments'} =~ /^CONTROL$/i ) {
		$kernel->post( bot => privmsg => $echoLocation, "[?] CONTROL Commands (Level 4): ACL_RELOAD, PROFILE_LOAD, STATS_REGEN" );
		$kernel->post( bot => privmsg => $echoLocation, "[?] USERS_LOAD: Loads settings for all users from $module{'User Settings'}{'File'}" );
		$kernel->post( bot => privmsg => $echoLocation, "[?] USERS_SAVE: Saves settings for all users to $module{'User Settings'}{'File'}" );
		$kernel->post( bot => privmsg => $echoLocation, "[?] ACL_RELOAD: Reloads the Access Control Lists" );
		$kernel->post( bot => privmsg => $echoLocation, "[?] STATS_REGEN: Regenerates the Statistics Page" );
	}
	
	if ( $module{'Help'}{'Arguments'} = /^COMMANDS$/i ) {
		$kernel->post( bot => privmsg => $echoLocation, " [?] Commands are issued either in-channel, or via private message (/msg)." );
		$kernel->post( bot => privmsg => $echoLocation, " [?] All commands must be prefixed with a response identifier, either ! (public) or . (private). " );
		$kernel->post( bot => privmsg => $echoLocation, " [?] For a list of commands you can use, type !INFO or .INFO " );
	}
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

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

my @CONFIG_CHANNEL;
	$CONFIG_CHANNEL[0] = '#en';
	$CONFIG_CHANNEL[1] = '#enBot';
	$CONFIG_CHANNEL[2] = '#enGames';

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

########################
# Module Configuration #
########################

my %module = ();
	
	$module{'Active'}{'Access Control'} = 1;
		$module{'Access Control'}{'File'}	= 'settings-acl.ini';
		$module{'Access Control'}{'Data'}	= new Config::Abstract::Ini("$module{'Access Control'}{'File'}");
	
	$module{'Active'}{'Help'} = 1;
		$module{'Help'}{'Called'}		= 0;
		$module{'Help'}{'Arguments'}		= '';
		
	$module{'Active'}{'User Settings'} = 1;
		$module{'User Settings'}{'File'}	= 'settings-user.ini';
		$module{'User Settings'}{'Data'} = new Config::Abstract::Ini($module{'User Settings'}{'File'});
	
	$module{'Active'}{'Profile'} = 1;
		$module{'Profile'}{'Called'}		= 0;
		$module{'Profile'}{'Read'}		= '';
		$module{'Profile'}{'Write'}		= '';
		
	$module{'Active'}{'Contention'} = 1;
		$module{'Contention'}{'Called'}		= 0;
		$module{'Contention'}{'Arguments'}	= '';
		$module{'Contention'}{'Channel'}	= '#enGames';
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
	if ( $channel eq $CONFIG_CHANNEL[0] ) {
		print "[$timestamp] <$nick> $msg\n"; # Log to screen
	}
	
	################
	# Access Check #
	################
	## Parses the access control list for nick, and if it finds a match, assigns 
	## a control level, which is used to detemine which commands can be used.
	
	my $control = -1;
	
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
		
	}
	
	
	
	######################
	# SuperOper Commands #
	######################
	
	if ( $control >= 4 ) {
		if ( ( $module{'Active'}{'Contention'} eq 1 ) && ( $channel eq $module{'Contention'}{'Channel'} ) &&( $command =~ /^CONTENTION (.+)/i ) ) {
			if ( $1 =~ /^RESTORE (.+)/i ) {
				$module{'Contention'}{'Arguments'} = $1;
				$module{'Contention'}{'Called'} = 1001;
				goto _DONE;
			}
			
			if ( $1 =~ /^NEW ROUND$/i ) {
				$module{'Contention'}{'Called'} = 1002;
				goto _DONE;
			}
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
			
			if ( $1 =~ /^VIEW (.+)/i ) {
				$module{'Profile'}{'Called'} = 1;
				$module{'Profile'}{'Read'} = $1;
				goto _DONE;
			}
			
			if ( $1 =~ /^SET (.+)/i ) {
				$module{'Profile'}{'Called'} = 2;
				$module{'Profile'}{'Write'} = $1;
				goto _DONE;
			}
			
		}
		
		if ( ( $module{'Active'}{'Contention'} eq 1 ) && ( $channel eq $module{'Contention'}{'Channel'} ) && ( $command =~ /^CONTENTION (.+)/i ) ) {
			if ( $1 =~ /^INSTALL$/i ) {
				$module{'Contention'}{'Called'} = 1;
				goto _DONE;
			}
			
			if ( $1 =~ /^TOGGLE$/i ) {
				$module{'Contention'}{'Called'} = 2;
				goto _DONE;
			}
			
			if ( $1 =~ /^REST$/i ) {
				if ( $module{'Contention'}{'Last Action'} ne $nick ) {
					$module{'Contention'}{'Last Action'} = $nick;
					$module{'Contention'}{'Called'} = 3;
				} else {
					$kernel->post( bot => privmsg => $module{'Contention'}{'Channel'}, " [G] You were the last person to act, give someone else a turn." );
				}
				goto _DONE;
			}
			
			if ( $1 =~ /^SPEND EXPERIENCE (.+)/i ) {
				$module{'Contention'}{'Arguments'} = $1;
				$module{'Contention'}{'Called'} = 4;
				goto _DONE;
			}
			
			if ( $1 =~ /^ATTACK (.+)/i ) {
				if ( $module{'Contention'}{'Last Action'} ne $nick ) {
					$module{'Contention'}{'Last Action'} = $nick;
					$module{'Contention'}{'Arguments'} = $1;
					$module{'Contention'}{'Called'} = 5;
				} else {
					$kernel->post( bot => privmsg => $module{'Contention'}{'Channel'}, " [G] You were the last person to act, give someone else a turn." );
				}
				goto _DONE;
			}
			
			if ( $1 =~ /^CAST (.+)/i ) {
				if ( $module{'Contention'}{'Last Action'} ne $nick ) {
					$module{'Contention'}{'Last Action'} = $nick;
					$module{'Contention'}{'Arguments'} = $1;
					$module{'Contention'}{'Called'} = 6;
				} else {
					$kernel->post( bot => privmsg => $module{'Contention'}{'Channel'}, " [G] You were the last person to act, give someone else a turn." );
				}
				goto _DONE;
			}
			
			if ( $1 =~ /^CONSIDER (.+)/i ) {
				$module{'Contention'}{'Called'} = 7;
				$module{'Contention'}{'Arguments'} = $1
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
## v0.4.2-5
if ( ( $module{'Active'}{'Contention'} == 1 ) && ( $module{'Contention'}{'Called'} > 0 ) ) {
	
	## Installs Contention support in the profile for current user.
	if ( $module{'Contention'}{'Called'} == 1 ) {
		my $is_installed = $module{'User Settings'}{'Data'}->get_entry_setting("$nick",'Contention_LEVEL',0);
		if ( $is_installed == 0 ) {
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
	
	if ( $module{'Contention'}{'Called'} == 2 ) {
		if ( $module{'User Settings'}{'Data'}->get_entry_setting("$nick",'Contention_ENABLED',0) == 0 ) {
			$module{'User Settings'}{'Data'}->set_entry_setting("$nick",'Contention_ENABLED',1);
			$kernel->post( bot => privmsg => $module{'Contention'}{'Channel'}, " [!G] $nick has enabled\cC5 Contention,\x0F they are now able to attack, and be attacked. " );
		} else {
			$module{'User Settings'}{'Data'}->set_entry_setting("$nick",'Contention_ENABLED',0);
			$kernel->post( bot => privmsg => $module{'Contention'}{'Channel'}, " [!G] $nick has disabled\cC5 Contention,\x0F they cannot attack, or be attacked. " );
		}
	}
	
	if ( $module{'Contention'}{'Called'} == 3 ) {
		my $restore_hp_amount = 0;
		my $hp_curr = $module{'User Settings'}{'Data'}->get_entry_setting("$nick",'Contention_HP_CURR',0);
		my $hp_max = $module{'User Settings'}{'Data'}->get_entry_setting("$nick",'Contention_HP_MAX',0);
		
		if ( $hp_curr ne $hp_max ) {
			if ( rand(1) == 0 ) {
				$restore_hp_amount = 3;
			} else {
				$restore_hp_amount = int(rand(4) +1);
			}
			$hp_curr += $restore_hp_amount;
			if ( $hp_curr > $hp_max ) { $hp_curr = $hp_max }
				$module{'User Settings'}{'Data'}->set_entry_setting("$nick",'Contention_HP_CURR',$hp_curr);
				$kernel->post( bot => privmsg => $module{'Contention'}{'Channel'}, " [G] $nick spends some time resting, and restores\cC9 +$restore_hp_amount HP\x0F!" );
		} else {
			$kernel->post( bot => privmsg => $module{'Contention'}{'Channel'}, " [G] $nick is already at\cC9 full HP\x0F!" );
			$module{'Contention'}{'Last Action'} = '';
		}
	}
	
	if ( $module{'Contention'}{'Called'} == 4 ) {
		my $choice	= $module{'Contention'}{'Arguments'};
		my $level	= $module{'User Settings'}{'Data'}->get_entry_setting("$nick",'Contention_LEVEL',1);
		my $hp_max	= $module{'User Settings'}{'Data'}->get_entry_setting("$nick",'Contention_HP_MAX',1);
		my $exp		= $module{'User Settings'}{'Data'}->get_entry_setting("$nick",'Contention_EXP',0);
		my $patk	= $module{'User Settings'}{'Data'}->get_entry_setting("$nick",'Contention_PATK',1);
		my $pdef	= $module{'User Settings'}{'Data'}->get_entry_setting("$nick",'Contention_PDEF',1);
		
		if ( $choice =~ /^PATK$/i ) {
			my $required_exp = ( $patk * 100 );
			if ( $exp >= $required_exp ) {
				$patk = $patk + 1;
				$exp = $exp - $required_exp;
				$kernel->post( bot => privmsg => $module{'Contention'}{'Channel'}, " [G] $nick has increased their Physical Attack to $patk\! " );
			} else {
				$kernel->post( bot => privmsg => $module{'Contention'}{'Channel'}, " [!G] You do not have enough Experience to do that. " );
			}
		}
		
		if ( $choice =~ /^PDEF$/i ) {
			my $required_exp =  ( $pdef * 100 );
			if ( $exp >= $required_exp ) {
				$pdef = $pdef + 1;
				$exp = $exp - $required_exp;
				$kernel->post( bot => privmsg => $module{'Contention'}{'Channel'}, " [G] $nick has increased their Physical Defense to $pdef\! " );
			} else {
				$kernel->post( bot => privmsg => $module{'Contention'}{'Channel'}, " [!G] You do not have enough Experience to do that. " );
			}
		}
		
		if ( $choice =~ /^LEVEL$/i ) {
			my $required_exp = ( $level * 1000 );
			if ( $exp >= $required_exp ) {
				$level = $level + 1;
				$exp = $exp - $required_exp;
				my $hp_gain = rand(10) +5;
				$hp_max = $hp_max + $hp_gain;
				$kernel->post( bot => privmsg => $module{'Contention'}{'Channel'}, " [G] $nick has increased their Level to $level\! " );
				$kernel->post( bot => privmsg => $module{'Contention'}{'Channel'}, " [G] $nick has gained $hp_gain HP! " );
			} else {
				$kernel->post( bot => privmsg => $module{'Contention'}{'Channel'}, " [!G] You do not have enough Experience to do that. " );
			}
		}
		
		$module{'User Settings'}{'Data'}->set_entry_setting("$nick",'Contention_LEVEL',$level);
		$module{'User Settings'}{'Data'}->set_entry_setting("$nick",'Contention_EXP',$exp);
		$module{'User Settings'}{'Data'}->set_entry_setting("$nick",'Contention_PATK',$patk);
		$module{'User Settings'}{'Data'}->set_entry_setting("$nick",'Contention_PDEF',$pdef);
		$module{'User Settings'}{'Data'}->set_entry_setting("$nick",'Contention_HP_MAX',$hp_max);

	}
	
	if ( ( $module{'Contention'}{'Called'} == 5 ) || ( $module{'Contention'}{'Called'} == 6 ) ) {
		my $attacker = $nick;
		my $defender; my $null;
		if ( $module{'Contention'}{'Called'} == 5 ) { $defender = $module{'Contention'}{'Arguments'}; }
		if ( $module{'Contention'}{'Called'} == 6 ) { ($null,$defender) = split / /, $module{'Contention'}{'Arguments'},2; }
		
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
				if ( ( $attacker eq $defender ) && ( $module{'Contention'}{'Called'} ne 6 ) ) {
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
			my $a_patk	= $module{'User Settings'}{'Data'}->get_entry_setting("$attacker",'Contention_PATK',1);
			my $a_pdef	= $module{'User Settings'}{'Data'}->get_entry_setting("$attacker",'Contention_PDEF',1);
			my $a_matk	= $module{'User Settings'}{'Data'}->get_entry_setting("$attacker",'Contention_MATK',1);
			my $a_mdef	= $module{'User Settings'}{'Data'}->get_entry_setting("$attacker",'Contention_MDEF',1);
			my $a_hp_curr	= $module{'User Settings'}{'Data'}->get_entry_setting("$attacker",'Contention_HP_CURR',50);
			my $a_hp_max	= $module{'User Settings'}{'Data'}->get_entry_setting("$attacker",'Contention_HP_MAX',50);
			my $a_mp_curr	= $module{'User Settings'}{'Data'}->get_entry_setting("$attacker",'Contention_MP_CURR',0);
			my $a_mp_max	= $module{'User Settings'}{'Data'}->get_entry_setting("$attacker",'Contention_MP_MAX',0);
			
			my $d_name	= "\cC12$defender\x0F";
			my $d_level	= $module{'User Settings'}{'Data'}->get_entry_setting("$defender",'Contention_LEVEL',1);
			my $d_exp	= $module{'User Settings'}{'Data'}->get_entry_setting("$defender",'Contention_EXP',0);
			my $d_patk	= $module{'User Settings'}{'Data'}->get_entry_setting("$defender",'Contention_PATK',1);
			my $d_pdef	= $module{'User Settings'}{'Data'}->get_entry_setting("$defender",'Contention_PDEF',1);
			my $d_matk	= $module{'User Settings'}{'Data'}->get_entry_setting("$defender",'Contention_MATK',1);
			my $d_mdef	= $module{'User Settings'}{'Data'}->get_entry_setting("$defender",'Contention_MDEF',1);
			my $d_hp_curr	= $module{'User Settings'}{'Data'}->get_entry_setting("$defender",'Contention_HP_CURR',50);
			my $d_hp_max	= $module{'User Settings'}{'Data'}->get_entry_setting("$defender",'Contention_HP_MAX',50);
			my $d_mp_curr	= $module{'User Settings'}{'Data'}->get_entry_setting("$defender",'Contention_MP_CURR',0);
			my $d_mp_max	= $module{'User Settings'}{'Data'}->get_entry_setting("$defender",'Contention_MP_MAX',0);
			
			if ( $module{'Contention'}{'Called'} == 5 ) {
				my $a_aroll	= int(rand($a_level * $a_patk +10));
				my $a_droll	= int(rand($a_level * $a_pdef +10));
				
				my $d_aroll	= int(rand($d_level * $d_patk +10));
				my $d_droll	= int(rand($d_level * $d_pdef +10));
				
				my $roll_data	= "\cC4 $a_aroll/$a_droll\x0F vs\cC12 $d_aroll/$d_droll\x0F";
				
				if ( $defender eq $CONFIG_NICK ) { $module{'Contention'}{'Last Action'} = ''; }
				
				if ( $a_aroll > $d_droll ) {
					my $damage = $a_aroll - $d_droll; $d_hp_curr = $d_hp_curr - $damage;
					$kernel->post( bot => privmsg => $module{'Contention'}{'Channel'}, "[G]$roll_data | $a_name strikes $d_name, dealing $damage points of damage. $d_name has\cC12 [$d_hp_curr/$d_hp_max]\x0F remaining." );
					if ( $d_hp_curr <= 0 ) { 
						my $rewardExp = int( ( $d_level / $a_level ) * 10 );
						if ( $rewardExp < 1 ) { $rewardExp = 1; }
						my $totalExp = $a_exp + $rewardExp;
						$module{'User Settings'}{'Data'}->set_entry_setting("$attacker",'Contention_EXP',$totalExp);
						$kernel->post( bot => privmsg => $module{'Contention'}{'Channel'}, " [G] $a_name defeats $d_name in battle, gaining\cC13 $rewardExp Experience Points\x0F. " );
						$a_hp_curr = $a_hp_max;
						$kernel->post( bot => privmsg => $module{'Contention'}{'Channel'}, " [G] $a_name has been restored to\cC9 full HP\x0F\!" );
						$d_hp_curr = $d_hp_max;
						$kernel->post( bot => privmsg => $module{'Contention'}{'Channel'}, " [G] $d_name has been restored to\cC9 full HP\x0F\!" );
					}
				} elsif ( ( $a_aroll < $d_droll ) && ( $defender ne $CONFIG_NICK ) ) {
					$kernel->post( bot => privmsg => $module{'Contention'}{'Channel'}, " [G]$roll_data | $d_name evades $a_name\'s strike. " );
				} else {
					if ( $d_aroll > $a_droll ) {
						my $damage = $d_aroll - $a_droll; $a_hp_curr = $a_hp_curr - $damage;
						$kernel->post( bot => privmsg => $module{'Contention'}{'Channel'}, " [G]$roll_data | $d_name dodges, and counterattacks $a_name, dealing $damage points of damage. $a_name has\cC4 [$a_hp_curr/$a_hp_max]\x0F HP remaining." );
						if ( $a_hp_curr <= 0 ) { 
							my $rewardExp = int( ( $a_level / $d_level ) * 10 );
							if ( $rewardExp < 1 ) { $rewardExp = 1; }
							my $totalExp = $d_exp + $rewardExp;
							$module{'User Settings'}{'Data'}->set_entry_setting("$defender",'Contention_EXP',$totalExp);
							$kernel->post( bot => privmsg => $module{'Contention'}{'Channel'}, " [G] $d_name defeats $a_name in battle, gaining\cC11 $rewardExp Experience Points\x0F. " );
							$a_hp_curr = $a_hp_max;
							$kernel->post( bot => privmsg => $module{'Contention'}{'Channel'}, " [G] $a_name has been restored to\cC9 full HP\x0F\!" );
							$d_hp_curr = $d_hp_max;
							$kernel->post( bot => privmsg => $module{'Contention'}{'Channel'}, " [G] $d_name has been restored to\cC9 full HP\x0F!" );
						}
					} elsif ( $d_aroll < $a_droll ) {
						$kernel->post( bot => privmsg => $module{'Contention'}{'Channel'}, " [G]$roll_data | $d_name evades, and attempts to counter $a_name, but fails. " );
					} else {
						$kernel->post( bot => privmsg => $module{'Contention'}{'Channel'}, " [G]$roll_data | $a_name and $d_name lose track of each other for one round. No damage dealt, none taken. " );
					}
				}
				
				$module{'User Settings'}{'Data'}->set_entry_setting("$attacker",'Contention_HP_CURR',$a_hp_curr);
				$module{'User Settings'}{'Data'}->set_entry_setting("$defender",'Contention_HP_CURR',$d_hp_curr);
			}
			
			if ( $module{'Contention'}{'Called'} == 6 ) {
				if ( $a_matk > 0 ) { 
					## Get collection of known spells.
					my $grimoire = $module{'User Settings'}{'Data'}->get_entry_setting("$attacker",'Contention_GRIMOIRE',0);
					
					## Determine spell being cast, and target.
					my ( $spell, $target ) = split / /, $module{'Contention'}{'Arguments'}, 2;
					
					my $target_hp_curr = $module{'User Settings'}{'Data'}->get_entry_setting("$target",'Contention_HP_CURR',0);
					my $target_mp_curr = $module{'User Settings'}{'Data'}->get_entry_setting("$target",'Contention_MP_CURR',0);
					my $target_hp_max = $module{'User Settings'}{'Data'}->get_entry_setting("$target",'Contention_HP_MAX',0);
					my $target_mp_max = $module{'User Settings'}{'Data'}->get_entry_setting("$target",'Contention_MP_MAX',0);
					
					## Is the spell being cast, known?
					if ( $grimoire =~ /$spell/i ) { 
						if ( $spell =~ /^CURE$/i ) {
							my $required_mp = ( $a_level * $a_matk );
							my $restore_hp_amount = int(rand( $a_level * $a_matk) *5);
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
	
	if ( $module{'Contention'}{'Called'} == 7 ) {
		my $target = $module{'Contention'}{'Arguments'};
		
		if ( $module{'User Settings'}{'Data'}->get_entry_setting("$target",'Contention_LEVEL',0) >= 1 ) {
			my $enabled	= $module{'User Settings'}{'Data'}->get_entry_setting("$target",'Contention_ENABLED',0);
			my $level	= $module{'User Settings'}{'Data'}->get_entry_setting("$target",'Contention_LEVEL',0);
			my $exp		= $module{'User Settings'}{'Data'}->get_entry_setting("$target",'Contention_EXP',0);
			my $patk	= $module{'User Settings'}{'Data'}->get_entry_setting("$target",'Contention_PATK',0);
			my $pdef	= $module{'User Settings'}{'Data'}->get_entry_setting("$target",'Contention_PDEF',0);
			my $hp_curr	= $module{'User Settings'}{'Data'}->get_entry_setting("$target",'Contention_HP_CURR',0);
			my $hp_max	= $module{'User Settings'}{'Data'}->get_entry_setting("$target",'Contention_HP_MAX',0);
			my $matk	= $module{'User Settings'}{'Data'}->get_entry_setting("$target",'Contention_MATK',0);
			my $mdef	= $module{'User Settings'}{'Data'}->get_entry_setting("$target",'Contention_MDEF',0);
			my $mp_curr	= $module{'User Settings'}{'Data'}->get_entry_setting("$target",'Contention_MP_CURR',0);
			my $mp_max	= $module{'User Settings'}{'Data'}->get_entry_setting("$target",'Contention_MP_MAX',0);
			
			$kernel->post( bot => privmsg => $echoLocation, "[?] $target" );
			$kernel->post( bot => privmsg => $echoLocation, "[?] +------------------------+" );
			$kernel->post( bot => privmsg => $echoLocation, "[?] | Level (Experience): $level ($exp)" );
			$kernel->post( bot => privmsg => $echoLocation, "[?] | HP(Max): $hp_curr($hp_max) | Physical ATK/DEF: $patk / $pdef" );
			
			if ( $matk > 0 ) {
			$kernel->post( bot => privmsg => $echoLocation, "[?] | MP(Max): $mp_curr($mp_max) | Magical ATK/DEF: $matk / $mdef" );
			} else {
			$kernel->post( bot => privmsg => $echoLocation, "[?] | Does not know magic." );
			}
			
			$kernel->post( bot => privmsg => $echoLocation, "[?] +------------------------+ ");
		} else { 
			$kernel->post( bot => privmsg => $echoLocation, "[?] $target does not play\cC5 Contention\x0F\." );
		}
	}
	
	if ( $module{'Contention'}{'Called'} >= 1000 ) {
		if ( $module{'Contention'}{'Called'} == 1001 ) {
			my $restore_target = $module{'Contention'}{'Arguments'};
			my $restore_hp_amount = $module{'User Settings'}{'Data'}->get_entry_setting("$restore_target",'Contention_HP_MAX',0);
			my $restore_mp_amount = $module{'User Settings'}{'Data'}->get_entry_setting("$restore_target",'Contention_MP_MAX',0);
			if ( $restore_hp_amount ne 0 ) {
				$module{'User Settings'}{'Data'}->set_entry_setting("$restore_target",'Contention_HP_CURR',$restore_hp_amount);
				$module{'User Settings'}{'Data'}->set_entry_setting("$restore_target",'Contention_MP_CURR',$restore_mp_amount);
				$kernel->post( bot => privmsg => $module{'Contention'}{'Channel'}, " [G] $restore_target has been restored to\cC9 full HP/MP\x0F!" );
			}
		}
		if ( $module{'Contention'}{'Called'} == 1002 ) {
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

##################################
## Help Module by Chris Olstrom ##
if ( ( $module{'Active'}{'Help'} == 1 ) && ( $module{'Help'}{'Called'} > 0 ) ) {
	if ( $module{'Help'}{'Called'} == 1 ) {

		if ( $module{'Help'}{'Arguments'} =~ /^PROFILE$/i ) {
			$kernel->post( bot => privmsg => $echoLocation, "[?] PROFILE Commands (Level 0): SET, VIEW" );
			$kernel->post( bot => privmsg => $echoLocation, "[?] SET <text>: Sets your profile to <text>" );
			$kernel->post( bot => privmsg => $echoLocation, "[?] VIEW <user>: Reads the profile of <user>" );
		}
		
		if ( $module{'Help'}{'Arguments'} =~ /^CONTENTION$/i ) {
			$kernel->post( bot => privmsg => $echoLocation, "[?] CONTENTION Commands (Level 0)" );
			$kernel->post( bot => privmsg => $echoLocation, "[?] The help entry for\cC5 Contention\x0F has become too large to display here. To view the complete help file for it, browse to\cC12 http://colstrom.whatthefork.org/software/perl/enbot/modules/readme-contention.txt\x0F " );
		}
		
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

################################################################
# modules/core.pm - Essential things for the bot, and modules. #
################################################################
#
# Copyright (C) 2004 Chris Olstrom
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Library General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
#
################################################################################
our %triggerIndex;

sub HandleMessage {
	my ($kernel,$moduleSettings,$kernel,$who,$where,$message) = @_;				# Assign data to named scalars.
	
																				# Thanks to xmath, from #perlhelp on EFnet, for this more efficient splitting.
	my ($nick, $hostmask) = split /!/, $who, 2;									# Seperate nick and hostmask.
	
	my $channel = $where->[0];													# Determine where the message is coming from.

																				# Thanks to cardioid, from #perlhelp on EFnet, for this more efficient timestamp generation.
	my $timestamp = sprintf("%02d:%02d", (localtime)[2,1]);						# Get time from local settings, and format it to be more readable.

	LogMessage($kernel,$moduleSettings,$channel,'console',"[$timestamp] <$nick> $message");	# Log the message, we mimic mIRC's format, so we can use utilities that act on mIRC logs with our logs! Compatibility++
	
	if ( $message =~ /^[!|\.](.+)/i ) {											# Is it a trigger?
		my $prefix = substr($message,1);										# Which control character?
		my ($trigger,$arguments) = split / /,$1,2;								# Seperate trigger and arguments.
		
		if ( exists $triggerIndex{$trigger} ) {
			$triggerIndex{$trigger}->($kernel,$moduleSettings,$channel,$nick,$arguments);
		}
	}
}

sub LogMessage {
	my($kernel,$moduleSettings,$logFrom,$logTo,$message) = @_;
	my $logChannels = $moduleSettings->get_entry_setting('Logging','Channels','');
	
	if ( $logFrom =~ /$logChannels/i ) {										# Are we supposed to be logging this channel?
		if ( $logTo eq 'console' ) {											# Log to console?
			print "$message\n";													# Log to console, for maximum flexibility. Allows total log manipulation by the user, should they so desire. I tend to run the bot with... 'run ./enbot.pl >> /home/username/log/enbot &'
		}
	}

	return 1;
}

sub Echo {
	my ($kernel,$location,$message) = @_;
	$kernel->post( bot => 'privmsg' => $location, $message );
}

return 1;

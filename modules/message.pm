##############################################################
# modules/message.pm - Figures out what to do with messages. #
##############################################################
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

sub HandleMessage {
	my ($kernel,$moduleSettings,$kernel,$who,$where,$messageBody) = @_;			# Assign data to named scalars.
	
																				# Thanks to xmath, from #perlhelp on EFnet, for this more efficient splitting.
	my ($nick, $hostmask) = split /!/, $who, 2;									# Seperate nick and hostmask.
	
	my $channel = $where->[0];													# Determine where the message is coming from.

																				# Thanks to cardioid, from #perlhelp on EFnet, for this more efficient timestamp generation.
	my $timestamp = sprintf("%02d:%02d", (localtime)[2,1]);						# Get time from local settings, and format it to be more readable.

	LogMessage($kernel,$moduleSettings,$channel,'screen',"[$timestamp] <$nick> $messageBody");	# Log the message, we mimic mIRC's format, so we can use utilities that act on mIRC logs with our logs! Compatibility++
	
	my $accessLevel = AccessCheck($kernel,$moduleSettings,$nick);				# Check the user's access.
	
	my $echoLocation = $nick;													# Define default method for command replies
	
	if ( $messageBody =~ /^[!|\.](.+)/i ) {										# Is it a trigger?
		my $triggerBody = $1;													# -_- I don't know why it needs this, but it is filled with hate without it.
		if ( ( $messageBody =~ /^!/ ) && ( $accessLevel >= 1 ) ) {				# Public response? Is the user allowed to?
			$echoLocation = $channel;											
		} elsif ( $messageBody =~ /^\./ ) {										# Private response?
			$echoLocation = $nick;												
		}
		HandleTrigger($kernel,$moduleSettings,$nick,$echoLocation,$triggerBody);# Pass it to the trigger module.
	}
	
}

return 1;

###############################################################
# modules/logging.pm - Dumps messages to various log formats. #
###############################################################
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

sub LogMessage {
	my($kernel,$moduleSettings,$logFrom,$logTo,$messageBody) = @_;
	my $logChannels = $moduleSettings->get_entry_setting('Logging','Channels','');
	
	if ( $logFrom =~ /$logChannels/i ) {										# Are we supposed to be logging this channel?
		if ( $logTo eq 'screen' ) {												# Log to screen?
			print "$messageBody\n";												## Log to console, for maximum flexibility. Allows total log manipulation by the user, should they so desire. I tend to run the bot with... 'run ./enbot.pl >> /home/username/log/enbot &'
		}
	}

	return 1;
}

return 1;

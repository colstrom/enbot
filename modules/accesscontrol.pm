########################################################################
# modules/accesscontrol.pm - Authenticates users and restricts access. #
########################################################################
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

sub AccessCheck {
	my($kernel,$moduleSettings,$nick) = @_;

	my $accessLevel = $moduleSettings->get_entry_setting('AccessControl','Default',-1);
	my $accessFile = $moduleSettings->get_entry_setting('AccessControl','File');
	my $accessLists = new Config::Abstract::Ini("$accessFile");

# Parse the access control list for nick, and if it finds a match, assigns 
# an access level, which is used to detemine which commands can be used.
	
	foreach my $acl ('Normal','Voice','HalfOp','Oper','SuperOp','Founder','Owner','Author','Banned') {
		if ( $accessLists->get_entry_setting("$acl",'List','') =~ /$nick/i ) {
			$accessLevel = $accessLists->get_entry_setting("$acl",'Level',0);
		}
	}
	
	return $accessLevel;
}

return 1;

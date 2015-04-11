# Writing modules for enBot #

Register any triggers your module uses with...
```
$triggerIndex{'triggername'} = \&subroutine_to_execute_on_trigger;
```
Write any subroutines you need. Syntax is almost entirely standard Perl, with a few requirements...

Now, the bot core is going to pass some data to your function.
  * $kernel - You'll need this to interact with the bot's core (mainly for echo)
  * $moduleSettings - config/modules.ini
  * $channel - The channel the command came from.
  * $nick - Who issued the command.
  * $arguments - Whatever parameters were passed along with the command.

Example:
```
sub name_of_subroutine {
	# Parse the data passed by the bot's core, and assign it to useful variables.
	my ($kernel,$moduleSettings,$channel,$nick,$arguments) = @_;

	# CODE
	# CODE
	# CODE

	# To make the bot say something, use...
	Echo($kernel,$where_to_send_to,$message);
	
	# To read settings from the modules.ini file...
	my $data = $moduleSettings->get_entry_setting('Section','Parameter','Default if not set');
	
}

# Without this, the module will not load.
return 1;
```
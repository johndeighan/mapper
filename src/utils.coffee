# utils.coffee

import {undef} from '@jdeighan/coffee-utils'

# ---------------------------------------------------------------------------

export stdSplitCommand = (line, level) ->

	if lMatches = line.match(///^
			\#
			([A-Za-z_]\w*)   # name of the command
			\s*
			(.*)             # argstr for command
			$///)
		[_, cmd, argstr] = lMatches
		return [cmd, argstr]
	else
		return undef      # not a command

# ---------------------------------------------------------------------------

export stdIsComment = (line, level) ->

	lMatches = line.match(///^
			(\#+)     # one or more # characters
			(.|$)     # following character, if any
			///)
	if lMatches
		[_, hashes, ch] = lMatches
		return (hashes.length > 1) || (ch in [' ','\t',''])
	else
		return false

# ---------------------------------------------------------------------------

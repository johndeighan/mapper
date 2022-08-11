# StoryMapper.coffee

import {undef, defined} from '@jdeighan/coffee-utils'
import {Mapper} from '@jdeighan/mapper'
import {TreeWalker} from '@jdeighan/mapper/tree'

# ---------------------------------------------------------------------------

export class StoryMapper extends TreeWalker

	mapNode: (hNode) ->

		if lMatches = hNode.str.match(///
				([A-Za-z_][A-Za-z0-9_]*)  # identifier
				\:                        # colon
				\s*                       # optional whitespace
				(.+)                      # a non-empty string
				$///)
			[_, ident, str] = lMatches

			if str.match(///
					\d+
					(?:
						\.
						\d*
						)?
					$///)
				return str
			else
				# --- surround with single quotes, double internal single quotes
				str = "'" + str.replace(/\'/g, "''") + "'"
				return "#{ident}: #{str}"
		else
			return hNode.str

# StoryMapper.coffee

import {undef, defined} from '@jdeighan/coffee-utils'

import {Mapper} from '@jdeighan/mapper'
import {TreeMapper} from '@jdeighan/mapper/tree'

# ---------------------------------------------------------------------------
#    Convert lines like:
#       key: <string>
#    to
#       key: '<string>'
#    while doubling internal single-quote characters
#    unless <string> is a number
# ---------------------------------------------------------------------------

export class StoryMapper extends TreeMapper

	mapNode: (hNode) ->

		if lMatches = hNode.str.match(///
				([A-Za-z_][A-Za-z0-9_]*)  # identifier
				\:                        # colon
				\s*                       # optional whitespace
				(.+)                      # a non-empty string
				$///)
			[_, key, value] = lMatches

			if value.match(///
					\d+
					(?:
						\.
						\d*
						)?
					$///)
				# --- don't mess with numbers
				return "#{key}: #{value}"
			else
				# --- surround with single quotes,
				#     double internal single quotes
				value = "'" + value.replace(/\'/g, "''") + "'"
				return "#{key}: #{value}"
		else
			return hNode.str

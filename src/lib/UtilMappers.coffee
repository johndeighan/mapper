# UtilMappers.coffee

import {undef, defined} from '@jdeighan/base-utils'
import {dbgEnter, dbgReturn, dbg} from '@jdeighan/base-utils/debug'

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

	getUserObj: (hNode) ->

		dbgEnter 'getUserObj', hNode
		if lMatches = hNode.str.match(///
				([A-Za-z_][A-Za-z0-9_]*)  # identifier
				\:                        # colon
				\s*                       # optional whitespace
				(.+)                      # a non-empty string
				$///)
			dbg "is <key>: <value>"
			[_, key, value] = lMatches
			dbg 'key', key
			dbg 'value', value

			if value.match(///
					\d+
					(?:
						\.
						\d*
						)?
					$///)
				# --- don't mess with numbers
				dbg "<value> is a number, return <key>: <value>"
				result = "#{key}: #{value}"
			else
				dbg "<value> is not a number"
				# --- surround with single quotes,
				#     double internal single quotes
				value = "'" + value.replace(/\'/g, "''") + "'"
				result = "#{key}: #{value}"
		else
			dbg "not <key>: <value>, return hNode.str"
			result = hNode.str
		dbgReturn 'getUserObj', result
		return result

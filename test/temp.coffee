# temp.coffee

import {say} from '@jdeighan/coffee-utils'
import {parsePLL} from '@jdeighan/string-input/pll'

say "Hi, there!"

contents = """
		development = yes
		if development
			color = red
			if usemoods
				mood = somber
		if not development
			color = blue
			if usemoods
				mood = happy
		"""

result = parsePLL(contents, (x) -> x)
say result, 'RESULT:'

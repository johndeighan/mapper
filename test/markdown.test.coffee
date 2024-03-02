# markdown.test.coffee

import {
	undef, nonEmpty, toBlock, toArray, CWS,
	} from '@jdeighan/base-utils'
import {assert, croak} from '@jdeighan/base-utils/exceptions'
import {LOG, LOGVALUE} from '@jdeighan/base-utils/log'
import {setDebugging} from '@jdeighan/base-utils/debug'
import {UnitTester, equal} from '@jdeighan/base-utils/utest'
import {mydir} from '@jdeighan/coffee-utils/fs'

import {markdownify} from '@jdeighan/mapper/markdown'

# ---------------------------------------------------------------------------

normalize = (block) =>

	lLines = toArray(block) \
		.filter((line) => nonEmpty(line)) \
		.map((line) => CWS(line))
	return toBlock(lLines)

block = """
	simple
		indented    more\t\t\t\twords

		blank
	"""

equal normalize(block), """
	simple
	indented more words
	blank
	"""

# ---------------------------------------------------------------------------

(() ->

	class MarkdownTester extends UnitTester

		transformValue: (text) ->

			return normalize(markdownify(text))

		transformExpected: (text) ->

			return normalize(text)

	mdTester = new MarkdownTester()

	# ..........................................................

	mdTester.equal """
			title
			=====
			text
			""", """
			<h1>title</h1>
			<p>text</p>
			"""

	mdTester.equal """
			title
			-----
			text
			""", """
			<h2>title</h2>
			<p>text</p>
			"""

	# --- Comments are stripped

	mdTester.equal """
			# title
			text
			""", """
			<p>text</p>
			"""

	mdTester.equal """
			# title
			text
			""", """
			<p>text</p>
			"""

	mdTester.equal """
		this is **bold** text
		""", """
		<p>this is <strong>bold</strong> text</p>
		"""

	mdTester.equal """
		```javascript
				adapter: adapter({
					pages: 'build',
					assets: 'build',
					fallback: null,
					})
		```
		""", """
		<pre><code class="language-javascript"> adapter: adapter(&lbrace;
		pages: 'build',
		assets: 'build',
		fallback: null,
		&rbrace;)
		</code></pre>
		"""

	)()

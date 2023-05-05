# markdown.test.coffee

import {undef} from '@jdeighan/base-utils'
import {assert, croak} from '@jdeighan/base-utils/exceptions'
import {LOG, LOGVALUE} from '@jdeighan/base-utils/log'
import {setDebugging} from '@jdeighan/base-utils/debug'
import {UnitTester, UnitTesterNorm} from '@jdeighan/unit-tester'
import {mydir} from '@jdeighan/coffee-utils/fs'

import {markdownify} from '@jdeighan/mapper/markdown'

# ---------------------------------------------------------------------------

(() ->

	class MarkdownTester extends UnitTesterNorm

		transformValue: (text) ->

			return markdownify(text)

	mdTester = new MarkdownTester()

	# ..........................................................

	mdTester.equal 26, """
			title
			=====
			text
			""", """
			<h1>title</h1>
			<p>text</p>
			"""

	mdTester.equal 35, """
			title
			-----
			text
			""", """
			<h2>title</h2>
			<p>text</p>
			"""

	# --- Comments are stripped

	mdTester.equal 46, """
			# title
			text
			""", """
			<p>text</p>
			"""

	mdTester.equal 53, """
			# title
			text
			""", """
			<p>text</p>
			"""

	mdTester.equal 60, """
		this is **bold** text
		""", """
		<p>this is <strong>bold</strong> text</p>
		"""

	mdTester.equal 66, """
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

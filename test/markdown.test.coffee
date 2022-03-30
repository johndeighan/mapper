# markdown.test.coffee

import {UnitTester} from '@jdeighan/unit-tester'
import {undef} from '@jdeighan/coffee-utils'
import {mydir} from '@jdeighan/coffee-utils/fs'
import {convertMarkdown, markdownify} from '@jdeighan/string-input/markdown'

simple = new UnitTester()

# ---------------------------------------------------------------------------

class MarkdownTester extends UnitTester

	transformValue: (text) ->

		return markdownify(text)

tester = new MarkdownTester()

# ---------------------------------------------------------------------------

(() ->

	tester.equal 24, """
			title
			=====
			text
			""", """
			<h1>title</h1>
			<p>text</p>
			"""

	tester.equal 33, """
			title
			-----
			text
			""", """
			<h2>title</h2>
			<p>text</p>
			"""

	# --- Comments and blank lines are stripped

	tester.equal 44, """
			# title
			text
			""", """
			<p>text</p>
			"""

	tester.equal 51, """
			## title
			text
			""", """
			<p>text</p>
			"""

	tester.equal 58, """
		this is **bold** text
		""", """
		<p>this is <strong>bold</strong> text</p>
		"""

	tester.equal 64, """
		```javascript
				adapter: adapter({
					pages: 'build',
					assets: 'build',
					fallback: null,
					})
		```
		""", """
		<pre><code class="language-javascript"> adapter: adapter(&lbrace;
		pages: &#39;build&#39;,
		assets: &#39;build&#39;,
		fallback: null,
		&rbrace;)
		</code></pre>
		"""

	convertMarkdown false

	tester.equal 83, """
			title
			=====
			text
			""", """
			title
			=====
			text
			"""
	)()

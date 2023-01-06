# markdown.test.coffee

import {undef} from '@jdeighan/base-utils'
import {assert, croak} from '@jdeighan/base-utils/exceptions'
import {LOG, LOGVALUE} from '@jdeighan/base-utils/log'
import {setDebugging} from '@jdeighan/base-utils/debug'
import {UnitTester, UnitTesterNorm} from '@jdeighan/unit-tester'
import {mydir} from '@jdeighan/coffee-utils/fs'

import {
	markdownify, SimpleMarkDownMapper,
	} from '@jdeighan/mapper/markdown'

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

	# --- Comments and blank lines are stripped

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
		pages: &#39;build&#39;,
		assets: &#39;build&#39;,
		fallback: null,
		&rbrace;)
		</code></pre>
		"""

	)()

# ---------------------------------------------------------------------------
# Test SimpleMarkDownMapper

(() ->

	class MarkdownTester extends UnitTester

		transformValue: (block) ->

			getter = new SimpleMarkDownMapper(block)
			return getter.getBlock()

	mdTester = new MarkdownTester()

	# ..........................................................

	mdTester.equal 101, """
		A title
		=======

		some text

		""", """
		<h1>A title</h1>
		<p>some text</p>
		"""

	mdTester.equal 112, """
		A title
		=======

		A subtitle
		----------

		some text

		""", """
		<h1>A title</h1>
		<h2>A subtitle</h2>
		<p>some text</p>
		"""

	mdTester.equal 127, """
		=======

		some text

		""", """
		<p>=======</p>
		<p>some text</p>
		"""

	mdTester.equal 137, """
		A title
		=======
		# this is a comment
		some text

		""", """
		<h1>A title</h1>
		<p>some text</p>
		"""

	)()

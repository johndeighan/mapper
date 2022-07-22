# markdown.test.coffee

import {UnitTester, UnitTesterNorm, simple} from '@jdeighan/unit-tester'
import {undef} from '@jdeighan/coffee-utils'
import {setDebugging} from '@jdeighan/coffee-utils/debug'
import {mydir} from '@jdeighan/coffee-utils/fs'
import {
	markdownify, SimpleMarkDownMapper,
	} from '@jdeighan/mapper/markdown'

# ---------------------------------------------------------------------------

(() ->

	class MarkdownTester extends UnitTesterNorm

		transformValue: (text) ->

			return markdownify(text)

	tester = new MarkdownTester()

	# ..........................................................

	tester.equal 26, """
			title
			=====
			text
			""", """
			<h1>title</h1>
			<p>text</p>
			"""

	tester.equal 35, """
			title
			-----
			text
			""", """
			<h2>title</h2>
			<p>text</p>
			"""

	# --- Comments and blank lines are stripped

	tester.equal 46, """
			# title
			text
			""", """
			<p>text</p>
			"""

	tester.equal 53, """
			# title
			text
			""", """
			<p>text</p>
			"""

	tester.equal 60, """
		this is **bold** text
		""", """
		<p>this is <strong>bold</strong> text</p>
		"""

	tester.equal 66, """
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

			getter = new SimpleMarkDownMapper(import.meta.url, block)
			return getter.getBlock()

	tester = new MarkdownTester()

	# ..........................................................

	tester.equal 112, """
		A title
		=======

		some text

		""", """
		<h1>A title</h1>
		<p>some text</p>
		"""

	tester.equal 125, """
		=======

		some text

		""", """
		<p>=======</p>
		<p>some text</p>
		"""

	tester.equal 133, """
		A title
		=======
		# this is a comment
		some text

		""", """
		<h1>A title</h1>
		<p>some text</p>
		"""

	)()

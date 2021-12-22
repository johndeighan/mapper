# markdown.test.coffee

import {undef} from '@jdeighan/coffee-utils'
import {mydir} from '@jdeighan/coffee-utils/fs'
import {UnitTester} from '@jdeighan/coffee-utils/test'
import {markdownify} from '@jdeighan/string-input/markdown'

root = process.env.DIR_ROOT = mydir(`import.meta.url`)
process.env.DIR_DATA = "#{root}/data
process.env.DIR_MARKDOWN = "#{root}/markdown
simple = new UnitTester()

# ---------------------------------------------------------------------------

class MarkdownTester extends UnitTester

	transformValue: (text) ->

		return markdownify(text)

tester = new MarkdownTester()

# ---------------------------------------------------------------------------

(() ->

	tester.equal 31, """
			title
			=====
			""", """
			<h1>title</h1>
			"""

	tester.equal 38, """
			title
			-----
			""", """
			<h2>title</h2>
			"""

	tester.equal 45, """
		this is **bold** text
		""", """
		<p>this is <strong>bold</strong> text</p>
		"""

	tester.equal 51, """
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

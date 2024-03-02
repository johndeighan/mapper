# FuncHereDoc.test.coffee

import {undef, isString, OL} from '@jdeighan/base-utils'
import {assert} from '@jdeighan/base-utils/exceptions'
import {UnitTester, equal} from '@jdeighan/base-utils/utest'
import {map} from '@jdeighan/mapper'
import {Fetcher} from '@jdeighan/mapper/fetcher'
import {TreeMapper} from '@jdeighan/mapper/tree'
import {mapHereDoc, replaceHereDocs} from '@jdeighan/mapper/heredoc'
import '@jdeighan/mapper/funcheredoc'

# ---------------------------------------------------------------------------

(() ->
	class HereDocTester extends UnitTester

		transformValue: (block) ->

			assert isString(block), "not a string: #{OL(block)}"
			return mapHereDoc(block)

	tester = new HereDocTester()

	# ------------------------------------------------------------------------

	tester.equal """
			() =>
				count += 1
			""",
			"`()=>count+=1`"

	# ------------------------------------------------------------------------
	# Function block, with no name or parameters

	tester.equal """
			() =>
				return true
			""",
			"`()=>!0`"

	# ------------------------------------------------------------------------
	# Function block, with no name but one parameter

	tester.equal """
			(evt) =>
				console.log evt.name
			""",
			"`o=>console.log(o.name)`"

	# ------------------------------------------------------------------------
	# Function block, with no name but one parameter

	tester.equal """
			(  evt  )     =>
				LOG evt.name
			""",
			"`a=>LOG(a.name)`"

	# ---------------------------------------------------------------------------

	tester.equal """
			(evt) =>
				LOG 'click'
			""",
			'`c=>LOG("click")`'

	)()

# ------------------------------------------------------------------------
# --- HEREDOC handling - function

(() ->
	fetcher = new Fetcher("""
			(event) =>
				event.preventDefault()
				alert 'clicked'
				return

			""")

	equal replaceHereDocs("on:click={<<<}", fetcher),
			'on:click={`e=>{e.preventDefault(),alert("clicked")}`}'

	)()

# ---------------------------------------------------------------------------

(() ->

	class CieloTester extends UnitTester

		transformValue: (content) ->

			assert isString(content), "not a string: #{OL(content)}"
			hSource = {content, source: 'cielo.test.js'}
			return map(hSource, TreeMapper)

	cieloTester = new CieloTester()

	# ..........................................................

	cieloTester.equal """
			handler = {<<<}
				() =>
					return 42
			""", """
			handler = {`()=>42`}
			"""

	cieloTester.equal """
			handler = {<<<}
				(x, y) =>
					return 42
			""", """
			handler = {`(a,b)=>42`}
			"""
	)()

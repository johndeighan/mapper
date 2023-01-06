# FuncHereDoc.test.coffee

import {undef} from '@jdeighan/base-utils'
import {utest, UnitTester} from '@jdeighan/unit-tester'
import {map} from '@jdeighan/mapper'
import {Fetcher} from '@jdeighan/mapper/fetcher'
import {TreeMapper} from '@jdeighan/mapper/tree'
import {mapHereDoc, replaceHereDocs} from '@jdeighan/mapper/heredoc'
import '@jdeighan/mapper/funcheredoc'

# ---------------------------------------------------------------------------

(() ->
	class HereDocTester extends UnitTester

		transformValue: (block) ->

			return mapHereDoc(block)

	tester = new HereDocTester()

	# ------------------------------------------------------------------------

	tester.equal 23, """
			() =>
				count += 1
			""",
			"`()=>count+=1`"

	# ------------------------------------------------------------------------
	# Function block, with no name or parameters

	tester.equal 32, """
			() =>
				return true
			""",
			"`()=>!0`"

	# ------------------------------------------------------------------------
	# Function block, with no name but one parameter

	tester.equal 41, """
			(evt) =>
				console.log evt.name
			""",
			"`o=>console.log(o.name)`"

	# ------------------------------------------------------------------------
	# Function block, with no name but one parameter

	tester.equal 50, """
			(  evt  )     =>
				LOG evt.name
			""",
			"`a=>LOG(a.name)`"

	# ---------------------------------------------------------------------------

	tester.equal 58, """
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

	utest.equal 79, replaceHereDocs("on:click={<<<}", fetcher),
			'on:click={`e=>{e.preventDefault(),alert("clicked")}`}'

	)()

# ---------------------------------------------------------------------------

(() ->

	class CieloTester extends UnitTester

		transformValue: (content) ->

			hSource = {content, source: 'cielo.test.js'}
			return map(hSource, TreeMapper)

	cieloTester = new CieloTester()

	# ..........................................................

	cieloTester.equal 93, """
			handler = {<<<}
				() =>
					return 42
			""", """
			handler = {`()=>42`}
			"""

	cieloTester.equal 101, """
			handler = {<<<}
				(x, y) =>
					return 42
			""", """
			handler = {`(a,b)=>42`}
			"""
	)()

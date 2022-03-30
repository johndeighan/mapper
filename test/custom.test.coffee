# custom.test.coffee

import {UnitTester, UnitTesterNoNorm} from '@jdeighan/unit-tester'
import {
	assert, undef, pass, isEmpty, isArray, isString, CWS,
	} from '@jdeighan/coffee-utils'
import {firstLine, remainingLines} from '@jdeighan/coffee-utils/block'
import {SmartInput} from '@jdeighan/string-input'
import {addHereDocType} from '@jdeighan/string-input/heredoc'

# ---------------------------------------------------------------------------

class SmartTester extends UnitTesterNoNorm

	transformValue: (block) ->
		oInput = new SmartInput(block)
		return oInput.getAllText()

tester = new SmartTester()

# ---------------------------------------------------------------------------
# --- test creating a custom HEREDOC section
#
#     e.g. with header line *** we'll create an upper-cased single line string

class UCHereDoc

	myName: () ->
		return 'upper case'

	isMyHereDoc: (block) ->
		return firstLine(block) == '***'

	map: (block) ->
		str = CWS(remainingLines(block).toUpperCase())
		return {
			str: JSON.stringify(str)
			obj: str
			}

addHereDocType new UCHereDoc()

# ---------------------------------------------------------------------------

tester.equal 45, """
		str = <<<
			***
			select ID,Name
			from Users

		""", """
		str = "SELECT ID,NAME FROM USERS"
		"""

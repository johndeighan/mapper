# MathML.test.coffee

import {UnitTesterNorm, UnitTester} from '@jdeighan/unit-tester'
import {assert, error, croak} from '@jdeighan/unit-tester/utils'
import {
	undef, pass, isEmpty, isArray, isString,
	} from '@jdeighan/coffee-utils'
import {setDebugging} from '@jdeighan/coffee-utils/debug'
import {mapMath} from '@jdeighan/mapper/math'

simple = new UnitTesterNorm()

# ---------------------------------------------------------------------------

class MathTester extends UnitTester

	transformValue: (str) ->
		assert isString(str), "MathTester: not a string"
		return mapMath(str)

tester = new MathTester()

# ---------------------------------------------------------------------------

tester.equal 25, 'expr X + 2', {
	cmd: 'expr'
	lAtoms: [
		{
			type: 'ident'
			value: 'X'
			}
		{
			type: 'op'
			value: '+'
			}
		{
			type: 'number'
			value: '2'
			}
		]
	}

tester.equal 43, 'sub', {
		cmd: 'sub'
		}

tester.equal 47, 'sup', {
		cmd: 'sup'
		}

tester.equal 51, 'frac', {
		cmd: 'frac'
		}

tester.equal 55, 'SIGMA', {
		cmd: 'SIGMA'
		lAtoms: [
			{
				type: 'op',
				value: '&#x03A3;',
				},
			]
		}

tester.equal 59, 'group', {
		cmd: 'group'
		lAtoms: [
			{type: 'op', value: '('}
			{type: 'op', value: ')'}
			]
		}

tester.equal 67, 'group {', {
		cmd: 'group'
		lAtoms: [
			{type: 'op', value: '{'}
			{type: 'op', value: '}'}
			]
		}

tester.equal 75, 'group { ]', {
		cmd: 'group'
		lAtoms: [
			{type: 'op', value: '{'}
			{type: 'op', value: ']'}
			]
		}

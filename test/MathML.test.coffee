# MathML.test.coffee

import {LOG, assert, croak, setDebugging} from '@jdeighan/exceptions'
import {UnitTesterNorm, UnitTester} from '@jdeighan/unit-tester'
import {
	undef, pass, isEmpty, isArray, isString,
	} from '@jdeighan/coffee-utils'

import {mapMath} from '@jdeighan/mapper/math'

# ---------------------------------------------------------------------------

class MathTester extends UnitTester

	transformValue: (str) ->
		assert isString(str), "MathTester: not a string"
		return mapMath(str)

mathTester = new MathTester()

# ---------------------------------------------------------------------------

mathTester.equal 25, 'expr X + 2', {
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

mathTester.equal 43, 'sub', {
		cmd: 'sub'
		}

mathTester.equal 47, 'sup', {
		cmd: 'sup'
		}

mathTester.equal 51, 'frac', {
		cmd: 'frac'
		}

mathTester.equal 55, 'SIGMA', {
		cmd: 'SIGMA'
		lAtoms: [
			{
				type: 'op',
				value: '&#x03A3;',
				},
			]
		}

mathTester.equal 59, 'group', {
		cmd: 'group'
		lAtoms: [
			{type: 'op', value: '('}
			{type: 'op', value: ')'}
			]
		}

mathTester.equal 67, 'group {', {
		cmd: 'group'
		lAtoms: [
			{type: 'op', value: '{'}
			{type: 'op', value: '}'}
			]
		}

mathTester.equal 75, 'group { ]', {
		cmd: 'group'
		lAtoms: [
			{type: 'op', value: '{'}
			{type: 'op', value: ']'}
			]
		}

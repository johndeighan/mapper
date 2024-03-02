# MathML.test.coffee

import {
	undef, pass, isEmpty, isArray, isString, OL,
	} from '@jdeighan/base-utils'
import {assert, croak} from '@jdeighan/base-utils/exceptions'
import {LOG} from '@jdeighan/base-utils/log'
import {setDebugging} from '@jdeighan/base-utils/debug'
import {UnitTester} from '@jdeighan/base-utils/utest'

import {mapMath} from '@jdeighan/mapper/mathml'

# ---------------------------------------------------------------------------

class MathTester extends UnitTester

	transformValue: (str) ->
		assert isString(str), "not a string: #{OL(str)}"
		return mapMath(str)

mathTester = new MathTester()

# ---------------------------------------------------------------------------

mathTester.equal 'expr X + 2', {
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

mathTester.equal 'sub', {
		cmd: 'sub'
		}

mathTester.equal 'sup', {
		cmd: 'sup'
		}

mathTester.equal 'frac', {
		cmd: 'frac'
		}

mathTester.equal 'SIGMA', {
		cmd: 'SIGMA'
		lAtoms: [
			{
				type: 'op',
				value: '&#x03A3;',
				},
			]
		}

mathTester.equal 'group', {
		cmd: 'group'
		lAtoms: [
			{type: 'op', value: '('}
			{type: 'op', value: ')'}
			]
		}

mathTester.equal 'group {', {
		cmd: 'group'
		lAtoms: [
			{type: 'op', value: '{'}
			{type: 'op', value: '}'}
			]
		}

mathTester.equal 'group { ]', {
		cmd: 'group'
		lAtoms: [
			{type: 'op', value: '{'}
			{type: 'op', value: ']'}
			]
		}

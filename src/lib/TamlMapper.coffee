# TamlMapper.coffee

import {
	undef, pass, defined, notdefined, isEmpty, nonEmpty, oneof, OL,
	isString, isArray, isHash,
	} from '@jdeighan/base-utils'
import {assert, croak} from '@jdeighan/base-utils/exceptions'
import {dbgEnter, dbgReturn, dbg} from '@jdeighan/base-utils/debug'

import {TreeMapper} from '@jdeighan/mapper/tree'

export lQuote = '«'
export rQuote = '»'

# ---------------------------------------------------------------------------

export parseValue = (str) =>

	dbgEnter 'parseValue', str
	assert isString(str), "not a string"
	switch str
		when 'undef'
			result = undef
		when 'null'
			result = null
		when 'true'
			result = true
		when 'false'
			result = false
		else
			result = parseFloat(str)
			if isNaN(result)
				if lMatches = str.match(///^ « (.*) » $///)
					result = lMatches[1]
				else
					result = str
	dbgReturn 'parseValue', result
	return result

# ---------------------------------------------------------------------------

export class TamlMapper extends TreeMapper

	constructor: (hInput, options) ->

		dbgEnter 'TamlMapper', hInput, options
		super hInput, options
		firstNode = @fetch()
		assert (firstNode.str == '---'), "missing header"
		dbgReturn 'TamlMapper', this

	# ..........................................................

	getUserObj: (hNode) ->

		{str} = hNode
		if (str == '-')
			return {
				type: 'listItem'
				}
		if lMatches = str.match(///^ - \s* (.*) $///)
			[_, valStr] = lMatches
			assert nonEmpty(valStr), "valStr is empty"
			return {
				type: 'listItem'
				value: parseValue(valStr)
				}
		if lMatches = str.match(///^ (\S+) : \s* (.*) $///)
			[_, key, valStr] = lMatches
			if (valStr.length == 0)
				return {
					type: 'hashItem'
					key
					}
			else
				return {
					type: 'hashItem'
					key
					value: parseValue(valStr)
					}
		return {
			type: 'value'
			value: parseValue(str)
			}

	# ..........................................................

	beginWalk: (hGlobalEnv) ->

		hGlobalEnv.isSet = false
		# --- hGlobalEnv.value is set later
		return undef

	# ..........................................................

	beginLevel: (hEnv) ->

		hEnv.isSet = false
		# --- hEnv.value is set later
		return undef

	# ..........................................................

	visit: (hNode, hEnv, hParEnv) ->

		dbgEnter 'visit', hNode
		assert isHash(hEnv), "missing env"
		assert isHash(hParEnv), "missing parent env"

		parValue = hParEnv.value  # --- unpack parent environment
		{uobj} = hNode
		switch uobj.type

			when 'listItem'
				if hParEnv.isSet
					dbg "hParEnv.value already set to #{OL(parValue)}"
					assert isArray(parValue),
						"list item, but parent value is #{OL(parValue)}"
				else
					dbg "set hParEnv.value to []"
					hParEnv.value = []
					hParEnv.isSet = true

			when 'hashItem'
				assert uobj.hasOwnProperty('key'), "missing key"
				assert nonEmpty(uobj.key), "empty key"
				if hParEnv.isSet
					dbg "hParEnv.value already set to #{OL(parValue)}"
					assert isHash(parValue),
						"hash item, but parent value is #{OL(parValue)}"
				else
					dbg "set hParEnv.value to {}"
					hParEnv.value = {}
					hParEnv.isSet = true

			when 'value'
				croak "Not Implemented"

		if uobj.hasOwnProperty('value')
			# --- This should cause any children to throw error
			hEnv.isSet = true
			hEnv.value = uobj.value
		else
			hEnv.isSet = false

		dbg 'final hNode', hNode
		dbgReturn 'visit', undef
		return undef

	# ..........................................................

	endVisit: (hNode, hEnv, hParEnv) ->

		dbgEnter 'endVisit', hNode
		assert isHash(hEnv), "missing env"
		assert isHash(hParEnv), "missing parent env"

		type = hNode.uobj.type
		key = hNode.uobj.key
		if hParEnv.isSet
			if isArray(hParEnv.value)
				assert (type == 'listItem'), "type = #{OL(type)}"
				dbg "push to parent list: #{OL(hEnv.value)}"
				hParEnv.value.push hEnv.value
			else if isHash(hParEnv.value)
				assert (type == 'hashItem'), "type = #{OL(type)}"
				dbg "add to parent hash: #{OL(key)}: #{OL(hEnv.value)}"
				hParEnv.value[key] = hEnv.value

		dbg 'final hNode', hNode
		dbgReturn 'endVisit', undef
		return undef

	# ..........................................................

	endWalk: (hGlobalEnv) ->

		@value = hGlobalEnv.value    # set the final value
		return undef

	# ..........................................................

	getResult: (hOptions=undef) ->

		dbgEnter "getResult"
		@walk(hOptions)      # should set @result
		result = @value
		dbgReturn "getResult", result
		return result


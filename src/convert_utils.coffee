# convert_utils.coffee

import {strict as assert} from 'assert'
import {dirname, resolve, parse as parse_fname} from 'path';
import CoffeeScript from 'coffeescript'
import marked from 'marked'
import sass from 'sass'
import yaml from 'js-yaml'

import {
	say, undef, pass, croak, log, isEmpty, nonEmpty, isComment, isString,
	unitTesting, escapeStr, firstLine, arrayToString,
	} from '@jdeighan/coffee-utils'
import {
	splitLine, indented, undented, tabify, untabify, indentLevel,
	} from '@jdeighan/coffee-utils/indent'
import {slurp, pathTo} from '@jdeighan/coffee-utils/fs'
import {debug} from '@jdeighan/coffee-utils/debug'
import {svelteHtmlEsc} from '@jdeighan/coffee-utils/svelte'

import {StringInput, CoffeeMapper, SassMapper} from '@jdeighan/string-input'
import {getNeededImports} from '@jdeighan/string-input/code'

# ---------------------------------------------------------------------------
#   isTAML - is the string valid TAML?

export isTAML = (input) ->

	return (firstLine(input).indexOf('---') == 0)

# ---------------------------------------------------------------------------
#   taml - convert valid TAML string to a JavaScript value

export taml = (str) ->

	debug "enter taml('#{escapeStr(str)}')"
	if not str?
		debug "return undef - str is not defined"
		return undef
	assert isString(str), "taml(): not a string"
	header = firstLine(str)
	assert (header.indexOf('---') == 0), "taml(): not a TAML string"
	return yaml.load(untabify(str, 1))

# ---------------------------------------------------------------------------
#   tamlStringify - convert a data structure into a valid TAML string

export tamlStringify = (obj) ->

	if not obj?
		return 'undef'
	str = yaml.dump(obj, {
			skipInvalid: true
			indent: 1
			sortKeys: false
			lineWidth: -1
			})
	return "---\n" + tabify(str)

# ---------------------------------------------------------------------------
#   slurpTAML - read TAML from a file

export slurpTAML = (filepath) ->
	contents = slurp(filepath)
	return taml(contents)

# ---------------------------------------------------------------------------

export preprocessCoffee = (code) ->

	assert (indentLevel(code)==0), "preprocessCoffee(): has indentation"

	oInput = new CoffeeMapper(code)
	newcode = oInput.getAllText()

	debug "call getNeededImports()"
	lImports = getNeededImports(newcode)
	if isEmpty(lImports)
		return newcode
	else
		return "#{arrayToString(lImports)}\n#{newcode}"

# ---------------------------------------------------------------------------

export brewExpr = (expr, force=false) ->

	assert (indentLevel(expr)==0), "brewCoffee(): has indentation"

	if unitTesting && not force
		return expr
	try
		newexpr = CoffeeScript.compile(expr, {bare: true}).trim()

		# --- Remove any trailing semicolon
		pos = newexpr.length - 1
		if newexpr.substr(pos, 1) == ';'
			newexpr = newexpr.substr(0, pos)

	catch err
		croak err, expr, "brewExpr"
	return newexpr

# ---------------------------------------------------------------------------

export brewCoffee = (text, force=false) ->

	debug "enter brewCoffee()"
	debug text, "INPUT TEXT:"

	newtext = preprocessCoffee(text)

	debug newtext, "NEW TEXT:"
	if unitTesting && not force
		return newtext
	try
		script = CoffeeScript.compile(newtext, {bare: true})
		debug script, "SCRIPT:"
	catch err
		log newtext, "Mapped Text:"
		croak err, text, "Original Text"
	return script

# ---------------------------------------------------------------------------

export markdownify = (text) ->

	debug "enter markdownify('#{escapeStr(text)}')"
	if unitTesting
		debug "return original text"
		return text
	text = undented(text)
	html = marked(text, {
			grm: true,
			headerIds: false,
			})
	debug "marked returned '#{escapeStr(html)}'"
	result = svelteHtmlEsc(html)
	debug "return '#{escapeStr(result)}'"
	return result

# ---------------------------------------------------------------------------

export sassify = (text) ->

	oInput = new SassMapper(text)
	newtext = oInput.getAllText()
	if unitTesting
		return newtext
	result = sass.renderSync({
			data: newtext,
			indentedSyntax: true,
			indentType: "tab",
			})
	return result.css.toString()

# ---------------------------------------------------------------------------

hExtToEnvVar = {
	'.md':   'dir_markdown',
	'.taml': 'dir_data',
	'.txt':  'dir_data',
	}

# ---------------------------------------------------------------------------

export getFileContents = (fname, convert=false) ->

	debug "enter getFileContents('#{fname}')"
	if unitTesting
		debug "return - unit testing"
		return "Contents of #{fname}"

	{root, dir, base, ext} = parse_fname(fname.trim())
	assert not root && not dir, "getFileContents():" \
		+ " root='#{root}', dir='#{dir}'" \
		+ " - full path not allowed"
	envvar = hExtToEnvVar[ext]
	debug "envvar = '#{envvar}'"
	assert envvar, "getFileContents() doesn't work for ext '#{ext}'"
	dir = process.env[envvar]
	debug "dir = '#{dir}'"
	assert dir, "env var '#{envvar}' not set for file extension '#{ext}'"
	fullpath = pathTo(base, dir)   # guarantees that file exists
	debug "fullpath = '#{fullpath}'"
	assert fullpath, "getFileContents(): Can't find file #{fname}"

	contents = slurp(fullpath)
	if not convert
		debug "return - not converting"
		return contents
	switch ext
		when '.md'
			return markdownify(contents)
		when '.taml'
			return taml(contents)
		when '.txt'
			return contents
		else
			croak "getFileContents(): No handler for ext '#{ext}'"

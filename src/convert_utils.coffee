# convert_utils.coffee

import {strict as assert} from 'assert'
import {dirname, resolve, parse as parse_fname} from 'path';
import CoffeeScript from 'coffeescript'
import marked from 'marked'
import sass from 'sass'
import yaml from 'js-yaml'

import {
	say, undef, pass, error, isEmpty, isComment, isString,
	unitTesting, escapeStr, firstLine,
	} from '@jdeighan/coffee-utils'
import {
	splitLine, indented, undented, untabify,
	} from '@jdeighan/coffee-utils/indent'
import {slurp, pathTo} from '@jdeighan/coffee-utils/fs'
import {debug, setDebugging} from '@jdeighan/coffee-utils/debug'
import {svelteHtmlEsc} from '@jdeighan/coffee-utils/svelte'
import {StringInput} from '@jdeighan/string-input'

# ---------------------------------------------------------------------------
#   isTAML - is the string valid TAML?

export isTAML = (input) ->

	return (firstLine(input).indexOf('---') == 0)

# ---------------------------------------------------------------------------
#   taml - convert valid TAML string to a JavaScript value

export taml = (str) ->

	if not str?
		return undef
	assert isString(str), "taml(): not a string"
	header = firstLine(str)
	if (header == '--- function')
		code = str.substr(header.length + 1)
		return new Function(brewExpr(code))
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
###

- removes blank lines and comments

- converts
		<varname> <== <expr>
	to:
		`$: <varname> = <expr>;`

- converts
		<== <expr>
	to:
		`$: <expr>;`

- converts
		<===
			<code>
	to:
		```
		$: {
			<code>
			}
###
# ---------------------------------------------------------------------------
# --- export to allow unit testing

export class CoffeeMapper extends StringInput
	# - removes blank lines and comments
	# - converts <var> <== <expr> to `$: <var> = <expr>

	mapLine: (orgLine) ->

		[level, line] = splitLine(orgLine)
		if isEmpty(line) || line.match(/^#\s/)
			return undef
		if lMatches = line.match(///^
				(?:
					([A-Za-z][A-Za-z0-9_]*)   # variable name
					\s*
					)?
				\< \= \=
				\s*
				(.*)
				$///)
			[_, varname, expr] = lMatches
			if expr
				# --- convert to JavaScript if not unit testing ---
				try
					jsExpr = brewCoffee(expr).trim()   # will have trailing ';'
				catch err
					error err.message

				if varname
					result = indented("\`\$\: #{varname} = #{jsExpr}\`", level)
				else
					result = indented("\`\$\: #{jsExpr}\`", level)
			else
				if varname
					error "Invalid syntax - variable name not allowed"
				code = @fetchBlock(level+1)
				try
					jsCode = brewCoffee(code)
				catch err
					error err.message

				result = """
						\`\`\`
						\$\: {
						#{indented(jsCode, 1)}
						#{indented('}', 1)}
						\`\`\`
						"""
			return indented(result, level)
		else
			return orgLine

# ---------------------------------------------------------------------------

export brewExpr = (expr) ->

	if unitTesting
		return expr
	try
		newexpr = CoffeeScript.compile(expr, {bare: true}).trim()

		# --- Remove any trailing semicolon
		pos = newexpr.length - 1
		if newexpr.substr(pos, 1) == ';'
			newexpr = newexpr.substr(0, pos)

	catch err
		say "CoffeeScript error!"
		say expr, "expr:"
		error "CoffeeScript error: #{err.message}"
	return newexpr

# ---------------------------------------------------------------------------

export brewCoffee = (text) ->

	oInput = new CoffeeMapper(text)
	newtext = oInput.getAllText()
	if unitTesting
		return newtext
	try
		script = CoffeeScript.compile(newtext, {bare: true})
	catch err
		say "CoffeeScript error!"
		say text, "Original Text:"
		say newtext, "Mapped Text:"
		error "CoffeeScript error: #{err.message}"
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

class SassMapper extends StringInput
	# --- only removes comments

	mapLine: (line) ->

		if isComment(line)
			return undef
		return line

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
			error "getFileContents(): No handler for ext '#{ext}'"

# ---------------------------------------------------------------------------
# to be removed

findFile = (fname) ->

	{root, dir, base, ext} = parse_fname(fname.trim())
	assert not root && not dir, "findFile():" \
		+ " root='#{root}', dir='#{dir}'" \
		+ " - full path not allowed"
	envvar = hExtToEnvVar[ext]
	assert envvar, "findFile() doesn't work for ext '#{ext}'"
	dir = process.env[envvar]
	assert dir, "env var '#{envvar}' not set for file extension '#{ext}'"
	fullpath = pathTo(base, dir)   # guarantees that file exists
	assert fullpath, "findFile(): Can't find file #{fname}"
	return fullpath

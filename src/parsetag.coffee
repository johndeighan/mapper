# parsetag.coffee

import {
	assert, undef, pass, error, croak, words, nonEmpty,
	} from '@jdeighan/coffee-utils'

hNoEnd = {}
for tag in words('area base br col command embed hr img input' \
		+ ' keygen link meta param source track wbr')
	hNoEnd[tag] = true

# ---------------------------------------------------------------------------

export parsetag = (line) ->

	if lMatches = line.match(///^
			(?:
				([A-Za-z][A-Za-z0-9_]*)  # variable name
				\s*
				=
				\s*
				)?                       # variable is optional
			([A-Za-z][A-Za-z0-9_]*)     # tag name
			(?:
				\:
				( [a-z]+ )
				)?
			(\S*)                       # modifiers (class names, etc.)
			\s*
			(.*)                        # attributes & enclosed text
			$///)
		[_, varName, tagName, subtype, modifiers, rest] = lMatches
		if (tagName=='svelte') && subtype
			tagName = "#{tagName}:#{subtype}"
			subtype = undef
	else
		error "parsetag(): Invalid HTML: '#{line}'"

	switch subtype
		when undef, ''
			pass
		when 'startup', 'onmount', 'ondestroy'
			if (tagName != 'script')
				error "parsetag(): subtype '#{subtype}' only allowed with script"
		when 'markdown', 'sourcecode'
			if (tagName != 'div')
				error "parsetag(): subtype 'markdown' only allowed with div"

	# --- Handle classes added via .<class>
	lClasses = []
	if (subtype == 'markdown')
		lClasses.push 'markdown'

	if modifiers
		# --- currently, these are only class names
		while lMatches = modifiers.match(///^
				\. ([A-Za-z][A-Za-z0-9_]*)
				///)
			[all, className] = lMatches
			lClasses.push className
			modifiers = modifiers.substring(all.length)
		if modifiers
			error "parsetag(): Invalid modifiers in '#{line}'"

	# --- Handle attributes
	hAttr = {}     # { name: { value: <value>, quote: <quote> }, ... }

	if varName
		hAttr['bind:this'] = {value: varName, quote: '{'}

	if rest
		while lMatches = rest.match(///^
				(?:
					(?:
						( bind | on )          # prefix
						:
						)?
					([A-Za-z][A-Za-z0-9_]*)   # attribute name
					)
				=
				(?:
					  \{ ([^}]*) \}           # attribute value
					| " ([^"]*) "
					| ' ([^']*) '
					|   ([^"'\s]+)
					)
				\s*
				///)
			[all, prefix, attrName, br_val, dq_val, sq_val, uq_val] = lMatches
			if br_val
				value = br_val
				quote = '{'
			else
				assert ! prefix?, "prefix requires use of {...}"
				if dq_val
					value = dq_val
					quote = '"'
				else if sq_val
					value = sq_val
					quote = "'"
				else
					value = uq_val
					quote = ''

			if prefix
				attrName = "#{prefix}:#{attrName}"

			if attrName == 'class'
				for className in value.split(/\s+/)
					lClasses.push className
			else
				if hAttr.attrName?
					error "parsetag(): Multiple attributes named '#{attrName}'"
				hAttr[attrName] = { value, quote }

			rest = rest.substring(all.length)

	# --- The rest is contained text
	rest = rest.trim()
	if lMatches = rest.match(///^
			['"]
			(.*)
			['"]
			$///)
		rest = lMatches[1]

	# --- Add class attribute to hAttr if there are classes
	if (lClasses.length > 0)
		hAttr.class = {
			value: lClasses.join(' '),
			quote: '"',
			}

	# --- If subtype == 'startup'
	if subtype == 'startup'
		if ! hAttr.context
			hAttr.context = {
				value: 'module',
				quote: '"',
				}

	# --- Build the return value
	hToken = {
		type: 'tag'
		tag: tagName
		}
	if subtype
		hToken.subtype = subtype
	if nonEmpty(hAttr)
		hToken.hAttr = hAttr

	# --- Is there contained text?
	if rest
		hToken.containedText = rest

	return hToken

# ---------------------------------------------------------------------------

export isBlockTag = (hTag) ->

	{tag, subtype} = hTag
	return   (tag=='script') \
			|| (tag=='style') \
			|| (tag == 'pre') \
			|| ((tag=='div') && (subtype=='markdown')) \
			|| ((tag=='div') && (subtype=='sourcecode'))

# ---------------------------------------------------------------------------
# --- export only for unit testing

export attrStr = (hAttr) ->

	if ! hAttr
		return ''
	str = ''
	for attrName in Object.getOwnPropertyNames(hAttr)
		{value, quote} = hAttr[attrName]
		if quote == '{'
			bquote = '{'
			equote = '}'
		else
			bquote = equote = quote
		str += " #{attrName}=#{bquote}#{value}#{equote}"
	return str

# ---------------------------------------------------------------------------

export tag2str = (hToken, type='begin') ->

	if (type == 'begin')
		str = "<#{hToken.tag}"    # build the string bit by bit
		if nonEmpty(hToken.hAttr)
			str += attrStr(hToken.hAttr)
		str += '>'
		return str
	else if (type == 'end')
		if hNoEnd[hToken.tag]
			return undef
		else
			return "</#{hToken.tag}>"
	else
		croak "type must be 'begin' or 'end'"

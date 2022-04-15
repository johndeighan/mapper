<!DOCTYPE html>
<style>
	body {
		max-width: 800px;
		margin-left: auto;
		margin-right: auto;
		}
	.language-text {
		display: block;
		padding: 15px;
		width: 500px;
		background-color: khaki;
		}
	.language-coffeescript {
		display: block;
		padding: 15px;
		width: 500px;
		background-color: antiquewhite;
		}
	math {
		display: block;
		padding: 15px;
		width: 500px;
		height: auto;
		background-color: lightGray;
		}
	.large {
		font-size: 48px;
		}
</style>

class TreeMapper
===============

To use the TreeMapper class:

1. Define a mapping function (a regular function)

2. Use function treeFromBlock() to get the tree

3. Create a subclass of TreeWalker, overriding method
	visit(superNode, level) and optionally
	endVisit(superNode, level)

4. Pass the tree to the TreeWalker constructor, call the
	walk() method, then fetch the mapped data. Often, you'll
	want to create a method in your class to fetch the mapped
	data but you may also simply get it directly from a
	property of your class.

As an example, let's create a limited mathematical language.
The primitive items in this language includes:

	- numbers      - a string of one or more digits
	- identifiers  - a string of one or more letters or digits
	                 beginning with a letter
	- operators    - arbitrary non-whitespace strings

From these, we can build the following expressions:

	<program> ::= <expr>+
	<atom> ::= <number> | <ident> | <op>
	<expr> ::=
		  'expr' <atom>*    => <expr>*
		| 'group' <op>{0,2} => <expr>+
		| 'sub'             => <expr>{2}
		| 'SIGMA'           => <expr>{3,}
		| <atom>

	Everything before a => is on one line, and everything
	after the => is on a separate line, at one higher level,
	i.e. everything after the => is a child of the target element.

Examples:
---------

-----------------------------------------------

```text
expr X + 3
```

should produce MathML that displays:

<math xmlns='http://www.w3.org/1998/Math/MathML'>
	<row>
		<mi> X </mi>
		<mo> + </mo>
		<mn> 3 </mn>
	</row>
</math>

-----------------------------------------------

```text
group
	expr X + 3
```

should produce MathML that displays:

<math xmlns='http://www.w3.org/1998/Math/MathML'>
	<row>
		<mo> ( </mo>
		<mi> X </mi>
		<mo> + </mo>
		<mn> 3 </mn>
		<mo> ) </mo>
	</row>
</math>

-----------------------------------------------

```text
sub
	X
	2
```
should produce MathML that displays:

<math xmlns='http://www.w3.org/1998/Math/MathML'>
	<msub>
		<mi> X </mi>
		<mn> 2 </mn>
	</msub>
</math>
-----------------------------------------------

```text
SIGMA
	0
	10
	sub
		X
		2
```
should produce MathML that displays:

<math xmlns='http://www.w3.org/1998/Math/MathML'>
	<munderover>
		<mo class="large"> &#x03A3; <!--SIGMA--> </mo>
		<mi>0</mi>
		<mi>10</mi>
	</munderover>
	<msub>
		<mi>X</mi>
		<mn>2</mn>
	</msub>
</math>

-----------------------------------------------

```text
group
	SIGMA
		0
		10
		sub
			X
			2
```
should produce MathML that displays:

<math xmlns='http://www.w3.org/1998/Math/MathML'>
	<mrow>
		<mo> ( </mo>
		<munderover>
			<mo class="large"> &#x03A3; <!--SIGMA--> </mo>
			<mi>  0 </mi>
			<mi> 10 </mi>
		</munderover>
		<msub>
			<mi> X </mi>
			<mn> 2 </mn>
		</msub>
		<mo> ) </mo>
	</mrow>
</math>

Implementation
==============

1. Define a mapping function
----------------------------

To implement this, we first create a mapping function. The
critical thing to understand is that your mapping function does
not need to deal with nested items, i.e. child nodes. It should
only map simple strings, i.e. with no embedded newline or
carriage return characters. Later, when you write your
TreeWalker subclass, you will get a chance to deal with a node's
children. Here is a mapping function for this language:

```coffeescript
export mathMapper = (line) ->

	if isEmpty(line) then return undef
	lWords = line.split(/\s+/)    # split on whitespace
	return getNode(lWords[0], lWords.slice(1))
```

`isEmpty()` returns true if str is undefined or consists of only
whitespace characters. Returning undef indicates that this line
should be ignored.

`getNode()` receives a command name and an array of strings as
input and returns a hash with key 'cmd' and 'lAtoms' if there
is something besides the command name on the line.

Each input string is mapped to one of the following:

```coffeescript
{
	cmd: 'expr'
	lAtoms: [<atom>, ... ]
	}
```

```coffeescript
{
	cmd: 'group'
	lAtoms: [<op>, <op>]
	}
```

```coffeescript
{
	cmd: 'sub'
	}
```

```coffeescript
{
	cmd: 'SIGMA'
	}
```

The lAtoms key will not be present if there are no atoms
(currently only applies to cmd 'expr'). A node's children
(e.g. subtree) does not appear in the above, i.e. not handled
by your mathMapper() function. Note that you can supply 0..3
arguments to the `group` command, but if less than 2, default
values will be supplied.
Each atom in lAtoms, where it exists, is one of the following:

```coffeescript
{
	cmd: 'ident'
	value: str
	}
```

```coffeescript
{
	cmd: 'number'
	value: str
	}
```

```coffeescript
{
	cmd: 'op'
	value: str
	}
```

A number consists of a string of one or more digits. Any string that
starts with a digit, but is not just a string of digits, is an error.

An identifier is anything that starts with a letter or underscore
and is followed by zero or more letters, underscores or digits.

Anything else is considered an operator.

2. Use function treeFromBlock() to get the tree
---------------------------------------------

Execute the following code:

```coffeescript
code = """
	SIGMA
		0
		10
		sub
			X
			2
	"""

result = treeFromBlock(code, mathMapper)
LOG 'result', result
```

The output will be:

```text
------------------------------------------
result:
---
-
   lineNum: 1
   node:
      cmd: SIGMA
   subtree:
      -
         lineNum: 2
         node:
            cmd: expr
            lAtoms:
               -
                  type: number
                  value: '0'
      -
         lineNum: 3
         node:
            cmd: expr
            lAtoms:
               -
                  type: number
                  value: '10'
      -
         lineNum: 4
         node:
            cmd: sub
         subtree:
            -
               lineNum: 5
               node:
                  cmd: expr
                  lAtoms:
                     -
                        type: ident
                        value: X
            -
               lineNum: 6
               node:
                  cmd: expr
                  lAtoms:
                     -
                        type: number
                        value: '2'
------------------------------------------
```
You can check that the structure is correct, but remember that
none of your code will rely on the key names 'node', 'children'
or 'lineNum' - we're just ensuring that the correct tree will be
used in the next step.

3. Create a subclass of TreeWalker
----------------------------------

The critial methods to override are visit() and endVisit().

The visit() method receives parameters **node** and
**level**. The behavior of our visit() method won't depend on
the level, so we'll concern ourselves only with the **node**
parameter. This parameter will be set to whatever our
mathMapper() function returned - in this case, a hash with
key **cmd**, and also key **lAtoms** if anything beside the
command name appeard on the line.

While our tree is being "walked", we want to build up a
string of MathML code. For that purpose, our TreeWalker
subclass will define a property named **@mathml** that will
initially be set to the empty string, which will be appended
to as nodes are visited.

Our subclass of TreeWalker is:

```coffeescript
export class MathTreeWalker extends TreeWalker

	constructor: (tree) ->
		super tree
		@mathml = ''

	visit: (superNode) ->
		debug "enter visit()"
		node = superNode.node
		switch node.cmd
			when 'expr'
				debug "cmd: #{node.cmd}"
				@mathml += "<mrow>"
				for atom in node.lAtoms
					switch atom.type
						when 'number'
							@mathml += "<mn>#{atom.value}</mn>"
						when 'ident'
							@mathml += "<mi>#{atom.value}</mi>"
						when 'op'
							@mathml += "<mo>#{atom.value}</mo>"
			when 'group'
				debug "cmd: #{node.cmd}"
				@mathml += "<mrow>"
				@mathml += node.lAtoms[0].value
			when 'sub'
				debug "cmd: #{node.cmd}"
				@mathml += "<msub>"
			when 'SIGMA'
				debug "cmd: #{node.cmd}"
				@mathml += "<munderover>"
				@mathml += "<mo class='large'> &#x03A3; </mo>"
			else
				croak "visit(): Not a command: '#{node.cmd}'"
		debug "return from visit()"
		return

	endVisit: (superNode) ->
		debug "enter endVisit()"
		node = superNode.node
		switch node.cmd
			when 'expr'
				debug "cmd: #{node.cmd}"
				@mathml += "</mrow>"
			when 'group'
				debug "cmd: #{node.cmd}"
				@mathml += node.lAtoms[1].value
				@mathml += "</mrow>"
			when 'sub'
				debug "cmd: #{node.cmd}"
				@mathml += "</msub>"
			when 'SIGMA'
				debug "cmd: #{node.cmd}"
				@mathml += "</munderover>"
			else
				croak "endVisit(): Not a command: '#{node.cmd}'"
		debug "return from endVisit()"
		return

	getMathML: () ->

		debug "CALL getMathML()"
		return "<math displaystyle='true'> #{@mathml} </math>"
```

4. Pass the tree to the TreeWalker constructor, call the
	walk() method, then fetch the mapped data.
-----------------------------------

```coffeescript
code = """
	SIGMA
		0
		10
	sub
		X
		2
	"""

tree = treeFromBlock(code, mathMapper)
walker = new MathTreeWalker(tree)
walker.walk()
mathml = walker.getMathML()
LOG 'mathml', mathml
```

This will output:

```xml
------------------------------------------
mathml:
---
<math displaystyle='true'> <munderover><mo class='large'> &#x03A3; </mo
><mrow><mn>0</mn></mrow><mrow><mn>10</mn></mrow></munderover><msub><mro
w><mi>X</mi></mrow><mrow><mn>2</mn></mrow></msub> </math>
------------------------------------------
```

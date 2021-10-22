class StringInput
=================

A StringInput object is constructed with a multi-line string
and when the get() method is called it returns each of those
lines in turn, returning undef when EOF is reached.

In addition:

	- if you override the method `mapLine()` each line will
		be passed to that method, which can convert the line
		to any JavaScript value, and can fetch additional
		lines, using the `fetch()` method, in the process.

	- the line `#include <filename>` (which may include preceding
		indentation) will result in the given file being read and
		used for input until the file is exhausted:

		1. <filename> must be a simple filename (no path allowed)
		2. File is searched for in this order:
			a. the same directory as the file containing #include
			b. these directories, if defined in hPrivEnv for these extensions:
				'.md':   'DIR_MARKDOWN',
				'.taml': 'DIR_DATA',
				'.txt':  'DIR_DATA',

		2. The option hIncludePaths was passed to the StringInput
			constructor
		3. The file extension of the <filename> was included as
			a key in hIncludePaths (the key must start with '.')

		The indentation of the line containing '#include' will be
		added to each line of the file being included.

Environment variables to control include paths:

DIR_ROOT
DIR_MARKDOWN
DIR_DATA
DIR_TEXT

Parsing a PLL (Python-like language)
====================================

1. Define a mapping function
2. Use function treeFromBlock to get the tree

Let's say that you want to create a language for
creating "expression objects" that allows functions:

	add - to add some numbers
	subtract - to add some numbers
	multiply - to add some numbers
	divide - to add some numbers
	sigma - to sum numbers over some index set

For example, these are valid expressions:

```text
sum
	13
	49
	53
```

```text
multiply
	sum
		13
		22
		53
	22
```

Numbers must be integers.
We also want to allow identifiers, which must be single upper-case letters:

```text
multiply
	sum
		13
		X
	divide
		Y
		3
```

Here is a valid sigma expression:

```text
sigma
	I in range(5)
	multiply
		I
		22
```

i.e. sigma expects 2 parts:

	1. <identifier> in range(<number> or <identifier>)
	2. an expression

SYNOPSIS:
---------

```coffeescript
mapper = (str) ->
	if lMatches =



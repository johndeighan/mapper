class StringInput
=================

A StringInput object is constructed with a multi-line string
and when the get() method is called it returns each of those
lines in turn, returning undef when EOF is reached.

In addition:
	- if you supply a mapper (a function), each of the lines
		will be transformed by that function. If the function
		returns undef, then get() skips that line
	- if you supply the option hIncludePaths, then if the
		line '#include <filename>" is encountered (it may
		include indentation), and the file extension of
		<filename> matches one of the keys in hIncludePaths,
		the lines in that file are returned as if they were
		placed at the location of '#include <filename>'

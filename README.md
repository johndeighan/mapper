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
		used for input until the file is exhausted, but only if:

		1. <filename> is a simple filename (no path allowed)
		2. The option hIncludePaths was passed to the StringInput
			constructor
		3. The file extension of the <filename> was included as
			a key in hIncludePaths (the key must start with '.')

		The indentation of the line containing '#include' will be
		added to each line of the file being included.

class SmartInput
=================

A SmartInput object is a subclass of StringInput, and is therefore
constructed from a block (i.e. a multi-line string) and an optional source.
It has the following features:

1. Removes blank lines and comments from the block by default, but this
	behavior can be modified by overriding methods handleEmptyLine() and
	handleComment()

2. If a line has an indentation level of N, then all lines following it
	that have an indentation level of N+2 or greater are considered to be
	continuation lines and are appended to the original line, with a space
	character separator, before it is passed to mapLine().

3. Handles HEREDOCs automatically. When a line contains one or more "<<<"
	strings, for each one it fetches all following lines at a greater level
	(but remember #2 above, which is done first), then interprets that block
	as a HEREDOC section, which results in "<<<" being replaced by a string
	that generates that object (if it's a string, it will be surrounded by
	quote marks).

4. To modify its behavior, override mapString(line, level), not mapLine()
	because mapLine() implements #3 above.

NOTE: You can add new types of HEREDOC sections by defining a new class
	that includes these methods:

```text
myName() - provide the name of the new type (must be unique)
isMyHereDoc(block) - return true if this class should handle it
map(block, result) - return the object you want to replace '<<<'
	- this should return a hash with keys `obj` and `str`, where obj
		is the actual object, and str is a string which will directly
		replace the '<<<' and should compile to the same object
```

- If isMyHereDoc returns a true value, then that value will be passed
	as the 2nd parameter to map() - it can be any true value, not just
	a boolean

Once the class has been defined, you can enable that type of HEREDOC with:

```coffeescript
addHereDocType new HereDocClass()
```

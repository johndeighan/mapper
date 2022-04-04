class PLLParser
===============

1. Define a mapping function (regular function)
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



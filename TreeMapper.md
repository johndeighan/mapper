class TreeMapper
===============

To use the TreeMapper class:

1. Define a mapping function (a regular function)
2. Use function treeFromBlock to get the tree

As an example, let's create a limited mathematical language.
The primitive items in this language includes:

	- numbers      - a string of one or more digits
	- identifiers  - a string of one or more letters or digits
	                 beginning with a letter
	- operators    - arbitrary non-whitespace strings

From these, we can build the following expressions:

	<expr> ::=
		  <number>
		| <ident>
		| <binop>
		| <array>

	<binop> ::=
		| <expr> <op> <expr>
		| '(' <expr> <op> <expr> ')'

	<array> ::=
		'[' <expr>* ']'

	<sup> ::=
		'sup' <expr> <expr>

	<sub> ::=
		'sub' <expr> <expr>

	<frac> ::=
		'frac' <expr> <expr>

	<underover> ::=
		'underover' <expr> <expr> <expr>

For example, this

```text
sup
	X
	2
```
should produce MathML that displays:

<math xmlns='http://www.w3.org/1998/Math/MathML'>
	<sup>
		<mi>X</mi>
		<mn>2</mn>
	</sup>
</math>

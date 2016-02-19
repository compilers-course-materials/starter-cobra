# Cobra

![A cobra](https://upload.wikimedia.org/wikipedia/commons/thumb/9/94/Indian_Cobra.JPG/1920px-Indian_Cobra.JPG)

In this assignment you'll implement a small language called Cobra, which
implementes an en**co**ded **b**inary **r**epresent**a**tion of different
values.  It also uses C function calls to implement some user-facing
operations, like printing and reporting errors.

## The Cobra Language

As usual, there are a few pieces that go into defining a language for us to
compile.

- A description of the concrete syntax – the text the programmer writes

- A description of the abstract syntax – how to express what the
  programmer wrote in a data structure our compiler uses.  As in Boa, this
  will include a surface `expr` type, and a core `aexpr` type.

- The _semantics_—or description of the behavior—of the abstrac
  syntax, so our compiler knows what the code it generates should do.


### Concrete Syntax

The concrete syntax of Boa is:

```
<expr> :=
  | let <bindings> in <expr>
  | if <expr>: <expr> else: <expr>
  | <binop-expr>

<binop-expr> :=
  | <identifier>
  | <number>
  | true
  | false
  | add1(<expr>)
  | sub1(<expr>)
  | isnum(<expr>)
  | isbool(<expr>)
  | print(<expr>)
  | <expr> + <expr>
  | <expr> - <expr>
  | <expr> * <expr>
  | <expr> < <expr>
  | <expr> > <expr>
  | <expr> == <expr>
  | ( <expr> )

<bindings> :=
  | <identifier> = <expr>
  | <identifier> = <expr>, <bindings>
}
```

### Abstract Syntax

#### User-facing

The abstract syntax of Cobra is an OCaml datatype, and corresponds nearly
one-to-one with the concrete syntax.  Here, we've added `E` prefixes to the
constructors, which will distinguish them from the ANF forms later.

```
type prim1 =
  | Add1
  | Sub1
  | Print
  | IsNum
  | IsBool

type prim2 =
  | Plus
  | Minus
  | Times
  | Less
  | Greater
  | Equal

type expr =
  | ELet of (string * expr) list * expr
  | EPrim1 of prim1 * expr
  | EPrim2 of prim2 * expr * expr
  | EIf of expr * expr * expr
  | ENumber of int
  | EBool of bool
  | EId of string
```

#### Compiler-facing

The compiler-facing abstract syntax of Boa splits the above expressions into
three categories

```
type immexpr =
  | ImmNumber of int
  | ImmBool of bool
  | ImmId of string

and cexpr =
  | CPrim1 of prim1 * immexpr
  | CPrim2 of prim2 * immexpr * immexpr
  | CIf of immexpr * aexpr * aexpr
  | CImmExpr of immexpr

and aexpr =
  | ALet of string * cexpr * aexpr
  | ACExpr of cexpr
```

These are quite similar to the constructs for Boa – the main additions are
the new primitives.

### Semantics

With the addition of two types to the language, there are two main changes
that ripple through the implementation:

- The representation of values
- The possibility of errors

There is one other major addition, which is the `print` primitive, discussed
more below.

The representation of values requires a definition.  We'll use the following
representations for the Cobra runtime:

- `true` will be represented as the constant `0xFFFFFFFF`
- `false` will be represented as the constant `0x7FFFFFFF`
- numbers will be represented with a zero in the leftmost bit, as in class.
  So, for example, `2` is represented as `0x00000004`.

You should augment the provided `print` function in `main.c` to print these
values correctly: `true` and `false` should print as those words, and numbers
should print out as the underlying number being represented.

You should raise errors in the following cases:

- `-`, `+`, `*`, `<`, and `>` should raise an error (by printing it out) with
  the substring `"expected a number"` if the operation doesn't get two numbers
  (you can print more than this if you like, but it must be a substring)
- `add1` and `sub1` should raise an error with the substring `"expected a
  number"` if the argument isn't a number
- `+`, `-`, and `*` should raise an error with the substring `"overflow"` if
  the result overflows, and falls outside the range representable in 31 bits.
  The `jo` instruction (not to be confused with the Joe Instructor) which
  jumps if the last instruction overflowed, is helpful here.
- `if` should raise an error with the substring `"expected a boolean"` if the
  conditional value is not a boolean.

These error messages should be printed on standard _error_, so use a
call like:

```
fprintf(stderr, "Error: expected a number")
```

I recommend raising an error by adding some fixed code to the end of your
generated code that calls into error functions you implement in `main.c`.  For
example, you might insert code like:

```
internal_error_non_number:
  push eax
  call error_non_number
```

Which will store the value in `eax` on the top of the stack, move `esp`
appropriately, and perform a jump into `error_non_number` function, which you
will write in `main.c` as a function of one argument.

The other operators, `==`, `isnum`, `isbool`, and `print`, cannot raise
errors, and always succeed.

The final piece of new semantics is the `print` operator.  A `print`
expression should pass the value of its subexpression to the `print` function
in `main.c`, and evaluate to the same value (`print` in `main.c` helps out
here by returning its argument).  The main work you need to do here is similar
to when calling an error function; evaluate the argument, push it onto the
stack with `push`, and then `call` into `print`.

### Examples

```
let x = 1 in
let y = print(x + 1) in
print(y + 2)

# will output

2
4
4
```

The first 2 comes from the first print expression.  The first 4 comes from the
second print expression.  The final line prints the answer of the program as
usual, so there's an “extra” 4.

```
if 54: true else: false

# prints (on standard error) something like:

Error: expected a boolean in if, got 54
```



## Implementing Cobra

### Memory Layout and Calling C Functions



### New Assembly Constructs

- `Sized`

    You may run into errors that report that the _size_ of an operation is
    ambiguous.  This could happen if you write, for example:

    ```
    cmp [ebp-8], 0
    ```

    Because the assembler doesn't know if the program should move a four-byte
    zero, a one-byte zero, or something in between into memory starting at
    `[ebp-8]`.  To solve this, you can supply a size:

    ```
    cmp [ebp-8], DWORD 0
    ```

    This tells the assembler to use the “double word” size for 0, which
    corresponds to 32 bits.  A `WORD` corresponds to 16 bits, and a `BYTE`
    corresponds to 16 bits.  To get a sized argument, you can use the `Sized`
    constructor from `arg`.



As usual, full summaries of the instructions we use are at [this assembly
guide](http://www.cs.virginia.edu/~evans/cs216/guides/x86.html).

- `IMul of arg * arg` — Multiply the left argument by the right argument, and
  store in the left argument (typically the left argument is `eax` for us)
  
  Example: `mul eax, 4`

- `ILabel of string` — Create a location in the code that can be jumped to
  with `jmp`, `jne`, and other jump commands

  Example: `this_is_a_label:`

- `ICmp of arg * arg` — Compares the two arguments for equality.  Set the
  _condition code_ in the machine to track if the arguments were equal, or if
  the left was greater than or less than the right.  This information is used
  by `jne` and other conditional jump commands.

  Example: `cmp [esp-4], 0`

  Example: `cmp eax, [esp-8]`

- `IJne of string` — If the _condition code_ says that the last comparison
  (`cmp`) was given equal arguments, do nothing.  If it says that the last
  comparison was _not_ equal, immediately start executing instructions from
  the given string label (by changing the program counter).

  Example: `jne this_is_a_label`

- `IJe of string` — Like `IJne` but with the jump/no jump cases reversed

- `IJmp of string` — Unconditionally start executing instructions from the
  given label (by changing the program counter)

  Example: `jmp always_go_here`

#### Combining `cmp` and Jumps for If

When compiling an if expression, we need to execute exactly _one_ of the
branches (and not accidentally evaluate both!).  A typical structure for doing
this is to have two labels: one for the else case and one for the end of the
if expression.  So the compiled shape may look like:

```
  cmp eax, 0    ; check if eax is equal to 0
  je else_branch
  ; commands for then branch go here
  jmp end_of_if
else_branch:
  ; commands for else branch go here
end_of_if:
```

Note that if we did _not_ put `jmp end_of_if` after the commands for the then
branch, control would continue and evaluate the else branch as well.  So we
need to make sure we skip over the else branch by unconditionally jumping to
`end_of_if`.

#### Creating New Names on the Fly

In both ANF and when creating labels, we can't simply use the same identifier
names and label names over and over.  The assembler will get confused if we
have nested `if` expressions, because it won't know which `end_of_if` to `jmp`
to, for example.  So we need some way of generating new names that we know
won't conflict.

You've been provided with a function `gen_temp` (meaning “generate
temporary”) that takes a string and appends the value of a counter to it,
which increases on each call.  You can use `gen_temp` to create fresh names
for labels and variables, and be guaranteed the names won't overlap as long as
you use base strings don't have numbers at the end.

For example, when compiling an `if` expression, you might call `gen_temp`
twice, once for the `else_branch` label, and once for the `end_of_if` label.
This would produce output more like:

```
  cmp eax, 0    ; check if eax is equal to 0
  je else_branch1
  ; commands for then branch go here
  jmp end_of_if2
else_branch1:
  ; commands for else branch go here
end_of_if2:
```

And if there were a _nested_ if expression, it might have labels like
`else_branch3` and `end_of_if4`.

### Implementing ANF

Aside from conditionals, the other major thing you need to do in the
implementation of Boa is add an implementation of ANF to convert the
user-facing syntax to the ANF syntax the compiler uses.  A few cases—`EIf`,
`EPrim1`, and `ENumber`—are done for you.  You should study these in detail
and understand what's going on.

There is a detailed write up on the [course
page](https://www.cs.swarthmore.edu/~jpolitz/cs75/s16/n_anf-tutorial.html)
that describes how to think of implementing ANF in some detail, and gives
examples of the pieces of the implementation.

### A Note on Scope

For this assignment, you can assume that all variables have different names.
That means in particular you don't need to worry about nested instances of
variables with the same name, duplicates within a list, etc.  The combination
of these with `anf` causes some complications that go beyond our goals for
this assignment.

### Testing Functions

As before, `t` and `te` test the compiler end-to-end, checking for
answers and errors, respectively.

There are two new testing functions you can use as well:

- `ta` – This takes an `aexpr` and an expected answer as a string, and
  compiles and runs the `aexpr` using your compiler.  This is useful if you
  want to, for instance, test binary operators in your compiler before you are
  confident that the ANF transformation works.
- `tanf` – This takes a `expr` and an `aexpr` and calls `anf` on the
  `expr` with `{fun ie -> ACExpr(CImmExpr(ie))`, and checks that the
  result is equal to the provided @tt{aexpr}.  You can use this to test your
  ANF directly, to make sure it's producing the constrained expression you
  expect, before you try compiling it.

### Recommended TODO List

Here's an order in which you could consider tackling the implementation:

1. Fill in the `ImmId` case in the compiler.  This will let you run things
   like `sub1(sub1(5))` and other nested expressions.
2. Write some tests for the input and output of nested `EPrim1` expressions in
   `tanf`, to understand what the ANF transformation looks like on those
   examples.
3. Finish the `CIf` case in the compiler, so you can run simple programs with
   `if`.  This includes the pretty-printing for the comparison and jump
   instructions, etc.
4. Write some tests for the input and output of performing `anf` on `EIf`
   expressions, again to get a feel for what the transformation looks like.
5. Work through both the `anf` implementation and the compiler implementation
   of `Prim2`.  Write tests as you go.
6. Work through both the `anf` implementation and the compiler implementation
   of `ELet`.  Write tests as you go.

## Handing In

A complete implementation of ANF and the compiler is due Wednesday, February
17, at 11:59pm.


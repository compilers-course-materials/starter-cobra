# Cobra

![A cobra](https://upload.wikimedia.org/wikipedia/commons/thumb/9/94/Indian_Cobra.JPG/1920px-Indian_Cobra.JPG)

In this assignment you'll implement a small language called Cobra, which
implementes a **co**ded **b**inary **r**epresent**a**tion of different values.
It also uses C function calls to implement some user-facing operations, like
printing and reporting errors.

## Errata

- The counter for generated variable names is not reset before each call to
  `anf`, which can make testing with `tanf` a little odd, since variables keep
  incrementing.  If you want to have the counter reset before each call to
  `anf`, you can change the body of the `anf` function to be:

  ```
  begin
    count := 0;
    anf_k e (fun imm -> ACExpr(CImmExpr(imm)))
  end
  ```
- The arguments to `assert_equal` in `tanf` are backwards relative to how
  OUnit reports the expected and actual values.  To get more useful error
  reports, change the body of `tanf` from 

  ```
  assert_equal (anf program) expected ~printer:string_of_aexpr;;
  ```

  to

  ```
  assert_equal expected (anf program) ~printer:string_of_aexpr;;
  ```

- An early version of this assignment described `if` as taking the then branch
  when the conditional was equal to 0.  It should take the _else_ branch when
  the conditional is equal to 0, just like in C.



## The Boa Language

As usual, there are a few pieces that go into defining a language for us to
compile.

- A description of the concrete syntax – the text the programmer writes

- A description of the abstract syntax – how to express what the
  programmer wrote in a data structure our compiler uses.

- The _semantics_—or description of the behavior—of the abstrac
  syntax, so our compiler knows what the code it generates should do.


In boa, the second step is broken up into two:

- A description of the user-facing abstract syntax – how to express what the
  programmer wrote in a data structure our compiler uses, translated directly
  from the concrete syntax.

- A description of the compiler-facing abstract syntax – in this case, the
  `aexpr`, `cexpr`, and `immexpr` datatypes, which are translated from the
  user-facing abstract syntax.

### Concrete Syntax

The concrete syntax of Boa is:

```
<expr> :=
  | let <bindings> in <expr>
  | if <expr>: <expr> else: <expr>
  | <binop-expr>

<binop-expr> :=
  | <number>
  | <identifier>
  | add1(<expr>)
  | sub1(<expr>)
  | <expr> + <expr>
  | <expr> - <expr>
  | <expr> * <expr>
  | ( <expr> )

<bindings> :=
  | <identifier> = <expr>
  | <identifier> = <expr>, <bindings>
}
```

As in Adder, a `let` expression can have one _or more_ bindings.


### Abstract Syntax

#### User-facing

The abstract syntax of Boa is an OCaml datatype, and corresponds nearly
one-to-one with the concrete syntax.  Here, we've added `E` prefixes to the
constructors, which will distinguish them from the ANF forms later.

```
type prim1 =
  | Add1
  | Sub1

type prim2 =
  | Plus
  | Minus
  | Times

type expr =
  | ELet of (string * expr) list * expr
  | EPrim1 of prim1 * expr
  | EPrim2 of prim2 * expr * expr
  | EIf of expr * expr * expr
  | ENumber of int
  | EId of string
```

#### Compiler-facing

The compiler-facing abstract syntax of Boa splits the above expressions into
three categories

```
type immexpr =
  | ImmNumber of int
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


### Semantics

Numbers, unary operators, let-bindings, and ids have the same semantics as
before.  Binary operator expressions evaluate their arguments and combine them
based on the operator.  If expressions behave similarly to if statements in C:
first, the conditional (first part) is evaluated.  If it is `0`, the else
branch is evaluated.  Otherwise, the then branch is evaluated.

### Examples

```
sub1(5)

# as an expr

EPrim1(Sub1, ENum(5))

# evaluates to

4
```

```
if 5 - 5: 6 else: 8

# as an expr

EIf(EPrim2(Minus, ENum(5), ENum(5)), ENum(6), ENum(8))

# evaluates to

8
```

```
let x = 10, y = 9 in
if (x - y) * 2: x else: y

# as an expr

ELet([("x", ENum(10)), ("y", ENum(9))],
  EIf(EPrim2(Times, EPrim2(Minus, EId("x"), EId("y")), ENum(2)),
      EId("x"),
      EId("y")))
```

## Implementing Boa

### New Assembly Instructions

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


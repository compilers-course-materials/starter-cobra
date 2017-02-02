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

The concrete syntax of Cobra is:

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
- numbers will be represented with a zero in the rightmost bit, as in class.
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

In order to set up the stack properly to call C functions, like `print` and
your error functions, it's necessary to make a few changes to what we
had in Boa.

- **Allocating stack space ahead of time**: At the start of our generated code
  (which we now recognize is a function body participating in a C runtime
  stack), we need to make sure we make enough stack space for all variables we
  create, and reserve that space ahead of time.  To do this, we move `esp` to
  point to a location that is N words away (so N * 4 bytes for us), where N is
  the greatest number of variables we need at once.  This is actually tricky
  to compute to be fully optimal (teaser for later in the semester: by
  “tricky” I mean NP-hard), but it's easy to get an OK heuristic – we can
  compute the maximum depth of nested definitions.

  To do this, we need the `count_vars` function, which we implemented in
  class, so I've provided it.  You need to add instructions to the provided
  spot in `stack_setup` in order to make sure the correct space is allocated
  on the stack by subtracting the right amount from `esp`.
  
- **Using the Base Pointer**: In addition, this means that all variable
  references need to happen from `ebp` rather than from `esp`.  This is
  because `esp` can change while we are pushing arguments onto the stack for
  other function calls, so `ebp` is the place we should trust for consistent
  offsets.
  
- **Participating in the C stack**: As a C function callee (from `main`) and
  caller (of error functions and `print`), our code has some responsibilities.
  First, we need to store the old base pointer upon entry, and update the
  base pointer to hold the current top of the stack (which includes the return
  pointer into main, for example).  This is why the typical top two lines of
  most C functions are:

  ```
  push ebp
  mov ebp, esp
  ```

  Similarly, when we're done with the function, we need to restore the stack
  pointer to its old location, and put the old base pointer value back.  This
  is why the last lines before a `ret` in a C function are often:

  ```
  mov esp, ebp
  pop ebp
  ```

- **Other Responsibilities**: If we were using registers beyond `eax`, `ebp`,
  and `esp`, we'd be responsible for storing some of them as callee, and some
  as caller.  But we're not going to go into those details for this
  assignment.  Since we aren't using those registers, it has no effect on our
  code's behavior.

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

- `HexConst`

    Sometimes it's nice to read things in hex notation as opposed to decimal
    constants.  I've provided a new `HexConst` `arg` that's useful for this
    case.

- `IPush`, `IPop`

    These two instructions manage values on the stack.  `push` adds a value at
    the current location of `esp`, and increments `esp` to point past the
    added value.  `pop` decrements `esp` and moves the value at the location
    `esp` was pointing to into the provided arg.

- `ICall`

    A call does two things:

      - Pushes the next _code_ location onto the stack (just like a `push`),
        which becomes the return pointer
      - Performs an unconditional `jmp` to the provided label

    `call` does not affect `ebp`, which the program must maintain on its own.

- `IShr`, `IShl`: Bit shifting operations

- `IAnd`, `IOr`, `IXor`: Bit masking operations

- `IJo`, `IJno`: Jump to the provided label if the last arithmetic operation
  did/did not overflow

As usual, full summaries of the instructions we use are at [this assembly
guide](http://www.cs.virginia.edu/~evans/cs216/guides/x86.html).


### Testing Functions

These are the same as they were for Boa.  ANF is provided, and hasn't changed
aside from the addition of new primitives and `EBool`.  So your tests should
focus on `te` and `t` tests.

An old friend is helpful here, too: `valgrind`.  You can run `valgrind
output/some_test.run` in order to get a little more feedback on tests that
fail with `-10` as their exit code (which usually indicates a segfault).  This
can sometimes tip you off quite well as to how memory is off, since sometimes
you'll see code trying to jump to a constant that's in your code, or other
obvious tells that there's something off in the stack.  Also, if you've done
all your stack management correctly, `valgrind` will report a clean run for
your program!

### Recommended TODO List

Here's an order in which you could consider tackling the implementation:

1. Fix the `print` function in `main.c` so that it prints out the right
   output.  It will need to check for the tag using C bitwise operators,
   and use `printf` to print the right value.
2. Take a first shot at figuring out how to increase the stack appropriately
   by using `count_vars` and adding to `stack_setup`.
3. Fill in the `CPrim1` case for everything but `print`, and figure out how to
   check for errors, and call the "non-number" error reporting function.  Test
   as you go.  Be aware that if the function call segfaults, it may be because
   you need to refine step 2.
4. Implement `print` by compiling it to with a call to the `print` after
   pushing appropriate arguments.  Be aware that if the call doesn't work, it
   may be because of step 2 again.  Test as you go; be aware that you should
   test interesting sequences of `print` expressions and let-bindings to make
   sure your stack integrity is good before and after calls.
3. Fill in all of the `CPrim2` cases, using the error-reporting from the last
   step.  Test as you go.
5. Complete the `if` case and test as you go.


## Handing In

A complete implementation is due by Thursday, February 25 at 11:59pm.


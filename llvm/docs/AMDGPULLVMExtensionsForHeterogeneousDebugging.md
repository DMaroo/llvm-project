# AMDGPU LLVM Extensions for Heterogeneous Debugging <!-- omit in toc -->

- [Introduction](#introduction)
- [High-Level Goals](#high-level-goals)
- [Motivation](#motivation)
- [Changes from LLVM Language Reference Manual](#changes-from-llvm-language-reference-manual)
  - [External Definitions](#external-definitions)
    - [Well-Formed](#well-formed)
    - [Type](#type)
    - [Value](#value)
  - [Location Description](#location-description)
  - [LLVM Debug Information Expressions](#llvm-debug-information-expressions)
  - [LLVM Expression Evaluation Context](#llvm-expression-evaluation-context)
  - [Location Descriptions Of LLVM Entities](#location-descriptions-of-llvm-entities)
  - [High Level Structure](#high-level-structure)
    - [Global Variable](#global-variable)
  - [Metadata](#metadata)
    - [`DIObject`](#diobject)
      - [`DIVariable`](#divariable)
        - [`DIGlobalVariable`](#diglobalvariable)
        - [`DILocalVariable`](#dilocalvariable)
      - [`DIFragment`](#difragment)
    - [`DICompositeType`](#dicompositetype)
    - [`DILifetime`](#dilifetime)
    - [`DICompileUnit`](#dicompileunit)
    - [`DIExpr`](#diexpr)
      - [`DIOpReferrer`](#diopreferrer)
      - [`DIOpArg`](#dioparg)
      - [`DIOpConstant`](#diopconstant)
      - [`DIOpConvert`](#diopconvert)
      - [`DIOpReinterpret`](#diopreinterpret)
      - [`DIOpOffset`](#diopoffset)
      - [`DIOpBitOffset`](#diopbitoffset)
      - [`DIOpComposite`](#diopcomposite)
      - [`DIOpAddrOf`](#diopaddrof)
      - [`DIOpDeref`](#diopderef)
      - [`DIOpRead`](#diopread)
      - [`DIOpAdd`](#diopadd)
      - [`DIOpSub`](#diopsub)
      - [`DIOpMul`](#diopmul)
      - [`DIOpDiv`](#diopdiv)
      - [`DIOpShr`](#diopshr)
      - [`DIOpShl`](#diopshl)
  - [Intrinsics](#intrinsics)
    - [`llvm.dbg.def`](#llvmdbgdef)
    - [`llvm.dbg.kill`](#llvmdbgkill)
- [Examples](#examples)
  - [Variable Located In An `alloca`](#variable-located-in-an-alloca)
  - [Variable Promoted To An SSA Register](#variable-promoted-to-an-ssa-register)
  - [Implicit Pointer Location Description](#implicit-pointer-location-description)
  - [Variable Broken Into Two Scalars](#variable-broken-into-two-scalars)
  - [Further Decomposition Of An Already SRoA'd Variable](#further-decomposition-of-an-already-sroad-variable)
  - [Multiple Live Ranges For A Single Variable](#multiple-live-ranges-for-a-single-variable)
  - [Global Variable Broken Into Two Scalars](#global-variable-broken-into-two-scalars)
  - [Induction Variable](#induction-variable)
  - [Proven Constant](#proven-constant)
  - [Common Subexpression Elimination (CSE)](#common-subexpression-elimination-cse)
- [References](#references)
- [Other Ideas](#other-ideas)
  - [Translating To DWARF](#translating-to-dwarf)
  - [Translating To PDB (CodeView)](#translating-to-pdb-codeview)
  - [Comparison With GCC](#comparison-with-gcc)
  - [Example Ideas](#example-ideas)
    - [Spilling](#spilling)
    - [Divergent Lane PC](#divergent-lane-pc)
    - [Simultaneous Lifetimes In Multiple Places](#simultaneous-lifetimes-in-multiple-places)
    - [File Scope Globals](#file-scope-globals)
    - [Lds Variables](#lds-variables)
    - [Make Sure The Non-SSA MIR Form Works With def/kill Scheme](#make-sure-the-non-ssa-mir-form-works-with-defkill-scheme)
  - [Integer Fragment IDs](#integer-fragment-ids)
    - [Variable Broken Into Two Scalars](#variable-broken-into-two-scalars-1)
    - [Further Decomposition Of An Already SRoA'd Variable](#further-decomposition-of-an-already-sroad-variable-1)
    - [Multiple Live Ranges For A Fragment](#multiple-live-ranges-for-a-fragment)

# Introduction

As described in the [DWARF Extensions For Heterogeneous Debugging][18] (the
"DWARF extensions"), AMD has been working to support debugging of heterogeneous
programs. This document describes changes to the LLVM representation of debug
information (the "LLVM extensions") required to support the DWARF extensions.
These LLVM extensions continue to support previous versions of the DWARF
standard, including DWARF 5 without extensions, as well as other debug formats
which LLVM currently supports, such as CodeView.

The LLVM extensions do not constitute a direct implementation of all concepts
from the DWARF extensions, although wherever reasonable the most fundamental
aspects are kept identical. The concepts defined in the DWARF extensions which
are used directly in the LLVM extensions with their semantics unchanged are
enumerated in the [External Definitions](#external-definitions) section below.

The most significant departure from the DWARF extensions is in the
consolidation of expression evaluation stack entries. In the DWARF extensions,
each entry on the expression evaluation stack contains either a typed value or
an untyped location description. In the LLVM extensions, each entry on the
expression evaluation stack instead contains a pair of a location description
and a type.

Additionally, the concept of a "generic type", used as a default when a type is
needed but not stated explicitly, is eliminated. Together these changes imply
that the concrete set of operations available differ between the DWARF and LLVM
extensions.

These changes are made to remove redundant representations of semantically
equivalent expressions, which simplifies the work the compiler must do when
updating debug information expressions to reflect code transformations. This is
possible in the LLVM extensions as there is no requirement for backwards
compatibility, nor any requirement that the intermediate representation of debug
information conform to any particular external specification. Consequently we
are able to increase the accuracy of existing debug information, while also
extending the debug information to cover cases which were previously not
described at all.

# High-Level Goals

There are several specific cases where our approach will allow for more
accurate or more complete debug information than would be feasible
with only incremental changes to the existing approach.

- Support describing the location of induction variables. LLVM currently has a
  new implementation of partial support for expressions which depend on
  multiple LLVM values, although it is currently limited exclusively to a
  subset of cases for induction variables. This support is also inherently
  limited as it can only refer directly to LLVM values, not to source variables
  symbolically. This means it is not possible to describe an induction variable
  which, for example, depends on a variable whose location is not static over
  the whole lifetime of the induction variable.
- Support describing the location of arbitrary expressions over scalar-replaced
  aggregate values, even in the face of other dependant expressions. LLVM
  currently must drop debug information when any expression would depend on a
  composite value.
- Support describing all locations of values which are live in multiple machine
  locations at the same instruction. LLVM currently must pick only one such
  location to describe. This means values which are resident in multiple places
  must be conservatively marked read-only, even when they could be read-write
  if all of their locations were reported accurately.
- Accurately support describing the range over which a given location is active.
  LLVM currently pessimizes debug information as there is no rigorous means to
  limit the range of a described location.
- Support describing the factoring of expressions. This allows features such as
  DWARF procedures to be used to reduce the size of debug information. Factoring
  can also be more convenient for the compiler to describe lexically nested
  information such as program location for inactive lanes in divergent control
  flow.

# Motivation

The original motivation for this proposal was to make the minimum required
changes to the existing LLVM representation of debug information needed to
support the [DWARF Extensions For Heterogeneous Debugging][18]. This involved an
evaluation of the existing debug information for machine locations in LLVM,
which uncovered some hard-to-fix bugs rooted in the incidental complexity and
inconsistency of LLVM's debug intrinsics and expressions.

Attempting to address these bugs in the existing framework proved more difficult
than expected. It became apparent that the shortcomings of the existing solution
were a direct consequence of the complexity, ambiguity, and lack of
composability encountered in DWARF.

With this in mind, we revisited the DWARF extensions to see if they could inform
a more tractable design for LLVM. We had already worked to address the
complexity and ambiguity of DWARF by defining a formalization for its expression
language, and improved the composability by unifying values and location
descriptions on the evaluation stack. Together, these changes also increased the
expressiveness of DWARF. Using similar ideas in LLVM, allowed us to support
additional real world cases, and describe existing cases with greater accuracy.

This led us to start from the DWARF extensions and design a new set of debug
information representations. This was very heavily influenced by prior art in
LLVM, existing RFCs, mailing list discussions, review comments, and bug reports,
without which we would not have been able to make this proposal. Some of the
influences include:

- The use of intrinsics to capture local LLVM values keeps the proposal close to
  the existing implementation, and limits the incidental work needed to support
  it for the reasons outlined in [[LLVMdev] [RFC] Separating Metadata from the
  Value hierarchy][02].
- Support for debug locations which depend on multiple LLVM values is required
  by several optimizations, including expressing induction variables, which is
  the motivation for [D81852 [DebugInfo] Update MachineInstr interface to better
  support variadic DBG_VALUE instructions][06].
- Our solution also generalizes the notion of "fragments" to support composing
  with arbitrary expressions. For example, fragmentation can be represented even
  in the presence of arithmetic operators, as occurs in [D70601 Disallow
  DIExpressions with shift operators from being fragmented][07].
- The desire to support multiple concurrent locations for the same variable is
  described in detail in [[llvm-dev] Proposal for multi location debug info
  support in LLVM IR][03] (continued at [[llvm-dev] Proposal for multi location
  debug info support in LLVM IR][04]) and [Multi Location Debug Info support for
  LLVM][05]. Support for overlapping location list entries was added in DWARF 5.
- Bugs, like [Bug 40628 - [DebugInfo@O2] Salvaged memory loads can observe
  subsequent memory writes][09] which was partially worked around in [D57962
  [DebugInfo] PR40628: Don't salvage load operations][08], often result from
  passes being unable to accurately represent the relationship between source
  variables. Our approach supports encoding that information in debug
  information in a mechanical way, with straightforward semantics.
- Use of `distinct` for our new metadata nodes is motivated by use cases
  similar to those in [[LLVMdev] [RFC] Separating Metadata from the Value
  hierarchy (David Blaikie)][01] where the content of a node is not sufficient
  context to unique it.

Recognizing that the least error prone place to make changes to debug
information is at the point where the underlying code is being transformed, we
biased the representation for this case.

The expression evaluation stack contains uniform pairs of location description
and type, such that all operations have well-defined semantics and no
side-effects on the evaluation of the surrounding expression. These same
semantics apply equally throughout the compiler. This allows for referentially
transparent updates which can be reasoned about in the context of a single
operation and its inputs and outputs, rather than the space of all possible
surrounding operations and dependant expressions.

By eliminating any implicit expression inputs or operations, and constraining
the state space of expressions using well-formedness rules, it is always
unambiguous whether a given transformation is valid and semantics-preserving,
without ever having to consider anything outside of the expression itself.

Designing around a separation of concerns regarding expression modification and
simplification allows each update to the debug information to introduce
redundant or sub-optimal expressions. To address this, an independent
"optimizer" can simplify and canonicalize expressions. As the expression
semantics are well-defined, an "optimizer" can be run without specific
knowledge of the changes made by any one pass or combination of passes.

Incorporating a means to express "factoring", or the definition of one
expression in terms of one or more other expressions, makes "shallow" updates
possible, bounding the work needed for any given update. This factoring is
usually trivial at the time the expression is created, but expensive to infer
later. Factored expressions can result in more compact debug information by
leveraging dynamic calling of DWARF procedures in DWARF 5, and we expect to be
able to use factoring for other purposes, such as debug information for
[divergent control flow][24]. It is possible to statically "flatten" this
factored representation later, if required by the debug information format
being emitted, or if the emitter determines it would be more profitable to do
so.

Leveraging the DWARF extensions as a foundation, the concept of a location
description is used as the fundamental means of recording debug information. To
support this, every LLVM entity which can be referenced by an expression has a
well-defined location description, and is referred to by expressions in an
explicit, referentially transparent manner. This makes updates to reflect
changes in the underlying LLVM representation mechanical, robust, and simple.
Due to factoring, these updates are also more localized, as updates to an
expression are transparently reflected in all dependant expressions without
having to traverse them, or even be aware of their existence.

Without this factoring, any changes to an LLVM entity which is effectively used
as an input to one or more expressions must be "macro-expanded" at the time
they are made, in each place they are referenced. This in turn inhibits the
valid transformations the context-insensitive "optimizer" can safely perform,
as perturbing the macro-expanded expression for an LLVM entity makes it
impossible to reflect future changes to that entity in the expression. Even if
this is considered acceptable, once expressions begin to effectively depend on
other expressions (for example, in the description of induction variables,
where one program object depends on multiple other program objects) there is no
longer a bound on the recursive depth of expressions which must be visited for
any given update, making even simple updates expensive in terms of compiler
resources. Furthermore, this approach requires either a combinatorial explosion
of expressions to describe cases when the live ranges of multiple program
objects are not equal, or the dropping of debug information for all but one
such object. None of these tradeoffs were considered acceptable.

# Changes from LLVM Language Reference Manual

This section defines the changes from the [LLVM Language Reference Manual][10].

## External Definitions

Some required concepts are defined outside of this document. We reproduce some
parts of those definitions, along with some expansion on their relationship to
this proposal and any extensions.

### Well-Formed

The definition of "well-formed" is the one from the section titled
[Well-Formedness in the LLVM Language Reference Manual][11].

### Type

The definition of "type" is the one from the [LLVM Language Reference
Manual][12].

### Value

The definition of "value" is the one from the [LLVM Language Reference
Manual][10].

## Location Description

The definitions of "location description", "single location description", and
"location storage" are the ones from the section titled [DWARF Location
Description][21] in the DWARF Extensions For Heterogeneous Debugging.

A location description can consist of one or more single location descriptions.
A single location description specifies a location storage and bit offset. A
location storage is a linear stream of bits with a fixed size.

The storage encompasses memory, registers, and literal/implicit values.

Zero or more single location descriptions may be active for a location
description at the same instruction.

## LLVM Debug Information Expressions

_[Note: LLVM expressions derive much of their semantics from the DWARF
expressions described in the [AMDGPU Dwarf Expressions][19].]_

LLVM debug information expressions ("LLVM expressions") specify a typed
location. _[Note: Unlike DWARF expressions, they cannot directly describe how to
compute a value. Instead, they are able to describe how to define an implicit
location description for a computed value.]_

If the evaluation of an LLVM expression does not encounter an error, then it
results in exactly one pair of location description and type.

If the evaluation of an LLVM expression encounters an error, the result is an
evaluation error.

If an LLVM expression is not well-formed, then the result is undefined.

The following sections detail the rules for when a LLVM expression is not
well-formed or results in an evaluation error.

## LLVM Expression Evaluation Context

An LLVM expression is evaluated in a context that includes the same context
elements as described in [DWARF Expression Evaluation Context][22] with the
following exceptions.  The _current result kind_ is not applicable as all LLVM
expressions are location descriptions.  The _current object_ and _initial stack_
are not applicable as LLVM expressions have no implicit inputs.

## Location Descriptions Of LLVM Entities

The notion of location storage is extended to include the abstract LLVM entities
of _values_, _global variables_, _stack slots_, _virtual registers_, and
_physical registers_. In each case the location storage conceptually holds the
value of the corresponding entity.

For global variables, the location storage corresponds to the SSA value for the
address of the global variable as is the case when referenced in LLVM IR.

In addition, an implicit address location storage kind is defined. The size of
the storage matches the size of the type for the address.  The value in the
storage is only meaningful when used in its entirety by a `DIOpDeref` operation,
which yields a location description for the entity that the address references.
_[Note: This is a generalization to the implicit pointer location description of
DWARF 5.]_

Location descriptions can be associated with instances of any of these location
storage kinds.

## High Level Structure

### Global Variable

The definition of "global variable" is the one from the [LLVM Language Reference
Manual][13] with the following addition.

The optional `dbg.default` metadata attachment can be used to specify a
`DILifetime` as the default lifetime segment of the global variable.

_[Note: Global variables in LLVM exist for the duration of the program. The
default lifetime can be used to specify the location for that entire duration.
However, the location of a global variable may exist in a different location for
a given part of a subprogram. This can be expressed using bounded lifetime
segments. If the default lifetime segment is specified, it only applies for the
program locations not covered by a bounded lifetime segment. If the default
lifetime segment is not specified, and no bounded lifetime segment covers the
program location, then the global variable location is the undefined location
description for that program location.]_

## Metadata

An abstract metadata node exists only to abstractly specify common aspects of
derived node types, and to refer to those derived node types generally.
Abstract node types cannot be created directly.

### `DIObject`

A `DIObject` is an abstract metadata node.

Represents the identity of a program object used to hold data. There are several
kinds of program objects.

#### `DIVariable`

A `DIVariable` is a `DIObject` which represents the identity of a source
language program variable. If is also used for non-source language program
variables that should be exposed to the debugger by including `DIFlagArtificial`
in the `flags` field.

##### `DIGlobalVariable`

A `DIGlobalVariable` is a `DIVariable` which represents the identity of a global
source language program variable. See [DIGlobalVariable][16].

##### `DILocalVariable`

A `DILocalVariable` is a `DIVariable` which represents the identity of a local
source language program variable. See [DILocalVariable][15].

#### `DIFragment`

```llvm
distinct !DIFragment()
```

A `DIFragment` is a `DIObject` which represents the identity of a non-source
language variable program object, or a piece of a source language or non-source
language program variable. These are used in the definition of other `DIObject`s
and are not exposed as named variables for the debugger.

_[Note: A non-source language program variable may be introduced by the
compiler. These may be used in expressions needed for describing debugging
information required by the debugger. They may be introduced to factor the
definition of part of a location description shared by other location
descriptions for convenience or to permit more compact debug information. They
can also be introduced to allow the compiler to specify multiple lifetime
segments for the single location description referenced for a default or type
lifetime segment.]_

_[Note: In DWARF a `DIFragment` can be represented using a
`DW_TAG_dwarf_procedure` DIE.]_

_[Example: An implicit variable needed for calculating the size of a dynamically
sized array.]_

_[Example: The fragments into which SRoA splits a source language variable. The
location description of the source language variable would then use an
expression that combines the fragments appropriately.]_

_[Example: Divergent control flow can be described by factoring information
about how to determine active lanes by lexical scope, which results in more
compact debug information.]_

_[Note: `DIFragment` replaces using `DW_OP_LLVM_fragment` in the current LLVM IR
`DIExpression` operations. This simplifies updating expressions which now purely
describe the location description. Using `DIFragment` has other benefits such as
expression factoring.]_

### `DICompositeType`

A `DICompositeType` represents the identity of a composite source program type.
See [DICompositeType][14].

For `DICompositeType` with a `tag` field of `DW_TAG_array_type`, the optional
`dataLocation`, `associated`, and `rank` fields specify a `DILifetime` as a type
lifetime segment. _[Note: The `argObjects` of the type lifetime segment can be
used to specify other `DIVariable`s if necessary.]_

### `DILifetime`

```llvm
distinct !DILifetime(object: !DIObject, location: !DIExpr, argObjects: {!DIObject,...})
```

Represents a lifetime segment of a data object. A lifetime segment specifies a
location description expression, references a data object either explicitly or
implicitly, and defines when the lifetime segment applies. The location
description of a data object is defined by the, possibly empty, set of lifetime
segments that reference it.

There are four kinds of lifetime segment:

- A _type lifetime segment_ is one referenced by a `DICompositeType`. If
  referenced by more than one `DICompositeType` it is not well-formed. See
  [`DICompositeType`](#dicompileunit).
- A _default lifetime segment_ is one referenced by the `dbg.default` field of a
  global variable. If referenced by more than one global variable it is not
  well-formed. See [global variable](#global-variable).
- A _bounded lifetime segment_ is one referenced by the first argument of a call
  to the `llvm.dbg.def` or `llvm.dbg.kill` intrinsic. If not referenced by
  exactly one call to the `llvm.dbg.def` intrinsic it is not well-formed. See
  [`llvm.dbg.def`](#llvmdbgdef) and  [`llvm.dbg.kill`](#llvmdbgkill).
- A _computed lifetime segment_ is one not referenced.

A `DILifetime` which does not match exactly one of the above kinds is not
well-formed.

The `object` field is required for a default, bounded, and computed lifetime
segment. It explicitly specifies the data object of the lifetime segment.

The `object` field must be omitted for a type lifetime segment. The data object
is implicitly the instance of the type being accessed with the lifetime segment.

A bounded lifetime segment is only active if the current program location's
instruction is in the range covered. The call to the `llvm.dbg.def` intrinsic
which specifies the `DILifetime` is the start of the range, which extends along
all forward control flow paths until either a call to a `llvm.dbg.kill`
intrinsic which specifies the same `DILifetime`, or to the end of an exit basic
block.

The location description of a `DIObject` is a function of the current program
location's instruction and the, possibly empty, set of lifetime segments with an
`object` field that references the `DIObject`:

- If there is a computed lifetime segment, then the location description is
  comprised of the location description of the computed lifetime segment. If the
  `DIObject` has any other lifetime segments it is not well-formed.
- If the current program location is defined, and any bounded lifetime segment
  is active, then the location description is comprised of all of the location
  descriptions of all active bounded lifetime segments.
- Otherwise, if there is a default lifetime segment, then the location
  description is comprised of the location description of that default lifetime
  segment.
- Otherwise, the location description is the undefined location description.

_[Note: When multiple bounded lifetime segments for the same DIObject are active
at a given instruction, it describes the situation where an object exists
simultaneously in more than one place. For example, if a variable exists both in
memory and in a register after the value is spilled but before the register is
clobbered.]_

_[Note: A `DIObject` with no `DILifetime`s has an undefined location
description. If the `argObjects` field of a `DILifetime` references such a
`DIObject` then the argument can be removed and the `location` expression
updated to use the `DIOpConstant` with an `undef` value.]_

The optional `argObjects` field specifies a tuple of zero or more input
`DIObject`s to the expression specified by the `location` field. Omitting the
`argObjects` field is equivalent to specifying it to be the empty tuple.

The required `location` field specifies the expression which evaluates to the
location description of the lifetime segment. The expression may refer to the
arguments specified by the `argObjects` field using their position in the tuple.

The expression may refer to the lifetime segment's _referrer_ (see
[`DIOpReferrer`](#diopreferrer)):

- The referrer of a type lifetime segment is defined as the object that is being
  accessed using the type.
- The referrer of a default lifetime segment is defined as the global variable
  that references it.
- The referrer of a bounded lifetime segment is the LLVM entity specified by the
  second argument of the call to the `llvm.dbg.def` intrinsic that references
  it.
- A computed lifetime segment does not have a referrer and the expression is not
  well-formed if it uses the `DIOpReferrer` operation.

The reachable lifetime graph is transitively defined as the graph formed by the
edges:

- from each `DIVariable` (termed root nodes and also termed reachable
  `DIObject`s) to the `DILifetime`s that reference them (termed reachable
  `DILifetime`s)
- from each reachable `DILifetime` to the `DIObject`s referenced by their
  `argObjects` fields (termed reachable `DIObject`s).
- from each reachable `DIObject` to the  reachable `DILifetime`s that reference
  them (termed reachable `DILifetime`s)

If the reachable lifetime graph has any cycles or if any `DILifetime` or
`DIFragment` are not in the reachable lifetime graph then then the metadata is
not well-formed.

When the LLVM IR is serialized to bit code, all `DILifetime` and `DIFragment` in
the reachable lifetime graph are retained even if not accessible by following
references from root nodes.

_[Note: In current debug information the `DILifetime` information is part of the
debug intrinsics. A new lifetime for an object is defined by using a debug
intrinsic to start a new lifetime. This means an object can have at most one
active lifetime for any given program location. Separating the lifetime
information into a separate metadata node allows there to be multiple debug
intrinsics to begin different lifetime segments over the same program locations.
It also allows a debug intrinsic to indicate the end of the lifetime by
referencing the same lifetime as the intrinsic that started it.]_

### `DICompileUnit`

A `DICompileUnit` represents the identity of source program compile unit. See
[DICompileUnit][17].

All `DIGlobalVariable` global variables of the compile unit must be referenced
by the `globals` field of the `DICompileUnit`.

_[Note: This is different to the current debug information in which the
`globals` field of `DICompileUnit` references `DIGlobalVariableExpression`.
`DIGlobalVariableExpression` is no longer used and is replaced by using the
`DILifetime` for both local and global variables.]_

> TODO: Should `DICompileUnit` have a `retainedNodes` field added to use to
> retain computed lifetime segment `DILifetime` nodes that are in the active
> lifetime graph but not reachable from a root node? If so, should active
> computed lifetime segments be put on the `retainedNodes` field of the
> `DICompileUnit` if reachable from a `DIGlobalVariable`, and the
> `retainedNodes` field of the `DISubprogram`s corresponding to
> `DILocalVariable`s from which it is reachable?

### `DIExpr`

```llvm
!DIExpr(DIOp, ...)
```

Represents an expression, which is a sequence of zero or more operations defined
in the following sections.

The evaluation of an expression is done in the context of an associated
`DILifetime` that has a `location` field that references it.

The evaluation of the expression is performed on a stack where each stack
element is a tuple of a type and a location description. If the stack does not
have a single element after evaluation then the expression is not well-formed.
The evaluation is the typed location description of the single resulting stack
element.

> TODO: Maybe operators should specify their input type(s)? It do not match what
> DWARF does currently. Such types cannot trivially be used to enforce type
> correctness since the expression language is an arbitrary stack, and in
> general the whole expression has to be evaluated to determine the inputs types
> to a given operation.

Each operation definition begins with a specification which describes the
parameters to the operation, the entries it pops from the stack, and the entries
it pushes on the stack. The specification is accepted by the following modified
BNF grammar, where `[]` denotes character classes, `*` denotes zero-or-more
repetitions of a term, and `+` denotes one-or-more repetitions of a term.

```bnf
         <specification> ::= <syntax> <stack-effects>

                <syntax> ::= <operation-identifier> "(" <parameter-binding-list> ")"
<parameter-binding-list> ::= ""
                             | <parameter-binding>  ( "," <parameter-binding-list> )+
     <parameter-binding> ::= <binding-identifer> ":" <parameter-binding-kind>
<parameter-binding-kind> ::= "type" | "index" | "literal" | "addrspace"

         <stack-effects> ::= "{" <stack-binding-list> "->" <stack-binding-list> "}"
    <stack-binding-list> ::= ""
                             | <stack-binding> ( " " <stack-binding-list> )+
         <stack-binding> ::= <binding-identifer> ":" <binding-identifer>

   <operation-identifer> ::= [A-Za-z]+
     <binding-identifer> ::= [A-Z][A-Z0-9]* "'"*
```

The `<syntax>` describes the LLVM IR concrete syntax of the operation in an
expression.

The `<parameter-binding-list>` defines positional parameters to the operation.
Each parameter in the list has a `<binding-identifer>` which binds to the
argument passed via the parameter, and a `<parameter-binding-kind>` which
defines the kind of arguments accepted by the parameter.

The possible parameter kinds are:

- `type`: An LLVM type.
- `index`: A non-negative literal integer.
- `literal`: An LLVM literal value expression.
- `addrspace`: An LLVM target-specific address space identifier.

The `<stack-effects>` describe the effect of the operation on the stack. The
first `<stack-binding-list>` describes the "inputs" to the operation, which are
the entries it pops from the stack in the left-to-right order. The second
`<stack-binding-list>` describes the "outputs" of the operation, which are the
entries it pushes onto the stack in a right-to-left order. In both cases the top
stack element comes first on the left.

If evaluation can result in a stack with fewer entries than required by an
operation then the expression is not well-formed.

Each `<stack-binding>` is a pair of `<binding-identifier>`s. The first
`<binding-identifier>` binds to the location description of the stack entry.
The second `<binding-identifier>` binds to the type of the stack entry.

Each `<binding-identifier>` identifies a meta-syntactic variable. When reading
the `specification` left-to-right, the first mention binds the meta-syntactic
variable to an entity, subsequent mentions are an assertion that they are the
identical bound entity. If evaluation can result in parameters and stack inputs
that do not conform to the assertions then the expression is not well-formed.
The assertions for stack outputs define post-conditions of the operation output.

The remaining body of the definition for an operation may reference the bound
metasyntactic variable identifiers from the specification, and may define
additional metasyntactic variables following the same left-to-right binding
semantics.

In the operation definitions, the operator `bitsizeof` computes the size in bits
of the given LLVM type, rather than the size in bytes.

#### `DIOpReferrer`

```llvm
DIOpReferrer(T:type)
{ -> L:T }
```

`L` is the location description of the referrer `R` of the associated lifetime
segment `LS`. If `LS` is a computed lifetime segment then the expression is
ill-formed.

`bitsizeof(T)` must equal `bitsizeof(R)`, otherwise the expression is not
well-formed.

#### `DIOpArg`

```llvm
DIOpArg(N:index, T:type)
{ -> L:T }
```

`L` is the location description of the `N`th element, `O`, of the `argObjects`
field `F` of the associated lifetime segment `LS`.

If `F` is not a tuple of `DIObject`s with at least `N` elements then the
expression is not well-formed. `bitsizeof(T)` must equal `bitsizeof(O)`,
otherwise the expression is not well-formed.

_[Note: As with any location description, `L` may consist of multiple single
location descriptions. For example, this will occur if the `O` has more than one
bounded lifetime segment active. By definition these must all describe the same
object. This implies that when reading from them, any of the single location
descriptions may be chosen, whereas when writing to them the write must be
performed into each single location description.]_

#### `DIOpConstant`

```llvm
DIOpConstant(T:type V:literal)
{ -> L:T }
```

`V` is a literal value of type `T` or `undef`.

If `V` is `undef` then `L` comprises one undefined location description `IL`.

Otherwise, `L` comprises one implicit location description `IL`. `IL` specifies
implicit location storage `ILS` and offset 0. `ILS` has value `V` and size
`bitsizeof(T)`.

#### `DIOpConvert`

```llvm
DIOpConvert(T':type)
{ L:T -> L':T' }
```

Creates a value `V'` of type `T'` by

Reads `bitsizeof(T)` bits from `L` as value `V` of type `T` and converts it to
value `V'` of type `T'`.

The expression is not well-formed if `T` or `T'` are not equivalent to
`DIBasicType` types. The conversions match those performed by DWARF the
`DW_OP_convert` operation.

`L'` comprises one implicit location description `IL'`. `IL'` specifies implicit
location storage `ILS'` and offset 0. `ILS'` has value `V'` and size
`bitsizeof(T')`.

#### `DIOpReinterpret`

```llvm
DIOpReinterpret(T':type)
{ L:T -> L:T' }
```

Reads `bitsizeof(T)` bits from `L` and treats the bits as value `V'` of type
`T'`.

If `bitsizeof(T)` is not equal to `bitsizeof(T')` then the expression is not well-formed.

`L'` comprises one implicit location description `IL'`. `IL'` specifies implicit
location storage `ILS'` and offset 0. `ILS'` has value `V'` and size
`bitsizeof(T')`.

#### `DIOpOffset`

```llvm
DIOpOffset()
{ B:I L:T -> L':T }
```

`L'` is `L`, but updated by adding `VB` * 8 to its bit offset. `VB` is the value
obtained by reading `bitsizeof(U)` bits from `B` as an integral type `I`. `I`
may be a signed or unsigned integral type.

If `I` is not an integral type then the expression is not well-defined.

#### `DIOpBitOffset`

```llvm
DIOpBitOffset()
{ B:I L:T -> L':T }
```

`L'` is `L`, but updated by adding `VB` to its bit offset. `VB` is the value
obtained by reading `bitsizeof(U)` bits from `B` as an integral type `I`. `I`
may be a signed or unsigned integral type.

If `I` is not an integral type then the expression is not well-defined.

#### `DIOpComposite`

```llvm
DIOpComposite(N:index, T:type)
{ L1:T1 L2:T2 ... LN:TN -> L:T }
```

`L` comprises one complete composite location description `CL` with offset 0.
The location storage associated with `CL` is comprised of `N` parts each of bit
size `bitsizeof(TM)` starting at the location storage specified by `LM`. The
parts are concatenated starting at offset 0 in the order with `M` from `N` to 1
and no padding between the parts.

If the sum of `bitsizeof(TM)` for `M` from 1 to `N` does not equal
`bitsizeof(T)` then the expression is not well-formed.

#### `DIOpAddrOf`

```llvm
DIOpAddrOf(N:addrspace)
{ L:T -> L':T' }
```

`L'` comprises one implicit address location description `IAL`. `T'` is a
pointer to `T` in address space `N`. `IAL` specifies implicit address location
storage `IALS` and offset 0.

`IALS` is `bitsizeof(T')` bits and conceptually holds a reference to the storage
that `L` denotes. If `DIOpDeref` is applied to the resulting `L':T'` then it
will result in `L:T`. If any other operation is applied then the expression is
not well-formed.

_[Note: `DIOpAddrOf` can be used for any location description kind of 'L', not
just memory location descriptions.]_

_[Note: DWARF only supports creating implicit pointer location descriptors for
variables or DWARF procedures. It does not support creating them for an
arbitrary location description expression. The examples below cover the current
LLVM optimizations and only use `DIOpAddrOf` applied to `DIOpReferrer`,
`DIOPArg`, and `DIOpConstant`. All these cases can map onto existing DWARF in a
straightforward manner. There would be more complexity if `DIOpAddrOf` was used
in other situations. Such usage could either be addressed by dropping debug
information as LLVM currently does in numerous situations, or by adding
additional DWARF extensions.]_

#### `DIOpDeref`

```llvm
DIOpDeref()
{ L:T -> L':T' }
```

`T` is a pointer to `T'` in address space `N`.

If `T` is not a pointer type then the expression is not well-formed.

If `L:T` was produced by a `DIOpAddrOf` operation then see
[`DIOpAddrOf`](#DIOpAddrOf).

Otherwise, `L'` comprises one memory location description `MLD`. `MLD` specifies
bit offset `A` and the memory location storage corresponding to address space
`N`. `A` is the value obtained by reading `bitsizeof(T)` bits from `L` and
multiplying by 8.

#### `DIOpRead`

```llvm
DIOpRead()
{ L:T -> L':T }
```

`L'` comprises one implicit location description `IL`. `IL` specifies implicit
location storage `ILS` and offset 0. `ILS` has value `V` and size
`bitsizeof(T)`.

`V` is the value of type `T` obtained by reading `bitsizeof(T)` bits from `L`.

#### `DIOpAdd`

```llvm
DIOpAdd()
{ L1:T L2:T -> L:T }
```

`V1` is the value of type `T` obtained by reading `bitsizeof(T)` bits from `L1`.
`V2` is the value of type `T` obtained by reading `bitsizeof(T)` bits from `L2`.

`L` comprises one implicit location description `IL`. `IL` specifies implicit
location storage `ILS` and offset 0. `ILS` has value `V2 + V1` and size
`bitsizeof(T)`.

#### `DIOpSub`

```llvm
DIOpSub()
{ L1:T L2:T -> L:T }
```

`V1` is the value of type `T` obtained by reading `bitsizeof(T)` bits from `L1`.
`V2` is the value of type `T` obtained by reading `bitsizeof(T)` bits from `L2`.

`L` comprises one implicit location description `IL`. `IL` specifies implicit
location storage `ILS` and offset 0. `ILS` has value `V2 - V1` and size
`bitsizeof(T)`.

#### `DIOpMul`

```llvm
DIOpMul()
{ L1:T L2:T -> L:T }
```

`V1` is the value of type `T` obtained by reading `bitsizeof(T)` bits from `L1`.
`V2` is the value of type `T` obtained by reading `bitsizeof(T)` bits from `L2`.

`L` comprises one implicit location description `IL`. `IL` specifies implicit
location storage `ILS` and offset 0. `ILS` has value `V2 * V1` and size
`bitsizeof(T)`.

#### `DIOpDiv`

```llvm
DIOpDiv()
{ L1:T L2:T -> L:T }
```

`V1` is the value of type `T` obtained by reading `bitsizeof(T)` bits from `L1`.
`V2` is the value of type `T` obtained by reading `bitsizeof(T)` bits from `L2`.

`L` comprises one implicit location description `IL`. `IL` specifies implicit
location storage `ILS` and offset 0. `ILS` has value `V2 / V1` and size
`bitsizeof(T)`.

#### `DIOpShr`

```llvm
DIOpShr()
{ L1:T L2:T -> L:T }
```

`V1` is the value of type `T` obtained by reading `bitsizeof(T)` bits from `L1`.
`V2` is the value of type `T` obtained by reading `bitsizeof(T)` bits from `L2`.

`L` comprises one implicit location description `IL`. `IL` specifies implicit
location storage `ILS` and offset 0. `ILS` has value `V2 >> V1` and size
`bitsizeof(T)`. If `T` is an unsigned integral type then the result is filled
with 0 bits. If `T` is a signed integral type then the result is filled with the
sign bit of `V1`.

If `T` is not an integral type the expression is not well-formed.

#### `DIOpShl`

```llvm
DIOpShl()
{ L1:T L2:T -> L:T }
```

`V1` is the value of type `T` obtained by reading `bitsizeof(T)` bits from `L1`.
`V2` is the value of type `T` obtained by reading `bitsizeof(T)` bits from `L2`.

`L` comprises one implicit location description `IL`. `IL` specifies implicit
location storage `ILS` and offset 0. `ILS` has value `V2 << V1` and size
`bitsizeof(T)`. The result is filled with 0 bits.

If `T` is not an integral type the expression is not well-formed.

## Intrinsics

The intrinsics define the program location range over which the location
description specified by a bounded lifetime segment of a `DILifetime` is active.
They support defining a single or multiple locations for a source program
variable. Multiple locations can be active at the same program location as
supported by [DWARF location lists][20].

### `llvm.dbg.def`

```llvm
void @llvm.dbg.def(metadata, metadata)
```

The first argument to `llvm.dbg.def` must be a `DILifetime`, and is the
beginning of the bounded lifetime being defined.

The second argument to `llvm.dbg.def` must be a value-as-metadata, and defines
the LLVM entity acting as the referrer of the bounded lifetime segment specified
by the first argument. A value of `undef` is allowed and specifies the undefined
location description.

_[Note: `undef` can be used when the lifetime segment expression does not use a
`DIOpReferrer` operation, either because the expression evaluates to a constant
implicit location description, or because it only uses `DIOpArg` operations for
inputs.]_

The MC pseudo instruction equivalent is `DBG_DEF` which has the same two
arguments with the same meaning:

```llvm
DBG_DEF metadata, <value>
```

### `llvm.dbg.kill`

```llvm
void @llvm.dbg.kill(metadata)
```

The first argument to `llvm.dbg.kill` must be a `DILifetime`, and is the
end of the lifetime being killed.

Every call to the `llvm.dbg.kill` intrinsic must be reachable from a call to
the `llvm.dbg.def` intrinsic which specifies the same `DILifetime`, otherwise
it is not well-formed.

The MC pseudo instruction equivalent is `DBG_KILL` which has the same argument
with the same meaning:

```llvm
DBG_KILL metadata
```

# Examples

Examples which need meta-syntactic variables prefix them with a sigil to
concisely give context. The prefix sigils are:

| __Sigil__ | __Meaning__                                              |
| :-------: | :------------------------------------------------------- |
|     %     | SSA IR Value                                             |
|     $     | Non-SSA MIR Register (for example, post phi-elimination) |
|     #     | Arbitrary literal constant                               |

The syntax used in the examples attempts to match LLVM IR/MIR as closely as
possible, with the only new syntax required being that of the expression
language.

## Variable Located In An `alloca`

The frontend will generate `alloca`s for every variable, and can trivially
insert a single `DILifetime` covering the whole body of the function, with the
expression `DIExpr(DIOpReferrer(<type>*), DIOpDeref()`, referring to the
`alloca`. Walking the debug intrinsics provides the necessary information to
generate the DWARF `DW_AT_location` attributes on variables.

```llvm
%x.addr = alloca i64, addrspace(5)
call void @llvm.dbg.def(metadata !2, metadata i64 addrspace(5)* %x.addr)
store i64* %x.addr, ...
...
call void @llvm.dbg.kill(metadata !2)

!1 = !DILocalVariable("x", ...)
!2 = distinct !DILifetime(object: !1, location: !DIExpr(DIOpReferrer(i64 addrspace(5)*), DIOpDeref()))
```

## Variable Promoted To An SSA Register

The promotion semantically removes one level of indirection, and correspondingly
in the debug expressions for which the `alloca` being replaced was the referrer,
an additional `DIOpAddrOf(N)` is needed.

An example is `mem2reg` where an `alloca` can be replaced with an SSA value:

```llvm
%x = i64 ...
call void @llvm.dbg.def(metadata !2, metadata i64 %x)
...
call void @llvm.dbg.kill(metadata !2)

!1 = !DILocalVariable("x", ...)
!2 = distinct !DILifetime(object: !1, location: !DIExpr(DIOpReferrer(i64), DIOpAddrOf(5), DIOpDeref()))
```

The canonical form of this is then just `DIOpReferrer(i64)` as the pair of
`DIOpAddrOf(N)`, `DIOpDeref()` cancel out:

```llvm
%x = i64 ...
call void @llvm.dbg.def(metadata !2, metadata i64 %x)
...
call void @llvm.dbg.kill(metadata !2)

!1 = !DILocalVariable("x", ...)
!2 = distinct !DILifetime(object: !1, location: !DIExpr(DIOpReferrer(i64)))
```

## Implicit Pointer Location Description

The transformation for removing a level of indirection is always to add an
`DIOpAddrOf(N)`, which may result in a location description for a pointer to a
non-memory object.

```c
int x = ...;
int *p = &x;
return *p;
```

```llvm
%x.addr = alloca i64, addrspace(5)
call void @llvm.dbg.def(metadata !2, metadata i64 addrspace(5)* %x.addr)
store i64 addrspace(5)* %x.addr, i64 ...
%p.addr = alloca i64*, addrspace(5)
call void @llvm.dbg.def(metadata !4, metadata i64 addrspace(5)* addrspace(5)* %p.addr)
store i64 addrspace(5)* addrspace(5)* %p.addr, i64 addrspace(5)* %x.addr
%0 = load i64 addrspace(5)* addrspace(5)* %p.addr
%1 = load i64 addrspace(5)* %0
ret i64 %1

!1 = !DILocalVariable("x", ...)
!2 = distinct !DILifetime(object: !1, location: !DIExpr(DIOpReferrer(i64 addrspace(5)*), DIOpDeref()))
!3 = !DILocalVariable("p", ...)
!4 = distinct !DILifetime(object: !3, location: !DIExpr(DIOpReferrer(i64 addrspace(5)* addrspace(5)*), DIOpDeref()))
```

_[Note: The `llvm.dbg.def` could either be placed after the `alloca` or after
the `store` that defines the variables initial value. The difference is whether
the debugger will be able to allow the user to access the variable before it is
initialized. Proposals exist to allow the compiler to communicate when a
variable is uninitialized separately from defining its location.]_

First round of `mem2reg` promotes `%p.addr` to an SSA register `%p`:

```llvm
%x.addr = alloca i64, addrspace(5)
store i64 addrspace(5)* %x.addr, i64 ...
call void @llvm.dbg.def(metadata !2, metadata i64 addrspace(5)* %x.addr)
%p = i64 addrspace(5)* %x.addr
call void @llvm.dbg.def(metadata !4, metadata i64 addrspace(5)* %p)
%0 = load i64 addrspace(5)* %p
return i64 %0

!1 = !DILocalVariable("x", ...)
!2 = distinct !DILifetime(object: !1, location: !DIExpr(DIOpReferrer(i64 addrspace(5)*), DIOpDeref()))
!3 = !DILocalVariable("p", ...)
!4 = distinct !DILifetime(object: !3, location: !DIExpr(DIOpReferrer(i64 addrspace(5)*), DIOpAddrOf(5), DIOpDeref()))
```

Simplify by eliminating `%p` and directly using `%x.addr`:

```llvm
%x.addr = alloca i64, addrspace(5)
store i64 addrspace(5)* %x.addr, i64 ...
call void @llvm.dbg.def(metadata !2, metadata i64 addrspace(5)* %x.addr)
call void @llvm.dbg.def(metadata !4, metadata i64 addrspace(5)* %x.addr)
load i64 %0, i64 addrspace(5)* %x.addr
return i64 %0

!1 = !DILocalVariable("x", ...)
!2 = distinct !DILifetime(object: !1, location: !DIExpr(DIOpReferrer(i64 addrspace(5)*), DIOpDeref()))
!3 = !DILocalVariable("p", ...)
!4 = distinct !DILifetime(object: !3, location: !DIExpr(DIOpReferrer(i64 addrspace(5)*)))
```

Second round of `mem2reg` promotes `%x.addr` to an SSA register `%x`:


```llvm
%x = i64 ...
call void @llvm.dbg.def(metadata !2, metadata i64 %x)
call void @llvm.dbg.def(metadata !4, metadata i64 %x)
%0 = i64 %x
return i64 %0

!1 = !DILocalVariable("x", ...)
!2 = distinct !DILifetime(object: !1, location: !DIExpr(DIOpReferrer(i64), DIOpAddrOf(5), DIOpDeref()))
!3 = !DILocalVariable("p", ...)
!4 = distinct !DILifetime(object: !3, location: !DIExpr(DIOpReferrer(i64), DIOpAddrOf(5)))
```

Simplify by eliminating adjacent `DIOpAddrOf(5), DIOpDeref()` and use `%x`
directly in the `return`:

```llvm
%x = i64 ...
call void @llvm.dbg.def(metadata !2, metadata i64 %x)
call void @llvm.dbg.def(metadata !2, metadata i64 %x)
return i64 %x

!1 = !DILocalVariable("x", ...)
!2 = distinct !DILifetime(object: !1, location: !DIExpr(DIOpReferrer(i64)))
!3 = !DILocalVariable("p", ...)
!4 = distinct !DILifetime(object: !3, location: !DIExpr(DIOpReferrer(i64), DIOpAddrOf(5)))
```

If `%x` was being assigned a constant then can eliminated `%x` entirely and
substitute all uses with the constant:

```llvm
call void @llvm.dbg.def(metadata !2, metadata i1 undef)
call void @llvm.dbg.def(metadata !4, metadata i1 undef)
return i64 ...

!1 = !DILocalVariable("x", ...)
!2 = distinct !DILifetime(object: !1, location: !DIExpr(DIOpConstant(i64 ...)))
!3 = !DILocalVariable("p", ...)
!4 = distinct !DILifetime(object: !3, location: !DIExpr(DIOpConstant(i64 ...), DIOpAddrOf(5)))
```

## Variable Broken Into Two Scalars

When a transformation decomposes one location into multiple distinct ones, it
must follow all `llvm.dbg.def` intrinsics to the `DILifetime`s referencing the
original location and update the expression and positional arguments such that:

- All instances of `DIOpReferrer()` in the original expression are replaced with
  the appropriate composition of all the new location pieces, now encoded via
  multiple `DIOpArg()` operations referring to input `DIObject`s, and a
  `DIOpComposite` operation. This makes the associated `DILifetime` a computed
  lifetime segment.
- Those location pieces are represented by new `DIFragment`s, one per new
  location, each with appropriate `DILifetime`s referenced by new `llvm.dbg.def`
  and `llvm.dbg.kill` intrinsics.

It is assumed that any transformation capable of doing the decomposition in the
first place must have all of this information available, and the structure of
the new intrinsics and metadata avoids any costly operations during
transformations. This update is also "shallow", in that only the `DILifetime`
which is immediately referenced by the relevant `llvm.dbg.def`s need to be
updated, as the result is referentially transparent to any other dependant
`DILifetime`s.

```llvm
%x = ...
call void @llvm.dbg.def(metadata !2, metadata i64 addrspace(5)* %x)
...
call void @llvm.dbg.kill(metadata !2)

!1 = !DILocalVariable("x", ...)
!2 = distinct !DILifetime(object: !1, location: !DIExpr(DIOpReferrer(i64 addrspace(5)*)))
```

Transformed a `i64` SSA value into two `i32` SSA values:

```llvm
%x.lo = i32 ...
call void @llvm.dbg.def(metadata !4, metadata i32 %x.lo)
...
%x.hi = i32 ...
call void @llvm.dbg.def(metadata !6, metadata i32 %x.hi)
...
call void @llvm.dbg.kill(metadata !6)
call void @llvm.dbg.kill(metadata !4)

!1 = !DILocalVariable("x", ...)
!2 = distinct !DILifetime(object: !1, location: !DIExpr(DIOpArg(1, i32), DIOpArg(0, i32), DIOpComposite(2, i64)), argObjects: {!3, !5})
!3 = distinct !DIFragment()
!4 = distinct !DILifetime(object: !3, location: !DIExpr(DIOpReferrer(i32)))
!5 = distinct !DIFragment()
!6 = distinct !DILifetime(object: !5, location: !DIExpr(DIOpReferrer(i32)))
```

## Further Decomposition Of An Already SRoA'd Variable

An example to demonstrate the "shallow update" property is to take the above
IR:

```llvm
%x.lo = i32 ...
call void @llvm.dbg.def(metadata !4, metadata i32 %x.lo)
...
%x.hi = i32 ...
call void @llvm.dbg.def(metadata !6, metadata i32 %x.hi)
...
call void @llvm.dbg.kill(metadata !6)
call void @llvm.dbg.kill(metadata !4)

!1 = !DILocalVariable("x", ...)
!2 = distinct !DILifetime(object: !1, location: !DIExpr(DIOpArg(1, i32), DIOpArg(0, i32), DIOpComposite(2, i64)), argObjects: {!3, !5})
!3 = distinct !DIFragment()
!4 = distinct !DILifetime(object: !3, location: !DIExpr(DIOpReferrer(i32)))
!5 = distinct !DIFragment()
!6 = distinct !DILifetime(object: !5, location: !DIExpr(DIOpReferrer(i32)))
```

and subdivide `%x.hi` again:

```llvm
%x.lo = i32 ...
call void @llvm.dbg.def(metadata !4, metadata i32 %x.lo)
%x.hi.lo = i16 ...
call void @llvm.dbg.def(metadata !8, metadata i16 %x.hi.lo)
%x.hi.hi = i16 ...
call void @llvm.dbg.def(metadata !10, metadata i16 %x.hi.hi)
...
call void @llvm.dbg.kill(metadata !10)
call void @llvm.dbg.kill(metadata !8)
call void @llvm.dbg.kill(metadata !4)

!1 = !DILocalVariable("x", ...)
!2 = distinct !DILifetime(object: !1, location: !DIExpr(DIOpArg(1, i32), DIOpArg(0, i32), DIOpComposite(2, i64)), argObjects: {!3, !5})
!3 = distinct !DIFragment()
!4 = distinct !DILifetime(object: !3, location: !DIExpr(DIOpReferrer(i32)))
!5 = distinct !DIFragment()
!6 = distinct !DILifetime(object: !5, location: !DIExpr(DIOpArg(1, i16), DIOpArg(0, i16), DIOpComposite(2, i32)), argObjects: {!7, !9})
!7 = distinct !DIFragment()
!8 = distinct !DILifetime(object: !7, location: !DIExpr(DIOpReferrer(i16)))
!9 = distinct !DIFragment()
!10 = distinct !DILifetime(object: !9, location: !DIExpr(DIOpReferrer(i16)))
```

Note that the expression for the original source variable `x` did not need to
be changed, as it is defined in terms of the `DIFragment`, the identity of
which is never changed after it is created.

## Multiple Live Ranges For A Single Variable

Once out of SSA, or even while in SSA via memory, there may be multiple re-uses
of the same storage for completely disparate variables, and disjoint and/or
overlapping lifetimes for any single variable. This is modeled naturally by
maintaining _defs_ and _kills_ for these live ranges independently at, for
example, definitions and clobbers.

```llvm
$r0 = MOV ...
DBG_DEF !2, $r0
...
SPILL %frame.index.0, $r0
DBG_DEF !3, %frame.index.0
...
$r0 = MOV ; clobber
DBG_KILL !2
DBG_DEF !6, $r0
...
$r1 = MOV ...
DBG_DEF !4, $r1
...
DBG_KILL !6
DBG_KILL !4
DBG_KILL !3
RETURN

!1 = !DILocalVariable("x", ...)
!2 = distinct !DILifetime(object: !1, location: !DIExpr(DIOpReferrer(i32)))
!3 = distinct !DILifetime(object: !1, location: !DIExpr(DIOpReferrer(i32)))
!4 = distinct !DILifetime(object: !1, location: !DIExpr(DIOpReferrer(i32)))
!5 = !DILocalVariable("y", ...)
!6 = distinct !DILifetime(object: !5, location: !DIExpr(DIOpReferrer(i32)))
```

In this example, `$r0` is referred to by disjoint `DILifetime`s for different
variables. There is also a point where multiple `DILifetime`s for the same
variable are live.

The first point implies the need for intrinsics/pseudo-instructions to define
the live range, as simply referring to an LLVM entity does not provide enough
information to reconstruct the live range.

The second point is needed to accurately represent cases where, for example, a
variable lives in both a register and in memory. The current
intrinsics/pseudo-instructions do not have the notion of live ranges for source
variables, and simply throw away at least one of the true lifetimes in these
cases.

## Global Variable Broken Into Two Scalars

```llvm
@g = i64 !dbg.default !2

!1 = !DIGlobalVariable("g")
!2 = distinct !DILifetime(object: !1, location: !DIExpr(DIOpReferrer(i64 addrspace(1)*), DIDeref()))
```

Becomes:

```llvm
@g.lo = i32 !dbg.default !4
@g.hi = i32 !dbg.default !6

!1 = !DIGlobalVariable("g")
!2 = distinct !DILifetime(object: !1, location: !DIExpr(DIOpArg(1, i32), DIOpArg(0, i32), DIOpComposite(2, i64)), argObjects: {!3, !5})
!3 = distinct !DIFragment()
!4 = distinct !DILifetime(object: !3, location: !DIExpr(DIOpReferrer(i32 addrspace(1)*), DIDeref()))
!5 = distinct !DIFragment()
!6 = distinct !DILifetime(object: !5, location: !DIExpr(DIOpReferrer(i32 addrspace(1)*), DIDeref()))
```

`!dbg.default` is "hidden" when any other lifetime is in effect. This allows,
for example, a function to override the location of a global over some range
without needing to "kill" and "def" a global lifetime.

## Induction Variable

Starting with some program:

```llvm
%x = i64 ...
call void @llvm.dbg.def(metadata !2, metadata i64 %x)
...
%y = i64 ...
call void @llvm.dbg.def(metadata !4, i64 %y)
...
%i = i64 ...
call void @llvm.dbg.def(metadata !6, metadata i64 %z)
...
call void @llvm.dbg.kill(metadata !6)
call void @llvm.dbg.kill(metadata !4)
call void @llvm.dbg.kill(metadata !2)

!1 = !DILocalVariable("x", ...)
!2 = distinct !DILifetime(object: !1, location: !DIExpr(DIOpReferrer(i64)))
!3 = !DILocalVariable("y", ...)
!4 = distinct !DILifetime(object: !3, location: !DIExpr(DIOpReferrer(i64)))
!5 = !DILocalVariable("i", ...)
!6 = distinct !DILifetime(object: !5, location: !DIExpr(DIOpReferrer(i64)))
```

If analysis proves `i` over some range is always equal to `x + y`, the storage
for `i` can be eliminated, and it can be materialized at every use. The
corresponding change needed in the debug information is:

```llvm
%x = i64 ...
call void @llvm.dbg.def(metadata !2, metadata i64 %x)
...
%y = i64 ...
call void @llvm.dbg.def(metadata !4, metadata i64 %y)
...
call void @llvm.dbg.def(metadata !6, metadata i64 undef)
...
call void @llvm.dbg.kill(metadata !6)
call void @llvm.dbg.kill(metadata !4)
call void @llvm.dbg.kill(metadata !2)

!1 = !DILocalVariable("x", ...)
!2 = distinct !DILifetime(object: !1, location: !DIExpr(DIOpReferrer(i64)))
!3 = !DILocalVariable("y", ...)
!4 = distinct !DILifetime(object: !3, location: !DIExpr(DIOpReferrer(i64)))
!5 = !DILocalVariable("i", ...)
!6 = distinct !DILifetime(object: !5, location: !DIExpr(DIOpArg(0, i64), DIOpArg(1, i64), DIOpAdd()), DIOpArg(!1, !3})
```

For the given range, the value of `i` is computable so long as both `x` and `y`
are live, the determination of which is left until the backend debug information
generation (for example, for old DWARF or for other debug information formats),
or until debugger runtime when the expression is evaluated (for example, for
DWARF with `DW_OP_call` and `DW_TAG_dwarf_procedure`). During compilation this
representation allows all updates to maintain the debug information efficiently
by making updates "shallow".

In other cases this can allow the debugger to provide locations for part of a
source variable, even when other parts are not available. This may be the case
if a `struct` with many fields is broken up during SRoA and the lifetimes of
each piece diverge.

## Proven Constant

As a very similar example to the above induction variable case (in terms of the
updates needed in the debug information), the case where a variable is proven to
be a statically known constant over some range turns the following:

```llvm
%x = i64 ...
call void @llvm.dbg.def(metadata !2, metadata i64 %x)
...
call void @llvm.dbg.kill(metadata !2)

!1 = !DILocalVariable("x", ...)
!2 = distinct !DILifetime(object: !1, location: !DIExpr(DIOpReferrer(i64)))
```

into:

```llvm
call void @llvm.dbg.def(metadata !2, metadata i64 undef)
...
call void @llvm.dbg.kill(metadata !2)

!1 = !DILocalVariable("x", ...)
!2 = distinct !DILifetime(object: !1, location: !DIExpr(DIOpConstant(i64 ...)))
```

## Common Subexpression Elimination (CSE)

This is the example from [Bug 40628 - [DebugInfo@O2] Salvaged memory loads can
observe subsequent memory writes][09]:

```c
 int
 foo(int *bar, int arg, int more)
 {
   int redundant = *bar;
   int loaded = *bar;
   arg &= more + loaded;

   *bar = 0;

   return more + *bar;
 }

int
main() {
  int lala = 987654;
  return foo(&lala, 1, 2);
}
```

Which after `SROA+mem2reg` becomes (where `redundant` is `!17` and `loaded` is
`!16`):

```llvm
; Function Attrs: noinline nounwind uwtable
define dso_local i32 @foo(i32* %bar, i32 %arg, i32 %more) #0 !dbg !7 {
entry:
  call void @llvm.dbg.value(metadata i32* %bar, metadata !13, metadata !DIExpression()), !dbg !18
  call void @llvm.dbg.value(metadata i32 %arg, metadata !14, metadata !DIExpression()), !dbg !18
  call void @llvm.dbg.value(metadata i32 %more, metadata !15, metadata !DIExpression()), !dbg !18
  %0 = load i32, i32* %bar, align 4, !dbg !19, !tbaa !20
  call void @llvm.dbg.value(metadata i32 %0, metadata !16, metadata !DIExpression()), !dbg !18
  %1 = load i32, i32* %bar, align 4, !dbg !24, !tbaa !20
  call void @llvm.dbg.value(metadata i32 %1, metadata !17, metadata !DIExpression()), !dbg !18
  %add = add nsw i32 %more, %1, !dbg !25
  %and = and i32 %arg, %add, !dbg !26
  call void @llvm.dbg.value(metadata i32 %and, metadata !14, metadata !DIExpression()), !dbg !18
  store i32 0, i32* %bar, align 4, !dbg !27, !tbaa !20
  %2 = load i32, i32* %bar, align 4, !dbg !28, !tbaa !20
  %add1 = add nsw i32 %more, %2, !dbg !29
  ret i32 %add1, !dbg !30
}
```

And previously led to this after `EarlyCSE`, which removes the redundant load
from `%bar`:

```llvm
define dso_local i32 @foo(i32* %bar, i32 %arg, i32 %more) #0 !dbg !7 {
entry:
  call void @llvm.dbg.value(metadata i32* %bar, metadata !13, metadata !DIExpression()), !dbg !18
  call void @llvm.dbg.value(metadata i32 %arg, metadata !14, metadata !DIExpression()), !dbg !18
  call void @llvm.dbg.value(metadata i32 %more, metadata !15, metadata !DIExpression()), !dbg !18

  ; This is not accurate to begin with, as a debugger which modifies
  ; `redundant` will erroneously update the pointee of the parameter `bar`.
  call void @llvm.dbg.value(metadata i32* %bar, metadata !16, metadata !DIExpression(DW_OP_deref)), !dbg !18

  %0 = load i32, i32* %bar, align 4, !dbg !19, !tbaa !20
  call void @llvm.dbg.value(metadata i32 %0, metadata !17, metadata !DIExpression()), !dbg !18
  %add = add nsw i32 %more, %0, !dbg !24
  call void @llvm.dbg.value(metadata i32 undef, metadata !14, metadata !DIExpression()), !dbg !18

  ; This store "clobbers" the debug location description for `redundant`, such
  ; that a debugger about to execute the following `ret` will erroneously
  ; report `redundant` as equal to `0` when the source semantics have it still
  ; equal to the value pointed to by `bar` on entry.
  store i32 0, i32* %bar, align 4, !dbg !25, !tbaa !20
  ret i32 %more, !dbg !26
}
```

But now becomes (conservatively):

```llvm
define dso_local i32 @foo(i32* %bar, i32 %arg, i32 %more) #0 !dbg !7 {
entry:
  call void @llvm.dbg.value(metadata i32* %bar, metadata !13, metadata !DIExpression()), !dbg !18
  call void @llvm.dbg.value(metadata i32 %arg, metadata !14, metadata !DIExpression()), !dbg !18
  call void @llvm.dbg.value(metadata i32 %more, metadata !15, metadata !DIExpression()), !dbg !18

  ; The above mentioned patch for PR40628 adds special treatment, dropping
  ; the debug information for `redundant` completely in this case, making
  ; this conservatively correct.
  call void @llvm.dbg.value(metadata i32 undef, metadata !16, metadata !DIExpression()), !dbg !18

  %0 = load i32, i32* %bar, align 4, !dbg !19, !tbaa !20
  call void @llvm.dbg.value(metadata i32 %0, metadata !17, metadata !DIExpression()), !dbg !18
  %add = add nsw i32 %more, %0, !dbg !24
  call void @llvm.dbg.value(metadata i32 undef, metadata !14, metadata !DIExpression()), !dbg !18
  store i32 0, i32* %bar, align 4, !dbg !25, !tbaa !20
  ret i32 %more, !dbg !26
}
```

Effectively at the point of the CSE eliminating the load, it conservatively
marks the source variable `redundant` as optimized out.

It seems like the semantics that CSE really wants to encode in the debug
intrinsics is that, after the point at which the common load occurs, the
location for both `redundant` and `loaded` is `%0`, and that they are both
read-only. It seems like it must prove this to combine them, and if it can only
combine them over some range it can insert additional live ranges to describe
their separate locations outside of that range. The implicit pointer example is
further evidence of why this may need to be the case, because at the time
implicit pointer is created it is not know which source variable to bind to in
order to get the multiple lifetimes in this design.

This seems to be supported by the fact that even in current LLVM trunk, with
the more conservative change to mark the `redundant` variable as `undef` in the
above case, changing the source to modify `redundant` after the load results in
both `redundant` and `loaded` referring to the same location, and both being
read-write. A modification of `redundant` in the debugger before the use of
`loaded` is permitted, and would have the effect of also updating `loaded`. An
example of the modified source needed to cause this is:

```c
int
foo(int *bar, int arg, int more)
{
  int redundant = *bar;
  int loaded = *bar;
  arg &= more + loaded; // A store to redundant here affects loaded.

  *bar = redundant; // The use and subsequent modification of `redundant` here
  redundant = 1;    // effectively circumvents the patch for PR40628.

  return more + *bar;
}

int
main() {
  int lala = 987654;
  return foo(&lala, 1, 2);
}
```

Note that after `EarlyCSE`, this example produces the same location description
for both `redundant` and `loaded` (metadata `!17` and `!18`):

```llvm
define dso_local i32 @foo(i32* %bar, i32 %arg, i32 %more) #0 !dbg !8 {
entry:
  call void @llvm.dbg.value(metadata i32* %bar, metadata !14, metadata !DIExpression()), !dbg !19
  call void @llvm.dbg.value(metadata i32 %arg, metadata !15, metadata !DIExpression()), !dbg !19
  call void @llvm.dbg.value(metadata i32 %more, metadata !16, metadata !DIExpression()), !dbg !19
  %0 = load i32, i32* %bar, align 4, !dbg !20, !tbaa !21

  ; The same location is reused for both source variables, without it being
  ; marked read-only (namely without it being made into an implicit location
  ; description).
  call void @llvm.dbg.value(metadata i32 %0, metadata !17, metadata !DIExpression()), !dbg !19
  call void @llvm.dbg.value(metadata i32 %0, metadata !18, metadata !DIExpression()), !dbg !19

  ; Modifications to either source variable in a debugger affect the other from
  ; this point on in the function.
  %add = add nsw i32 %more, %0, !dbg !25
  call void @llvm.dbg.value(metadata i32 undef, metadata !15, metadata !DIExpression()), !dbg !19
  call void @llvm.dbg.value(metadata i32 1, metadata !17, metadata !DIExpression()), !dbg !19
  ret i32 %add, !dbg !26
}
```

_[Note: To see this result, i386 is required; x86_64 seems to do even more optimization
which eliminates both `loaded` and `redundant`.]_

Fixing this issue in the current debug information is technically possible, but
as noted in the review for the attempted conservative patch, "this isn't
something that can be fixed without a lot of work, thus it's safer to turn off
for now."

The AMDGPU LLVM extensions make this case tractable to support with full
generality and composability with other optimizations. The expected result of
`EarlyCSE` would be:

```llvm
define dso_local i32 @foo(i32* %bar, i32 %arg, i32 %more) #0 !dbg !8 {
entry:
  call void @llvm.dbg.def(metadata i32* %bar, metadata !19), !dbg !19
  call void @llvm.dbg.def(metadata i32 %arg, metadata !20), !dbg !19
  call void @llvm.dbg.def(metadata i32 %more, metadata !21), !dbg !19
  %0 = load i32, i32* %bar, align 4, !dbg !20, !tbaa !21

  call void @llvm.dbg.def(metadata i32 %0, metadata !22), !dbg !19
  call void @llvm.dbg.def(metadata i32 %0, metadata !23), !dbg !19

  %add = add nsw i32 %more, %0, !dbg !25
  ret i32 %add, !dbg !26
}

!14 = !DILocalVariable("bar", ...)
!15 = !DILocalVariable("arg", ...)
!16 = !DILocalVariable("more", ...)
!17 = !DILocalVariable("redundant", ...)
!18 = !DILocalVariable("loaded", ...)
!19 = distinct !DILifetime(object: !14, location: !DIExpr(DIOpReferrer(i32*)))
!20 = distinct !DILifetime(object: !15, location: !DIExpr(DIOpReferrer(i32)))
!21 = distinct !DILifetime(object: !16, location: !DIExpr(DIOpReferrer(i32)))
!21 = distinct !DILifetime(object: !17, location: !DIExpr(DIOpReferrer(i32), DIOpRead()))
!22 = distinct !DILifetime(object: !18, location: !DIExpr(DIOpReferrer(i32), DIOpRead()))
```

Which accurately describes that both `redundant` and `loaded` are read-only
after the common load.

# References

1. [[LLVMdev] [RFC] Separating Metadata from the Value hierarchy (David Blaikie)][01]
2. [[LLVMdev] [RFC] Separating Metadata from the Value hierarchy][02]
3. [[llvm-dev] Proposal for multi location debug info support in LLVM IR][03]
4. [[llvm-dev] Proposal for multi location debug info support in LLVM IR][04]
5. [Multi Location Debug Info support for LLVM][05]
6. [D81852 [DebugInfo] Update MachineInstr interface to better support variadic
   DBG_VALUE instructions][06]
7. [D70601 Disallow DIExpressions with shift operators from being fragmented][07]
8. [D57962 [DebugInfo] PR40628: Don't salvage load operations][08]
9. [Bug 40628 - [DebugInfo@O2] Salvaged memory loads can observe subsequent memory writes][09]
10. [LLVM Language Reference Manual][10]
    1. [Well-Formedness][11]
    2. [Type System][12]
    3. [Global Variables][13]
    4. [DICompositeType][14]
    5. [DILocalVariable][15]
    6. [DIGlobalVariable][16]
    7. [DICompileUnit][17]
11. [LLVM DWARF Extensions For Heterogeneous Debugging][18]
    1. [DWARF Expressions][19]
    2. [DWARF Location List Expressions][20]
    3. [DWARF Location Description][21]
    4. [DWARF Expression Evaluation Context][22]
12. [LLVM User Guide for AMDGPU Backend][23]
    1. [DW_AT_LLVM_lane_pc][24]

[01]: https://lists.llvm.org/pipermail/llvm-dev/2014-November/078656.html
[02]: https://lists.llvm.org/pipermail/llvm-dev/2014-November/078682.html
[03]: https://lists.llvm.org/pipermail/llvm-dev/2015-December/093535.html
[04]: https://lists.llvm.org/pipermail/llvm-dev/2016-January/093627.html
[05]: https://gist.github.com/Keno/480b8057df1b7c63c321
[06]: https://reviews.llvm.org/D81852
[07]: https://reviews.llvm.org/D70601
[08]: https://reviews.llvm.org/D57962
[09]: https://bugs.llvm.org/show_bug.cgi?id=40628
[10]: https://llvm.org/docs/LangRef.html
[11]: https://llvm.org/docs/LangRef.html#well-formedness
[12]: https://llvm.org/docs/LangRef.html#type-system
[13]: https://llvm.org/docs/LangRef.html#global-variables
[14]: https://llvm.org/docs/LangRef.html#dicompositetype
[15]: https://llvm.org/docs/LangRef.html#dilocalvariable
[16]: https://llvm.org/docs/LangRef.html#diglobalvariable
[17]: https://llvm.org/docs/LangRef.html#dicompileunit
[18]: https://llvm.org/docs/AMDGPUDwarfExtensionsForHeterogeneousDebugging.html
[19]: https://llvm.org/docs/AMDGPUDwarfExtensionsForHeterogeneousDebugging.html#dwarf-expressions
[20]: https://llvm.org/docs/AMDGPUDwarfExtensionsForHeterogeneousDebugging.html#dwarf-location-list-expressions
[21]: https://llvm.org/docs/AMDGPUDwarfExtensionsForHeterogeneousDebugging.html#dwarf-location-description
[22]: https://llvm.org/docs/AMDGPUDwarfExtensionsForHeterogeneousDebugging.html#dwarf-expression-evaluation-context
[23]: https://llvm.org/docs/AMDGPUUsage.html
[24]: https://llvm.org/docs/AMDGPUUsage.html#dw-at-llvm-lane-pc

# Other Ideas

## Translating To DWARF

> TODO: Define algorithm for computing DWARF location descriptions and loclists.
>
> - Define rule for implicit pointers (`DIOpAddrof` applied to a referrer)
>   - Look for a compatible, existing program object
>   - If not, generate an artificial one
>   - This could be bubbled up to DWARF itself, to allow implicits to hold
>     arbitrary location descriptions, eliminating the need for the artificial
>     variable, and make translation simpler.

## Translating To PDB (CodeView)

> TODO: Define.

## Comparison With GCC

> TODO: Understand how this compares to what GCC is doing?

## Example Ideas

### Spilling

> TODO: SSA -> stack slot

```llvm
%x = i32 ...
call void @llvm.dbg.def(metadata !1, metadata i32 %x)
...
call void @llvm.dbg.kill(metadata !1)

!0 = !DILocalVariable("x")
!1 = distinct !DILifetime(object: !0, location: !DIExpr(DIOpReferrer(i32)))
```

spill %x:

```llvm
%x.addr = alloca i32, addrspace(5)
store i32* %x.addr, ...
call void @llvm.dbg.def(metadata !1, metadata i32 *%x)
...
call void @llvm.dbg.kill(metadata !1)

!0 = !DILocalVariable("x")
!1 = distinct !DILifetime(object: !0, location: !DIExpr(DIOpReferrer(i32 addrspace(5)*), DIOpDeref()))
```

> TODO: stack slot -> register

> TODO: register -> stack slot

### Divergent Lane PC

> TODO: Re-do example given in [LLVM User Guide for AMDGPU Backend -
> DW_AT_LLVM_lane_pc][24] using these extesions.

### Simultaneous Lifetimes In Multiple Places

> TODO: Define.

### File Scope Globals

> TODO: Define.

### Lds Variables

> TODO: LDS variables, one variable but multiple kernels with distinct
> lifetimes, is that possible in LLVM?
>
> Could allow the `llvm.dbg.def` intrinsic to refer to a global, and use that
> to define live ranges which live in functions and refer to storage outside
> of the function.
>
> I would expect tha LDS variables would have no `!dbg.default` and instead have
> `llvm.dbg.def` in each function that can access it. The bounded lifetime
> segment would have an expression that evaluates to the location of the LDS
> variable in the specific subprogram. For a kernel it would likely be an
> absolute address in the LDS address space. Each kernel may have a different
> address. In functions that can be called from multiple kernels it may be an
> expression that uses the LDS indirection variables to determine the actual LDS
> address.

### Make Sure The Non-SSA MIR Form Works With def/kill Scheme

> TODO: Make sure the non-SSA MIR form works with def/kill scheme, and
> additionally confirm why we don't seem to need the work upstream that is
> trying to move to referring to an instruction rather than a register? See
> [[llvm-dev] [RFC] DebugInfo: A different way of specifying variable locations
> post-isel](https://lists.llvm.org/pipermail/llvm-dev/2020-February/139440.html).

## Integer Fragment IDs

> TODO: This was just a quick jotting-down of one idea for eliminating the need
> for a distincit `DIFragment` to represent the identity of fragments.

### Variable Broken Into Two Scalars

```llvm
%x.lo = i32 ...
call void @llvm.dbg.def(metadata i32 %x.lo, metadata !4)
...
%x.hi = i32 ...
call void @llvm.dbg.def(metadata i32 %x.hi, metadata !6)
...
call void @llvm.dbg.kill(metadata !4)
call void @llvm.dbg.kill(metadata !6)

!1 = !DILocalVariable("x", ...)
!2 = distinct !DILifetime(object: !1, location: !DIExpr(var 0, var 1, composite 2))
!3 = distinct !DILifetime(object: 0, location: !DIExpr(referrer))
!4 = distinct !DILifetime(object: 1, location: !DIExpr(referrer))
```

### Further Decomposition Of An Already SRoA'd Variable

```llvm
%x.lo = i32 ...
call void @llvm.dbg.def(metadata i32 %x.lo, metadata !3)
%x.hi.lo = i16 ...
call void @llvm.dbg.def(metadata i16 %x.hi.lo, metadata !5)
%x.hi.hi = i16 ...
call void @llvm.dbg.def(metadata i16 %x.hi.hi, metadata !6)
...
call void @llvm.dbg.kill(metadata !4)
call void @llvm.dbg.kill(metadata !8)
call void @llvm.dbg.kill(metadata !10)

!1 = !DILocalVariable("x", ...)
!2 = distinct !DILifetime(object: !1, location: !DIExpr(var 0, var 1, composite 2))
!3 = distinct !DILifetime(object: 0, location: !DIExpr(referrer))
!4 = distinct !DILifetime(object: 1, location: !DIExpr(var 2, var 3, composite 2))
!5 = distinct !DILifetime(object: 2, location: !DIExpr(referrer))
!6 = distinct !DILifetime(object: 3, location: !DIExpr(referrer))
```

### Multiple Live Ranges For A Fragment

```llvm
%x.lo.0 = i32 ...
call void @llvm.dbg.def(metadata i32 %x.lo, metadata !3)
...
call void @llvm.dbg.kill(metadata !3)
%x.lo.1 = i32 ...
call void @llvm.dbg.def(metadata i32 %x.lo, metadata !4)
%x.hi.lo = i16 ...
call void @llvm.dbg.def(metadata i16 %x.hi.lo, metadata !6)
%x.hi.hi = i16 ...
call void @llvm.dbg.def(metadata i16 %x.hi.hi, metadata !7)
...
call void @llvm.dbg.kill(metadata !4)
call void @llvm.dbg.kill(metadata !6)
call void @llvm.dbg.kill(metadata !7)

!1 = !DILocalVariable("x", ...)
!2 = distinct !DILifetime(object: !1, location: !DIExpr(var 0, var 1, composite 2))
!3 = distinct !DILifetime(object: 0, location: !DIExpr(referrer))
!4 = distinct !DILifetime(object: 0, location: !DIExpr(referrer))
!5 = distinct !DILifetime(object: 1, location: !DIExpr(var 2, var 3, composite 2))
!6 = distinct !DILifetime(object: 2, location: !DIExpr(referrer))
!7 = distinct !DILifetime(object: 3, location: !DIExpr(referrer))
```

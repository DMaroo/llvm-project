===========================================
Clang |release| |ReleaseNotesTitle|
===========================================

.. contents::
   :local:
   :depth: 2

Written by the `LLVM Team <https://llvm.org/>`_

.. only:: PreRelease

  .. warning::
     These are in-progress notes for the upcoming Clang |version| release.
     Release notes for previous releases can be found on
     `the Releases Page <https://llvm.org/releases/>`_.

Introduction
============

This document contains the release notes for the Clang C/C++/Objective-C
frontend, part of the LLVM Compiler Infrastructure, release |release|. Here we
describe the status of Clang in some detail, including major
improvements from the previous release and new feature work. For the
general LLVM release notes, see `the LLVM
documentation <https://llvm.org/docs/ReleaseNotes.html>`_. For the libc++ release notes,
see `this page <https://libcxx.llvm.org/ReleaseNotes.html>`_. All LLVM releases
may be downloaded from the `LLVM releases web site <https://llvm.org/releases/>`_.

For more information about Clang or LLVM, including information about the
latest release, please see the `Clang Web Site <https://clang.llvm.org>`_ or the
`LLVM Web Site <https://llvm.org>`_.

Potentially Breaking Changes
============================
These changes are ones which we think may surprise users when upgrading to
Clang |release| because of the opportunity they pose for disruption to existing
code bases.


C/C++ Language Potentially Breaking Changes
-------------------------------------------

C++ Specific Potentially Breaking Changes
-----------------------------------------

ABI Changes in This Version
---------------------------

What's New in Clang |release|?
==============================
Some of the major new features and improvements to Clang are listed
here. Generic improvements to Clang as a whole or to its underlying
infrastructure are described first, followed by language-specific
sections with improvements to Clang's support for those languages.

C++ Language Changes
--------------------

C++20 Feature Support
^^^^^^^^^^^^^^^^^^^^^

C++23 Feature Support
^^^^^^^^^^^^^^^^^^^^^

C++2c Feature Support
^^^^^^^^^^^^^^^^^^^^^
- Compiler flags ``-std=c++2c`` and ``-std=gnu++2c`` have been added for experimental C++2c implementation work.
- Implemented `P2738R1: constexpr cast from void* <https://wg21.link/P2738R1>`_.

Resolutions to C++ Defect Reports
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

C Language Changes
------------------

C2x Feature Support
^^^^^^^^^^^^^^^^^^^
- Implemented the ``unreachable`` macro in freestanding ``<stddef.h>`` for
  `WG14 N2826 <https://www.open-std.org/jtc1/sc22/wg14/www/docs/n2826.pdf>`_

- Removed the ``ATOMIC_VAR_INIT`` macro in C2x and later standards modes, which
  implements `WG14 N2886 <https://www.open-std.org/jtc1/sc22/wg14/www/docs/n2886.htm>`_

- Implemented `WG14 N2934 <https://www.open-std.org/jtc1/sc22/wg14/www/docs/n2934.pdf>`_
  which introduces the ``bool``, ``static_assert``, ``alignas``, ``alignof``,
  and ``thread_local`` keywords in C2x.

- Implemented `WG14 N2900 <https://www.open-std.org/jtc1/sc22/wg14/www/docs/n2900.htm>`_
  and `WG14 N3011 <https://www.open-std.org/jtc1/sc22/wg14/www/docs/n3011.htm>`_
  which allows for empty braced initialization in C.

  .. code-block:: c

    struct S { int x, y } s = {}; // Initializes s.x and s.y to 0

  As part of this change, the ``-Wgnu-empty-initializer`` warning group was
  removed, as this is no longer a GNU extension but a C2x extension. You can
  use ``-Wno-c2x-extensions`` to silence the extension warning instead.

- Updated the implementation of
  `WG14 N3042 <https://www.open-std.org/jtc1/sc22/wg14/www/docs/n3042.htm>`_
  based on decisions reached during the WG14 CD Ballot Resolution meetings held
  in Jan and Feb 2023. This should complete the implementation of ``nullptr``
  and ``nullptr_t`` in C. The specific changes are:

- Clang's resource dir used to include the full clang version. It will now
  include only the major version. The new resource directory is
  ``$prefix/lib/clang/$CLANG_MAJOR_VERSION`` and can be queried using
  ``clang -print-resource-dir``, just like before.

What's New in Clang |release|?
==============================
Some of the major new features and improvements to Clang are listed
here. Generic improvements to Clang as a whole or to its underlying
infrastructure are described first, followed by language-specific
sections with improvements to Clang's support for those languages.

    void func(nullptr_t);
    func(0); // Previously required to be rejected, is now accepted.
    func((void *)0); // Previously required to be rejected, is now accepted.

    nullptr_t val;
    val = 0; // Previously required to be rejected, is now accepted.
    val = (void *)0; // Previously required to be rejected, is now accepted.

    bool b = nullptr; // Was incorrectly rejected by Clang, is now accepted.

- Implemented `WG14 N3124 <https://www.open-std.org/jtc1/sc22/wg14/www/docs/n3124.pdf>_`,
  which allows any universal character name to appear in character and string literals.


Non-comprehensive list of changes in this release
-------------------------------------------------

New Compiler Flags
------------------

Deprecated Compiler Flags
-------------------------

Modified Compiler Flags
-----------------------

Removed Compiler Flags
-------------------------

Attribute Changes in Clang
--------------------------

Improvements to Clang's diagnostics
-----------------------------------
- Clang constexpr evaluator now prints template arguments when displaying
  template-specialization function calls.

Bug Fixes in This Version
-------------------------
- Fixed an issue where a class template specialization whose declaration is
  instantiated in one module and whose definition is instantiated in another
  module may end up with members associated with the wrong declaration of the
  class, which can result in miscompiles in some cases.

Bug Fixes to Compiler Builtins
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Bug Fixes to Attribute Support
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Bug Fixes to C++ Support
^^^^^^^^^^^^^^^^^^^^^^^^

- Clang limits the size of arrays it will try to evaluate at compile time
  to avoid memory exhaustion.
  This limit can be modified by `-fconstexpr-steps`.
  (`#63562 <https://github.com/llvm/llvm-project/issues/63562>`_)

- Fix a crash caused by some named unicode escape sequences designating
  a Unicode character whose name contains a ``-``.
  (`Fixes #64161 <https://github.com/llvm/llvm-project/issues/64161>_`)

- Fix cases where we ignore ambiguous name lookup when looking up memebers.
  (`#22413 <https://github.com/llvm/llvm-project/issues/22413>_`),
  (`#29942 <https://github.com/llvm/llvm-project/issues/29942>_`),
  (`#35574 <https://github.com/llvm/llvm-project/issues/35574>_`) and
  (`#27224 <https://github.com/llvm/llvm-project/issues/27224>_`).

Bug Fixes to AST Handling
^^^^^^^^^^^^^^^^^^^^^^^^^

Miscellaneous Bug Fixes
^^^^^^^^^^^^^^^^^^^^^^^

Miscellaneous Clang Crashes Fixed
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Target Specific Changes
-----------------------

AMDGPU Support
^^^^^^^^^^^^^^

X86 Support
^^^^^^^^^^^

Arm and AArch64 Support
^^^^^^^^^^^^^^^^^^^^^^^

Windows Support
^^^^^^^^^^^^^^^

LoongArch Support
^^^^^^^^^^^^^^^^^

RISC-V Support
^^^^^^^^^^^^^^

CUDA/HIP Language Changes
^^^^^^^^^^^^^^^^^^^^^^^^^

CUDA Support
^^^^^^^^^^^^

AIX Support
^^^^^^^^^^^

WebAssembly Support
^^^^^^^^^^^^^^^^^^^

AVR Support
^^^^^^^^^^^

DWARF Support in Clang
----------------------

Floating Point Support in Clang
-------------------------------
- Add ``__builtin_elementwise_log`` builtin for floating point types only.
- Add ``__builtin_elementwise_log10`` builtin for floating point types only.
- Add ``__builtin_elementwise_log2`` builtin for floating point types only.
- Add ``__builtin_elementwise_exp`` builtin for floating point types only.
- Add ``__builtin_elementwise_exp2`` builtin for floating point types only.
- Add ``__builtin_set_flt_rounds`` builtin for X86, x86_64, Arm and AArch64 only.
- Add ``__builtin_elementwise_pow`` builtin for floating point types only.
- Add ``__builtin_elementwise_bitreverse`` builtin for integer types only.

AST Matchers
------------

clang-format
------------

libclang
--------

Static Analyzer
---------------

.. _release-notes-sanitizers:

Sanitizers
----------

Python Binding Changes
----------------------

Additional Information
======================

A wide variety of additional information is available on the `Clang web
page <https://clang.llvm.org/>`_. The web page contains versions of the
API documentation which are up-to-date with the Git version of
the source code. You can access versions of these documents specific to
this release by going into the "``clang/docs/``" directory in the Clang
tree.

If you have any questions or comments about Clang, please feel free to
contact us on the `Discourse forums (Clang Frontend category)
<https://discourse.llvm.org/c/clang/6>`_.

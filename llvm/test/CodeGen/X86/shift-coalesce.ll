; NOTE: Assertions have been autogenerated by utils/update_llc_test_checks.py
; RUN: llc < %s -mtriple=i686-- -x86-asm-syntax=intel | FileCheck %s

; PR687

define i64 @foo(i64 %x, i64* %X) {
; CHECK-LABEL: foo:
; CHECK:       # %bb.0:
; CHECK-NEXT:    push esi
; CHECK-NEXT:    .cfi_def_cfa_offset 8
; CHECK-NEXT:    .cfi_offset esi, -8
; CHECK-NEXT:    mov esi, dword ptr [esp + 8]
; CHECK-NEXT:    mov edx, dword ptr [esp + 12]
; CHECK-NEXT:    mov eax, dword ptr [esp + 16]
; CHECK-NEXT:    movzx ecx, byte ptr [eax]
; CHECK-NEXT:    mov eax, esi
; CHECK-NEXT:    shl eax, cl
; CHECK-NEXT:    shld edx, esi, cl
; CHECK-NEXT:    test cl, 32
; CHECK-NEXT:    je .LBB0_2
; CHECK-NEXT:  # %bb.1:
; CHECK-NEXT:    mov edx, eax
; CHECK-NEXT:    xor eax, eax
; CHECK-NEXT:  .LBB0_2:
; CHECK-NEXT:    pop esi
; CHECK-NEXT:    .cfi_def_cfa_offset 4
; CHECK-NEXT:    ret
        %tmp.1 = load i64, i64* %X           ; <i64> [#uses=1]
        %tmp.3 = trunc i64 %tmp.1 to i8         ; <i8> [#uses=1]
        %shift.upgrd.1 = zext i8 %tmp.3 to i64          ; <i64> [#uses=1]
        %tmp.4 = shl i64 %x, %shift.upgrd.1             ; <i64> [#uses=1]
        ret i64 %tmp.4
}


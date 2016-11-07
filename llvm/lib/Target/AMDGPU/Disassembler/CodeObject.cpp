//===- CodeObject.cpp - ELF object file implementation ----------*- C++ -*-===//
//
//                     The LLVM Compiler Infrastructure
//
// This file is distributed under the University of Illinois Open Source
// License. See LICENSE.TXT for details.
//
//===----------------------------------------------------------------------===//
//
// This file defines the HSA Code Object file class.
//
//===----------------------------------------------------------------------===//

#include "CodeObject.h"

namespace llvm {

using namespace object;

const ELFNote* getNext(const ELFNote &N) {
  return reinterpret_cast<const ELFNote *>(
    N.getDesc().data() + alignTo(N.descsz, ELFNote::ALIGN));
}

ErrorOr<const amd_kernel_code_t *> KernelSym::getAmdKernelCodeT(
  const HSACodeObject *CodeObject) const {
  auto TextOr = CodeObject->getTextSection();
  if (!TextOr) {
    return TextOr.getError();
  }

  auto ArrayOr = CodeObject->getELFFile()->getSectionContentsAsArray<uint8_t>(*TextOr);
  if (!ArrayOr)
    return ArrayOr.getError();

  return reinterpret_cast<const amd_kernel_code_t *>((*ArrayOr).data() + getValue());
}

ErrorOr<const KernelSym *> KernelSym::asKernelSym(const HSACodeObject::Elf_Sym *Sym) {
  if (Sym->getType() != ELF::STT_AMDGPU_HSA_KERNEL)
    return std::error_code();

  return static_cast<const KernelSym *>(Sym);
}

void HSACodeObject::InitMarkers() const {
  auto TextSecOr = getTextSection();
  if (!TextSecOr)
    return;

  KernelMarkers.push_back((*TextSecOr)->sh_size);

  for (const auto &Sym : kernels()) {
    auto Kernel = KernelSym::asKernelSym(getSymbol(Sym.getRawDataRefImpl())).get();
    KernelMarkers.push_back(Kernel->st_value);
    if (auto KernelCodeOr = Kernel->getAmdKernelCodeT(this)) {
      KernelMarkers.push_back(Kernel->st_value + (*KernelCodeOr)->kernel_code_entry_byte_offset);
    }
  }

  array_pod_sort(KernelMarkers.begin(), KernelMarkers.end());
}

HSACodeObject::note_iterator HSACodeObject::notes_begin() const {
  if (auto NotesOr = getNoteSection()) {
    if (auto ContentsOr = getELFFile()->getSectionContentsAsArray<uint8_t>(*NotesOr))
      return const_varsize_item_iterator<ELFNote>(*ContentsOr);
  }

  return const_varsize_item_iterator<ELFNote>();
}

HSACodeObject::note_iterator HSACodeObject::notes_end() const {
  return const_varsize_item_iterator<ELFNote>();
}

iterator_range<HSACodeObject::note_iterator> HSACodeObject::notes() const {
  return make_range(notes_begin(), notes_end());
}

kernel_sym_iterator HSACodeObject::kernels_begin() const {
  auto TextIdxOr = getTextSectionIdx();
  if (!TextIdxOr)
    return kernels_end();

  auto TextIdx = TextIdxOr.get();
  return kernel_sym_iterator(symbol_begin(), symbol_end(),
    [this, TextIdx](const SymbolRef &Sym)->bool {
      auto KernelOr = KernelSym::asKernelSym(getSymbol(Sym.getRawDataRefImpl()));
      if (!KernelOr || (*KernelOr)->st_shndx != TextIdx)
        return false;

      return true;
    });
}

kernel_sym_iterator HSACodeObject::kernels_end() const {
  return kernel_sym_iterator(symbol_end(), symbol_end(),
                             [](const SymbolRef&){return true;});
}

iterator_range<kernel_sym_iterator> HSACodeObject::kernels() const {
  return make_range(kernels_begin(), kernels_end());
}

ErrorOr<ArrayRef<uint8_t>> HSACodeObject::getKernelCode(const KernelSym *Kernel) const {
  auto KernelCodeTOr = Kernel->getAmdKernelCodeT(this);
  if (!KernelCodeTOr)
    return KernelCodeTOr.getError();

  auto TextOr = getTextSection();
  if (!TextOr)
    return TextOr.getError();

  auto SecBytesOr = getELFFile()->getSectionContentsAsArray<uint8_t>(*TextOr);
  if (!SecBytesOr)
    return SecBytesOr.getError();

  uint64_t CodeStart = Kernel->getValue() +
                       (*KernelCodeTOr)->kernel_code_entry_byte_offset;
  auto CodeEndI = std::upper_bound(KernelMarkers.begin(),
                                   KernelMarkers.end(),
                                   CodeStart);
  uint64_t CodeEnd = CodeStart;
  if (CodeEndI != KernelMarkers.end())
    CodeEnd = *CodeEndI;
  
  return SecBytesOr->slice(CodeStart, CodeEnd - CodeStart);
}

ErrorOr<const HSACodeObject::Elf_Shdr *> 
HSACodeObject::getSectionByName(StringRef Name) const {
  auto ELF = getELFFile();
  auto SectionsOr = ELF->sections();
  if (!SectionsOr)
    return SectionsOr.getError();
  
  for (const auto &Sec : *SectionsOr) {
    auto SecNameOr = ELF->getSectionName(&Sec);
    if (std::error_code EC = SecNameOr.getError()) {
      return EC;
    } else if (*SecNameOr == Name) {
      return ErrorOr<const Elf_Shdr *>(&Sec);
    }
  }
  return object_error::invalid_section_index;
}

ErrorOr<uint32_t> HSACodeObject::getSectionIdxByName(StringRef Name) const {
  auto ELF = getELFFile();
  uint32_t Idx = 0;
  auto SectionsOr = ELF->sections();
  if (!SectionsOr)
    return SectionsOr.getError();

  for (const auto &Sec : *SectionsOr) {
    auto SecNameOr = ELF->getSectionName(&Sec);
    if (std::error_code EC = SecNameOr.getError()) {
      return EC;
    } else if (*SecNameOr == Name) {
      return Idx;
    }
    ++Idx;
  }
  return object_error::invalid_section_index;
}

ErrorOr<uint32_t> HSACodeObject::getTextSectionIdx() const {
  if (auto IdxOr = getSectionIdxByName(".text")) {
    auto SecOr = getELFFile()->getSection(*IdxOr);
    if (SecOr || isSectionText(toDRI(*SecOr)))
      return IdxOr;
  }
  return object_error::invalid_section_index;
}

ErrorOr<uint32_t> HSACodeObject::getNoteSectionIdx() const {
  return getSectionIdxByName(".note");
}

ErrorOr<const HSACodeObject::Elf_Shdr *> HSACodeObject::getTextSection() const {
  if (auto IdxOr = getTextSectionIdx())
    return getELFFile()->getSection(*IdxOr);

  return object_error::invalid_section_index;
}

ErrorOr<const HSACodeObject::Elf_Shdr *> HSACodeObject::getNoteSection() const {
  if (auto IdxOr = getNoteSectionIdx())
    return getELFFile()->getSection(*IdxOr);

  return object_error::invalid_section_index;
}

} // namespace llvm
"""M0 compiler smoke check. This validates an ELF; it is not a CPU or loader."""
import sys
from pathlib import Path

from elftools.elf.elffile import ELFFile


def check(path: Path) -> None:
    with path.open("rb") as stream:
        elf = ELFFile(stream)
        assert elf.elfclass == 32 and elf.little_endian, "expected ELF32 little endian"
        assert elf["e_machine"] == "EM_RISCV", "expected RISC-V"
        assert elf["e_type"] == "ET_EXEC", "expected static executable"
        assert elf["e_flags"] == 0, "unexpected compressed/float/embedded ABI flags"
        assert not any(s["p_type"] in ("PT_INTERP", "PT_DYNAMIC") for s in elf.iter_segments())
        loads = [s for s in elf.iter_segments() if s["p_type"] == "PT_LOAD"]
        assert loads, "ELF has no loadable segments"
        for seg in loads:
            assert seg["p_filesz"] <= seg["p_memsz"]
            assert seg["p_paddr"] == seg["p_vaddr"], "M0 uses identical load/run addresses"
            assert 0x10000 <= seg["p_vaddr"] <= seg["p_vaddr"] + seg["p_memsz"] <= 0x20000
            assert len(seg.data()) == seg["p_filesz"], "truncated segment"
        entry = elf["e_entry"]
        assert entry % 4 == 0
        assert any(s["p_flags"] & 1 and s["p_vaddr"] <= entry < s["p_vaddr"] + s["p_filesz"] for s in loads)
        attrs = elf.get_section_by_name(".riscv.attributes")
        assert attrs and b"rv32i2p1\x00" in attrs.data(), "expected exact rv32i2p1 target attribute"
        assert any(s["p_memsz"] > s["p_filesz"] for s in loads), "probe should exercise BSS"
        print(f"PASS {path}: ELF32 / little endian / RISC-V / RV32I / ILP32; entry=0x{entry:08x}")
        for seg in loads:
            print(f"  PT_LOAD address=0x{seg['p_vaddr']:08x} file={seg['p_filesz']} memory={seg['p_memsz']}")


if __name__ == "__main__":
    check(Path(sys.argv[1]))

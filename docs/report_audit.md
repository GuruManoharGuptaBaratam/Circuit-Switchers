# Phase I report audit

The clean supplied clone and live GitHub main both resolved to
`9a227c8fb9713d0b9284dcb9cd3ad7cb10bc733a`. The two planning PDFs
describe scope and assignments. The RTL, Git history and current regression
establish delivered behavior.

| Previous report claim | Actual implementation | Evidence | Correction |
| --- | --- | --- | --- |
| Report audits `370a8f7` | Baseline includes Members 3 and 4 | `3b44e0e`, `cb44829`, `7cf0ef7`, merge `9a227c8` | Use current baseline |
| Geometry is 1 KiB, 64 lines, 16 bytes per line and 22/6/4 fields | Matches decoder slices and RAM widths | `rtl/address_decoder.v`, `rtl/*ram.v` | Keep, distinguish data from metadata |
| Top-level response is interface only and dependencies are missing | All modules are instantiated with functional RTL | `rtl/cache_top.v`, `scripts/check_cache_top.sh` | Document integrated read path |
| Lookup, comparator and selectors are pending | A valid bit and 22-bit tag equality determine a hit. Cached and refill blocks have separate byte selectors | `rtl/cache_lookup.v`, `rtl/tag_comparator.v`, `rtl/data_selector.v` | Update prose and diagrams |
| Refills and replacement are pending | Aligned block address from active tag/index. Ready qualifies one refill edge. Response bypass selects a byte from the memory block | `rtl/cache_controller.v`, `rtl/cache_top.v` | Show implemented sequencing |
| Stub build succeeds and no-stub elaboration is blocked | Old no-stub failure predates delivered controller/memory RTL | Historical audit log and current real-only compile | Preserve historical evidence with provenance |
| Four controller states, 2/8 cycles and 6-cycle penalty | Four states confirmed. Counts refer to rising edge acceptance through rising edge response sampling | `rtl/cache_controller.v`, `rtl/main_memory_model.v`, Member 5 monitor | Clarify cycle convention |
| Module test checks imply integrated evidence | Decoder/storage/lookup are unit tests. Member 4 independently tests integrated controller behavior | `tb/tb_*.v`, simulation logs | Distinguish assertion counts from completed CPU transactions |
| Member 3 and 5 jointly verified conflicts in prior work | Member 3's Git history shows lookup/selection and directed checks. No baseline Member 5 workload delivery | Git history and baseline test files | Remove unsupported coordination attribution |
| No Member 5 tests or measurements | Full-system scoreboard and workload entry points added for this milestone | `tb/tb_cache_system.v`, metrics and VCDs | Report freshly executed workload results |
| Bibliography exists | All bibliography lines were commented out | Baseline report source | Restore checked references and resolve citations |
| Editable Mermaid sources are tracked | Baseline tracks rendered files and a historical render manifest | `git ls-tree -r 9a227c8 submission/report/figures` | Supply editable replacements for stale diagrams |
| Video remains unrecorded | Team recording and link have not been supplied | Submission inventory | Retain pending status and supply spoken script |

## Bibliography checks

- Alan Jay Smith, “Cache Memories,” ACM Computing Surveys 14(3), 473–530,
  September 1982. ACM's Crossref record confirms
  [DOI 10.1145/356887.356892](https://api.crossref.org/works/10.1145/356887.356892).
- Hennessy and Patterson's sixth edition and its memory hierarchy chapter
  were confirmed against [Elsevier's edition record](https://shop.elsevier.com/books/computer-architecture/hennessy/978-0-12-811905-1).
- Patterson and Hennessy's second RISC-V edition and memory hierarchy
  chapter were confirmed against [Elsevier's ISBN record](https://www.educate.elsevier.com/book/details/9780128203316).
- The historical Verilog standard citation was removed with the language
  standards discussion. The report describes the actual Icarus regression
  and does not make a claim of conformance to that standard.

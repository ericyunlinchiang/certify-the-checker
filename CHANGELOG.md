# Changelog

## v0.3.4 (2026-11-25)
- New column: compiler warnings (`gcc -Wall -Wextra -Wconversion -Wsign-conversion`); silent on all six examples, also
  with the explicit cast in 01 removed. New "any static check" column. Results of the other columns unchanged.
- README: says up front that this is not a new discovery; new section on combining checks and the "white zone", with
  three 2026 measurements (feedback from r/cprogramming).

## v0.3.3 (2026-11-24)
- DOI badge, "How to cite" section and DOI in CITATION.cff (Zenodo, all versions: 10.5281/zenodo.24493237).

## v0.3.2 (2026-11-24)
- README: related work (how this relates to large benchmark suites such as NIST Juliet).
- First release archived on Zenodo (citable with a DOI).

## v0.3.1 (2026-11-24)
- README: FAQ answering common questions with the measured results.
- Project web page in `docs/` (GitHub Pages), CHANGELOG.

## v0.3 (2026-11-24)
- Two more examples: 05 (a bug the tests never reach; two checkers find it) and 06 (divide by zero, not a memory bug).
- Each example lists its bug lines (root cause and where it goes wrong); a checker finds the bug if it reports any of them.
- Coverage depth measured with gcov for each kind of input (none / partial / line / branch / input-class).
- Every run writes a readout.json that follows `schema/readout.schema.json`; CI validates it.
- Stricter checker flags (`gcc -Wall -Wextra -fanalyzer`, `cppcheck --enable=all`); results for 01-04 unchanged.
- The standard opens with a plain-language version; README says what the repo does and does not show.
- Dockerfile; `llms.txt` and `DIGEST.md` (whole repo in one file); CI publishes raw outputs and builds the Docker image.

## v0.2 (2026-11-24)
- Four examples with a results table, `tools/run_all.sh` and `tools/run_example.sh`, CONTRIBUTING, issue templates, CI.

## v0.1 (2026-11-24)
- Plain-language README, runnable example folder, readout template.

## v0 (2026-11-24)
- First release: the standard and one example.

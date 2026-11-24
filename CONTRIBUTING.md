# Contributing

Contributions of all sizes are welcome. You do not need a security background.

## 1. Share a checker result (easiest)
Run any checker you have (Coverity, CodeQL, Semgrep, Infer, PVS-Studio, Clang-Tidy, an AI code reviewer, ...) on
`examples/*/target.c` and open an issue with the **Checker result** template. Include the checker version and the exact
command, so others can reproduce it. Results that disagree with the table are the most interesting ones.

## 2. Add an example
Each example is one folder in `examples/` with three small files:

- `target.c`: one function with one bug, written by you for this repository (no third-party code, no real vulnerabilities
  in other projects);
- `harness.c`: a `main` that takes the input-class name as its first argument and calls the function once;
- `example.env`: `TITLE`, `FUNC` (function name), `BUG_LINES` (root-cause line and the line where it goes wrong),
  `BUG_LINES_WHY` (one sentence per line), `CLASSES` (kinds of input; usually at least one fine and one that triggers the bug).

Then:

1. run `tools/run_example.sh examples/<your-folder>` and check the output looks right;
2. run `tools/run_all.sh`, then update `examples/expected-results.txt` with the new line;
3. regenerate `DIGEST.md` (`tools/make_digest.sh > DIGEST.md`) and `SHA256SUMS`:
   `find . -type f ! -name SHA256SUMS ! -path './.git/*' | sed 's|^\./||' | LC_ALL=C sort | xargs sha256sum > SHA256SUMS`;
4. open a pull request. CI runs every example on Ubuntu 24.04, checks the table, validates the readouts and publishes raw outputs.

Good examples are short (under 30 lines) and have one clear bug. Cases where a checker says CLEAN are welcome, and so are
cases where a checker finds what the tests miss: the point is an honest table, not a one-sided one.

## 3. Improve the standard
Open an issue or pull request against `STANDARD-v0.md`. Explain the problem with a concrete case if you can.

## License of contributions
By contributing you agree that text is licensed CC BY 4.0 and code Apache-2.0, as for the rest of the repository.

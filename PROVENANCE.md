# Provenance

- Standard (STANDARD-v0.md): written by the author. Its building blocks are common public engineering ideas: static and
  LLM-generated checkers under-approximate; execution and formal oracles have different blind spots; a clean verdict holds
  only for the configuration and inputs it was obtained under; coverage has depth (line / branch / condition / input class).
- Examples: targets, harnesses and scripts are the author's own code, written for this repository. The checkers are three
  public static analyzers run unmodified (clang's static analyzer, gcc -fanalyzer, cppcheck); execution uses
  AddressSanitizer and UBSan; coverage is measured with gcov. Tool versions are listed in the README.
- These files were prepared and reproduced in a personal environment, using only public tools.

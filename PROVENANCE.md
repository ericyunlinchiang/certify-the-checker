# Provenance

- Standard (STANDARD-v0.md): written by the author. Its building blocks are common public engineering ideas: static and
  LLM-generated checkers under-approximate; execution and formal oracles have different blind spots; a clean verdict holds
  only for the configuration and inputs it was obtained under; coverage has depth (line / branch / condition / input class).
- Worked example: target, harness and scripts are the author's own code, written for this package. The checkers are two
  public static analyzers run unmodified (clang's static analyzer and gcc -fanalyzer); the execution oracle is
  AddressSanitizer. Tool versions are pinned in the example README.
- These files were prepared and reproduced in a personal environment, using only public tools.

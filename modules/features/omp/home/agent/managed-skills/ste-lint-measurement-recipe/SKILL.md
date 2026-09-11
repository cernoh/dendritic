---
name: ste-lint-measurement-recipe
description: "Measure and clean up STE prose with ~/.omp/agent/scripts/ste-lint.py: the stdin-vs-file invocation rule, running it without a system python via nix, and the false positives and markdown gotchas that make the naive counters lie. Use when drafting or linting issues, PR bodies, READMEs, or docs into ASD-STE100 Simplified Technical English."
---

# Measuring STE

The heuristic linter lives at `~/.omp/agent/scripts/ste-lint.py`. It measures the
mechanical subset of ASD-STE100. Judgment rules still need a reading pass.

Use it in the delta workflow: measure, apply `skill://ste-writing`, measure again.
The drop in violations per 100 words is the signal.

## Invocation

**The linter reads stdin only when no file arguments are passed.** With file
arguments it prints one summary line per file and hides the detail.

```bash
# summary line per file (no detail)
python3 ~/.omp/agent/scripts/ste-lint.py draft.md

# full JSON, one file at a time (needed to see WHICH rule fired)
python3 ~/.omp/agent/scripts/ste-lint.py < draft.md
```

`total` is the number to drive to zero. `total_per100w` compares drafts of
different lengths. `em_dash` is reported separately and is NOT part of `total`.

## No system python on NixOS

`python3` is often absent. Run the script through nix:

```bash
nix shell nixpkgs#python3 --command python3 ~/.omp/agent/scripts/ste-lint.py < draft.md
```

## Locate the offending text

The JSON names the rule, not the sentence. Print the matches with a helper. The
rule patterns are module attributes, so import the script rather than copying
regexes:

```python
import importlib.util, pathlib, re
spec = importlib.util.spec_from_file_location(
    "stelint", str(pathlib.Path.home() / ".omp/agent/scripts/ste-lint.py"))
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)

t = m.strip_code(pathlib.Path(PATH).read_text())
print("LONG:", [s for s in m.sentences(t) if m.wc(s) > 20])
print("passive:", re.findall(rf"\b{m.BE}\s+(?:\w+ed|{m.PP_IRREG})\b", t, re.I))
print("hedge:", re.findall(r"\b(?:" + "|".join(map(re.escape, m.MODAL_HEDGE)) + r")\b", t, re.I))
```

`sentences()` and `wc()` are the counters behind the long-sentence rule. Reuse
them rather than re-deriving.

## False positives to expect

These fire on correct prose. Recognise them instead of rewriting good text.

| Rule | Trigger | Why |
| --- | --- | --- |
| passive_voice | `are United` | `BE + PP_IRREG` is a flat word list, so any participle-shaped word matches. |
| contraction | `adapter's`, `site's`, `retailer's` | The pattern includes `\b\w+['’]s\b`, so every possessive counts. |
| nominalization | `evidence of`, `presence of` | `\b\w{4,}(tion\|ment\|ance\|ence)\s+of\b` matches ordinary noun phrases. |

Rewrites that clear these are usually still fine prose. When the possessive is
genuine, prefer "the X of the Y" or a definite noun phrase.

## Markdown gotchas that make counters lie

1. **Blank-line-separate list items.** `long_paragraph(>6s)` splits on
   `\n\s*\n`. A numbered list written as one tight block counts as ONE paragraph
   with N sentences, and fires. Joining the items with blank lines fixes both
   the count and the readability.

2. **Tables count as paragraphs.** A markdown table row is one "sentence" to the
   splitter, so a wide table fires the paragraph rule. Convert the table to a
   numbered list of `**Field.** value` items when it must pass.

3. **Fenced code and inline code are stripped** before counting, so paths and
   identifiers in backticks do not inflate the word count. Prose inside a fence
   is invisible to the linter.

4. **Quoted material still counts.** A long quotation from a terms page can
   fire the paragraph rule. Break the quote into a block or trim it.

## Sentence splitting

`sentences()` splits on `[.!?:]` followed by whitespace and a capital. A list
label like `1. **Target**` counts as its own sentence. Headings lose their `#`
prefix and count too. Expect the sentence count to exceed the prose sentence
count in structured documents.

## Practical loop

1. Draft the text.
2. `ste-lint.py file.md` for the total.
3. If the total is above zero, re-run the flagged file through stdin for the
   rule names.
4. Run the locator helper for the rule that fired.
5. Fix, then re-run the summary across every file before publishing.

Lint before creating the issue or PR. A repository with an STE CI job rejects the
body after it exists.

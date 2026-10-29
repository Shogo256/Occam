# Occam

A feasibility checkpoint for screens of accumulation in Gram-negative
bacteria. You state the screen you are planning; it answers which parts of it
hold, which do not, and what to do about the parts that do not.

The conditions it knows are the eNTRy rules, which are about **entry across
the Gram-negative outer membrane** — whether a compound gets in, not whether
it works once it is there. Activity is a separate axis here, and a weaker one:
the model is fitted on a Gram-positive label standing in for target binding
without the permeability barrier, and every run says so.

**It emits no molecules.** What to make is the chemist's call. This answers
whether the screen around that call can establish what it is meant to.

## One minute

Build the image once (**Running it**, below), then:

```bash
podman run --rm occam \
  "120 distinct scaffolds from the CHAMP library, primary amine strictly required, rotatable bonds at most 5, molecular weight under 450."
```

Verbatim, trimmed where marked:

```
occam 9696a84b05-dirty at 2026-10-16T11:11:41+09:00
read as:
  library              CHAMP (accumulation in E. coli, 1,132) - no primary
                       amine in 1,132 rows (measured 2026-10-14) ...
  deliverable          120 distinct scaffolds
                       counted as Bemis-Murcko frameworks (RDKit
                       MurckoScaffoldSmiles), one per distinct framework

  ionisable nitrogen   an unhindered primary amine  (not negotiable)
                       Richter 2017, first eNTRy condition, best case
                       the second eNTRy condition, globularity at most 0.25,
                         is not evaluated here: it needs a 3D conformer and
                         nothing in this pipeline generates one
  flexibility          at most 5 rotatable bonds  (may be relaxed)
                       Richter 2017, third eNTRy condition
  molecular weight     under 450 Da  (may be relaxed)
                       chosen by this study; no published bound
                       note: not a permeability bound. Richter 2017 reports no
                             correlation between accumulation and molecular
                             weight; measured here, 450 -> 600 changes
                             survivors 1.1x against 2.8x for rotatable bonds.
                             Read it as a size bound.

every part of the request was read. 2 leftover fragment(s) were articles,
prepositions or the words for the data itself.

comparing 9 specifications in a single pass over the library
  1 requirement(s) held as asked, the rest varied
  1,132 molecules read in 3.2s, holding 36 KiB of state

requirements that did not change the result:
  flexibility filtered nothing on this library: every pair of specifications
    differing only in it gave the same survivor count, in all 3 comparisons.
    Do not report it as a constraint that was applied.
  molecular weight filtered nothing on this library: ...

verdict: no setting of these knobs can fill the request

what would unblock it:
  a larger or different library: the best reachable is 0 distinct scaffolds
    against 120 required
  or a lower requirement, which is the requester's decision

which condition removed everything:
  ionisable nitrogen   an unhindered primary amine   keeps 0 of 1,132 (0.0%)  <- removes everything on its own
  flexibility          at most 5 rotatable bonds     keeps 1,072 of 1,132 (94.7%)
  molecular weight     under 450 Da                  keeps 1,129 of 1,132 (99.7%)
  each condition applied by itself, over one pass of the library. A condition
    keeping 0 on its own removes everything whatever the others do.
    ionisable nitrogen: it was held as asked, so no looser setting of it was
      compared. Dropping the mark on it is what would let the sweep try one
```

Three things there are the whole design. One condition emptied the set and the
other two are named as having removed almost nothing — so a reader does not
spend a week loosening the weight bound. The weight bound is marked as this
project's choice rather than a published one. And the request's own `strictly`
is identified as what stopped an alternative being offered.

## The near miss

A library that can nearly fill the request gets two specifications, not one.
Asked for 500 scaffolds from a ZINC22 slice:

```
verdict: the specification as asked cannot fill the request; a looser one can

as asked: 430 molecules pass, about 187 distinct scaffolds (sketch estimate;
  counted exactly only where the verdict turns on it) - cannot fill the request

recommended instead:
  an unhindered primary amine; at most 9 rotatable bonds; under 450 Da
  1,820 molecules pass, 686 distinct scaffolds, counted exactly
  loosened flexibility to at most 9 rotatable bonds
    the published limit moved; no chemical claim

closest specification that did not reach:
  an unhindered primary amine; at most 7 rotatable bonds; under 600 Da
  1,292 molecules pass, 494 distinct scaffolds, counted exactly - 6 short of the 500 asked for
  the closest specification that was counted exactly and did not reach the
    request. It is not an alternative -- it does not fill the order -- but how
    far short it fell is the figure that says whether to widen the library or
    lower the request, and a recommendation further away cannot say it
```

686 scaffolds answers the question and closes it. *Six short* is the figure
that leaves a decision: drop the request to 494, widen the library, or move
one more published limit. A tool that reports only the specification that
worked has thrown that away.

## What a screen of it would establish

The third part is the one a reviewer asks about. It runs on the recommended
specification and reports what the screen could and could not settle
(trimmed at the `...`):

```
  ordering the survivors: cannot be answered
      a top N cannot be drawn from this set: 46.5% of scores are distinct
        against a 50% floor declared before the run, measured on 1,820
        molecules, so whatever breaks the tie would be choosing them rather
        than the score.
      the 50% floor is declared, not derived: no published source states a
        distinct-share floor. ... Read a verdict near the floor as near a
        convention

  predicting activity: can be answered only by extrapolating past the training set
      100.0% of this set sits outside the structures the model was fitted on,
        and none of it is inside (median 0.217, max 0.371 against a 0.4
        threshold). An order can be produced; its meaning is not established.
      positive control: passes
        the same measurement run inside the training set gives median 0.747,
          with 94.0% at or above the threshold, so the measurement can clear
          it
        this rules out: a fingerprint radius or bit-length mismatch, or salts
          and stereochemistry left on one side. Any of those would depress the
          control too.
      what would close it: 318 compounds measured, one per neighbourhood
        at Tanimoto 0.4. 56 of them cover half the set, 153 cover four fifths
        44 neighbourhoods hold one compound, so the tail is one purchase each
```

Four things in that block are the reason this exists rather than a filter
script.

**Every refusal carries its cost to lift.** "Outside the training set" ends in
318 compounds, 56 of them for half the set, and the count is given across the
threshold band (0.30: 196, 0.40: 318, 0.50: 502, 0.60: 699) because it is a
property of the threshold and not a fact about the library.

**Every negative result has a positive control.** The applicability verdict is
run again inside the training set, where it must pass — and does, at median
0.747. Without that, a fingerprint mismatch or a stray salt would read exactly
like a library that is out of domain.

**A declared number says it is declared.** The 50% floor is this project's
convention and says so, including that it does not single itself out over 0.45
or 0.55.

**It names what is actually tied.** Pressed for detail, the tie resolves to
1,551 molecules in 577 groups, *every one of them* a stereoisomer set the
fingerprint cannot see; counting chirality would give 1,816 distinct of 1,820
— and that is a refit of the activity model, not a flag to turn on. A "46.5%
of scores are distinct" with nothing under it is a number a reader can only
accept or reject.

## Running it

Two ways. Neither is a pip wheel: the engine is Rust and the chemistry is
RDKit, so a wheel would need a build matrix per platform and per Python
version and RDKit would still have to come from somewhere else afterwards.
The reasoning is at the top of the [`Dockerfile`](Dockerfile).

**Container.** Carries the four measured datasets, so it answers out of the
box:

```bash
git clone https://github.com/Shogo256/Occam && cd Occam
podman build --build-arg OCCAM_VERSION="$(git describe --always --dirty --abbrev=10)" -t occam .
podman run --rm occam --help
```

`docker` works the same. The build pulls the Rust toolchain and RDKit;
the image measured **633 MB** on 2026-10-16. Both base images are pinned by
digest, because they were not: two builds from the same Dockerfile on the same
day came out at 557 MB and 633 MB, and "about 560 MB" sat on this page while
the number was 633. Pass `OCCAM_VERSION` or every run reports its version as
`unknown`: an image carries no git history, and the line that stamps a result
has nothing else to read.

**From a checkout**, with [Nix](https://nixos.org/download):

```bash
./occam                 # type the request at the prompt
./occam --help
./occam "<request>"
```

`./occam` enters `shell.nix` itself. The dependencies are pinned there, and a
request run outside it would be using some other RDKit.

## Getting the data

A clone carries **no data at all** — only the manifests, one per dataset,
holding the source, the licence, the checksums of the files and what was
measured from them. That is deliberate: one source is CC BY-NC-ND, whose
NoDerivatives clause reaches sharing parts of it. See [`NOTICE`](NOTICE).

One command fetches what they declare and builds what the tool reads:

```bash
python3 py/fetch.py --dry-run    # what it would do, and nothing else
python3 py/fetch.py              # the four measured sets, 18 MB
python3 py/fetch.py --zinc       # and the ZINC22 slices, 73 MB gzipped
```

`--zinc` was written as "about 300 MB" before it had been run. Measured: 73 MB
gzipped over three slices, and the -N ingest is the slow part.

| | pinned at | ingest |
|---|---|---|
| CHAMP | Zenodo 17434251 | `py/ingest_champ.py` |
| GramNegAccum | `HergenrotherLab/GramNegAccum` v1.0 | `py/ingest_gna.py` |
| IMI-COMBINE | `IMI-COMBINE/broad_spectrum_prediction` `3c222f96` | `py/ingest_imi.py` |
| B3DB | `theochem/B3DB` v1.1.1 | `py/ingest.py` |

**The checksum is the guarantee, not the pin.** Every URL names a tag or a
commit, and a tag can be moved, so the bytes are hashed against the manifest
and a mismatch stops the run rather than ingesting it. Verified: the seven
files fetched this way are byte-identical to the ones every figure in
[`HANDOFF.md`](HANDOFF.md) was measured on, and the parquet rebuilt from them is byte-identical too —
1,132 / 197 / 22,052 / 7,807 rows.

**ZINC22** is opt-in and different. Its terms permit screening and the sharing
of screening results and require written permission to redistribute large
portions, so it is fetched from the source rather than shipped. No checksum
was ever recorded for any slice, so what gets verified is the row count after
ingest, and the slice's own line count against what the manifest declares —
weaker than a checksum, and `--dry-run` says so rather than leaving it to be
assumed.
Mount the result into the container:

```bash
podman run --rm -v "$PWD/zinc:/occam/data/work" occam "<request>"
```

The charge suffix in a ZINC filename is the **predicted protonation state at
pH 7.4**, not the formal charge of the structure as drawn. Nearly every SMILES
in every slice is written neutral. Confusing the two selects against the
published rule rather than for it, and it is why this tool has no charge knob;
the manifest says so at length.

## Writing a request

Write it the way you would describe the screen to a colleague. Four things
have to be in it.

> **500 distinct scaffolds** from the **dicationic ZINC library**,
> **primary amine strictly required**, **rotatable bonds at most 5**,
> **molecular weight strictly under 450**

| | what it is | if you leave it out |
|---|---|---|
| **how many of what** | `500 distinct scaffolds` | it stops and says so |
| **which library** | `the dicationic ZINC library` | it stops and says so |
| **the conditions** | the three below | it uses the strictest setting and tells you it did |
| **which you will not trade** | the word `strictly` | **everything becomes negotiable — see below** |

Anything it does not recognise, it stops on. It never rounds a number to the
nearest one it knows, and it never quietly drops a phrase it could not read.

The deliverable may be written in Japanese: `256 distinct 骨格` reads exactly
as `256 distinct scaffolds`. The confirmation prompt takes `はい` as well as
`y`. Everything else is English.

### The one thing worth being careful about

**Write `strictly` on the conditions you will not give up.** Without it, the
tool assumes every condition is open to negotiation, and the alternative it
proposes may give one away.

This is not an error, so nothing stops you. It is a different, equally valid
request — and it changes the answer completely. Measured this morning, the
same library and the same three conditions:

```
without "strictly"
  recommended: any nitrogen basic near pH 7.4; rotatable bonds at most 5;
               under 450 Da  ->  565 scaffolds, feasible

with "strictly"
  not feasible at any registered setting
    the most any of them reaches is about 72 distinct scaffolds against
    300 required
```

The first answer quietly relaxed **the primary amine** — the first eNTRy
condition, the one from Richter 2017 — to reach the number. It said so, in a
line most readers skip.

So read the echo at the top of every run. Each condition is marked:

```
  ionisable nitrogen   an unhindered primary amine  (not negotiable)
  flexibility          at most 5 rotatable bonds  (may be relaxed)
  molecular weight     under 450 Da  (not negotiable)
```

`--dry-run` prints exactly that and stops, in under a second. On anything
long, run it first.

**One more:** a `must` at the start of the sentence binds *everything* —
"The screening must satisfy the following: ..." makes every condition
non-negotiable, so **no alternative is proposed at all** and the answer is
yes or no. That is sometimes what you want. It is rarely what people expect.

### Which library

Say which charge state. The letter is **the form the molecule is predicted to
take at pH 7.4**, not the charge drawn in the structure file — those are
different things, and confusing them once cost this project a whole day's
results.

| write any of these | you get |
|---|---|
| `cationic ZINC` · `protonated ZINC` · `ZINC O slice` · `the +1 ZINC slice` | ZINC22, +1 at pH 7.4, 636,669 compounds. **The group the published rule is about** |
| `dicationic ZINC` · `ZINC +2 slice` · `multiply charged ZINC` · `ZINC P slice` | ZINC22, +2 or more, 17,775. Richest in primary amines — good for a trial run |
| `neutral ZINC` · `ZINC N slice` · `ZINC` | ZINC22, neutral, 1,000,000 of 4,572,322. **Stops**: Richter 2017 found 0 of 39 neutral compounds accumulating |
| `CHAMP` | accumulation measured in *E. coli*, 1,132 compounds |
| `GramNegAccum` · `GNA` | the eNTRy paper's own compounds, 197 |
| `IMI` | antibacterial activity, 22,051 |
| `B3DB` · `blood-brain` · `BBB` | blood-brain barrier, 7,807. **Stops** under the eNTRy conditions: wrong barrier |

The two that stop will run with `--yes` if you have read why. The reason is
printed either way.

### The conditions

Three, from Richter et al., *Nature* **545**:299 (2017) — the eNTRy rules.

| | write | |
|---|---|---|
| **an ionisable nitrogen** | `primary amine` | strictest reading: an unhindered primary amine |
| | `primary or secondary amine` | a secondary amine on carbon counts too |
| | `basic nitrogen` | any nitrogen basic near pH 7.4 |
| **flexibility** | `rotatable bonds at most 5` | the published limit |
| | `rotatable <= 7` or `rotatable bonds ≤ 9` | the limit moved. **No chemical claim** — it is a relaxation and is labelled one |
| **size** | `molecular weight under 450` | this project's choice. Not a permeability bound |
| | `MW under 600` | O'Shea & Moser, quoted in Richter 2017 — a statement about what exists, not a recommended cut-off |

Only **5, 7 or 9** and only **450 or 600**. Ask for 6, or for 500, and it
stops and offers the registered ones rather than picking for you.

**The second eNTRy condition is not evaluated.** Globularity at most 0.25
needs a 3D conformer and nothing here generates one. Every run says so. Two of
three conditions are applied, and the output never claims otherwise.

**There is no charge condition.** It was removed on 2026-10-11 after the
predicted protonation state and the drawn formal charge were confused with
each other. Naming one stops the run.

### Asking for a ranked list

You can. The answer addresses it directly:

```
you asked for the top 50. It cannot be drawn from this set: the scores are
  too tied for the order to be the model's, so whatever broke the tie would
  be choosing them.
```

That is the usual answer on these libraries, and the run says exactly why,
how far short it is, and what would change it.

### What it will not take from you

Numbers *about* the data. `the 100-million-item library`,
`7,394 distinct scaffolds`, `verified`, `pre-packed` — all discarded, with a
line saying they were. Every count in the answer comes from the measurement,
never from the request.

A target is matched against what has actually been measured here:
`an inhibitor of transglycosylase`, `against transglycosylase`. A bare word is
recorded, promoted if the evidence carries that label, and reported and run
past if not.

### A whole request, end to end

```bash
./occam --dry-run "500 distinct scaffolds from the cationic ZINC library,
                   primary amine strictly required,
                   rotatable bonds at most 5,
                   molecular weight strictly under 450"
```

Read the echo. If the conditions are marked the way you meant, drop
`--dry-run` and run it. For a record you will keep or submit, `--spec
request.json` takes the structured form instead of prose.

**Everything spelled out on this page is tested.** `tests/test_request.py`
puts each phrase through the reader and fails the build if it stops working,
so an example here that does not work is a broken build, not a stale
document.

## Before you use this

Five things, none of which the output can tell you:

1. **No experiment has been run.** Nothing here has touched a cell.
2. **No one else has ever run it.** External validation is zero.
3. **The eNTRy rules are Hergenrother lab's published work.** This applies
   them; it does not compete with them.
4. **Only ZINC22's open generations are used.** The site publishes credentials
   for the protected ones as a riddle; they were not used, because compounds
   drawn from them could affect the patentability of anything published from
   them. `data/raw/zinc22/manifest.json` records that.
5. **KeepOut is the same author and the same licence**, vendored under
   `third_party/keepout/`.

## Reading further

[`HANDOFF.md`](HANDOFF.md) is the whole record, in English. Sections 0 and 1
give the shape, section 4 is every established figure with what was withdrawn
beside it, and **section 7 is 117 contraindications** — every way this project
has been wrong, each marked with whether a test now stops it coming back.

It is worth reading section 7 before using any number from here. The habit it
records is the one the tool is built on: say what was measured, say what was
only inferred, and withdraw the second when it turns out to disagree with the
first.

## Tests

```bash
nix-shell --run 'python3 -m unittest tests/test_memory_invariant.py tests/test_ingest.py \
    tests/test_descriptors.py tests/test_folds.py tests/test_smiles.py \
    tests/test_invariants_locked.py tests/test_render.py tests/test_request.py \
    tests/test_no_duplicated_counts.py tests/test_contraindications.py \
    tests/test_prompts.py tests/test_documented_procedures.py'
nix-shell --run 'cd engine && cargo test --release -- --test-threads=1'
```

237 Python and 11 Rust. The module list is explicit on purpose: `unittest
discover` once collected nothing here and exited 0, which reads as green.

`OCCAM_PROMPTS=1` adds the slow layer — every recorded prompt run for real,
each record compared against `tests/fixtures/prompts/` field by field, 1,733
of them — and needs the data. 27 minutes, measured.
`--test-threads=1` is required, not tidiness: one Rust test deliberately holds
a guard that another trips if they overlap.

Some regions are frozen with [KeepOut](https://github.com/Shogo256/KeepOut)
and will refuse a structural edit. `tests/test_invariants_locked.py` lists
which ones and why each is frozen.

Output passes a boundary on the way out: a line carrying a Python repr stops
the run instead of reaching the reader. Three defects came out of the display
layer before it existed, the last of them a dict formatted into the summary a
reader stops at. It is in `render.display_boundary()`, and the reasoning for a
boundary rather than recorded strings to compare against is above it.

## Licence

Apache-2.0 — see [`LICENSE`](LICENSE). [`NOTICE`](NOTICE) says why that
licence, which datasets are not shipped here, and under whose terms.

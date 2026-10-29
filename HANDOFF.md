# Occam — handover

Last updated 2026-10-17. Working directory `/home/shogo/occam`.

**This document runs to section 13. Sections 0 and 1 give the whole shape,
section 8 gives the point to resume from. Read section 4 and section 7 — 117
contraindications — before using any number from here.**

Convention: comments in the code are English, and so is this document. It was
written in Japanese and translated on 2026-10-17 when the repository was
published; where the Japanese said something that had since become false, the
English says what is true now and names what changed.

---

## 0. Where this is (start here)

### What it is

**A checkpoint that assists a researcher.** Not a tool that produces a list of
drug candidates.

```
a request in -> bulk processing over large data, per request -> an assisting answer out
```

It returns three things.

| | |
|---|---|
| **what holds** | this specification can be answered with this data, and how many steps of relaxation it takes |
| **what does not** | it cannot be answered, and what is missing |
| **what instead** | **from measurement**: the resolution the evidence has, the specification that clears the floor, the nearest training set |

**It emits no molecules.** Which to make is the expert's judgement.

### Where the responsibility sits

```
NO   "we measure, you decide"
YES  "the consistency of what we hand you is ours. The scientific judgement is yours"
```

Proving scientific correctness is not what is being asked. **But what is
handed over must be what was asked for.** That guarantee broke three times on
2026-10-09 and -10 (sections 12 and 13).

### Using it

```bash
./occam "256 distinct scaffolds from the cationic ZINC library,
         primary amine, rotatable bonds at most 5,
         molecular weight strictly under 450"

./occam --spec request.json    # for a record or a submission; this is the authority
```

How to write a request, and what to watch for, is in **`README.md`**,
transcribed from the implementation. It used to be in `docs/prompt_format.md`;
`docs/` was made private on 2026-10-17 and the vocabulary moved to the page a
reader already opens, where `tests/test_request.py` now asserts every tested
spelling appears.

### What it can and cannot do

| | |
|---|---|
| **can** | decide whether a specification is answerable, propose relaxations with a frontier, decide whether an ordering can be drawn, decide applicability, compute how many compounds would close a gap, detect contradicting inputs, detect conditions that filter nothing |
| **cannot** | predict target specificity (no data), suggest chemistry (only substitutions in the registry and relaxations of its thresholds), generalise beyond this field (molecular descriptors and fingerprints only) |

### What to do next, in order

| | | |
|---|---|---|
| **1** | **external validation** | **nobody else has ever broken it.** The largest gap, and it is now possible: the repository is public |
| 2 | convert the prose contraindications to tests | ten in the queue in section 7, writable and not written |
| 3 | read ChEMBL by `target_chembl_id` | the hole under targets. Changing from `src_id` reaches it. Mind the CC BY-SA inheritance |
| 4 | conda-forge packaging | only once there is demand; the container and a clone cover it today |

**WITHDRAWN, 2026-10-17: "patent first, before showing anyone."** This section
used to open with a patent filing as the top priority, on the reasoning that
showing the work to an outside reader could count as disclosure, and noted
that no git remote was configured so no push could happen. The project was
published under Apache-2.0 instead, with no filing, and pushed to
github.com/Escoffier1156/Occam on 2026-10-17. `NOTICE` states why that licence
was chosen: its explicit patent grant is how the decision not to file is
stated in a form that binds.

---

## 0.5 Inventory of the implementation (every file)

Line counts measured 2026-10-17. The Japanese version's counts were from
2026-10-10 and every one of them had moved; `occam.py` alone had gone from 637
lines to 1,187.

### The assisting path (the product; new on 2026-10-09 and -10)

| file | what it does |
|---|---|
| **`occam.py`** 1,187 | **the one entry point.** Prose to a specification, deterministically and with no LLM, then through to the verdicts |
| `inventory.py` 283 | the inventory of evidence, read from the declarations in `data/raw/*/manifest.json`. `--find` searches a target name down to the label values |
| `feasible.py` 277 | the four-valued verdict (`answerable` / `not_answerable` / `answerable_but_extrapolating` / `undecidable`) and the count that would close a gap |
| `knobs.py` 348 | the conditions that can be turned, each with its **provenance** (published / relaxation / unjustified). The ones that cannot be turned are named too |
| `sweep.py` 442 | **27 specifications in one pass** (54 before the charge knob was retired; 9 or 3 when conditions are held as asked). HyperLogLog keeps distinct scaffolds in fixed state |
| `propose.py` 642 | constraint satisfaction and the fewest relaxation steps. **No weighted score.** Returns a frontier |
| `provenance.py` 332 | reads a library's slice from its own recorded provenance and checks it against the published rule. Detects a condition that contradicts it |
| `screenable.py` 1,354 | **whether an ordering can be drawn, whether the model's domain reaches, what it was trained on, and what instead.** With a positive control |
| `what_to_measure.py` 498 | how many compounds would bring a set inside the model's domain, one per neighbourhood |
| `coverage.py` 240 | coverage: the box, and nearest-neighbour distance |
| **`render.py`** 1,031 | **the display layer (new 2026-10-10).** No internal identifier reaches the screen. The record in JSON keeps them |
| `fetch.py` 354 | one command for the declared data: fetch what the manifests declare, verify the checksum, run the ingest (new 2026-10-16) |
| `charge_slices.py` 205 | the formal charge as drawn, per slice (new 2026-10-11). **The evidence for retiring the charge knob, reproducible down to the seed** |

#### Display and record are separate (`render.py`, 2026-10-10)

The screen was printing `primary_amine`, `mw_under_450`, `data/work/zinc_O`,
`[INERT]`, `not_answerable`. **Internal identifiers were leaking straight
through** to a reader who is a chemist, so the display was separated into one
layer.

| | read by | vocabulary |
|---|---|---|
| **the screen** | a person, once | `under 450 Da`, `ZINC22 tranche H29P240, -O slice (+1 at pH 7.4), 636,669 compounds` |
| **`data/work/*.json`** | anyone, later, with no interpretation | `mw_under_450`, `data/work/zinc_O` (**unchanged**) |

- the phrases live in `py/render.py`, and `py/knobs.py` — the one file where an
  edit changes a result — takes **no cosmetic edits**
- the risk of the two tables drifting is `tests/test_render.py`'s: add a
  setting without a phrase and it fails. **Every number inside a phrase is
  checked against the registry's own limit**, so 450 cannot be written as 500
- a setting with no phrase prints **as its identifier**. An English sentence
  guessed from the spelling would read fluently while being wrong about a
  number

Three more defects have come out of this layer since, which is what the
display boundary in section 7 (contraindications 108 and 110) is about.

### Measurement and verification (the path that produced the established figures)

| file | what it does |
|---|---|
| `stream_gbdt.py` 341 | **a histogram GBDT in bounded memory.** Used to decompose the 0.0540 residual |
| `inclusion.py` 445 | inclusion to the direction of transfer (**ended undecidable**) |
| `answerable.py` 256 | a test of whether outside the box really is unanswerable (**0 of 12 directions supported it**) |
| `globularity.py` 191 | the third eNTRy condition. **Found to be inert on this library** |
| `transfer.py` 195 | transfer, both directions, with the criterion declared before the run |
| `cv.py` 237 | repeated k-fold CV, a GBT baseline, recall@k |
| `bench.py` 183 | AUC over 21 seeds (M1) |
| `m3_order.py` 477 | the order swap (**withdrawn**). The shared parts, `score_with` and the rest, live here |
| `m3_models.py` 66 | the AUC of each model alone |

### Ingest

| file | what it does |
|---|---|
| **`smiles.py`** 136 | **the one SMILES parser.** Repairs dialects. Locked |
| `ingest.py` 149 | raw tsv/csv to parquet, RFC 4180 |
| `ingest_champ.py` 192 | CHAMP xlsx to parquet, with tertiles |
| `ingest_gna.py` 199 | GramNegAccum tables 1-4 to parquet, 197 compounds |
| `ingest_imi.py` 95 | IMI-COMBINE tsv to parquet, rows labelled on both axes only |
| `ingest_zinc.py` 155 | a ZINC22 tranche to parquet, one row group per part |
| `descriptors.py` 248 | SMILES to 9 descriptors and a scaffold |
| `fingerprints.py` 143 | SMILES to ECFP8, 2,048 bits |
| `fingerprint_library.py` 143 | ECFP8 for an unlabelled library, at the million-row scale, through numpy |
| `folds.py` 303 | splits (scaffold, butina) and Welford statistics |
| `gen_scale.py` 83 | replicate a parquet n times, for M0 |
| `fetch_chembl.py` 151 | the ChEMBL REST API (500s are frequent, so retry) |

### Candidate generation (**not the product. Demoted**)

| file | state |
|---|---|
| `candidates.py` 400 | **stops without `--emit-molecules`.** The path that produced section 4's figures. Carries a KeepOut lock |
| `sequential.py` 429 | the same. Converted to be specification-driven (`--spec`) |
| `screen.py` 164 | applies the permeability rules only. Grew into `sweep.py` |

### The engine (Rust, three builds)

| file | what it does |
|---|---|
| `main.rs` 244 | the loop and nothing else. Two passes: learn, then score |
| `bulk.rs` 270 | hands back one bulk at a time. Forces one row group per file |
| `carry.rs` 425 | the fixed-size carry. F/W/BINS, AUC, expand |
| `process.rs` 180 | what happens to one bulk |
| `metrics.rs` 32 | peak RSS (VmHWM) |

### Tests

Python **237**, Rust **11**, and the slow prompt layer **26** more behind
`OCCAM_PROMPTS=1`. KeepOut locks: **10**.

```bash
nix-shell --run 'python3 -m unittest tests/test_memory_invariant.py tests/test_ingest.py \
    tests/test_descriptors.py tests/test_folds.py tests/test_smiles.py \
    tests/test_invariants_locked.py tests/test_render.py tests/test_request.py \
    tests/test_no_duplicated_counts.py tests/test_contraindications.py \
    tests/test_prompts.py tests/test_documented_procedures.py' 2>&1 | tee data/work/tests.log
nix-shell --run 'cd engine && cargo test --release -- --test-threads=1'
```

**Always put the output in a file** (contraindication 48).

### Documents

| file | what it holds |
|---|---|
| `HANDOFF.md` | this |
| `README.md` | what the repository is, and **the request vocabulary, which is the parser's contract** |
| `NOTICE` | why Apache-2.0, and which datasets are not shipped here and under whose terms |
| `data/raw/*/manifest.json` | per dataset: the source, the licence, the checksums, what was measured from them, and how to fetch them |
| `tests/fixtures/prompts/RECORD.md` | the recorded prompt runs and how to re-record them |

**WITHDRAWN, 2026-10-17.** This table used to list `docs/m0.md`,
`docs/m4_s4_draft2.md`, `docs/m4_s3_s4_draft.md`, `docs/residual_prediction.md`
and `docs/inclusion_predictions.json`. **None of those files exists.** They
were deleted at some point and the table was never read again — the same fault
as RECORD.md's procedure reading a `prompts.txt` that was not in the
repository (contraindication 111). `py/stream_gbdt.py` still names
`docs/residual_prediction.md` in a comment, and
`tests/test_documented_procedures.py` did not catch either, because it checks
paths under `py/`, `tests/` and `engine/src/` and not `docs/`.

---

## 1. What Occam is (the mechanism under the product in section 0)

**Read section 0 first.** What follows is the **mechanism**, not the product.

A compute mechanism that cuts large data into fixed-size bulks, builds a
temporary computer for each bulk, processes it, **carries only the result
forward and destroys both the computer and the bulk**. Repeated once per bulk.

### How the mechanism and the product fit

The strength of fixed memory is **sweeping any volume cheaply**, and what that
is good for is:

- computing a property over all million rows and giving the distribution
- counting what share of a library is inside the training range
- **evaluating K specifications in one pass** (`sweep.py`: 27. **The 224 KB of
  fixed state was measured at 54**)

**All of those are questions about feasibility and coverage, not about
prediction.** So the mechanism's strength maps onto the assisting role, and
its weakness — the training data — is what constrains candidate generation.
The arrangement is natural.

The quality of a prediction is capped by the training data. That is the weak
point: 129 rows, 0.6%, with no resolution by target.

The aim is to make working memory independent of data volume.
`M ≈ D / N + R`, where D is the total data, N the number of bulks, and R the
size of the carried result.

It was called "Molt" and was renamed Occam on 2026-10-07.

### This registry is about one barrier (2026-10-11)

Every setting in `knobs.py` is an eNTRy rule, and they are about **entry into
the Gram-negative outer membrane**. They are not a general permeability rule
and they are not a rule about any other barrier.

**Until it was recorded in `APPLIES_TO`, that was written nowhere.** So
pointing the eNTRy conditions at the blood-brain barrier data (B3DB) ran to
completion and reported nothing wrong. **The same silence as the charge-slice
mix-up, in another place.**

| library | barrier |
|---|---|
| ZINC (−N / −O / −P) | **none.** A catalogue measures nothing, so it cannot contradict |
| IMI-COMBINE / CHAMP / GramNegAccum | the Gram-negative outer membrane |
| **B3DB** | **the blood-brain barrier** |

On a mismatch it prints the reason and stops; `--yes` runs it anyway, having
read why. **A library absent from `LIBRARY_BARRIER` is treated as unknown and
not assumed to agree with the registry.** `tests/test_request.py` holds every
nameable library to having a barrier recorded, so **the next library added
without one fails.**

#### There is no BBB knob

No published rule with numbers is recorded in this repository for it. Building
one would make every setting `relaxation` or `unjustified`, and **the
registry's property — that one line says whether a setting is published or
just a moved threshold — would collapse.** The same reason as contraindication
70: the literature does not always have a threshold.

What can be answered is **a question about BBB** (is this set inside B3DB's
domain, how many compounds would bring it inside), **not screening BBB with
the eNTRy conditions.**

#### Measuring it tells you something

For the ZINC −O set narrowed by two eNTRy conditions, median nearest-neighbour
to each measured set:

```
IMI-COMBINE (activity, 22,051)         0.212
B3DB (blood-brain barrier, 7,805)      0.202   <- second
CHAMP (permeability, 1,132)            0.168
GramNegAccum (permeability, 197)       0.141
```

**A set narrowed by the Gram-negative rule is nearer to the blood-brain
measurements than to the Gram-negative ones.** None reaches the 0.4 threshold
so the verdict does not change, but **what is missing reads differently.**
Naming the barrier beside each row is what made it readable.

### The three invariants that must hold

1. **R is fixed-size and depends on neither bulk size nor data volume.** No
   `Vec` and no `HashMap` inside `Carry`
2. **Peak memory does not grow in proportion to D**
3. **One computer and one bulk alive at a time.** No read-ahead, no buffering

**A change that breaks any of the three is rejected even if it is faster.**
"Learns in one pass" is *not* an invariant: that is about I/O, not memory.
Multiple epochs are allowed.

### The invariants are held mechanically, by KeepOut

**KeepOut is vendored under `third_party/keepout/`** (2026-10-11). Before that
`shell.nix` pointed at the absolute path `/home/shogo/KeepOut/src`, so **on any
other machine the guard was absent and the lock check skipped itself.** A skip
wears the same face as a pass.

| | |
|---|---|
| upstream | `https://github.com/Shogo256/KeepOut.git`, commit `cf65f79` |
| record | `third_party/keepout/manifest.json` — the commit and the SHA256 of each file |
| drift | `tests/test_invariants_locked.py` compares the hashes. Change the copy without fixing the manifest and it fails |
| absence | **a failure, not a skip** (`test_the_guard_is_not_silently_absent`) |

**RESOLVED, 2026-10-11.** This section used to carry a warning that KeepOut's
licence was undeclared — upstream had no LICENSE file, so handing the bundle to
anyone gave them no permission. It is declared now: Apache-2.0, `Copyright
2025-2026 Shogo Toda`, the same licence and the same author as this
repository, recorded in `third_party/keepout/manifest.json` and stated in
`NOTICE`.

KeepOut wraps code in `# [LOCK]` or `// [LOCK]` and refuses a structural
change. Formatting, comments and variable renames are ignored.

**Ten regions are locked** (`keepout.json`). `tests/test_invariants_locked.py`
is part of the suite and detects both

- a structural change inside a locked region
- a lock deleted from `keepout.json`

Re-running `keepout init` regenerates the hashes with the lock removed, so the
test pins the regions that must exist, each with its reason.

After adding a lock, register it with `keepout init .`, **check by diff that
no existing lock's hash moved**, then add it to `REQUIRED_LOCKS`. An
unregistered lock makes `check` warn, and protects nothing.

The call is `PYTHONPATH=third_party/keepout python3 -m keepout.cli check .`
It used to be an absolute path into a home directory; that is what made the
guard absent everywhere else.

The upstream was also fixed from here: `[LOCK: pbt]` returned a pass for a
region its engine could never call, and now returns `pbt_unverifiable`
instead. See contraindication 100.

---

## 2. Repository layout

The tree below is as of 2026-10-17. `docs/` is gone: it was made private that
day and what a reader needs moved into `README.md` and this file.

```
occam/
├── README.md              what this is, and the request vocabulary — the parser's contract
├── HANDOFF.md             this file
├── NOTICE                 why Apache-2.0; what is not shipped, and under whose terms
├── LICENSE                Apache-2.0
├── Dockerfile             two stages; both bases pinned by digest
├── shell.nix              the nix environment (rust, python3 + rdkit/duckdb/pyarrow/sklearn/click/hypothesis)
├── flake.nix
├── keepout.json           the hashes of the ten locked regions
├── occam                  the entry point the documentation names; enters shell.nix itself
├── data/
│   ├── raw/               never rewritten. .gitignore keeps the data out and tracks the manifests
│   │   ├── _searched.json      the record of 13 sources searched (the most important file here)
│   │   ├── champ/              CHAMP permeability (CC BY 4.0)
│   │   ├── gramnegaccum/       the eNTRy rules' own data (CC BY 4.0)
│   │   ├── imi_combine/        activity (MIT)
│   │   ├── b3db/               blood-brain barrier (CC0 1.0)
│   │   ├── zinc22/             the unmeasured library; tranche and fetch recorded, no SMILES
│   │   ├── chembl_src40/       CO-ADD's ChEMBL copy (CC BY-SA 3.0; nothing reads it)
│   │   └── sci_rep_2025/       manifest only (CC BY-NC-ND, so not used)
│   └── work/              generated. Safe to delete at any time
├── py/                    see the inventory in section 0.5
├── third_party/keepout/   vendored, Apache-2.0, same author
├── engine/
│   ├── Cargo.toml         features: fingerprint, linear
│   └── src/               main.rs, bulk.rs, carry.rs, process.rs, metrics.rs
└── tests/
    ├── test_memory_invariant.py      M0. 1x / 10x / 100x / 1000x
    ├── test_ingest.py                RFC 4180 round-trip property test
    ├── test_descriptors.py           descriptors, the 1% guard
    ├── test_folds.py                 splits; statistics from training rows only
    ├── test_smiles.py                the one parser
    ├── test_invariants_locked.py     KeepOut
    ├── test_render.py                the display layer; no identifier reaches the screen
    ├── test_request.py               request parsing; the vocabulary is closed
    ├── test_no_duplicated_counts.py  no count reaches the screen from two places
    ├── test_contraindications.py     the contraindications an assertion can reach
    ├── test_prompts.py               the prompt regression. By default it replays the
    │                                 records; OCCAM_PROMPTS=1 runs them for real (~27 min)
    ├── test_documented_procedures.py what the documents say to do, the suite does
    └── fixtures/prompts/             the records and RECORD.md. The count is not written
                                      down; it is however many run*/ there are
```

### The engine has three builds

| build | F | W | used for | Carry |
|---|---|---|---|---|
| `target/release/engine` | 9 | 54 (quadratic terms) | M1, CV inside CHAMP | 20,792 B |
| `target-lin/release/engine` | 9 | 9 (linear) | **transfer and coverage** | 20,608 B |
| `target-fp/release/engine` | 2048 | 2048 | the binding model | 45,080 B |

```bash
cargo build --release
cargo build --release --features linear      --target-dir target-lin
cargo build --release --features fingerprint --target-dir target-fp
```

The product invokes `target-fp` only. The other two are what produced the
figures in section 4, and the container ships all three.

---

## 3. Milestones

| stage | | state |
|---|---|---|
| **M0** | the wiring holds: memory independent of data volume | **met** |
| **M1** | know the floor at which prediction works | **met** |
| **M2** | have real data | **met**, open licences only |
| **M3** | the order swap helps | **not met**, below |
| M4 | take it somewhere | drafted, some figures reserved |

### M3, stated precisely

M3's claim is that putting the permeability filter before the binding
evaluation helps. **That has not been verified.**

- first measurement, a 51x effect: the output sizes of the two paths did not
  match. Withdrawn
- second, 1.2x: sigmoid saturation degenerated the ordering into row order,
  and row order was itself enriched 2.27x in hit rate. Withdrawn
- it has **not** been re-measured

What was learnt instead: **the filter enriches the set as a whole and does not
improve the top.** Without any filter, 92% of the top 25 are already active. A
filter only matters at a scale where the binding evaluation cannot be paid for
on every row — which is to say **it is first needed at stage three, an
unmeasured library of 10^6 to 10^9.**

### The stages (rewritten 2026-10-10)

**These used to be the stages of a candidate generator. The goal is the
assisting role, so the criteria are different.**

The old wording — stage three being "new compounds come out" — pulled the work
toward candidate generation on both 2026-10-09 and -10. A document left at an
old goal pulls the next session the same way.

| stage | | state |
|---|---|---|
| one | take a request and answer **holds / does not hold**, with grounds | **done** (`feasible.py`, `occam.py`) |
| two | answer **what instead**, from measurement | **done** (`propose.py`, `screenable.py`) |
| three | **put a control on every expensive verdict** | **done** (Tanimoto and globularity, 2026-10-10) |
| four | someone outside tries to break it | **not started.** The largest gap |

**Candidate generation — emitting a list of molecules — is not the goal.**
`py/sequential.py` and `py/candidates.py` remain as the path that produced
section 4's figures, and stop without `--emit-molecules`. The product is the
verdict in `py/occam.py`.

---

## 4. Established figures (all reproduced on the current code)

### M0: memory

| input | peak RSS |
|---|---|
| 1x | 4,100 KB |
| 1,000x (298 MiB) | 4,148 KB (+1.2%) |
| **10,000x (2.91 GiB)** | **3,988 KB (−2.7%)** |

+2.2% even at 20 epochs. The measurement is the larger of VmHWM and GNU time's
%M — **no longer: see contraindication 109.** Taking the larger of two
instruments that straddle each other biases a ratio upward in the numerator
and the denominator independently, and the invariant is now read from VmHWM
alone with %M kept as a cross-check.

**"301x" is unusable**: it was measured on the byte-string format and became
unreproducible the moment `Bulk` became a typed sample.

### M1: B3DB (the blood-brain barrier)

- Occam **0.8382 ± 0.0512** (21 seeds, scaffold 8:1:1, **`--epochs 10`**)
- for comparison, GCN 0.8264 ± 0.0105
- histogram approximation against exact Mann-Whitney: 8.9 × 10⁻⁵ apart

**The epoch count is 10.** The older record of 0.8383 ± 0.0515 did not say so,
and at the default of one epoch it comes out 0.8297 ± 0.0503, which does not
reproduce. Re-run on 2026-10-08 with `--epochs 10` it gave 0.8382 ± 0.0512,
0.0001 from the old value. **The figure was sound; the record was incomplete.**

The 0.0085 between one epoch and ten is an order of magnitude larger than the
effect of introducing `py/smiles.py` (0.0010). Record the settings with the
number, always.

### CV inside CHAMP (Butina 5-fold, 5 repeats, all 755 pooled)

| | AUC |
|---|---|
| Occam, 54 dimensions, 10 epochs | 0.8803 ± 0.0047 |
| Occam, 9 descriptors, 10 epochs | 0.8631 ± 0.0096 |
| GBT (ours, the same folds) | 0.9343 ± 0.0036 |
| difference (Occam − GBT) | −0.0540 [−0.0575, −0.0497] |

Decomposing it: 0.0815 initially, 0.0102 closed by multiple passes and 0.0173
by the interaction terms, leaving **0.0540, which is the model class.
Whether that is the price of O(1) memory is unverified** — a histogram-based
GBDT can be streamed.

### Transfer

**Re-measured on 2026-10-08 with 197 compounds, and the "holds / fails"
labels were withdrawn on 2026-10-09** because the declared criterion — the
lower bound of the CI above 0.5 — is confounded with the number of rows
evaluated (below). **The figures stand; the verdict does not.**

| direction | n | linear (9 descriptors) | with interaction terms (54) |
|---|---|---|---|
| CHAMP → GramNegAccum | 129 | 0.5944 [0.4933, 0.6921] | 0.4456 (extrapolating, uninterpretable) |
| GramNegAccum → CHAMP | 755 | 0.6537 [0.6150, 0.6926] | 0.2890 |

**The two linear directions are not distinguished.** The intervals overlap at
[0.6150, 0.6921] and the point estimates differ by 0.0593. Scaling the half
width by 1/√n to 755 rows puts CHAMP → GNA at 0.5526, also above 0.5.
**"It transfers in one direction only" cannot be written.**

35.7% of the evaluation side exceeds the p99 of the training side's logit —
extrapolation. The reverse direction is 0.0%. That is a diagnostic of the
model's weights and does not depend on n.

Withdrawn: the old 0.6961 [0.5908, 0.7944] and 0.6466 [0.6079, 0.6856], from a
broken parse over 217 compounds.

**The conclusion that interaction terms break transfer** (contraindication 17)
stands. The 0.2890 and 0.4456 at 54 dimensions are compared on the same
evaluation set with n matched, and 0.2890 against 0.6537 is not explained by a
CI width of ±0.04. The logit diverges out of distribution: p99 goes 17.12 →
283.15.

### Coverage (`py/coverage.py`, criterion declared before the run)

Against an evaluation pool of 11,025 with 3,037 true hits (27.55%), how much
can the public permeability data speak about?

| region | box | neighbour | **covered** | hit rate inside covered | share of all hits |
|---|---|---|---|---|---|
| CHAMP (755) | 6.2% | 1.1% | **0.6%** | 5.88% (4 rows) | 0.1% |
| GramNegAccum (129) | 37.3% | 28.6% | **22.7%** | 45.59% | 37.6% |
| union | 38.1% | — | **23.1%** | 44.87% | 37.6% |

- **box** = every descriptor inside the training side's 1st-to-99th percentile
  range. **A necessary condition and nothing more**
- **neighbour** = the distance to the nearest training point in standardised
  descriptor space is at or below the p95 of the nearest-neighbour distance
  distribution inside the training set
- **covered** = both. That is the headline figure

**Switching to the nearest-neighbour criterion takes CHAMP from 6.2% to 0.6%,
a tenth.** Reporting the box alone had been wrong.

**But even the nearest-neighbour figure is not "the share that can be
answered."** The box erred toward being too permissive, and a stricter
criterion does not fix the interpretation. `py/answerable.py` tested it
directly: membership does not predict AUC.

Two things follow:

1. **Chemical nearness matters, not the number of training rows.**
   GramNegAccum covers 22.7% with 129 rows; CHAMP covers 0.6% with 755. The
   library is antibacterials, and GramNegAccum was built from antibacterials
2. **Inside CHAMP's domain the hit rate is below the whole** (5.88% against
   27.55%). Though that is 4 of 68, so it is weak as a number

What falls outside (contraindication 23): for CHAMP it is MW at 83.0%,
aromatic rings 51.5%, HBA 44.6%. For GramNegAccum, logP 36.7%, rotatable bonds
29.0%, aromatic rings 25.2%.

### Outside the box is not "unanswerable" (`py/answerable.py`, 2026-10-09)

**Reading the coverage figures as "the share the model can speak about" is not
supported.** With the same model and the same weights, the evaluation set was
split into covered and uncovered and **a bootstrap CI was put on the
difference** — the two groups are disjoint, so the difference comes out
cleanly. It was first judged by whether two CIs overlapped, which is
contraindication 44 itself, and was replaced (contraindication 54).

Of 16 directions, 12 could be measured; in 4, covered held one row or fewer.

| verdict | directions |
|---|---|
| the CI of the difference contains 0 | **9** |
| below 0 (uncovered significantly better) | **3** |
| **above 0 (covered better)** | **0** |

**Not one direction has covered significantly better.** The CI widths run
0.054 to 0.214, so the resolution is ±0.03 to ±0.11.

### But it does not read as "outside is fine either" (difficulty is confounded)

Taking the best AUC achievable by a single descriptor as a proxy for
difficulty, measured on both sides:

| | |
|---|---|
| directions where uncovered is easier | **11 of 12** |
| rho(difficulty gap, difference) | **−0.510** |
| **the gaps of the 3 OPPOSITE directions** | **+0.1050 / +0.0887 / +0.0848 — the top three** |

**The three directions where uncovered is significantly better are exactly the
three with the largest difficulty gap.** So "outside the box is easier to
predict" is explained by difficulty and **is not a membership effect.**

Outside the box is usually the tail of the distribution, and tails separate
even on a single descriptor. **Cutting on a descriptor box makes the cut side
systematically easier.** That is a property of the split, not of the model.

### What this test establishes, and no more

AUC is a rank statistic within the set evaluated, and covered and uncovered
are **different discrimination problems with differently spread labels**, so
the two AUCs are not on one scale. What can be shown is:

> **The inside/outside split does not identify a subset where the model's
> ordering gets worse.**

That is enough to refuse reading the coverage share as "the share that can be
answered", since that reading requires outside to be worse. **It does not read
as "outside the applicability domain is fine"** (contraindication 55). And the
difficulty confound works in the direction that **masks** a membership effect:
uncovered is easier, so uncovered's AUC rises.

**Reserved:** this is a test of **ordering** (AUC). Probability calibration
may still break outside the box. For screening the ordering is what matters so
this metric is the right one, but calibration is separate
(contraindication 53).

**What this means for section 4:** 0.6% / 22.7% / 23.1% are **valid as a
description of distance and cannot be written as a ceiling on capability.**
Section 4's main argument moves to statistical power.

---

### Mutual coverage (for reference; it cannot predict transfer)

The training and application sides swapped and each measured against the
other. `--whole-library` for all rows.

| direction | box | neighbour | **covered** |
|---|---|---|---|
| GramNegAccum's region → CHAMP's 755 | 71.7% | 64.5% | **53.2%** |
| CHAMP's region → GramNegAccum's 129 | 10.9% | 0.8% | **0.8%** (1 row) |

The same conclusion **reproduces at three levels while needing less
information each time.** These are not three independent observations — the
logit is a linear map of the descriptors, so levels two and three are the same
geometry. The claim is **reduction**, not independence.

| measurement | needs | GNA → CHAMP | CHAMP → GNA |
|---|---|---|---|
| transfer AUC (CI lower bound) | labels and a model | 0.6150, holds | 0.4933, fails |
| share above the logit p99 | the model's weights | 0.0% | 35.7% |
| mutual coverage | **neither** | 53.2% | 0.8% |

**That reading of the reduction was withdrawn on 2026-10-09.** Read what
follows.

### The criterion is confounded with the number of rows evaluated (2026-10-09, the most important thing here)

Verifying against B3DB (`py/inclusion.py`, section 8) showed that **the
declared criterion — the CI lower bound above 0.5 — moves almost one-to-one
with the size of the evaluation set.** Over 14 directions:

| predictor of the CI lower bound | Spearman rho |
|---|---|
| coverage | **+0.042** |
| **rows evaluated** | **+0.526** |
| rows trained on | −0.504 |

The lower half width is set by the number evaluated: 0.0331 at n=1,133, 0.0126
at n=5,853. **Inclusion predicts nothing.**

Applied to CHAMP and GNA:

| | n | AUC | CI | lower half width |
|---|---|---|---|---|
| CHAMP → GNA | 129 | 0.5944 | [0.4933, 0.6921] | **0.1011** |
| GNA → CHAMP | 755 | 0.6537 | [0.6150, 0.6926] | 0.0387 |

- **the intervals overlap** at [0.6150, 0.6921]; the two directions are not
  distinguished
- the point estimates differ by **0.0593** and no more
- scaling the half width by 1/√n to 755 rows, **CHAMP → GNA also holds**, at a
  lower bound of 0.5526

**"It transfers in one direction only" does not hold.** The "fails" verdict is
an artefact of GramNegAccum having only 129 rows.

**What remains is a statement about power: the public data is not large enough
to measure transfer.** At 129 rows the interval is 0.2 wide and neither
direction can be decided.

**This is folded into section 4 rather than given a section of its own.** On
its own it is a section about a failed measurement and is not worth reading.
Inside section 4 the claim goes a level deeper:

> At 129 compounds the confidence interval on the transfer AUC is ±0.10, and
> which direction works cannot be decided. The shortage of public data does
> not merely stop a permeability model being used — **it makes it impossible
> even to measure whether transfer holds.**

### The ask can be quantified (half width scales as 1/√n)

```
0.1011 × √(129/n) = the target half width
```

| target half width | compounds needed |
|---|---|
| ±0.05 | about 530 |
| **±0.04** | **about 820** |
| ±0.03 | about 1,470 |

**"More data" becomes "about 800 compounds."** The same formula converts to
755, so it is consistent. A number the other side can decide against.

> Permeability data for compounds in the 350-600 molecular weight band
> carrying a basic nitrogen. **About 800 compounds to be usable for
> evaluation** — at the present 129 the interval is ±0.10 and whether transfer
> holds cannot be decided.

What falls outside CHAMP: MW 45.7%, TPSA 31.0%, HBA 24.0%. CHAMP is narrow in
MW and does not reach the size of antibacterials.

**Note:** GNA → CHAMP held on a set with 53.2% covered; the other 47% is
outside under the strict criterion. The AUC holds, but that is not "usable
everywhere".

### Threshold sensitivity (p95 is an arbitrary choice)

| neighbour threshold | GNA → CHAMP | CHAMP → GNA | IMI: CHAMP | IMI: GNA | IMI: union |
|---|---|---|---|---|---|
| p90 | 24.4% | 0.0% | 0.1% | 13.0% | 13.1% |
| **p95 (declared)** | **53.2%** | **0.8%** | **0.6%** | **22.7%** | **23.1%** |
| p99 | 71.7% | 7.0% | 4.8% | 37.3% | 38.0% |

**The direction of the asymmetry does not flip at any of the three
thresholds.** But the ratio moves from 10x to infinity, so **the ratio is not
used in any claim.** The old draft's "66x" and "220x per row" are withdrawn;
the second is invalid as arithmetic besides, because coverage saturates
against row count.  `--neighbour-percentile` moves it.

### The binding model (ECFP8, IMI-COMBINE)

| | AUC |
|---|---|
| Occam | **0.8228** |
| sklearn LR (defaults) | 0.7975 |
| sklearn RF | 0.8724 |
| published (ECFP8 + RF, random split) | 0.843 |

### Candidate output (`data/work/candidates.json`)

| group | conditions | surviving | lift | top 25 active | overlap with shuffle |
|---|---|---|---|---|---|
| A | primary amine + rotatable ≤5 + MW ≤600 | 4.5% | 2.82 | 84% | 100% |
| B | basic nitrogen + rotatable ≤5 + MW ≤600 | 12.3% | 2.01 | 84% | 100% |
| C | no filter | 100% | 1.00 | 92% | 100% |

MW ≤600 was **added by this study**; it is not in the eNTRy paper. Before it
went in, a 1,281 Da glycopeptide ranked first. Group A's top is entirely
fluoroquinolones. Tanimoto to the training side is ≥0.85 for 6 of 25 and ≥0.70
for 17 of 25, with a maximum of 0.963. **That is reproducing known compounds,
not proposing new ones.**

### Formal charge as drawn, per slice (2026-10-11, reproducible with `py/charge_slices.py`)

The evidence for retiring the charge knob. **This is a measurement of this
sample, not a property of ZINC22.**

The criterion was declared before the run: **at 99.9% or more formal charge
zero, the setting is inert on that slice.**

| slice | predicted state | sample | formal charge 0 | share | otherwise | criterion |
|---|---|---|---|---|---|---|
| **−N** | neutral | 20,000 | 20,000 | 100.0000% | — | met |
| **−O** | +1 | 20,000 | 19,977 | **99.8850%** | **23 at +1** | **not met** |
| **−P** | +2 or more | 17,775 (**all**) | 17,775 | 100.0000% | — | met |
| **−M** | −1 | 20,000 | 19,989 | 99.9450% | **11 at +1** | met |

Tranche zinc-22x H29P240, seed 0. `−M` was drawn from **the first 80,000 rows
of a partial download**, so the pool itself is only the front of the file.
**A measurement of that pool, not of the slice.**

#### What this measurement does not say

- **`100.0000%` means "none were found", not "none exist."** Zero in 20,000
  puts the upper bound around 0.015% at 95%. Below that, nothing can be said
- **That `−M` held no molecule drawn with a negative formal charge** is a
  statement about that sample of that partial download. **It is still the
  decisive ground for retiring the knob**: the knob cannot reach the anionic
  population
- **"Inert at this scale" is not written.** `−O`'s 0.115% does not round to
  zero as the survivor count grows. Retiring the knob makes it harmless, but
  written as a property it would bite later

#### It disagrees with an older measurement of the same quantity

The table in section 8 has **a different measurement**: `−O 19,971/20,000`,
`−M 19,995/20,000`. The values differ because the samples differ, and **which
is right cannot be decided — the older one records neither its seed nor the
extent of its pool, so it cannot be reproduced.** Only the table above can,
with `py/charge_slices.py`.

```bash
python3 py/charge_slices.py --also <path>/x_H29P240-M.part.gz --also-slice=-M
```

---

## 5. Data sources

`data/raw/_searched.json` records 13. `checked_here: true` marks the five
verified here; the rest are leads not confirmed.

### In use

| data | rows | licence | used for |
|---|---|---|---|
| **CHAMP** Zenodo 17434251 | 1,132 | CC BY 4.0 | permeability (training) |
| **GramNegAccum** Zenodo 19798859 | **197** (below) | CC BY 4.0 | permeability (validation) |
| **IMI-COMBINE** GitHub, commit 3c222f9 | 22,051 | MIT | activity |
| ChEMBL src_id=40 | 42,693 | CC BY-SA 3.0 | the efflux axis (unused) |
| **ZINC22** zinc-22x H29P240 | −O 636,669 / −P 17,775 / −N 1,000,000 (truncated from 4,572,322) | written permission to redistribute large portions | **the unmeasured library**, what gets screened |

ZINC's raw files are not in the repository — **a licence judgement.**
Redistributing large portions needs written permission, and screening and
sharing screening results are explicitly permitted.
**`data/raw/zinc22/manifest.json` carries the tranche identifier and the fetch
URLs** (added 2026-10-11). Before that the provenance was a `/tmp` path from a
session that no longer existed, and **nobody could re-derive any of section
4's ZINC figures.** The generation letter stays inside the filename,
`H29P240-O.x.smi.gz` (contraindication 67).

Since 2026-10-16 one command fetches all of it: `python3 py/fetch.py --zinc`.
It verifies each file against the manifest's checksum, and for ZINC — where no
checksum was ever recorded — against the row count after ingest and the
slice's own line count.

### How GramNegAccum's count breaks down (contraindication 25)

It moved four times in one day, so it is pinned here.

| stage | rows |
|---|---|
| rows in tables 1-4 | 240 (12 + 104 + 56 + 68) |
| rows with both SMILES and a numeric Accum | 234 (6 with empty SMILES removed) |
| unique structures (InChIKey skeleton) | **197** |
| of those, high / mid / low | 67 / 68 / 62 |
| `gna_feat`, mid excluded | **129** |

**The old 146 came from 217, not from 197** (74 + 72 + 71 = 217). Under the
broken parse, differences in stereo notation split identical structures and
gave 217. The 17 between 146 and 129 were not "lost": the denominator was
corrected from 217 to 197.

### Not used

- **Sci Rep 2025** (6,416 rows, permeability) → **CC BY-NC-ND 4.0.** NC and ND
  fail the Open Definition. The manifest is kept and the files deleted
- **CO-ADD directly** → the licence text contradicts itself: bulk distribution
  while forbidding systematic download. Not fetched
- ChEMBL has **no lpxC and no tolC** (all 35 assays checked through the API).
  E. coli is wild type only. The only efflux-deficient strain is
  P. aeruginosa PAO397

### Leads received 2026-10-08 and never measured

**Collins Lab (MIT), Zenodo 21481938** — 38,000 compounds across 7 species,
CC BY 4.0. **The record and the licence are confirmed; the download returns
403** (a Zenodo IP block; retry later). Being per-species, it could release
IMI-COMBINE's "four groups pooled" constraint. Three cytotoxicity cell lines
are included.

Others, unverified: SPARK accumulation, 464 rows, R&D-only licence; ZINC22
(fetchable per tranche, redistribution forbidden, screening permitted); Align
Foundation Zenodo 21456219 (a proposal, not data).
**Enamine's section 15.2 explicitly forbids feeding it to ML or QSAR. GDB
forbids patent use and its MW band does not match. Neither is usable.**

---

## 6. Corrected as errors in the specification

| the specification said | what is actually there |
|---|---|
| B3DB classification 7,808 rows, 2 broken | 7,807 records. The 2 are valid quoted records containing newlines |
| B3DB regression 1,066 rows | 1,063 records; only one blank line is dropped |
| hERG 8,883 rows | 8,884 records |
| hERG has rows with empty SMILES | none |
| Meng et al., XGBoost AUC 0.863 | the paper reports no model performance. The number does not exist |

---

## 7. The contraindications (traps already stepped in)

### Each item says whether a test holds it (2026-10-11)

**This list does not get read.** Past eighty items, nobody re-reads the whole
thing before a new design. What has actually been held is **the items that
became tests**; the ones left as prose have been stepped in again in a
different shape — which is exactly what contraindication 54 says.

| mark | meaning |
|---|---|
| **[T]** | **the trap returning makes a test fail.** The only effective defence |
| **[T-partial]** | a test watches part of it, and not the core of the item |
| **[prose]** | **prose only.** Nothing stops the next person stepping in it |

**The policy is to convert [prose] into tests.** Converting means writing an
assertion that fails if the trap returns. It does not mean rewriting the
prose.

The first conversion was contraindication 83. On 2026-10-10 `74,202` was found
reaching the screen from two places, **by a person reading the output.**
Contraindication 81 had said the same thing in prose and it had not worked.
`tests/test_no_duplicated_counts.py` now fails on that shape mechanically.

1. [T] **`data/raw/*` does not work in .gitignore** — re-including a
   subdirectory brings its contents back. Use `data/raw/**`
2. [T-partial] **`ru_maxrss` is unusable** — subprocess spawns through vfork,
   so the child inherits the parent's memory. Use VmHWM or GNU time's `%M`.
   **But never take both with `max()`** (contraindication 109): `%M` is the
   cross-check and VmHWM holds the verdict
3. [T] **parquet's `RowIter` holds two row groups at the changeover** — open
   and close the parts yourself
4. [T] **a parquet footer grows with the number of row groups** — force one
   row group per file
5. [T-partial] **pin glibc's mmap threshold** —
   `mallopt(M_MMAP_THRESHOLD, 64KiB)`. Without it RSS swings up to +19%
6. [T] **`let mut op = ...` reassigns after constructing, before dropping** —
   that breaks invariant 3. Scope it
7. [T] **TSV interprets quotes too** — `QUOTE_NONE` breaks records containing
   newlines
8. [T] **never standardise sparse binary features** — `p(1-p)` amplifies a
   rare bit to ±31, and subtracting the mean destroys the sparsity
9. [T] **continuous values do need standardising** — split the preprocessing
   by feature type
10. [prose] **`--dump-scores` returns test rows only** — zipping it against
    all rows' labels breaks silently. Return a row-index mapping
    (`score_with` requires the aligning argument)
11. [T] **Butina holds an O(n²) distance matrix** — OOM past 6,000.
    `BUTINA_MAX_MOLECULES` guards it
12. [T-partial] **scaffold splitting does not work on some data** — CHAMP's
    top two scaffolds (single benzene ring, no ring) are 52.7%. Switched to
    Butina at 0.4. IMI has 7,394 scaffolds with the top two at 3.2%, so
    scaffold is fine there
13. [T] **do not read `data/raw/` as a flat list of files** — it has
    subdirectories. `rglob("*")` with is_file
14. [T] **a sigmoid output saturates in f32** — out of distribution it pins at
    1.0 and the ordering disappears. **Rank on the logit.** Assert both the
    modal share and the distinct-value share
15. [prose] **if a deterministic sequence beats a random control reliably,
    suspect the input order** — IMI's first 1,000 rows have 2.27x the overall
    hit rate
16. [T-partial] **when applying out of distribution, put the two z
    distributions side by side** — if the application side's median exceeds
    the training side's p99, that is extrapolation
17. [T-partial] **quadratic interaction terms work in opposite directions in
    and out of distribution** — selecting features by in-distribution CV kills
    transfer
18. [T] **suspect dialects in external SMILES** — GramNegAccum has three:
    `[N+H2]`, `[N+@@H]`, `[N+]`
19. [prose] **transfer holding is not binary** — it is a function of distance
    in chemical space. State transfer to what, and what share of the
    application side is inside the training range
20. [prose] **extrapolation can be detected and abstained from** — but until
    the distribution of what was abstained on is measured, "inside the range
    it is right" cannot be said
21. [prose] **measure the distribution of what is left after narrowing to the
    applicability domain** — inside CHAMP's domain the hit rate was 0.60x the
    whole
22. [prose] **change the format and past measurements cannot be reproduced** —
    re-run any figure that goes into a document, on the code it goes in with
23. [prose] **"the share inside the range" does not convey coverage on its
    own** — list which descriptor is out and by how much
24. [T-partial] **every tie-break is a door for row order** — deduplication,
    taking a top N, breaking ties. Use a deterministic key (InChIKey)
25. [T] **say which count a count is: rows, unique structures, or successful
    parses** — GramNegAccum carried 368 / 234 / 217 / 197 / 150 side by side
26. [prose] **a search result is not a number until it has been measured here**
27. [T] **a parse failure shows up in the descriptors, not in the count** —
    `[N+]` reads as "a nitrogen cation with no hydrogens" and misses the
    primary-amine SMARTS. **It raises nothing, so the 1% guard does not catch
    it**
28. [T] **external notation varies in more than one way** — there were two.
    Token order inside brackets (`[N+H2]`) is **syntax** and a regex fixes it.
    An omitted hydrogen count (`[N+]`) is **meaning** and has to be re-derived
    from valence. Different problems, both needed
29. [T] **`MolFromSmiles(s, sanitize=False)` plus `SanitizeMol` is not
    equivalent to `MolFromSmiles(s)`** — the default path removes explicit
    hydrogens at the end and the `sanitize=False` path skips that. `[H]` stays
    in the graph and every descriptor shifts. **`Chem.RemoveHs` is required.**
    The valence repair appeared to change CHAMP, and CHAMP had not one atom
    the repair applied to
30. [T] **never apply a valence heuristic to a metal** — bare `[Li]`, `[Na]`,
    `[Fe]` are legitimate atoms and ions. Adding hydrogen because the valence
    looks short makes a different compound (`[Li]` → `[LiH]` in B3DB).
    **Restrict it to SMILES' organic subset** (B, C, N, O, P, S, F, Cl, Br, I)
31. [T-partial] **one parser** — a copy of the same repair sat in
    `candidates.py` with the bracket order fixed and the valence repair
    missing. The reference structures were quietly wrong
32. [T] **count the repairs and print the count** — without "how many were
    repaired" in the summary, a repair that works and a repair with nothing to
    do look the same
33. [T] **after replacing a parser, prove it is a no-op on the existing data**
    — down to comparing hashes of the output. CHAMP's features.parquet came
    out byte-identical, so the CV figures carried over
34. [prose] **write the settings next to the number** — M1's 0.8383 did not
    reproduce, and the cause was not the parser but the epoch count: 1 by
    default against 10 when it was recorded. The 0.0085 is eight times the
    parser's 0.0010. **A number with no settings recorded: suspect the
    settings before withdrawing the number**
35. [prose] **isolate a cause with an A/B** — the unease that "5 rows in 7,805
    moving something by 0.0086 is too much" led to a re-run on the old parser,
    which fixed the parser's share at 0.0010. Do not attribute by guessing
36. [prose] **a box is not enough for coverage** — 197 points in 9 dimensions
    leaves the inside of the box empty. By nearest-neighbour distance CHAMP
    goes 6.2% → 0.6%. The box is a necessary condition
37. [T] **`.gitignore` misses build output too** — `engine/target/` loses to
    the fact that there are three builds. Use `engine/target*/`. 633 of the
    first commit's 669 files were generated
38. [T] **matching canonical SMILES does not prove identity** — the
    `sanitize=False` path also skips assigning stereochemistry. Ring-internal
    double bond stereo goes unrecognised, and `MolToSmiles` writes it back
    from the bond directions, so **the SMILES match while the InChIKey
    changes.** InChIKey is the tie-break key (contraindication 24), so the
    representative structure changes. **A no-op check compares InChIKeys**
    (`Chem.AssignStereochemistry(mol, cleanIt=True, force=True)` resolves it)
39. [T] **`MolFromSmiles` has two default post-steps** — `RemoveHs` and
    `AssignStereochemistry`. Using `sanitize=False` means calling both
    yourself. One of the two leaves the other broken
40. [prose] **record the invocation arguments a figure needs to reproduce** —
    M1's 0.8383 was measured with `--epochs 10` and that was not recorded, so
    a re-run at the default gave 0.8297. The parser change looked like the
    cause and was worth 0.0010. **Do not attribute a cause before taking an
    A/B** — reporting without one would have withdrawn a sound figure
41. [prose] **~~the direction of transfer is set by inclusion~~ (withdrawn
    2026-10-09, as undecidable rather than refuted)** — tested over 7 pairs
    and 14 directions in B3DB and could not be told apart. All 14 held, so
    **there were no failures** and the predicted quantity has no variance. The
    partial correlation controlling for rows evaluated is +0.069 (against
    +0.635 for the row count), so coverage shows no explanatory power of its
    own, at n=6. **Not claimable, and not false either**
42. [prose] **do not generalise a transfer that held** — GNA → the IMI pool
    covers only 22.7%. **GNA → a library has not been shown to hold**
43. [prose] **"CI lower bound above 0.5" is a criterion about power, not
    about performance** — the lower half width moves as 1/√n, so the same AUC
    "fails" at n=129 and "holds" at n=755. **Match the rows evaluated before
    comparing directions**, or look at the point estimates and the overlap.
    Without matching, "it holds in one direction only" mistakes a statement
    about sample size for one about mechanism
44. [prose] **never write "one holds, one fails" about two overlapping CIs** —
    CHAMP/GNA's two directions overlap at [0.6150, 0.6921] and the point
    estimates differ by 0.0593. Whether a threshold falls between them is not
    grounds for distinguishing
45. [prose] **check first whether the split forces the predictor** — a set cut
    on an MW band has a box defined by MW, so cov = 0% is not a measurement.
    Three of five pairs were meaningless
46. [prose] **put the confounder through the same test as the predictor** —
    measure coverage alone and be satisfied, and you miss that the row count
    is the stronger effect. **Measure the alternative on the same ground**
47. [T] **`pgrep -f` in a wait loop matches itself and never finishes** —
    `while pgrep -f 'py/inclusion.py'; do sleep 20; done` has the pattern in
    its own command line, so it always finds at least one. **The watcher kept
    spinning long after the job finished in 15 minutes.** Split it as
    `[p]y/...` or wait on the PID
48. [prose] **do not wave away an intermittent test failure as
    unreproducible** — on 2026-10-09 an `errors=1` appeared once, and only
    stdout had been watched, so the traceback was gone. **Put stdout and
    stderr in a file on every run**
49. [prose] **distinguish "refuted" from "not decided"** — the B3DB test had
    all 14 directions hold and **no failures at all.** A test whose predicted
    quantity has no variance distinguishes nothing. That the outcome variable
    (the CI lower bound) contains 1/√n also blocked separating coverage's
    contribution. **The rule is not false; it is unmeasured**
50. [prose] **report every outcome variable computed** — the point estimates
    were computed and only the CI lower bound reported. **When the criterion
    itself is under suspicion, reporting only the numbers that fit the current
    frame hides the frame's error**
51. [prose] **never report a correlation from a chosen subset** — the partial
    correlation moved across +0.069 / +0.475 / +0.205 depending on how it was
    taken. Pick one row and **the choice makes the conclusion.** Writing the
    spread is the stronger evidence that nothing separates
52. [prose] **outside the descriptor box is not "unanswerable"** — the box is
    a conjunction over 9 descriptors, so **one axis irrelevant to the
    prediction being out puts a row outside.** Tested directly
    (`py/answerable.py`, 12 directions): **zero directions have covered
    significantly better.** The coverage figures are **a description of
    distance**, not a ceiling on capability
52b. **cutting a subset on a descriptor box makes the outside systematically
    easier** — by the best AUC a single descriptor achieves, uncovered is
    easier in 11 of 12. **The 3 directions where uncovered is significantly
    better are the 3 with the largest difficulty gap** (rho = −0.510).
    Outside the box is the tail of the distribution and tails separate on a
    single descriptor. **Never compare AUC across subsets without measuring
    difficulty**
53. [prose] **test an applicability metric for ordering and for calibration
    separately** — what `py/answerable.py` refuted is a reading about AUC,
    which is ordering. Calibration may still break outside the box. For
    screening the ordering is what matters, so the metric is right, but
    **"outside the applicability domain is fine" must not be generalised**
54. [prose] **you will step in your own contraindication on the next design**
    — right after writing 44, "never call two overlapping CIs holds and
    fails", `py/answerable.py`'s criterion **used the overlap as grounds for
    "nothing can be said."** For two disjoint groups, **a bootstrap CI on the
    difference** comes out cleanly. After writing a contraindication, check
    the next code you write against it once
55. [prose] **AUC does not compare across subsets** — it is a rank statistic
    within the set evaluated, so covered and uncovered are **different
    discrimination problems with differently spread labels.** "It predicts
    equally well outside" cannot be shown. What can is "the inside/outside
    split does not identify a subset where the ordering gets worse." Put a
    **difficulty proxy** beside it — the best AUC from a single descriptor —
    and check the difference is not explained by it
56. [prose] **how much data is needed has no answer until the question is
    fixed** — from the same 1/√n: about 150 to say it beats chance, about 650
    to tell two directions apart, about 1,470 for a half width of ±0.03.
    **An intermediate number like "about 800" answers none of them.** Write
    the ask with its question. And reserve that computing power from the
    observed effect size is optimistic: a smaller true difference needs more
57. [T] **varying the bulk size alone does not show independence from D** —
    the B axis, with D fixed, shows proportionality to B only. **Two axes are
    needed.** "Independent of D" was written once and corrected
58. [prose] **fixed costs can be broken down without a profiler** — a control
    run varying only the column count decomposed 34 MiB into "a parquet column
    buffer at 16.3 KiB per column". Neither heaptrack nor valgrind was needed
59. [T] **do not give the input a field for a factual number** — "100
    million", "0.071", "7,394" were all wrong as written. **Counts and
    differences come from the measurement.** The input takes the request only
60. [T] **stop on an unregistered value rather than rounding it** — nudging
    "MW under 500" to 450 puts a number nobody asked for into the record.
    Offer the candidates and stop
61. [T] **do not use a weighted score to select a proposal** — the w in
    `w1×survivors + w2×diversity` is invented, and "best" becomes a product of
    the weights. **Constraint satisfaction plus fewest relaxation steps** has
    no free weight, though how the steps are spaced is a human choice, so
    return a frontier
62. [T] **keep sketch error out of the verdict path** — deciding on the HLL's
    conservative lower bound leaves the error model in the decision. **Keep it
    to a coarse filter and count exactly in a second pass near the boundary**
63. [prose] **the proposal changes when the population does** — on a 50,000
    sample it was "two steps to basic_nitrogen"; at a million, "one step to
    rotb ≤7". **Do not treat a sample's proposal as production's**
64. [T-partial] **a library's slice is an input that decides the result, and
    needs recording and checking** — ZINC's `−N`/`−O`/`−M`/`−P` are **the
    predicted protonation state at pH 7.4, not the formal charge as drawn.**
    Taking `−N` alone systematically discarded the positive group eNTRy says
    accumulates. A 27-fold difference in survival. `py/provenance.py` reads it
    from the provenance and checks it against the published rule
65. [prose] **"everything exits cleanly and only the answer is wrong" is the
    worst shape** — four checkpoints all pass if the input is not in the
    specification. **Check first that the value deciding the result is
    recorded**
66. [T-partial] **never report a knob that changes nothing as a constraint
    applied** — `charge` gave identical survivor counts in 27 of 27
    comparisons. **And the evidence was printed in the output and skipped
    over.** `inert_knobs` detects it. **Added 2026-10-11: the knob was
    retired, and not because it was inert** — 23 of 20,000 molecules in `−O`
    really are drawn at +1. It was retired **because it measured a different
    quantity**; see section 4 and `RETIRED['charge']`
67. [prose] **do not rename an external data file** — renaming
    `H29P240-N.x.smi.gz` dropped the generation letter, and the machinery for
    reading provenance failed on a rename of our own making
68. [prose] **do not write "applied" for a partly implemented published rule**
    — the second eNTRy condition, globularity, was skipped and 2 of 3 was
    called "applied". Implemented, it turned out to be **inert on this
    library, passing 100%.** That it is inert could not be known without
    implementing it
69. [prose] **put the spread beside a conformer-dependent quantity** —
    globularity moves by a median of 0.033 and up to 0.236 across conformers.
    The paper does not say which conformer it used. Near the threshold the
    verdict flips
70. [prose] **the literature sometimes has no threshold** — Gram-negative
    specific logP / TPSA / HBD / HBA thresholds are not in peer-reviewed
    primary sources. **A mean is not a threshold.** A vendor poster is not a
    provenance, and it uses proprietary descriptors that are a different
    quantity from RDKit's
71. [T] **a prose parser breaks on inserted words** — `rotatable bonds at most
    5` parsed and `rotatable bonds must be at most 5` did not, dropping the
    requirement into `nothing was read from:`. **Test word order, not just the
    regex vocabulary.** A `_FILLER` now allows copulas, articles and
    intensifiers
72. [T] **defaulting `strict` to false was wrong** — the prose parser always
    set it false, so "strictly" in `molecular weight strictly under 450` was
    discarded and the weight offered up for relaxation. **An implementation
    that discards a word that is written is as bad as one that invents a word
    that is not**
73. [T] **a `must` at the front of a sentence binds every requirement** — "The
    screening must satisfy..." makes every knob strict, leaves one
    specification to compare, and no proposal comes out. The behaviour is
    intended, **but the user does not notice.** The output now shows how many
    are strict
74. [prose] **work drifts toward the impressive artefact** — the goal was an
    assisting answer, and two days held two sessions and 75 minutes of
    generating candidate lists. `verdict: feasible` looks like nothing
    happened; a list of 256 looks like something did. **Something that looked
    like progress was built without checking it was what was asked for**
75. [prose] **a document left at an old criterion pulls the work** — section
    3's stages still said "new compounds come out", and that pulled two days.
    **When the goal changes, fix the document first**
76. [prose] **existing machinery attracts the work** — `sequential.py` was
    easy to run, so it was run. **Physically stop** the path you do not want
    used (`--emit-molecules` is now required)
77. [prose] **a negative verdict without a revision is half an answer** — it
    used to stop at "there is no data for that target". Giving the resolution
    the evidence has — four organism classes and pMIC, with counts — lets the
    question be replaced
78. [prose] **the revision comes from measurement too. Do not invent
    chemistry** — "how about widening to secondary amines" is an unverifiable
    chemical claim. **Restrict it to substitutions within the published rule**
    and **relaxations of its thresholds**, measure the distance to every
    training set on hand, and answer "this is the nearest"
79. [T-partial] **`[INERT]` and `out_of_domain` look the same when the
    computation is broken** — both asserted without a positive control.
    **Globularity is now compared against the paper's 68 values** (r = 0.529,
    ranges agreeing), **and Tanimoto verified inside the same set** (median
    0.747). Both pass before either asserts
80. [T] **print a threshold's value and its source beside the verdict** —
    "0.0% at or above the threshold" cannot be checked. Write "nearest
    median 0.182, threshold 0.4, from the 0.4-to-0.6 applicability-domain
    convention at its lenient end"
81. [T] **if the count for one label moves between outputs, suspect the
    scope** — 8,601 (rows labelled on both axes, 22,051) against 17,530 (all
    sources, 74,202). **The first thing a reader prods**
82. [prose] **a negative result is cheaper when it comes from your own claim**
    — it was tested right after being made section 3's main argument, so it
    could be withdrawn before going outside. Know you are at n=1 before
    claiming
83. [T] **one output must not carry the same count from two independent
    literals** — `74,202` was in `occam.py`'s format string and in
    `screenable.py`'s scope sentence, **printed twice in one output.**
    Re-ingest and only one moves. A second instance: a training set's name was
    `IMI-COMBINE (activity, 22,051)` with the count inside it, and the same
    function measured that count. **Contraindication 81 said this in prose and
    it did not work.** `tests/test_no_duplicated_counts.py` scans the string
    literals of the reporting modules and fails when a count is written in two
    places. The allow-list holds quotations, page numbers and sample sizes
    only, and an entry without a one-sentence reason fails another test
84. [T] **a bound on the count is not a bound on the state** — narrowing the
    frontier to 8 bounds **how many** exact passes run and **not the memory of
    each.** Holding 8 sets at once is `8 × 46,437 scaffolds × 127.4 B ≈ 45 MB`,
    about what the sketch is avoiding (40.2 MiB for all 27 exactly).
    **Running one specification at a time and discarding it keeps the peak at
    the largest single one, about 5.6 MiB.** Invariant 3 — one computer and one
    bulk at a time — applied to the second pass. The price is I/O multiplied by
    the number of specifications. To raise the concurrency, derive it from a
    budget as `k × the largest specification's scaffold count × 127 B`: a
    division, not an invented weight. `tests/test_contraindications.py` pins
    the structure: `exact_scaffold_count` returns a count only, so the set
    cannot escape; it is not called inside a comprehension, so all results are
    never held at once; and `FRONTIER` is a declared constant
85. [T] **the second pass must read as much data as the first** — running the
    sweep at `--limit 20000` and the exact pass at `--limit 100000` made the
    frontier print **`123 molecules pass, 536 distinct scaffolds`.**
    **More scaffolds than survivors, which is impossible in principle.** The
    `exact` record was consistent at 683 survivors and 536 scaffolds, and
    **the display was combining the sketch's survivor count with the exact
    scaffold count.** The same scope mix-up as 25 and 81. Four fixes: the
    sweep records the `limit` it read; a mismatch prints the reason and stops
    (and `unrecorded` is refused too); the exact pass replaces `survivors` as
    well; and **scaffolds greater than survivors fails** — the cheapest check
    that catches the whole class
86. [prose] **do not conclude absence from a string search** — a document said
    "the product path does not call the engine" and **it did.** `grep
    'engine/target'` missed it because the code builds the path by joining
    (`ROOT / "engine" / "target-fp" / ...`) and that string never appears.
    **A string search was used to prove a negative.** Follow the import and
    call graph, or start it and see. Found on 2026-10-12 by reading
    `py/screenable.py:63`

    **Added 2026-10-14: undercounting the hits is the same hole.** Before
    moving `docs/` out of the repository, "the tests do not read docs" was
    concluded. grep had returned three lines; two were mentions inside
    docstrings and **the third, `tests/test_request.py:404`, actually called
    `read_text()`.** It surfaced after the move, when the documentation-parser
    agreement check failed. **Not believing a zero and reading every hit are
    the same discipline from two sides.** If a search returns several lines,
    read them all, or say how many you read
87. [T] **if you hold a process-wide guard, run the tests serially** —
    `cargo test` is parallel by default. `bulk.rs`'s `one_bulk_at_a_time` test
    **deliberately holds a `Bulk` while constructing a second** (catching the
    panic with `catch_unwind`), so during that window another thread's
    `process::tests::learning_and_scoring` calling `Bulk::new` trips the
    `LIVE_BULKS` assert. **A false positive from the test runner, not a
    violation.** It fired once and **did not reproduce in ten further runs.**
    Making the counter thread-local would silence it by weakening the guard in
    production, where the threads do not exist. The fix is how the tests are
    run: `-- --test-threads=1`. **It was diagnosable because the output was in
    a file** (contraindication 48). With stdout alone the traceback would have
    been lost and ten clean reruns would have closed it as a fluke
88. [T] **the candidate nearest the request is the one the sketch cannot
    place** — a specification lands in the uncertain band when its estimate is
    within three standard errors of the requirement, which is to say **when it
    is close to the answer.** The band is structurally where the best
    candidates live. Those rows were excluded from `feasible`, so the
    recommendation was chosen from "everything except the near misses". For a
    request of 500 the banded rows were discarded uncounted and 686 came out.
    Resolve them and they are placed correctly; where they cannot be resolved
    — the library cannot be re-read, or exact was switched off — they are
    named under `held_back`. **A candidate that could not be placed is not a
    candidate that failed.** The difference goes on the screen
89. [prose] **do not report a slope without breaking the confound** — to
    measure the cost of ranking as a function of molecule count, four points
    were run in ascending n. **n was confounded with run order** and least
    squares returned **−14.9 ms per molecule**, significant at 2σ. A per-
    molecule cost cannot be negative. The first point of a batch is the cold
    start and the slowest, and the fit was measuring the batch, not the count.
    Run in reverse, the same 1,820 took 299.84 s as the first point and
    242.92 s as the fourth. A second attempt compared only warmed points, and
    **both n=200 points came from the fast batch** — count correlated with
    batch again. The 9.6 ms per molecule taken by bracketing 1,820 between two
    200s inside one batch predicted 349 s for 13,946 and measured 248.
    **Three slope estimates, three withdrawals.** What is left is what can be
    said without a model: from 200 to 13,946, the per-molecule cost is not
    measurable
90. [T] **the sentence recording a withdrawal matches a search for what was
    withdrawn** — contraindication 86's shape, on the test side. Checking that
    `size=400` was gone from dead code with
    `assertNotRegex(source, r"size\s*=\s*400")` **matched the comment saying
    that number had been removed, and failed.** `is about not recorded` the
    same. **A sentence recording a deletion contains the deleted string.**
    Rewrite as a behaviour test: read the default through the AST, call the
    function and check its three branches. Stepped in twice in one day
91. [prose] **if cost justifies sampling, measure the cost first** —
    `SAMPLE = 1200` was supposed to save computation. Measured, 200 and 13,946
    took the same time: the cost is the fit over 22,051 rows for 10 epochs and
    has nothing to do with the survivor count. **The sampling bought no time
    at all and manufactured a false pass.** The design — derive the count from
    a time budget — was declared, then measured, and there turned out to be
    nothing to derive from, so the design went with it. **Declaring the
    criterion first is right; whether the declaration engages with the
    measurement is a separate question**
92. [T] **before saying "a library of N", check what N counts** — the screen
    printed `-N slice (neutral at pH 7.4), 1,000,000 compounds`. **The −N slice
    holds 4,572,322 and 1,000,000 was how much had been ingested.** The amount
    ingested was being stated as the size of the slice, wrong by 4.6x. −O
    (636,669) and −P (17,775) are complete, so the same words are right for
    them, and **side by side the three are indistinguishable.** The cause was
    printing `rows_written` as `rows`, and the slice's real size was recorded
    nowhere. `slice_rows` is measured and kept in the sidecar, and a truncated
    slice prints `1,000,000 of its 4,572,322 compounds read`. **A round count
    — exactly a million — is a symptom of truncation.** That the other two
    were 636,669 and 17,775 was the evidence, in plain sight
93. [prose] **when you present a part, say it is a part. The same failure in
    any layer** — stepped in three times on 2026-10-13, **in three different
    layers.** (1) implementation: `SAMPLE = 1200` measured 1,200 of 1,820 and
    used that distinct share as the whole set's for a pass/fail. (2) record:
    the screen said `-N slice, 1,000,000 compounds` when the slice is
    4,572,322. (3) document: the ranking cost table listed the warmed points
    only and did not mention the two cold starts excluded (273.14 and 299.84).
    **In all three the selection itself was reasonable, and the only error was
    not saying a selection had been made.** Implementation, record and
    document are different places, and **it is the same motion: offering what
    is to hand as the whole.** When you present a part, put the denominator,
    the excluded points and the reason in the same place
94. [prose] **writing the explanation for a user is an inspection** — on
    2026-10-13, writing `docs/prompt_format.md` found **two lies in the code**:
    the ingested amount shown as the slice size, and the strictest setting
    being applied to an unstated condition without saying so in `read as:`.
    **Neither was found by a test, and neither by external review.** The same
    shape as contraindication 73, where converting prose to a test exposed the
    gap between prose and implementation — the third time. **A shape that
    appears three times is a method, not a coincidence.** Do not write the
    explanation after the implementation; check the implementation while
    writing the explanation. Behaviour that cannot be explained is usually
    behaviour not worth having
95. [T] **an output directory is where generated files go, not a list of
    evidence that may be consulted** — `inventory.take()` swept
    `data/work/*.parquet` and got back **28 entries** for six datasets. Nine
    were **replicas the memory test makes** (the same B3DB rows up to 10,000x,
    78 million rows in total); the rest were feature and fingerprint tables,
    the same rows in another shape. A request naming a target searched the
    labels of all 28. **No contamination had occurred**, confirmed by
    measurement on 2026-10-14: `transglycosylase`, `gyrase`, `kinase`,
    `lipase`, `protease` and `purchase` match nothing in any of the 28. What
    matched were `group`, `threshold`, `reference`, `comments`, `split` and
    `label`, and **none can be promoted to a target** — promotion requires the
    `-ase` shape or a position in the closed syntax. **Two errors were
    cancelling, and fixing one exposes the other.** The fix is the same as for
    `-ase` (shape to position) and the default conditions (applied to shown):
    **from picking things up implicitly to taking them explicitly.** Making
    each manifest's `evidence` declaration the inventory's input dropped the
    test replicas (no manifest), hERG (`in_inventory: false`), ZINC22 (no
    labels, so nothing to answer a target question with) and ChEMBL src40
    (nothing consumes it) — **without adding one rule.** 28 entries to 4
96. [T] **a trade is struck in one place and spent in another** — the exact
    pass was written around "hold one set and pay the I/O per specification"
    (invariant 3 applied to the second pass). On −P, 17,775 rows, one pass is
    30 seconds and eight specifications are four minutes. **On −O, 636,669
    rows, one pass is 18 minutes and eight is two and a half hours.** The same
    code, a different library, and the trade collapses. **The docstring itself
    had forecast the release condition**: if a budget justifies k, k comes
    from dividing the budget. Changed to one pass over eight sets: nine
    specifications went **93.7 s → 19.6 s, 4.78x**, peak RSS **182.3 → 180.3
    MiB**, unchanged, and all seven verdicts identical. The pass ratio is
    9/2 = 4.5x and the excess is scaffold computation going from per
    specification per molecule to per molecule — profiled at 27.6% of the
    per-molecule cost. **A premise struck in one place and spent in another is
    `SAMPLE = 1200`'s shape** (contraindication 91). There the trade never
    held; here one that held collapsed when the conditions changed
97. [prose] **do not conclude from "it looks like the culprit". Measure stage
    by stage** — 4.1 GB observed on a two-way parallel run. **The change just
    made was "hold k sets at once", so blaming it is the natural move.**
    Measuring peak RSS per stage, the exact pass was 181.8 MiB — **the same as
    the old implementation's 182.3.** The 1.4 GB per process was in
    `rankability()`, and breaking that down further, `write_parts()` went
    387 → **2,781 MiB**, close to the 2,879 observed. **22,051 rows × 2,048
    columns, 0.7 MiB on disk and 180 MiB in Arrow, took thirteen times the
    original to write out.** Commit the change proven unrelated first and keep
    this as a separate matter. Mixed together, which fixed what cannot be
    separated later
98. [T] **do not expand Arrow into Python. Slice it as a view** —
    `write_parts()` called `to_pylist()` on all 2,048 columns and copied again
    with `[list(c) for c in columns]`. **An Arrow float32 is four bytes; a
    Python float is about thirty-two.** Writing out the training table —
    22,051 × 2,048, 0.7 MiB on disk, 180 MiB in Arrow — took **2.4 GB**,
    thirteen times what was written. And it scaled with rows: +220 MiB at
    1,820 and +1,170 MiB at 10,000. Two in parallel peaked at 4.1 GB.
    **`table.column(n).slice(start, length)` is a view: no conversion and no
    copy.** The training side went +2,394 → **+7 MiB**, the survivor side at
    10,000 rows +1,170 → **+9 MiB**, the stage 2,879.5 → **471.4 MiB**, and
    the peak during a run 4,109 → **940 MB**, with the spike gone. And
    **49.04 s → 1.38 s, 35x.** A change that cut memory made it 35 times
    faster because the conversion itself was the cost. **The dangerous part of
    such a rewrite is the slice window**: the shape stays right while
    different rows get written. "One row group per part" only checked
    `ingest_zinc.py`'s output and not `write_parts` itself, so a row-count
    match, the first part starting at the first row, and one split per row
    were added
99. [prose] **use a place the change cannot reach as a control** —
    `write_parts` alone was 35 times faster and the seven runs went 352 s →
    477 s, and 532 s alone. **Both cannot be true, so one measurement is
    missing something.** The explanation that came to mind was rounding in the
    float round-trip changing the engine's convergence — and before testing
    it, **the sweep time** was read: `17,775 molecules read in 11.6s` had
    become `17.8s`. **The sweep does not touch `write_parts` at all.** Same
    code, same input, 53% slower: that is the state of the machine. Before
    forming a hypothesis, check whether somewhere the change does not touch
    moved by the same amount. The same tool as yesterday's order confound
    (contraindication 89), and here the control was already in the run log
100. [T] **a mechanism that returns green for something it cannot inspect is
    worse than no check** — `rank_verdict()` — the asymmetry that a sample
    cannot cross the floor — was to be held by KeepOut's `[LOCK: pbt]`, the
    mode that pins behaviour over 10,000 inputs and **exists for exactly this.**
    Applied, `keepout check` passed. **Collapsing the implementation to
    `return "answerable"` also passed.** Three reasons stacked: (1) the PBT
    engine generates **one integer argument**, (2) it `exec`s the region **in
    an empty namespace**, so the module constant `MIN_DISTINCT_SHARE` is
    undefined, and (3) it skips call exceptions with `except: continue`. A
    three-argument function reading a module constant raises `TypeError` on
    all 10,000, every one is skipped, and the end is green. **The same shape
    as the two "a skip looks like a pass" faults of that week** — `unittest
    discover` collecting nothing and exiting 0, and a library with a
    population of zero proceeding to a verdict. Replaced with `[LOCK: ast]`
    freezing the structure only, with the behaviour held by three hypothesis
    property tests at 2,000 examples each, **generating the real three
    arguments.** A deliberately broken implementation was **confirmed to be
    caught by both.** Why `pbt` could not be used is left in a comment, so the
    next person who thinks "pbt suits this" does not swing at the same air
101. [prose] **measure that a proposed revision works before proposing it** —
    "a looser specification spreads the scores, so another frontier candidate
    may clear the floor" sat as the revision for an unrankable set from the
    day it was written and was never measured. **It does not work.** The
    engine's score is a sum of the weights of the fingerprint bits, so
    **molecules with the same fingerprint get the same score.** Measured, the
    distinct score count and the distinct fingerprint count were 846 and 846,
    exactly equal. Every specification selects from the same molecules, so
    anything sharing a fingerprint shares it under all of them. **This was one
    step from implementing `--full-frontier` to run it** — 32 minutes to
    measure eight specifications and produce a known answer eight times.
    Radius 4 → 5 and 2,048 → 8,192 bits leave it at 846, so it is not hash
    collision either. It is **stereoisomers**: 577 groups and 1,551 molecules,
    85%, collapse to one structure when stereochemistry is dropped, because
    ZINC carries isomers as separate entries and Morgan fingerprints ignore
    stereo by default. What works is `includeChirality=True` (846 → 1,816,
    99.8%), but **the fitted model was built on fingerprints without stereo**,
    so it needs a refit, and whether stereoisomers should be distinguished
    depends on the target and is not the tool's to decide. The proposal-side
    form of "measure the cost before sampling" (contraindication 91)
102. [prose] **if you write "measured", measure first** — an estimate of
    runtime was given as
    `SECONDS_PER_MILLION_READ = 800.0  # sweep plus one exact pass, measured`.
    **The sweep alone is 796 s per million**, and the exact pass — 1,269 s on
    −O, 56% of the 2,258 total — was missing entirely. A 38-minute run was
    predicted at 13. **The error is writing `measured`, more than the number
    itself**: a measured value and a placed value sitting in the same format
    cannot be told apart afterwards. Re-anchored on two end-to-end
    measurements and now agreeing (−P 532 s, −O 2,258 s). And **two points are
    two points**, so the comment says it moves if a run outside them appears
103. [T] **put every line claiming a source through at once** — rather than
    closing contraindication 102 with one fix, **32 lines carrying a number
    together with `measured`, `counted`, `observed`, `timed` or `profiled`**
    were extracted from the 14 product modules and audited. Two looked
    doubtful and were measured: **one was a lie and one was real.**
    (a) `SKETCH_RELATIVE_ERROR`'s "measured in this repository at 0.29% to
    1.24% over four cardinalities" — **no such measurement exists.** 0.016 is
    theoretical (1.04/√4096 = 1.63%), and the 0.29% quoted was **a memory
    growth figure from another table** (36,224 KiB against 36,328). Re-measured
    over 30 seeds and 6 cardinalities: 0.06% to 5.87%. (b) "scaffold
    computation is 27.6% of the per-molecule cost" — **measured at 27.8% and
    correct**; it had simply never been recorded. **Both sat in the same
    format and could not be told apart without measuring.** In a repository
    that works because it cites its sources, a lie in the source field is the
    most damaging kind
104. [prose] **re-measuring turns up something that was not under test** —
    the HLL error was measured for the source-label audit, and what came out
    was that **the error triples around 10,000 and exceeds the uncertain band
    (4.8%) twice in 30 runs.** 2.5 × 4,096 = 10,240, the point where
    HyperLogLog leaves its small-cardinality correction. At the other five
    cardinalities it was 0 of 30. The band holds it, but it happens more often
    than "rare at three standard errors" implies and **is concentrated at a
    particular cardinality.** The constant was left alone and where it is
    risky was recorded — the exact pass recounts inside the band, so that is
    what carries it. **Going to fix a lie turned up a property of a place that
    was not lying**
105. [T] **if you wrote "sample and say so", implement the saying so too** —
    `MAX_MOLECULES = 6000`'s comment said **`sample and say so instead`.** The
    sampling was implemented and **the saying so was not.** For a set of
    518,027 the screen printed `what would close it: 3,992 compounds measured,
    one per neighbourhood` with no denominator. **3,992 is the number of
    neighbourhoods found in a sample of 6,000.** On the same screen the
    ranking says `measured on 518,027 of 518,027` and applicability says
    `measured on 1,200 of 518,027`, and only this number did not. **And it
    does not saturate**: 500 → 477 (95.4%), 1,000 → 905 (90.5%), 2,000 → 1,680
    (84.0%), 4,000 → 2,932 (73.3%), 6,000 → 3,992 (66.5%). At the largest
    sample two thirds are still their own only neighbour, the whole-set value
    is larger, and by how much cannot be measured — Butina holds the full
    lower triangle, so 518,027 rows is 134 billion distances. `at least` was
    added, with `clustered on 6,000 of 518,027` and why it does not saturate.
    **The gap between intent and implementation was written out in the
    comment**, and a defect legible from reading the comment sat there for
    days
106. [prose] **do not substitute another thing's output for confirmation that
    something finished** — stepped in three times during the container build.
    (a) `podman build ... | tail -18`'s exit code was read as podman's. **A
    pipe's exit code is the last command's**, and `tail` always succeeds.
    (b) A quiet log tail was read as "it has stalled" and a second build was
    launched. **It was still being written**, and both later showed
    `Successfully tagged`. (c) `podman run` was launched before the build
    finished and contended on the layer store's lock. **All three are the same
    error**: assuming success without looking at the record of it. The same
    root as `unittest discover` returning 0 after running nothing, where the
    confirmation of "it ran" was substituted by an exit code. **Writing the
    wait condition is enough** — `until ! pgrep -f "podman build"; do sleep;
    done` and `grep -c "Successfully tagged"`
107. [T] **a feature that asserts provenance must not die where there is no
    provenance** — `show()` called `git describe` through a subprocess to
    print the version. There was a fallback for empty output
    (`"not a git checkout"`) and **none for the `git` command being absent.**
    A container has neither a `.git` nor a `git`, so it died with
    `FileNotFoundError` and took the tool with it. **The one line that records
    provenance was failing in the one environment where provenance cannot be
    recovered.** A kind that is never found locally, where `git` is always
    there, and **it came out because the distribution form was tried.** The
    fix is not installing `git`; it is not stopping without it. An image has
    no history, so `--build-arg OCCAM_VERSION` bakes it into `VERSION` at
    build time and the read order is VERSION → git → "not recorded".
    Contraindication Q — a result with no version on it — returning in a new
    distribution form
108. [T] **if one field holds three types, implement all three on the reading
    side too** — `suggested_revisions[*]["measured_alternatives"]` takes
    **three shapes**: a sentence for a one-sentence next step, a list of
    training-set rows, and the tie diagnosis as a dict. The detail printer
    dispatched on all three with `isinstance`, and **the ANSWER block assumed
    the sentence and put whatever arrived into an f-string.** So for **the
    verdict that comes up most often** — the scores tie — the summary a reader
    stops at ended in **a repr of fifteen keys**, three of them paragraphs:
    `to settle it: {'measured_on': 1820, 'distinct_fingerprints': 846,
    'why_this_bounds_the_score_count': 'the score is a sum over...'}`.
    **All six regression prompts passed over it** — the fixtures hold JSON and
    nothing compared the rendered strings. **It was found while pasting real
    output into the README.** A kind that surfaces the moment output is read
    the way a person reads it, which is why pasting it was worth doing. Split
    into `render.settle_line()`: the dict gets a one-line form — counting
    chirality gives 1,816 of 1,820, 99.8%, at the price of refitting the model
    — and the list returns `None`, because a comparison whose content is the
    ordering of four rows has no one-line form
109. [T] **with two instruments, `max()` becomes a device for picking the
    noisier one, not the larger** — `test_peak_rss_flat_across_scales`'s x1000
    came out **+11.4% against a 10% tolerance and failed.** Three reruns gave
    +4.1%, +0.9% and −1.1%. **The shape that tempts you to move the tolerance,
    when what needed moving was the choice of instrument.**
    `maxrss_kb = max(VmHWM, GNU time's %M)`, and the docstring says *the
    larger of two kernel readings* — **conservatism, not a fallback.** (The
    fallback theory dies on reading: VmHWM is **mandatory**, since
    `int("unknown")` would raise, and `%M` is **optional**, being 0 without
    GNU time. `%M` has never once stood in for a missing VmHWM.)
    **Taking the larger conservatively is right for an absolute bound** — how
    big did it get, at most. This check is a **ratio between two runs**, and
    `max()` of two readings that straddle each other **biases the numerator
    and the denominator upward independently**, so the ratio carries both.
    **Measured, 10 runs at each scale**: `max()` picked **VmHWM 5 times and
    `%M` 5 times at both scales**, and `%M − VmHWM` ran **−180 to +136 KiB**,
    so `%M` is not reliably the larger. The spread is 140-200 KiB for VmHWM
    against 284-384 for `%M`, **about double.** `/usr/bin/time -f %M true`
    returns **1,428-1,540 KiB** — `%M` has the wrapper's own footprint as its
    floor. The worst ratio the instrument alone can produce is 4,332/3,956 =
    **+9.5%** with `max()` (and +11.4% was observed) against 4,208/3,964 =
    **+6.2%** with VmHWM alone. The 10% tolerance stays as it is. Five runs
    after the change: −3.4% to +2.2%, where the four before spanned −1.1% to
    +11.4%. **`%M` is kept and printed, as a cross-check that fails if it
    differs from VmHWM by more than 2 MiB** — once a self-report is the
    instrument, something has to watch the instrument. The 2 MiB is the
    measured footprint of the wrapper, eleven times the largest disagreement
    observed. **Contraindication 2's "VmHWM or GNU time's `%M`" was half right
    and half short**: both are usable, and it never said how to use them
    together
110. [T] **three from one layer means the third is not the one to fix
    individually** — three have come out of the display layer: **E**, a filled
    slot making a sentence meaningless (`this library is about not recorded
    for this library`); **G**, a universal claim printed next to the `max()`
    that contradicted it; and **108**, a dict in an f-string ending the ANSWER
    in a repr. The first two were fixed individually. **At the third it was
    accepted that the layer needed defending.**

    **Why not golden strings.** Put the prose in the fixtures and every
    improvement to a sentence needs an update, and **the moment the person
    updating stops reading what they are replacing, the comparison has stopped
    being a check.** The fixture-side form of contraindication 90.

    **A boundary instead.** `render.display_boundary()` takes stdout for the
    length of a run, and **not one line carrying a repr can leave.** 200
    `print()` calls across 8 modules are covered in one place, and **the 201st
    is covered from the day it is written.** Not detection: the class is made
    unreachable. The same manner as stopping on an out-of-vocabulary phrase
    instead of rounding it, applied to rendering. **Fragments count as shapes**
    — `wrap()` breaks a long repr across lines, so the line a reader sees is
    like `'reads_as': 'the same` with **no brace on it.** Of the 12 lines 108
    put on the screen, **9 carried no brace**, so a check for `{'` alone
    passes most of the damage. A bare `{` is not a shape: the last line prints
    `--out-dir`, and **the path is the caller's and may contain braces.**

    **Trying to prove it turned up a second hole.** Reproducing 108 to watch
    the boundary fire **did not fire it**, because run6's fixture still held a
    **string** in `measured_alternatives`. The fixtures sat at `500f4f0` from
    2026-10-14, **without the 24 fields the code now writes**
    (`rankability.short_by`, `largest_tie.*`, the whole tie diagnosis). The
    live layer compared **two fields** — `rankability.verdict` and
    `applicability.verdict` — and **the subtree the defect lived in was
    recorded and never compared.** So the hole is a level deeper than "the
    strings are not compared": **most of the JSON is not compared either.**
    (See contraindication 113 for how far that went.)

    **`[LOCK: pbt]` cannot be used** (contraindication 100's reason). The PBT
    engine generates **one integer argument** and `exec`s the region **in an
    empty namespace**. A guard function taking one string raises `TypeError`
    on all 10,000 and reports `pbt_unverifiable` — no longer a false green,
    because the upstream was fixed — but **it cannot hold it.** `[LOCK: ast]`
    freezes the structure and a hypothesis property holds the behaviour:
    **any dict or list dropped into an f-string stops the run**, which binds
    the class rather than the dict that was found.

    **And a check for "no unresolved placeholder" does not catch E.** E's slot
    was **filled** and the sentence broke anyway; no `{...}` remains. There is
    **no `str.format`, no `%`-format and no `string.Template`** anywhere in
    the product code, so there is nothing for such a check to guard today. E
    is held by three behaviour tests calling `barrier_sentence()`, rewritten
    from a string search under contraindication 90. The `%s` shape is kept in
    the boundary as insurance against `%`-format arriving later, and **is not
    written up as guarding anything now**
111. [T] **"written down and never once run" was the same defect four times in
    one day** — one root: **correct when written, and left there with nobody
    putting it through.**

    | what was written | what was true |
    | --- | --- |
    | the revision "measure the frontier, 32 minutes" | never measured whether it helps. It cannot: the answer was already known |
    | the source label `measured` on `SKETCH_RELATIVE_ERROR` | that measurement did not exist (contraindications 102 and 103) |
    | the comment `sample and say so instead` | the sampling was implemented and **the saying so was not** (contraindication 105) |
    | `RECORD.md`'s re-recording procedure | it read a `prompts.txt` **that is not in this repository.** Never run as written |

    **A document is not a description of the repository, it is a claim about
    it**, and a claim nothing executes decays at the speed the code moves.

    The request vocabulary has been held this way for some time: every
    spelling it lists is put through the parser by `tests/test_request.py`, so
    an example that does not work is a failing build.
    `tests/test_documented_procedures.py` generalises that, as far as it goes
    cheaply: **a rooted path exists exactly; a bare filename resolves
    somewhere in the repository; a flag is one the program's argparse accepts;
    a cargo feature is declared in Cargo.toml; the documented module list is
    every test module and all copies of it agree; and the entry points answer
    `--help`.**

    **Deliberately not executed**: the container build, the ZINC fetch, the
    27-minute re-recording. **A check that takes twenty minutes is a check
    that gets switched off**, which is this module's own failure arriving by
    another road. All three are held by the cheap parts of them — their paths,
    their flags, their features.

    **Its first run caught itself**: the new module was not in the documented
    list, so it ran nowhere.

    **And the check for `prompts.txt` passed `prompts.txt`.** The pattern
    required whitespace on both sides, and the real thing reads
    `prompt=$(sed -n "${n}p" prompts.txt)` — **the name ends on a paren.**
    **It had been validated against the repaired RECORD.md, returned nothing,
    and was concluded to work**: measured on a document the fault had already
    been removed from. Fixed by widening the boundary to shell punctuation.
    **It was found by planting each of seven faults and checking the
    responsible check fails** — one of the seven passed. When adding a check,
    **watch it fail on a planted fault before watching it pass unmodified**
112. [T] **a provenance inferred from a document was reaching the reader's
    screen** — `data/raw/b3db/manifest.json`'s `which_version_this_is` said
    **"the copy here is from before upstream v1.0.0"** and concluded that
    **"re-fetching today would change the row count by 175 and move every
    number measured from this set"**, and on that basis **forbade
    re-fetching.** The grounds were one sentence of the upstream README —
    *categorical ... (7807 compounds prior to v1.0.0 and 7982 compounds
    after)* — and the inference that 7,807 rows here places it on the earlier
    side. **The bytes had not been looked at.**

    **Measured 2026-10-16: `B3DB/B3DB_classification.tsv` is touched by
    exactly one commit in the whole history** (`0ec04a3ffb1b`, 2021-02-25),
    and **at that commit, at `v1.1.1` and at `HEAD` it is the same 2,635,683
    bytes with the same sha256 `47a160ae...` as the copy here.** The README's
    7,982 **is not about this file.**

    And it was in `evidence.caveat`, so **it printed on screen**: `upstream
    version before v1.0.0: 7,807 rows against the 7,982 the repository holds
    today`, as a provenance note under the nearest-set comparison. **When
    contraindication 103 audited 32 lines claiming a source, this one was not
    in scope** — it contains none of `measured`, `counted`, `observed`,
    `timed`, `profiled`. **A claim about provenance can be written without any
    word that claims a measurement.** The caveat was deleted; there is no true
    replacement, because the file has one version.

    **It was found by trying to make the data fetch one command.** Writing
    `py/fetch.py` needs a URL, a pin and a checksum readable from each
    manifest, and **three of the five could not be re-fetched as they stood**:
    (a) CHAMP recorded **the local filename**, and Zenodo serves it under the
    paper's title; (b) IMI-COMBINE pinned a commit and **recorded no
    checksum**, so a re-fetch could be verified only by trusting the ref;
    (c) B3DB, above. **The implementation-side form of contraindications 93
    and 94: writing the explanation is an inspection.**

    **`B3DB_regression.tsv` matches no upstream version** — two commits touch
    it, at 421,902 B and 378,224 B, and the copy here is 378,970 B /
    `b0f4c844...`, **neither.** The manifest already said it is not evidence
    for any question this tool answers, and `grep -rn B3DB_regression py/
    tests/` is empty. It is declared **not fetched and not ingested**, with
    the unresolved provenance recorded in `files[1].provenance_unresolved`.
    **Something taken in and never resolved is worth recording as such.**

    Verification of the fetch: all seven files **byte-identical to the local
    copies**, and the rebuilt parquet **byte-identical** too (1,132 / 197 /
    22,052 / 7,807 rows). A corrupted checksum was confirmed to stop the run.
    **The checksum is the guarantee, not the pin** — a tag can be moved.
    ZINC22 has **no checksum for any slice**, so verification is the row count
    after ingest and the slice's own line count, and **contents changing
    without changing length would not be noticed.** `--dry-run` says so
113. [T] **decide a snapshot's comparison scope after measuring what moves** —
    the live layer compared **two fields** of `screenable.json`,
    `rankability.verdict` and `applicability.verdict`. The reason given was
    that timings and version stamps move, so a test comparing whole
    transcripts fails every commit and gets switched off — **and that reason
    had never been measured.**

    **Measured: two independent recordings of the same seven prompts differ in
    exactly one field, `sweep.summary.seconds`.** No count, no share, no
    ordering, and no version stamp — version stamps do not reach these five
    files at all. **So the scope could be essentially everything**, which is
    **1,733 fields** per run-set. The exclusion list is the one field that was
    measured, not a number that was placed.

    **A shape-only comparison went in first and was not enough.** Deleting
    B3DB's false caveat (contraindication 112) changed **five records**, and
    the shape comparison **reported one.** Two reasons stacked: (a) it sampled
    **only the first element** of a list — "one row stands for all of them",
    which they do not — and (b) taking the union instead reported **none**,
    because **CHAMP declares a caveat too**, so the field set never changed.
    **Deleting the caveat was a change of value, not of shape.** Catching it
    by shape was the wrong instrument; comparing values reports all five.

    **And that replacement silently moved four tests to the skipped side.**
    Splicing by string index deleted `ALibraryHeldInOneFile`'s class
    declaration together with its `@unittest.skipUnless(FIXTURES.is_dir())`,
    so four tests fell inside the `OCCAM_PROMPTS=1` class. **`Ran 237` was
    unchanged and so was `OK`; only `skipped` went 7 → 11.** Watching the
    total would not have shown it. **Read the skip count every time** — the
    third "a skip looks like a pass" that week, where the first two were on
    the checking side (`unittest discover` running nothing and exiting 0, and
    `[LOCK: pbt]` swinging at air) and this one was an editing accident. The
    class structure was restored by diffing against `git show HEAD:`
114. [T] **put a measured value inside a generated file and regenerating
    deletes the measurement** — a regression of contraindication 92. The −N
    slice's real size, 4,572,322, lived only in `data/work/zinc/parts.json`.
    **`py/ingest_zinc.py` does not write that field** — it was measured with
    `zcat` on 2026-10-13 and **added to the generated file by hand.**
    `python3 py/fetch.py --zinc` re-ingested and **destroyed the only
    machine-readable copy.** The screen immediately went back to `-N slice
    (neutral at pH 7.4), 1,000,000 compounds` — **the exact sentence
    contraindication 92 had fixed**, for a slice 4.6x that size. The number
    was still in the documents and in two source comments, and **nowhere a
    program reads.**

    Three fixes. (1) `data/raw/zinc22/manifest.json` **declares** `slice_rows`
    — a measurement belongs in a declaration, not in a generated file.
    (2) `provenance.identify()` **reads the declaration first and the sidecar
    second**, so a library ingested from somewhere else keeps its own record.
    (3) `py/fetch.py` **counts the lines of the `.gz` it just downloaded and
    compares**, by the same method as the original measurement, so the
    declaration is verified rather than trusted. Counted independently from a
    fresh download three days later: 4,572,322 / 636,669 / 17,775, **identical
    to the first time.**

    **And one step before running `--zinc`, another unimplemented check
    turned up.** `py/fetch.py` said in **three places — the docstring, the
    manifest and `--dry-run` — that a slice with no checksum is verified by
    its row count after ingest, and `rows_expected` was read nowhere.**
    Contraindication 105's shape, **stepped in an hour after writing
    contraindication 111** about written-and-never-run, and one step before
    running it and reporting it verified. Implemented, all three slices
    report.

    One more from running `--zinc`: the README said "about 300 MB" and it is
    **73 MB measured**, gzipped, over three slices. **A number written before
    it had been run.** Corrected.

    The data itself reproduced: **all 204 parquet parts byte-identical.** The
    only difference was the sidecar, where `source` went from **a path in a
    session temp directory that no longer exists** to
    `data/raw/zinc22/H29P240-P.x.smi.gz` — an improvement, which removes the
    very reason `zinc22/manifest.json` had to be written
115. [T] **auditing the numbers on the outward face, the second error was the
    container's size** — before publishing, the scope was set to "only the
    provenance claims on the pages a reader meets". README has 24 lines
    outside a code block carrying a number, and **23 are backed by a run or a
    record from that day.** The remaining one was the container's "about 560
    MB", and **the image had been deleted along with its layer store, so it
    could not be checked without a rebuild.** Rebuilt: **633 MB** — **13%
    wrong.**

    The cause was in the Dockerfile. **It pins rdkit, pyarrow, numpy and
    hypothesis exactly and then sat on the floating tags `FROM rust:1-slim`
    and `FROM python:3.14-slim`** — the first floating across all of Rust 1.x,
    the second across Python's patch releases. **Two builds from the same
    Dockerfile on the same day came out at 557 MB and 633 MB.** The floating
    bases are enough to explain 76 MB, and **the cause is not proven** — no
    digest from the first build was recorded anywhere. That is the other half
    of the same defect.

    Both are pinned by digest now, and after pinning it is still 633 MB and
    the image answers correctly. **The update procedure is written down**:
    pull the new tag, read its digest with `podman images --digests`, put it
    here, rebuild, record the new size. **Deleting the digest is not updating;
    it is unpinning.**

    One error in 24 audited. **Against the record of that day — two of three
    claims measured turned out false** (`SKETCH_RELATIVE_ERROR`'s fake
    `measured`, B3DB's false caveat) — that is an improvement, **and the one
    was on the first page a reader meets.** The measured runtime of the slow
    layer, 27 minutes, was added to the README at the same time
116. [T] **a refusal you designed is untested until you have fired it once** —
    one prompt was aimed at a path the seven recorded ones do not reach:
    **"300 scaffolds from B3DB under the eNTRy conditions, ranked, top 40, for
    a CNS-penetrant antibacterial programme."** A conflation a chemist could
    actually make — I want compounds that get into cells, eNTRy is the entry
    rule, B3DB is permeability data — and **a request any filter script
    answers with confidence.** `py/occam.py` names B3DB **precisely so this
    mismatch can fire.** Two things came out.

    **(a) `--yes` disabled two substantive refusals and the documentation
    described one.** The flag does three things: it skips the `run this?
    [y/N]` confirmation — **the only one documented** — and it overrides the
    refusal when the library measures a different barrier, and the refusal
    when the charge slice contradicts the published rule. The last two are not
    confirmations, they are **findings**. argparse said `do not ask before
    running` and the launcher said `do not ask before reading the library`.
    And **every automated caller passes `--yes`**: `tests/test_prompts.py`,
    the re-recording procedure, the container examples in the README. **So
    every scripted run had both findings switched off.**
    `b3db/manifest.json`'s `role` also said unconditionally that "a request
    pointing those at this data stops", which is false with `--yes`. All three
    were corrected. **Whether the flag should be split is a design call and
    was left alone.**

    **(b) The comparison set contained the library being screened.**
    `nearest_training_set()` compares the survivors against the four measured
    sets on this disk, and **any of those four can be the library a request
    names.** When it is, every survivor has an identical structure in the
    comparison set, so it gets **median nearest 1.000, 100.0% above the
    threshold, and the `*` that marks the sets a library is inside** — and it
    **sorts first.** The sentence closing the block says the first row is the
    one the library is actually nearest to. **The one reassuring row was the
    library matching itself.** Measured: screening B3DB left 1,963 survivors
    and printed `B3DB ... median nearest 1.000, 100.0%` above rows at 0.209,
    0.163 and 0.147. **With the self-match dropped, none of the three reaches
    the threshold** — the true conclusion, that no model fitted on anything
    here can speak about this library, had been hidden behind a 100% match
    with itself.

    **The recorded seven can never reach this**: five screen a ZINC slice,
    which is not one of the four candidates, and the CHAMP one **leaves no
    survivors, so the block never runs.** `report()` now takes the library and
    drops it from its own comparison. The fixtures were unchanged (237 passed)
117. [T] **write the argument that "this cannot affect X" only after counting
    everything your change touched** — when the self-comparison exclusion went
    in, the commit said **"this change cannot affect a library that is not one
    of the four candidates"** and the 27-minute live layer was skipped on that
    basis. The grounds were that all seven live prompts are a ZINC slice or
    CHAMP with no survivors, **and the fixtures being unchanged and 237 fast
    tests passing both supported it.** **The live layer failed anyway.**

    The argument was right about **the comparison rows** and **did not count
    the sentence added in the same change.** An unconditional clause — that
    the screened library is left out of the comparison — had been added to
    `what_this_means`, so **it reached all five ZINC records, which have
    nothing left out.** The failure was
    `run1.screenable.suggested_revisions.activity prediction.what_this_means`.
    **Reasoning about the data path and forgetting the string on the same
    path** — the display layer again, where contraindication 108 was.

    The fix was not re-recording but **making the sentence conditional**, said
    only when an exclusion actually happened. **A line explaining something
    that did not happen is the inverse of this project's rule** about
    presenting a part as a whole. The five ZINC records went back to the
    original string and **no fixture needed re-recording.** The candidate dict
    was lifted to the constant `TRAINING_SETS` and `is_a_training_set()` is
    now **asked as one question by both the comparison and the sentence** —
    two places that must agree having been written in two places was half the
    cause.

    **The run beat the argument.** The commit that said it could be known
    without running also said **"that is an argument and not a run"**, and the
    second sentence was the right one. Trying to save 27 minutes cost 27
    minutes plus 2,353 seconds plus the rerun.

### The conversion queue (of the [prose] items, the ones an assertion can reach)

**Cheapest first.** The selection criterion is "can an assertion be written".
The ones where it cannot — items about judgement and attitude — are more
correctly left as prose.

**Ten were converted** on 2026-10-11, into `tests/test_contraindications.py`.
That file now holds 79 tests, and the suite as a whole holds the later
contraindications too.

| contraindication | the test written |
|---|---|
| 1 | `.gitignore` has `data/raw/**` and not `data/raw/*`, and the manifests stay tracked |
| 4 | **open the parquet that was written and check it has one row group** |
| 13 | the walk of `data/raw/` returns no directories |
| 37 | `.gitignore` has `engine/target*/` and not a bare `engine/target/` |
| 47 | the `pgrep -f` pattern in a wait loop is split by brackets |
| 59 | all four kinds of factual claim land in `dropped_claims` and never become requirements |
| 61 | **by AST**, there is no weighting coefficient (the docstring explaining why is excluded) |
| 62 | the uncertain band is three times the error, and the sketch does not decide inside it |
| 73 | a leading `must` makes every knob strict and leaves one specification to compare |
| 80 | every path that prints a threshold also prints its `threshold_source` |

### What the conversion found: contraindication 73 did not exist in the implementation

**The request-format document described behaviour the code did not have.**
A leading `must` was not implemented; there was only the ±40-character clause
window. So in
`The screening must satisfy the following criteria: ... primary amine ...`,
**`primary amine` was read as relaxable and the proposer was offering to trade
it away.** The same shape as contraindication 72, defaulting `strict` to false.

The moment the prose became a test, the gap between prose and implementation
appeared. **That is the value of converting.** The code was fixed
(`LEAD_IN`: a compelling word inside an introductory clause ending in a colon
binds every requirement after it).

The remaining prose items are about judgement — which withdrawal to record,
not drifting toward the impressive artefact — and do not take the shape of a
test. **Admitting that and leaving them as prose is cheaper than pretending
otherwise.**

---

## 8. Work in progress (where to resume first)

### Done (2026-10-08)

The GramNegAccum parse fix is in `py/` and every figure depending on it was
re-measured.

1. **`py/smiles.py` added.** The one SMILES parser every module uses.
   Hydrogen count re-derived from valence (organic subset only), bracket
   order fixed, `RemoveHs`, `AssignStereochemistry`. The last two restore
   `MolFromSmiles`'s default post-steps and are locked (the ninth lock)
2. **All four parse sites unified** (`descriptors.py`, `fingerprints.py`,
   `candidates.py` twice, `folds.py`). The copy of the repair in
   `candidates.py` was missing the valence fix
3. **A residual-radical guard added** at 1%, in `descriptors.py`,
   `fingerprints.py` and `ingest_gna.py`. After the fix it is 0.000-0.013%
   against 38.2% without, which separates cleanly
4. **`py/ingest_gna.py` added.** 197 compounds. It verifies the scale agrees
   between tables on every run — 27 compounds are measured twice, with no
   disagreement
5. **`data/work/gna_feat/` rebuilt**, 146 rows to 129
6. **`py/coverage.py` added.** The nearest-neighbour criterion. Figures in
   section 4
7. **`tests/test_smiles.py` added**, 10 tests, pinning the three defects found

Introducing the parser turned up **three defects** in a verified fix sitting
in the scratchpad, and they were fixed (contraindications 29, 30, 38). Put in
as they were, CHAMP and IMI would have changed silently. The third was
invisible to a canonical-SMILES comparison and surfaced as one changed
InChIKey in the candidate output.

### The verification record

| data | effect of the fix |
|---|---|
| CHAMP | **features.parquet byte-identical.** The CV figures carry over unchanged |
| IMI-COMBINE | no change in canonical SMILES or InChIKey |
| B3DB | 5 rows changed, all legitimate restorations of an omitted hydrogen count. Effect on M1: 0.0010 |
| GramNegAccum | 66 hydrogens restored, 64 brackets fixed. 217 → 197 compounds |
| candidate output | **`candidates.json` identical to before.** Section 4's table carries over |

Take the no-op check on **both canonical SMILES and InChIKey.** SMILES alone
misses contraindication 38.

### Inclusion to the direction of transfer (`py/inclusion.py`) → **not supported**

**Section 3's main argument was at n=1, so it was tested against B3DB and
refuted on 2026-10-09.** The conclusion first.

| test | result |
|---|---|
| sign test, 3 unforced pairs, controls excluded | **2 of 3, P(≥2) = 0.50** |
| sign test, 3 forced pairs | **0 of 3 — every one reversed** |
| verdict test, ratio 3 or more | **0 of 3** (all 14 directions held; not one failure appeared) |
| Spearman: cov → CI lower bound, 8 unforced directions | rho = +0.548, p = 0.0855 |
| **Spearman: cov → CI lower bound, all 14** | **rho = +0.042** |
| **Spearman: rows evaluated → CI lower bound, all 14** | **rho = +0.526** |

**The rule is undecided, not refuted.** Two reasons.

**(a) Coverage and the number of rows evaluated cannot be separated.** The CI
lower bound is the point estimate minus a half width that contains 1/√n, so
"rows evaluated → CI lower bound = +0.526" follows almost by definition. It is
not a finding about transfer. Measured against the point estimate too:

| | rho(cov, AUC) | rho(rows, AUC) | **rho(cov, AUC \| rows)** | rho(rows, AUC \| cov) |
|---|---|---|---|---|
| all 14 | +0.086 | +0.482 | **+0.205** | +0.509 |
| 8 unforced | +0.548 | +0.548 | **+0.475** | +0.475 |
| 6 unforced, controls excluded | +0.429 | +0.714 | **+0.069** | +0.635 |

**That the three rows disagree is itself the result.** The partial correlation
swings **+0.069 to +0.475** depending on the subset — from "none" to
"moderate" — so **picking one row to report lets the choice make the
conclusion.** At n ≤ 14 they cannot be separated, which is the right
conclusion and stronger evidence than any single row.

**(b) The failures needed to discriminate never arrived.** **All 14
directions held**, CI lower bounds 0.6131 to 0.8457. The verdict test's 0 of 3
is not a failed prediction; there was not one failure to predict. **A test
whose outcome has no variance distinguishes nothing.** Every half of B3DB has
over 1,000 rows, so by construction no pair that could fail was built. This is
a limit of the verification design, not a refutation of the rule.

**rho = −0.504 for training rows is the same fact as +0.526 for evaluation
rows** — disjoint splits, so almost perfectly anticorrelated. Do not count
them as two independent pieces of evidence.

The clue was the three forced pairs coming out systematically reversed. A
direction with cov = 0% is always the one evaluating the wider side, so its
evaluation set is large. The CI's lower half width is set by the rows
evaluated (0.0331 at n=1,133, 0.0126 at n=5,853), so **the declared criterion
had become a criterion about power** (contraindication 43).

That invalidates the CHAMP/GNA verdict too (section 4). **Section 3's
mechanistic claim is withdrawn.**

What follows is kept as a record of the design.

B3DB's 7,805 rows were split into **seven disjoint pairs**, mutual coverage
measured without using labels or a model, and **which direction would fail was
declared before** transfer was measured in both.

| pair | A | B | cov(A→B) | cov(B→A) | ratio | cut on a box descriptor |
|---|---|---|---|---|---|---|
| random_halves (control) | 3902 | 3903 | 91.7% | 90.2% | 1.0 | no |
| scaffold_frequency | 4926 | 1133 | 34.4% | 83.0% | 2.4 | no |
| halogen | 5501 | 2304 | 86.0% | 56.7% | 1.5 | no |
| stereocentres | 1705 | 4400 | 46.1% | 27.1% | 1.7 | no |
| mw_band | 1969 | 5836 | 0.0% | 86.5% | ∞ | **yes** |
| tpsa_band | 1952 | 5853 | 0.0% | 79.1% | ∞ | **yes** |
| core_shell | 2341 | 2341 | 0.0% | 10.3% | ∞ | **yes** |

**The last column matters.** A set cut on an MW band has a box defined by MW,
so cov = 0% is not a measurement but **forced by construction.** The transfer
verdict is a real prediction, and the coverage predicting it becomes a
tautology. **The rule is tested by the top four pairs, not the bottom four** —
which is why splits outside the box's 9 descriptors (scaffold frequency,
halogen, stereocentres) were added.

The predictions are in `data/work/inclusion/predictions.json`, written
**before the engine was called even once.** Scoring is reported separately for
the top four and for all seven.

### How the procedure came about (there is no reason to hide it, so it is written)

1. It was first built with five pairs (random_halves, mw_band, tpsa_band,
   core_shell, scaffold_frequency)
2. At the point coverage was measured, **three pairs were found to have
   cov = 0% forced by construction**
3. **Transfer had not been run even once**, so two splits outside the box's 9
   descriptors were added, making seven, and the predictions were rewritten
4. Then transfer was run

**So the split design was changed after seeing coverage and before seeing
transfer.** After seeing transfer it would have been retrofitting, and that
order is the condition for it being sound. `predictions.json` keeps only the
final version, so the history exists only here.

One more. **The rank correlations were added after seeing 4 of the 14
directions**, so they are not a preregistered test. Only the sign test was
preregistered. The rank correlations are reported as analysis of this data.

The declared rule (`py/inclusion.py`'s docstring):
- **primary:** the direction with lower coverage has the lower CI bound (sign
  test)
- **secondary:** in pairs with a ratio of 3 or more, the low direction fails
  and the high one holds. Below 3, no verdict is predicted

**Do not mix the control (random_halves) into the sign test.** Calling the
direction on a 91.7% against 90.2% difference is a coin flip and would inflate
the hit rate. The control is used only to confirm that symmetric coverage
means both directions hold.

Unforced, excluding the control, is **3 pairs**. Even 3 of 3 is p = 1/8 =
12.5%, so **"verified" cannot be written.** M4 can say no more than
"consistent with the observation". The **rank correlation of (cov, CI lower
bound)** over the 8 unforced directions carries more information than a count
of binary hits.

**Always state the confounders.** If the failing direction is systematically
the one with a smaller training side or more skewed labels, the rule is
explained by that and not by inclusion. In CHAMP/GNA the larger side at 755
rows is the one that fails, so the sample-size explanation is ruled out
there; in the B3DB pairs it needs checking separately. The scoring table has
columns for training and evaluation row counts and positive rates.

The bootstrap count was lowered from 20,000 to 4,000. **A precision parameter,
not part of the declared criterion** — the evaluation sets are thousands of
rows rather than 129, so the CI is narrow enough. `auc_ci`'s default is now
resolved at call time.

### What to do next

1. **Rewrite M4 section 3 entirely.** Neither "it transfers" nor "it
   transfers in one direction only" is usable, because **both were written on
   a criterion that does not hold** — the rule was not shown false, it was not
   measured. **What remains is the power argument: transfer cannot be
   measured on public data.** At 129 rows the CI is 0.2 wide and neither
   direction can be decided. It connects to section 4's shortage of coverage,
   and is not made a mechanistic claim
2. **Compare transfer only with the evaluation rows matched**
   (contraindication 43). `py/transfer.py`'s criterion is a criterion about
   power. Either subsample the evaluation side down to the smaller, or report
   the point estimates and the overlap beside it
3. **Rewrite M4 section 7.** Not "more permeability data" but "permeability
   data in the region that overlaps antibacterials". **Do not name an
   institution as a data source until it has been fetched and its contents
   checked**
4. Stage three — an unmeasured library such as ZINC22 — is partly done: the
   screening path works and the fetch is one command. What has not been done
   is anything at 10^8 or beyond
5. Retry the Collins Lab Zenodo 21481938 download (waiting out a 403 IP
   block). **Neither its column layout nor its definition of active has been
   checked, so treat it as no more than a lead**

**RESOLVED: "there is still no first commit."** This section used to say 47
files were staged and the 633 build artefacts had been excluded by fixing
`.gitignore`. The repository has 44 commits and was published to
github.com/Escoffier1156/Occam on 2026-10-17.

### Figures withdrawn

- **CHAMP → GramNegAccum transfer, 0.6961 [0.5908, 0.7944]** → with the
  correct parse, 0.5944 [0.4933, 0.6921], failing under the declared criterion
- inside the applicability domain 42.1% / 54.4%, CHAMP alone 6.4% / 5.4% →
  replaced by `py/coverage.py`'s figures
- the old section 4's 33.8% / 20.2% / 88.3% (CHAMP alone, logit based) →
  unified onto the descriptor basis
- GramNegAccum at 217 compounds → 197

**Not withdrawn:** M1 0.8382 ± 0.0512 (reproduced with the epoch count
stated), all of the CV inside CHAMP (byte-identical), M0's memory, the binding
model.

### Open points

`py/coverage.py`'s covered is the AND of box and neighbour. The neighbour
threshold sits at the p95 of the nearest-neighbour distance inside the
training set, to make the criterion independent of dimensionality. **The
choice of p95 is itself arbitrary** and the figures move at p90 or p99. The
sensitivity was measured later and is in section 4.

---

## 9. M4 (one A4 page), the shape of it

The section structure is agreed. Drafts live outside this repository.

| section | | state |
|---|---|---|
| 1 | fixed memory (RSS −2.7% at 10,000x) | settled |
| 2 | why the permeability filter goes first | **must state that "it lowers cost" is unverified** |
| 3 | ~~transfer is set by inclusion in chemical space~~ | **withdrawn. The first draft's section 3 is unusable** (the criterion is confounded with power) |
| 4 | transfer cannot be measured on public permeability data | **second draft exists.** Section 3 folded into it |
| 5 | selecting features by in-distribution AUC kills transfer | settled (reproduces at 197 rows) |
| 6 | the output path that works, and its limits | settled (`candidates.json` identical to before the fix) |
| 7 | what is needed | **second draft exists.** Quantified to "about 800 compounds" |

### Sections 3 and 4 were joined by one mechanism

Instead of two independent observations side by side, they were written as
**two cross-sections of the same inclusion relation** — one from the
prediction side and one from the data side.

The grounds are three independent measurements pointing the same way (the
mutual coverage table in section 4). The third uses neither labels nor a
model, only descriptor space, so **which direction will fail can be predicted
before measuring any AUC.**

As a claim it is weaker than the old section 3's "it transfers", and
**stronger because it explains a mechanism.** It became a direct instance of
contraindication 19: transfer holding is not binary but a function of distance
in chemical space.

**Section 4's main argument changed.** CHAMP at 755 rows covers 0.6%;
GramNegAccum at 129 covers 22.7%. "Diversity, not row count" became a direct
number. (The per-row ratio that used to be quoted here is withdrawn: coverage
saturates against row count, so the division is invalid — contraindication in
section 4 under threshold sensitivity.)

### Reservations still standing

- GNA → CHAMP holding does not mean GNA → a library holds
  (contraindication 42)
- 0.6537 was measured over all 755 rows, a set that includes the 53.2% covered
- the p95 neighbour threshold is arbitrary

### Points still to fold into section 2 and the appendix

- section 2's "it lowers the overall evaluation cost" is unverified. With the
  budget matched, **the permeability-first path makes more evaluations**
  (N permeability evaluations against survivors × targets)
- the appendix needs a line reading "effect of the order swap: **unverified**;
  the measurement was affected by row order and is withdrawn"
- section 2's 40.1% is over the whole library, 22,052 rows. On the evaluation
  pool of 11,025 it is 39.6%

---

## 10. Working conventions

- comments in the code are **always English**
- `data/raw/` is never rewritten. Generated files go in `data/work/`
- if an invariant has to be broken, do not break it quietly — stop and give
  the reason
- **a number received from outside is not used until it has been measured
  here**
- declare the criterion before the run, as the transfer verification did
- when one of your own figures turns out invalid, withdraw it explicitly

### How to run the tests

**Always put the output in a file.** On 2026-10-09 an `errors=1` appeared
once, only stdout was being watched, the traceback was lost, and a rerun did
not reproduce it. An intermittent failure always matters later; make sure it
is still there next time.

```bash
nix-shell --run 'python3 -m unittest tests/test_memory_invariant.py tests/test_ingest.py \
    tests/test_descriptors.py tests/test_folds.py tests/test_smiles.py \
    tests/test_invariants_locked.py tests/test_render.py tests/test_request.py \
    tests/test_no_duplicated_counts.py tests/test_contraindications.py \
    tests/test_prompts.py tests/test_documented_procedures.py' 2>&1 | tee data/work/tests.log
nix-shell --run 'cd engine && cargo test --release -- --test-threads=1'
nix-shell --run 'OCCAM_FACTORS="1 10 100 1000" python3 -m unittest tests/test_memory_invariant.py'
nix-shell --run 'OCCAM_PROMPTS=1 python3 -m unittest tests/test_prompts.py'   # 27 minutes
```

237 Python and 11 Rust pass, plus 26 in the slow prompt layer. **Read the
skip count every time, not just the total** (contraindication 113).

---

## 11. Figures settled on 2026-10-09 (stage three and the assisting path)

### Memory: measured on two axes and confirmed on both (2,048 dimensions, real data, a million rows)

M0 was 9 descriptors over replicated synthetic data. This is real ZINC22 data
and 2,048-bit fingerprints.

**The B axis (data volume fixed, bulk varied 256-fold)**

| bulk | peak RSS | bulk, theoretical | fixed cost |
|---|---|---|---|
| 256 | 36.0 MiB | 2.0 | 34.0 |
| 1,024 | 42.0 MiB | 8.0 | 34.0 |
| 4,096 | 66.0 MiB | 32.0 | 34.0 |
| 16,384 | 161.8 MiB | 128.0 | 33.8 |
| 65,536 | 546.1 MiB | 512.0 | 34.1 |

**The D axis (bulk fixed at 256, data volume varied 62-fold)** — this is what
proves independence from D

| rows | peak RSS | against 16k |
|---|---|---|
| 16,384 | 36,224 KiB | baseline |
| 106,496 | 36,328 KiB | +0.29% |
| 1,007,616 | 37,164 KiB | +2.59% |

**The B axis alone cannot show independence from D** — it was written that
way once and corrected (contraindication 57). Two axes are needed.

**Breaking down the 34 MiB fixed cost** (no profiler; a control run varying
the column count)

| build | columns | peak RSS |
|---|---|---|
| descriptors, `target/release` | 9 | **3,044 KiB** |
| fingerprints, `target-fp/release` | 2048 | 36,224 KiB |

32.4 MiB over 2,039 columns is **16.3 KiB per column.** It is the parquet
column buffer: **proportional to the column count and not to the data
volume.**

```
peak RSS = base + columns × 16.3 KiB + bulk rows × columns × 4 B
```

All five points fit, with a constant residual of −1.3 to −1.6 MiB.

### Decomposing the 0.0540 residual: it was the model class

The prediction was **fixed before the run** in a file written at 21:53 against
a result at 22:03, checkable with `stat`. The same five folds
(`champ_butina/r0f0` to `r0f4`).

| condition | model | memory | mean AUC | CI95 |
|---|---|---|---|---|
| A | Occam, 54 dimensions, linear | O(1) | 0.8827 | [0.8524, 0.9033] |
| **C** | **streaming GBDT** | **O(1)** | **0.9347** | [0.9185, 0.9532] |
| B | sklearn HistGBT | all rows | 0.9346 | [0.9186, 0.9531] |

```
(C − A) gain from the model class  = +0.0520
(B − C) price of the memory bound  = −0.0001
```

**Fixed memory is not paying any AUC.** What pays is having chosen a linear
model. `py/stream_gbdt.py`'s fixed state is 2.03 MB — leaf histograms, bin
boundaries, quantile coarse bins — independent of row count.

**Reserved on scope:** at 755 rows the memory bound does not actually bind.
What was shown is algorithmic equivalence in bounded-memory form, not
equivalence at scale.

### Stage three: ZINC22

- **taken:** zinc-22x `H29P240-N`, a million rows (123 parts, one row group
  per part)
- MW median 403.6, maximum 596.2, **100% in 350-600**, parse failure rate
  **0.000%**
- **there is no header row** — contrary to the plan's description. Skipping
  it loses one molecule
- the heavy atom count is the directory's H number exactly. MW ≈ 13.9 ×
  heavy atoms
- **the 425 Da ceiling is specific to zinc-22g**, which the site marks "ZINC20
  in stock". Other generations reach higher
- **the largest generation cannot be fetched**: the site states the order is
  n, then x, then f, and `zinc-22n` returns 401. `2d/` and `2d-all/` are 401
  too
- **the protected generations' password is published on the page as a riddle
  and was not used.** The site states the protection exists to preserve the
  composition-of-matter patentability of never-synthesised molecules, which
  could conflict with publishing candidate structures. The decision is the
  owner's; it is recorded in `_searched.json`

### Sequential screening (`py/sequential.py`)

| stage | passing |
|---|---|
| MW<450 and charge 0 | 981,218 (18,781 too heavy, 1 charged) |
| rotatable ≤5 and an ionisable nitrogen | **25,310 (2.53%)** |
| group A, primary amine | **254** (a subset of group B) |
| the activity model (ECFP8, IMI's 22,051) | scored the 25,310. Guards passed: ties 0.028%, distinct 81.4% |
| scaffold stratification | 20,611 scaffolds → **256** |

**974,690 of 1,000,000 activity evaluations avoided.** The rule verdict still
needs one pass over everything (1,669 s against 137 s for the activity
evaluation). At this scale the total also falls, 1,669 against about 5,400 s.
**This is where M4 section 9's "lowering cost is unverified" got a number.**

**All 256 are outside the training range.** Nearest Tanimoto to the training
side's 22,051 is a median of 0.165 and **a maximum of 0.285.** Stage one,
inside IMI, failed as a reproduction of the known; stage three is new and
extrapolating. **On public data, producing new candidates and being able to
believe them do not hold at the same time.**

### The assisting path (six modules, new that day)

See section 0.5 for the current inventory. At the time of this record:
`inventory.py`, `feasible.py`, `knobs.py`, `sweep.py`, `propose.py`,
`occam.py`.

**HLL:** 4,096 registers, 4 KB per specification. The error quoted here as
"0.29 to 1.24% measured" **was not a measurement** — see contraindication 103.
Re-measured over 30 seeds and 6 cardinalities it is 0.06% to 5.87%, and the
theoretical value is 1.04/√4096 = 1.63%. **It is not used for a verdict**: a
coarse filter only, with the frontier counted exactly in a second pass.

**The sweep, measured over a million rows:** 54 specifications, one pass,
2,374 s, state **224,208 B** (4,152 B per specification), independent of row
count. **That was measured at 54, before the charge knob was retired. It has
not been re-measured at 27, so read the number as 54's.**

**The proposal over a million rows** (asking for 256 scaffolds)

```
as asked (primary_amine + rotb≤5 + MW<450 + neutral): 254 survive, ~199 scaffolds -> not possible
recommended: one step to rotb≤7                      : 744 survive, ~536 scaffolds -> possible
```

On a 50,000 sample the recommendation had been "two steps to basic_nitrogen".
**Change the population and the proposal changes.**

**What `occam.py` stopped** (measured on prose input)

| input | treated as |
|---|---|
| `transglycosylase` | checked against the evidence → **not_answerable** |
| `100-million-item`, `0.071 auc`, `7,394 domains` | **factual claims. Not accepted as input** |
| `pre-packed`, `verified` | claims about verification status → not accepted |
| `rotatable at most 6`, `MW under 500` | **unregistered. Offers [5,7,9] / [450,600] and stops. No rounding** |

### A by-product of building the registry

**eNTRy was being applied with two of its three conditions.** The second,
globularity ≤ 0.25, needs a 3D conformer and this pipeline generates none. It
is stated in `knobs.BLOCKED`. **Until that day it was written in no
document.**

### A scaffold filter in the Carry (designed, not implemented)

Needed once post-processing becomes impossible at 10^9. At that point **adding
one u64 scaffold hash to each top-K slot** is enough — 200 B fixed at K=25.
There is no need to remember the whole history: a scaffold pushed out has
already been judged not to belong at the top, so making it compete again on
reappearance is the right behaviour.

**Not implemented now.** Touching a locked region for a scale that has not
been reached is the wrong order.

---

## 12. 2026-10-10: yesterday's candidate output is void. Cause and fix

### The conclusion first

**The 256 candidates of 2026-10-09 and the proposal to relax to `rotb≤7` are
withdrawn.** The library slice was wrong, and **the request could be met with
no relaxation at all.**

| slice | rows | surviving as asked | scaffolds | reaches 256 |
|---|---|---|---|---|
| **−N (what was used)** | 1,000,000 | 254 (0.025%) | ~199 | **no** |
| **−O (what was discarded)** | 636,669 | **4,288 (0.674%)** | **~1,624** | **yes** |
| −P (also discarded) | 17,775 | 430 (2.419%) | ~187 | no |

**27x** in survival rate. `−O` has 64% of `−N`'s rows and **17x** the
survivors.

Keeping the primary amine — not relaxing `nitrogen`, going to `rotb≤9 +
MW<600` — all three slices reach it: 735 scaffolds for −N, **4,758 for −O**,
714 for −P.

### The cause: misreading ZINC's charge suffix

**`−N` / `−O` / `−M` / `−P` are the predicted protonation state at pH 7.4,
not the formal charge as drawn.**

Measured on zinc-22x H29P240, 20,000 per slice:

| slice | primary amine | basic N |
|---|---|---|
| −N | 0.21% | 9.74% |
| −O (+1) | **2.46%** | 94.96% |
| −M (−1) | 0.04% | 4.66% |
| −P (+2 or more) | **13.06%** | 100% |

**The formal-charge column was removed from this table.** The original values
(`−O 19,971/20,000`, `−M 19,995/20,000`, and "all zero" for `−N` and `−P`)
record neither a seed nor the extent of the pool and **cannot be reproduced.**
The reproducible re-measurement of 2026-10-11 is in section 4. **The two
columns above are left as that day's measurement** — they have not been
re-measured, so they are not touched.

**Nearly every slice's SMILES are written neutral**, so the `charge` knob does
not engage with the predicted protonation state. But **"it filters nothing"
was wrong**: 23 of 20,000 in `−O`'s sample are drawn at +1. The knob was
retired on 2026-10-11, **not because it was inert but because it measured a
different quantity** (`RETIRED['charge']` in `py/knobs.py`).

Richter 2017: 12 of 41 positively charged compounds accumulate, against
**0 of 39** neutral and **0 of 20** negative. **`−N` was the group eNTRy says
does not accumulate.**

### The real bug was that there was no check

The slice is an input that decides the result, and **it existed in no
specification, no record and no check.**

```
feasible.py  exits cleanly
sweep.py     exits cleanly
propose.py   exits cleanly
occam.py     exits cleanly
-> everything passes and only the answer is wrong
```

**And the evidence was printed in yesterday's output.** Twenty-seven pairs of
specifications differing only in `charge` had identical survivor counts in all
27. It was read past.

### The fix: `py/provenance.py` (new)

Three things automated, run by `occam.py` before anything else.

| | |
|---|---|
| **identify** | reads the slice from the library's own `parts.json` and puts it in the request's echo |
| **contradiction** | checks the slice against the published rule. `−N` plus an ionisable nitrogen → **stop** |
| **inert** | detects a knob that changes no survivor count. `charge` was identical in 27 of 27 on that run (the knob was retired 2026-10-11; see section 4) |

Yesterday's request now stops before running:

```
[contradiction] the request asks for an ionisable nitrogen, which is the first
                eNTRy condition, but the library is the slice predicted to be
                neutral at pH 7.4
stopping: the library contradicts the published rule the request is built on.
```

**The provenance had been broken by renaming the file**
(`H29P240-N.x.smi.gz` → `x_H29P240-N.smi.gz`, dropping the generation letter).
The regex now accepts both forms, and **do not rename ZINC's files** is
written in the code.

### globularity implemented (`py/globularity.py`) → inert on this library

eNTRy went from **2 of 3 to 3 of 3**. The definition is Richter 2017's: the
inverse condition number of the covariance matrix of the atomic coordinates.

**The two definitional anchors match exactly:** benzene 0.000 (reported 0.00)
and adamantane 1.000 (reported 1.00). Two drugs are within the conformer
spread: ampicillin 0.143 (reported 0.12, spread 0.086) and penicillin G 0.113
(reported 0.17, spread 0.020). **Both agree on pass/fail against the 0.25
threshold.**

**But the third condition filters nothing on this library.**

| | median | p95 | max | at or below 0.25 |
|---|---|---|---|---|
| the 256 candidates | 0.071 | 0.132 | 0.218 | 100% |
| 300 random library rows | 0.075 | 0.173 | 0.247 | **100%** |

ZINC22 H29 is mostly flat molecules containing aromatic rings, with almost
nothing spherical (globularity 1). Richter's 68 compounds include one at 0.49,
so **their set did contain spherical molecules.**

**The spread from conformer choice is a median of 0.033 and up to 0.236.**
The maximum is comparable to the 0.25 threshold, so **near the threshold the
verdict depends on which conformer is picked.** Here everything passed with
margin, so there was no effect.

### Literature search: no Gram-negative-specific threshold could be obtained

| sought | result |
|---|---|
| logP / TPSA / HBD / HBA thresholds | **not in peer-reviewed primary sources** |
| MW 414 Da, clogP −0.1 | **means, not thresholds.** Available only in secondary summaries, and the signs disagree |
| TPSA > 65.68, LogD < 1.793 | an Optibrium **poster** — not peer reviewed, 80 compounds, StarDrop proprietary descriptors, a different quantity from RDKit's |
| HBD / HBA | Gram-negative-specific values exist **nowhere.** Only Lipinski's general ones |

**Only one thing could be registered:** `mw_under_600`'s provenance was
corrected from "added by this study" to **`published (secondary: verbatim
quote in Richter 2017)`**, stating that it comes through a secondary source —
the same standard just applied in rejecting 414 Da for being secondary.

**Two findings came out instead:**

1. **Richter 2017 itself denies molecular weight.** Verbatim: "there is also
   no correlation between accumulation and molecular weight", and
   "accumulation does not increase with lower ClogD7.4". **`weight` is not a
   permeability knob.** Measured here it agrees: 450 → 600 is 1.1x against
   2.8x for rotatable bonds. A `caution` was added to `knobs.py`
2. **globularity's definition was obtained**, so it could be implemented

### Checked and found harmless (recorded)

**Sampling bias from `--limit 1000000`.** ZINC's files are sorted
alphabetically by SMILES, so the first million — 22% of all 4.57 million —
could be structurally skewed.

| set | primary amine | basic N | aromatic rings | median MW |
|---|---|---|---|---|
| sampled from the first million | 0.18% | 9.10% | 1.25 | 403.6 |
| sampled from all 4.57 million | 0.12% | 9.22% | 1.24 | 404.4 |

Basic N, aromatic rings and MW **agree within 1%.** The tranche is already
homogeneous — heavy atoms fixed at 29, a narrow logP band — so the sort order
does not skew structure.

**But the primary-amine comparison is underpowered.** At 4,000 samples, 0.18%
is 7 molecules and 0.12% is 5, which cannot distinguish a 1.5x difference. It
is group A's selector, so nothing is asserted.

### Confirmed unaffected

**The memory measurements and the residual decomposition (section 11) are
unaffected.** They are about row and column counts and are independent of
which molecules are selected.

---

## 13. 2026-10-10, later: correcting course toward the assisting role

### What was wrong

**The goal is the assisting role — holds / does not hold / what instead — and
the work had drifted into candidate generation.** Two sessions over two days,
75 minutes, spent generating molecule lists. Nobody asked for them.

Three causes, in the order they mattered rather than the order they are cheap.

1. **The gravity of the code.** `sequential.py` and `candidates.py` exist only
   to make candidate lists and were the easiest thing to run. Existing
   machinery attracts the work
2. **The document.** Section 3's stages still said "stage three: new compounds
   come out"
3. **A candidate list looks like an artefact.** `verdict: feasible` looks like
   nothing happened. **The work drifted toward the thing that looks
   impressive.** This is the real reason

### The fix: print all three pillars

| pillar | implementation | before |
|---|---|---|
| **what holds** | `verdict: feasible, 0 step(s) looser` | present |
| **what does not** | `[not_answerable]` with the reason | present |
| **what instead** | **`suggested_revisions` (new)** | **not on the screen** |

The third is the substance and it was missing. It comes from measurement, and
the constraint of **not inventing chemistry** is kept.

| verdict | where the revision comes from |
|---|---|
| a target is `not_answerable` | the resolution the evidence has, with counts, from the inventory: four organism classes and pMIC |
| ranking is `not_answerable` | measure distinct counts on each frontier specification and show which clears the floor |
| activity is `extrapolating` | **measure the nearest neighbour against every training set on hand** and name the closest |

Measured, against ZINC −P:

```
IMI-COMBINE (activity, 22,051)   nearest median 0.183  at or above 0.4: 0.0%
CHAMP (permeability, 1,132)      nearest median 0.156  at or above 0.4: 0.0%
GramNegAccum (permeability, 197) nearest median 0.131  at or above 0.4: 0.0%
-> none reaches. The revision is data, not a setting
```

### `py/screenable.py` (new): measurements buried in candidate generation became verdicts

Two measurements had been **gates applied after a molecule list came out.**
They were separated into verdicts of their own.

| verdict | |
|---|---|
| **rankability** | can the activity model order this set (the distinct share) |
| **applicability** | is it inside the training range (nearest Tanimoto) |
| reported alongside | **which label it was trained on** (`binding` = gram-positive) |

Decided on a sample, 1,200 by default with a fixed seed. Scoring all 4,288
takes 12 minutes, and at 47% distinct over 1,000 rows "it cannot be ordered"
can already be said. (The sampling was later measured and removed — see
contraindication 91. It bought no time at all.)

### Every expensive verdict got a positive control

**`[INERT]` and `0.0%` are values a broken computation also produces.** They
were being asserted with no control.

| control | expectation | measured | verdict |
|---|---|---|---|
| **Tanimoto** | holding IMI out, its nearest neighbour to itself should be high | **median 0.747, 94.0% at or above 0.4** | **pass** |
| **globularity** | should correlate with GramNegAccum's published `glob` column, 68 rows | **range 0.037-0.343** against a published 0.046-0.450, r = 0.529, threshold verdicts agreeing 82.4% | **the range passes** |

**Both refuted the hypothesis that the computation is broken.** With the
controls passing, "it needs data, not a setting" can be said. Before them it
could not.

**globularity's limits, stated:** r = 0.529, and 12 of 68 disagree at the
threshold. Conformer choice moves it by up to 0.236. **An individual
molecule's value is not trustworthy. Use it on distributions only.**

**And the published `glob` column itself has 55 of 68 — 81% — at or below
0.25.** The condition passes 81% even in the data it was derived from. The
100% in ZINC is the same direction, further out. **The `[INERT]` verdict is
supported by the paper's own data and not only by this implementation.**

### Candidate generation demoted

`py/sequential.py` and `py/candidates.py`:

- the docstring opens with **NOT THE PRODUCT**, the reason they are kept
  (section 4's figures and a KeepOut lock), and the reason for the guard (an
  assistant ran them unbidden twice on 2026-10-10)
- **they stop without `--emit-molecules`**
- the entry point (`occam.py`) cannot call them

### The scope of a count made explicit

Two numbers, 8,601 and 17,530, appeared for the same label in different
outputs. **They were different scopes.**

```
8,601   imi_clean.parquet, the 22,051 rows labelled on both axes  <- what the model trained on
17,530  all sources, combined_bioassay_data.tsv, 74,202 rows
```

### The source of a threshold put in the output

The 0.4 nearest Tanimoto is **the lenient end of the 0.4-to-0.6 applicability-
domain convention.** It was not derived. The threshold's value and its source
go beside the verdict.

---

*Translated from Japanese on 2026-10-17, when `docs/` was made private and
this file moved to the repository root. Statements that had become false were
corrected rather than carried over, and each correction says so: the patent
priority in section 0, the missing documents in section 0.5, KeepOut's
undeclared licence in section 1, the absent first commit in section 8, and
every line count and test count throughout.*

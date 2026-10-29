# Occam in a container.
#
# WHY A CONTAINER AND NOT A WHEEL
#
# The engine is Rust and the chemistry is RDKit. A wheel would have to be
# built per platform and per Python version, and RDKit would still come from
# pip or conda afterwards, so hiding the Rust does not remove the questions
# about the environment -- it adds a build matrix to maintain for one person.
# One image has no matrix.
#
# WHAT IS INSIDE, AND WHAT IS NOT
#
# The four measured datasets this tool answers from are here: CHAMP,
# GramNegAccum, B3DB and IMI-COMBINE, with the fitted features. 5.5 MB, all
# CC BY, CC0 or MIT, cited in data/raw/*/manifest.json.
#
# ZINC22 is not. Its terms permit screening and the sharing of screening
# results and require written permission to redistribute large portions, so
# the slices are fetched, not shipped. Mount them when you want them:
#
#     docker run --rm -v "$PWD/zinc:/occam/data/work" occam "500 distinct ..."
#
# Without them every request naming CHAMP, IMI, GramNegAccum or B3DB works,
# which is enough to see what the tool says and how it says it. Verified by
# running with the ZINC slices removed.

# THE BASE IMAGES ARE PINNED BY DIGEST, AND WERE NOT
#
# This file pins rdkit, pyarrow, numpy and hypothesis to exact versions, and
# then said FROM rust:1-slim and FROM python:3.14-slim -- a tag that floats
# across the whole Rust 1.x line and one that floats across Python patch
# releases. So the careful pinning below sat on a foundation that moved.
#
# It moved. Two builds from this file on the same day, 2026-10-16, came out at
# 557 MB and 633 MB. The unpinned bases are enough to explain 76 MB and the
# cause was not proven -- no digest from the first build was recorded, which
# is the other half of the same fault. The README had "about 560 MB" on its
# outward face, wrong by 13%, and that is what the provenance audit found.
#
# To update a base: pull the new tag, read its digest with
# `podman images --digests`, put it here, rebuild, and record the new size.
# Updating by deleting the digest is not updating, it is unpinning.
#
# WHAT THIS FILE BUILT, SO THE NEXT BUILD HAS SOMETHING TO DIFFER FROM
#
#   2026-10-16, from the two digests below, at commit a022276:
#     image id    sha256:a90a42aee1e9437ee73efa5f6646f11b67753d1b25946778caf064220f28106c
#     size        633,073,511 bytes (633 MB as podman reports it)
#
# Recorded because the layer store is temporary and gets deleted, and the
# first build's result was not recorded -- which is why "about 560 MB" sat on
# the README unverifiable, and why the 76 MB it was wrong by could be
# explained but not proven. A build that comes out at a different id is a
# different image; one at a different size with these digests unchanged is
# something to look into.
FROM docker.io/library/rust:1-slim@sha256:a1084bb57647249d08434a20058831537a49b7af2d109d2925a7a02b4ba6e4dc AS engine
WORKDIR /build
COPY engine/ engine/
# Three builds: the product invokes target-fp, and the other two are what the
# memory-invariant test measures. HANDOFF.md has the table.
RUN cd engine \
 && cargo build --release --quiet \
 && cargo build --release --quiet --features linear --target-dir target-lin \
 && cargo build --release --quiet --features fingerprint --target-dir target-fp \
 && find . -name engine -type f -path '*/release/*' -exec ls -la {} +

FROM docker.io/library/python:3.14-slim@sha256:a2b82f3c48559aa0a8446d9af49826b6e2b2016f4cd2afabfe6013ec53729170
LABEL org.opencontainers.image.title="Occam"
LABEL org.opencontainers.image.description="A screening feasibility checkpoint for Gram-negative accumulation: what holds, what does not, and what to do about the part that does not. It emits no molecules."
LABEL org.opencontainers.image.licenses="Apache-2.0"
LABEL org.opencontainers.image.source="https://github.com/Shogo256/Occam"

# Pinned to what shell.nix actually provides, read from the running
# interpreter rather than guessed: an image built against different versions
# is not the thing the tests passed on. hypothesis is here because the
# property tests are part of what a reader should be able to run.
RUN pip install --no-cache-dir \
      rdkit==2025.3.6 \
      pyarrow==24.0.0 \
      numpy==2.5.0 \
      hypothesis==6.151.10

WORKDIR /occam

# The version this image was built from. An image carries no history to ask,
# and the run has to say which version produced a result -- the line that did
# that shelled out to git and crashed here, where there is neither a .git nor
# a git binary.
#
#     podman build --build-arg OCCAM_VERSION="$(git describe --always --dirty --abbrev=10)" ...
ARG OCCAM_VERSION=unknown
RUN printf '%s\n' "$OCCAM_VERSION" > /occam/VERSION

COPY py/ py/
COPY occam LICENSE NOTICE ./
COPY HANDOFF.md ./
COPY tests/ tests/
COPY third_party/ third_party/
COPY keepout.json ./

# The declarations that say which artefact is evidence. Without them the
# inventory is empty and a question about a named target cannot be resolved.
COPY data/raw/ data/raw/

# The measured sets, and the features the activity model was fitted on.
COPY data/work/champ.parquet data/work/gna.parquet \
     data/work/imi_clean.parquet data/work/B3DB_classification.parquet \
     data/work/
COPY data/work/imi_fp/ data/work/imi_fp/

COPY --from=engine /build/engine/target/release/engine engine/target/release/engine
COPY --from=engine /build/engine/target-lin/release/engine engine/target-lin/release/engine
COPY --from=engine /build/engine/target-fp/release/engine engine/target-fp/release/engine

ENTRYPOINT ["python3", "/occam/py/occam.py"]
CMD ["--help"]

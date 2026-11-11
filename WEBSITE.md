# Automatic vignette publishing

The root workflow `.github/workflows/vignettes-pages.yaml` checks pull requests
and builds and publishes pushes to `main`. It also supports a manual run from
the Actions tab. Stereo-seq, Visium, Getting Started, PerturbSeq, CosMx and
Stored models are rebuilt from fresh results, and BridgeAnnotation and CITE-seq are rebuilt from
verified cached results. The two package vignettes (`vignettes/PhiSpace.Rmd`
and `vignettes/PhiSpaceST.Rmd`) are built by `scripts/build-package-vignettes.R`
from Bioconductor data that they download; R CMD check builds them too. The
first build script creates the staged site with
`pkgdown::init_site()`, which copies the shared assets, favicons and logo; the
repository does not commit a built website. The function reference
(`reference/`) is then rebuilt from `man/` by `scripts/build-reference.R`. The
home page (`index.html`), the authors and citation page (`authors.html`) and
`404.html` are rebuilt from `README.md`, `DESCRIPTION` and `inst/CITATION` by
`scripts/build-home.R`, which fails if either page lacks a DOI from
`inst/CITATION`. The same script rebuilds the articles index
(`articles/index.html`) from `_pkgdown.yml` and fails if an article in
`_pkgdown.yml` was not built. It removes the pages that pkgdown renders
from the repository notes (`AGENTS.md`, `CLAUDE.md`, this file) and then writes
`sitemap.xml` from all staged pages, so it must run last. The site uses
Bootstrap 3 and has no search index.

The website build files (`scripts/`, `.github/`, this file) are excluded from
the package by `.Rbuildignore`. Build outputs go to `Test/` and `docs/`, which
are ignored by git and by the package build.

A second workflow, `.github/workflows/R-CMD-check.yaml` (**R CMD check**), runs
`R CMD check --no-manual --ignore-vignettes` on the same pushes and pull
requests and fails on warnings. It does not deploy anything.

Both workflows cancel a running build when a newer commit reaches the same
branch, so only the newest push deploys.

## One-time GitHub setup

After these files are pushed, select **Settings → Pages → Build and deployment
→ Source → GitHub Actions**. The workflow uses GitHub's built-in token, with
deployment permissions only in the deployment job. No personal token is needed
as a workflow secret. Pull requests build a downloadable website artifact but
do not deploy. A failed build leaves the previous deployment in place.

## Build locally

From the repository root, with R 4.5 or later and Pandoc available, install the
package dependencies plus the R packages listed in the workflow. pkgdown 2.2.0
is installed from its explicit CRAN archive URL to match the existing website
assets. Both vignettes use `qs2` from the active CRAN repository; the archived
`qs` package is not required. Dependency resolution has been checked locally.
Then run:

```bash
export PHISPACE_SITE_DIR=Test/site-vignettes
Rscript --vanilla scripts/build-stereoseq.R
Rscript --vanilla scripts/build-visium.R
Rscript --vanilla scripts/build-bridge-annotation.R
Rscript --vanilla scripts/build-getting-started.R
Rscript --vanilla scripts/build-cite-seq.R
Rscript --vanilla scripts/build-perturbseq.R
Rscript --vanilla scripts/build-cosmx.R
Rscript --vanilla scripts/build-cosmx-multisample.R
Rscript --vanilla scripts/build-stored-models.R
Rscript --vanilla scripts/build-package-vignettes.R
Rscript --vanilla scripts/build-reference.R
Rscript --vanilla scripts/build-home.R
```

The Stored models script (`StoredModels.Rmd`) has no data folder of its own:
it verifies the CosMx inputs (`scripts/cosmx-inputs.tsv`, cache
`Test/cosmx-inputs`) and stages the four lung fibrosis references and
Lung5_Rep1. It trains its models in every build (about 2.5 minutes and 9 GB
locally).

The Stereo-seq script downloads the public archive, extracts only five required
inputs, and checks their SHA-256 hashes. These include the helper R script and
precomputed bridge annotations. It creates fresh analysis outputs on every run.
Visium downloads its public folder archive, extracts four verified inputs (about
1.6 GB), and checks their SHA-256 hashes. Both scripts recompute the analyses
shown in their vignettes. The input caches are `Test/stereoseq-inputs` and
`Test/visium-inputs`; the combined website is written to `Test/site-vignettes`.
Each article includes a session information file in the website artifact.
After rendering, each build script checks summaries of the fresh outputs
against `scripts/<slug>-results.tsv` with `scripts/check-results.R`, and fails if
they differ. Set `PHISPACE_RESULTS_OUT` to a file path to save the observed values.
Stereo-seq requires a new site directory, so it must run first; the other
scripts, including the reference build, append to it without replacing earlier
pages. Separate R processes release memory between articles.
For another full build, choose a new destination:

```bash
export PHISPACE_SITE_DIR=Test/site-vignettes-next
Rscript --vanilla scripts/build-stereoseq.R
Rscript --vanilla scripts/build-visium.R
Rscript --vanilla scripts/build-bridge-annotation.R
Rscript --vanilla scripts/build-getting-started.R
Rscript --vanilla scripts/build-cite-seq.R
Rscript --vanilla scripts/build-perturbseq.R
Rscript --vanilla scripts/build-cosmx.R
Rscript --vanilla scripts/build-cosmx-multisample.R
Rscript --vanilla scripts/build-stored-models.R
Rscript --vanilla scripts/build-package-vignettes.R
Rscript --vanilla scripts/build-reference.R
Rscript --vanilla scripts/build-home.R
```

Optional variables:

- `PHISPACE_STEREOSEQ_ARCHIVE`: an existing ZIP file to use instead of downloading.
- `PHISPACE_STEREOSEQ_INPUTS`: an alternative verified input-cache directory.
- `PHISPACE_VISIUM_INPUTS`: an alternative verified Visium input-cache directory.
- `PHISPACE_VISIUM_ARCHIVE`: an existing Visium ZIP file to use instead of downloading.
- `PHISPACE_SITE_DIR`: a new directory for the staged website.
- `PHISPACE_BRIDGE_ANNOTATION_INPUTS` and `PHISPACE_BRIDGE_ANNOTATION_ARCHIVE`:
  the BridgeAnnotation input cache (8 inputs and 3 cached results, about
  1.6 GB) and an existing ZIP file to use instead of downloading.
- `PHISPACE_BRIDGE_ANNOTATION_MODE`: `cached` (default) renders BridgeAnnotation
  from the verified results in its shared folder; `fresh` recomputes them. A
  fresh build peaks at 17 to 24 GB RAM, above the GitHub runner limit, so
  Actions uses `cached`. Run `fresh` locally before changing its cached files or
  expected values.
- `PHISPACE_CITE_SEQ_INPUTS`, `PHISPACE_CITE_SEQ_ARCHIVE` and
  `PHISPACE_CITE_SEQ_MODE`: the same roles for CITE-seq (7 inputs and 5 cached
  results, about 2.1 GB). Its fresh build peaks at about 65 GB RAM.
- `PHISPACE_PERTURBSEQ_INPUTS`, `PHISPACE_PERTURBSEQ_ARCHIVE` and
  `PHISPACE_PERTURBSEQ_MODE`: the same roles for PerturbSeq (3 inputs and 1
  cached score matrix, about 1.15 GB). Its default mode is `fresh`.
- `PHISPACE_COSMX_INPUTS`, `PHISPACE_COSMX_ARCHIVE` and `PHISPACE_COSMX_MODE`:
  the same roles for CosMx (14 inputs and 2 cached results, about 0.9 GB).
  Its default mode is `fresh`.
- `PHISPACE_STEREOSEQ_DATA`: the extracted data folder when running the vignette
  directly. The automation sets this to a fresh temporary analysis directory.
- `PHISPACE_VISIUM_DATA`: the data folder when running Visium directly.
  The Visium build script also uses a fresh temporary analysis directory.
- `PHISPACE_GETTING_STARTED_INPUTS`, `PHISPACE_GETTING_STARTED_ARCHIVE` and
  `PHISPACE_GETTING_STARTED_DATA`: the same roles for Getting Started. Its three
  inputs are about 210 MB; the input cache is `Test/getting-started-inputs`.

For a Visium-only build, run `Rscript --vanilla scripts/build-visium.R`; without
`PHISPACE_SITE_DIR`, it creates a new staged site in `Test/site-visium` that
contains only the Visium article.

If upstream inputs change, checksum verification fails. Review those changes
before updating the relevant `scripts/*-inputs.tsv`; changing a manifest also
changes the Actions data-cache key. Computed analysis outputs are never cached.

## Multi-sample CosMx workshop article

`CosMxMultiSample` is a separate website article in `vignettes/articles/`.
Its inputs are pinned to workshop commit
`49debcb8f7426825d4f2b0f193d7647199071f80` (`mig2025`), not the current
workshop package. `scripts/prepare-cosmx-multisample.R` downloads only the four
manifest-listed RDA files (about 235 MB), verifies SHA-256, and converts them
to checksum-validated qs2 with an identical-object round trip. A conversion
record checks both source-manifest and derived-file hashes on later runs.
Actions caches these verified inputs and conversions, never the newly
computed clustering. No new Dropbox upload is required.

`scripts/build-cosmx-multisample.R` defaults to `fresh`: it recomputes spatial
smoothing, joint clustering and its comparison with the saved workshop
partition. Both modes use the saved workshop memberships for the downstream
scientific example, and recompute signatures, correlations, PCA and DWD.
The objects contain precomputed five-reference scores, not expression data;
this is not a fresh reference fit. See
`scripts/cosmx-multisample-validation.md` for the compatibility decisions.

- `PHISPACE_COSMX_MULTISAMPLE_INPUTS`: raw and converted input cache.
- `PHISPACE_COSMX_MULTISAMPLE_DATA`: prepared data folder for a direct render.
- `PHISPACE_COSMX_MULTISAMPLE_RUN_DIR`: a new, empty analysis-directory path;
  the build creates it. Use this to retain fresh results for a cached check.
- `PHISPACE_COSMX_MULTISAMPLE_MODE`: `fresh` (default) or `cached`.
- `PHISPACE_COSMX_MULTISAMPLE_RESULTS`: required in cached mode; points to a
  fresh build's `output/`, containing `joint-clusters.qs2` and
  `joint-clusters.sha256`. The hash is checked before staging, and the build
  fails if the result is rewritten. Downstream computations still run.

For local work, put these caches, analysis directories and staged sites
outside the repository. Run `scripts/validate-cosmx-multisample.R` separately
to repeat the historical PCA/random-state comparison; it is not required by
the publishing workflow.

## Check deployment

In Actions, confirm that `build` and `deploy` of **Build and publish vignettes**
and the **R CMD check** job succeed. Open the changed live articles and
reference pages. Download the `vignette-website` artifact to inspect the
complete staged website if needed.

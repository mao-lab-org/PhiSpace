# Fresh means downstream analysis from the verified workshop scores, not
# retraining PhiSpace: the workshop objects do not contain expression data.
mode <- Sys.getenv("PHISPACE_COSMX_MULTISAMPLE_MODE", "fresh")
if (!mode %in% c("fresh", "cached")) stop("Mode must be 'fresh' or 'cached'.")
source("scripts/prepare-cosmx-multisample.R", local = TRUE)
site_dir <- Sys.getenv("PHISPACE_SITE_DIR", "Test/site-cosmx-multisample")
if (!dir.exists(site_dir)) {
  pkgdown::init_site(pkg = ".", override = list(destination = site_dir))
} else if (!file.exists(file.path(site_dir, "pkgdown.yml"))) {
  stop("Existing destination is not a staged pkgdown website: ", site_dir)
}
site_dir <- normalizePath(site_dir, winslash = "/")
run_dir <- Sys.getenv("PHISPACE_COSMX_MULTISAMPLE_RUN_DIR", tempfile("cosmx-multisample-run-"))
if (dir.exists(run_dir)) stop("Use a new analysis directory: ", run_dir)
dir.create(run_dir, recursive = TRUE)
if (!all(file.copy(converted, run_dir))) stop("Could not stage converted inputs.")
dir.create(file.path(run_dir, "output"))
cluster_path <- file.path(run_dir, "output", "joint-clusters.qs2")
if (mode == "cached") {
  results_dir <- Sys.getenv("PHISPACE_COSMX_MULTISAMPLE_RESULTS")
  if (!nzchar(results_dir)) stop("Cached mode requires PHISPACE_COSMX_MULTISAMPLE_RESULTS.")
  saved_cluster <- file.path(results_dir, "joint-clusters.qs2")
  saved_hash <- file.path(results_dir, "joint-clusters.sha256")
  if (!file.exists(saved_cluster) || !file.exists(saved_hash) ||
      !identical(sha256(saved_cluster), readLines(saved_hash, warn = FALSE))) {
    stop("Cached clustering is missing or its checksum does not match.")
  }
  if (!file.copy(saved_cluster, cluster_path)) stop("Could not stage cached clustering.")
  cached_hash <- sha256(cluster_path)
}
Sys.setenv(PHISPACE_COSMX_MULTISAMPLE_DATA = normalizePath(run_dir, winslash = "/"))
pkgload::load_all(".", quiet = TRUE)
pkgdown::build_article(
  "articles/CosMxMultiSample", pkg = ".", lazy = FALSE, new_process = FALSE,
  override = list(destination = site_dir), quiet = FALSE
)
article <- file.path(site_dir, "articles", "CosMxMultiSample.html")
html <- paste(readLines(article, warn = FALSE), collapse = "\n")
if (grepl("Dropbox/Research_projects", html, fixed = TRUE) ||
    !grepl("350,228", html, fixed = TRUE) || !grepl("historical_ari", html, fixed = TRUE)) {
  stop("Rendered article is missing expected content or contains a private path.")
}
if (mode == "cached" && !identical(cached_hash, sha256(cluster_path))) {
  stop("The cached build rewrote the verified clustering.")
}
writeLines(sha256(cluster_path), file.path(run_dir, "output", "joint-clusters.sha256"))
source("scripts/check-results.R", local = TRUE)
check_results("CosMxMultiSample", file.path(run_dir, "output"), slug = "cosmx-multisample")
writeLines(capture.output(sessionInfo()), file.path(site_dir, "CosMxMultiSample-sessionInfo.txt"))
message("Built CosMx multi-sample (", mode, "): ", article,
        "\nAnalysis directory: ", normalizePath(run_dir))

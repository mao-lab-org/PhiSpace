# Run from the repository root. Recover only four immutable workshop inputs;
# the current workshop package no longer ships them. RDA is read once for
# conversion; the article reads checksum-validated qs2 files only.
source_commit <- "49debcb8f7426825d4f2b0f193d7647199071f80"
source_url <- paste0("https://raw.githubusercontent.com/bhuvad/",
                     "CosMxSpatialAnalysisWorkshop/", source_commit, "/data/")
manifest <- read.delim("scripts/cosmx-multisample-inputs.tsv", stringsAsFactors = FALSE)
input_dir <- Sys.getenv("PHISPACE_COSMX_MULTISAMPLE_INPUTS", "Test/cosmx-multisample-inputs")
dir.create(input_dir, recursive = TRUE, showWarnings = FALSE)
sha256 <- function(path) digest::digest(path, algo = "sha256", file = TRUE)
options(timeout = max(1200, getOption("timeout")))
for (i in seq_len(nrow(manifest))) {
  path <- file.path(input_dir, manifest$path[i])
  if (!file.exists(path)) {
    tmp <- tempfile(tmpdir = input_dir)
    utils::download.file(paste0(source_url, manifest$path[i]), tmp,
                         mode = "wb", method = "libcurl")
    if (sha256(tmp) != manifest$sha256[i]) {
      unlink(tmp)
      stop("Downloaded input checksum mismatch: ", manifest$path[i])
    }
    if (!file.rename(tmp, path)) stop("Could not save input: ", path)
  }
  if (sha256(path) != manifest$sha256[i]) {
    stop("Input checksum mismatch: ", manifest$path[i],
         ". Review the upstream data before changing the manifest.")
  }
}

converted <- file.path(input_dir, c("allTissues.qs2", "historical-clusters.qs2"))
record_path <- file.path(input_dir, "conversion.tsv")
source_hash <- digest::digest(manifest, algo = "sha256")
valid_conversion <- FALSE
if (file.exists(record_path) && all(file.exists(converted))) {
  record <- read.delim(record_path, stringsAsFactors = FALSE)
  valid_conversion <- identical(record$path, basename(converted)) &&
    all(record$source_hash == source_hash) &&
    identical(record$sha256, unname(vapply(converted, sha256, character(1))))
}
if (!valid_conversion) {
  read_rda <- function(name) {
    env <- new.env(parent = emptyenv())
    loaded <- load(file.path(input_dir, paste0(name, ".rda")), envir = env)
    if (!identical(loaded, name)) stop("Unexpected object in ", name, ".rda")
    env[[name]]
  }
  allTissues <- c(read_rda("allTissues1"), read_rda("allTissues2"), read_rda("allTissues3"))
  historical <- read_rda("multiClustRes")
  # Preserve the original scores, coordinates and metadata. Keep only the
  # historical result fields needed to compare and name the new clustering.
  historical <- historical[c("clusters", "parameters")]
  for (i in seq_along(converted)) {
    object <- if (i == 1L) allTissues else historical
    qs2::qs_save(object, converted[i])
    if (!identical(object, qs2::qs_read(converted[i], validate_checksum = TRUE))) {
      stop("qs2 conversion changed an object: ", converted[i])
    }
  }
  write.table(data.frame(path = basename(converted), source_hash = source_hash,
                         sha256 = unname(vapply(converted, sha256, character(1)))),
              record_path, sep = "\t", quote = FALSE, row.names = FALSE)
  rm(allTissues, historical, object)
  gc()
}
message("Verified four pinned workshop inputs and two qs2 conversions in ",
        normalizePath(input_dir))

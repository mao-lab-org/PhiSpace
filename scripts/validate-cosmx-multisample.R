# Optional historical comparison, not part of the publishing build. Run from
# the repository root with PHISPACE_COSMX_MULTISAMPLE_INPUTS set if needed.
# Uses the 2025 getPC()/clusterPhiSpace() calculations explicitly; no old
# package installation is required. The old near-full irlba fit is deliberately
# retained here only to explain the change in random starts.
source("scripts/prepare-cosmx-multisample.R", local = TRUE)
pkgload::load_all(".", quiet = TRUE)
allTissues <- qs2::qs_read(converted[1], validate_checksum = TRUE)
historical <- qs2::qs_read(converted[2], validate_checksum = TRUE)$clusters
smoothed <- lapply(allTissues, function(spe) {
  spatialSmoother(spe, kernel = "gaussian", k = 15, include_self = TRUE, verbose = FALSE)
})
X <- do.call(rbind, lapply(smoothed, function(spe) {
  SingleCellExperiment::reducedDim(spe, "PhiSpace_smoothed")
}))
ari <- function(x, y) {
  counts <- table(x, y)
  choose2 <- function(z) z * (z - 1) / 2
  a <- sum(choose2(rowSums(counts)))
  b <- sum(choose2(colSums(counts)))
  expected <- a * b / choose2(sum(counts))
  (sum(choose2(counts)) - expected) / ((a + b) / 2 - expected)
}
set.seed(83904)
old_svd <- irlba::irlba(X, nv = ncol(X) - 1, center = colMeans(X))
old_scores <- sweep(old_svd$u[, 1:30, drop = FALSE], 2, old_svd$d[1:30], "*")
old_rng <- .Random.seed
old_fit <- kmeans(old_scores, centers = 9, iter.max = 1000,
                   nstart = 20, algorithm = "Lloyd")
current_pca <- getPC(X, ncomp = 30)
signs <- sign(colSums(current_pca$scores * old_scores))
pc_error <- max(abs(sweep(current_pca$scores, 2, signs, "*") - old_scores))
.Random.seed <- old_rng
controlled_fit <- kmeans(current_pca$scores, centers = 9, iter.max = 1000,
                          nstart = 20, algorithm = "Lloyd")
observed <- historical[rownames(X)]
metrics <- c(legacy_ari = ari(old_fit$cluster, observed),
             controlled_rng_ari = ari(controlled_fit$cluster, observed),
             max_pc_error = pc_error)
print(metrics, digits = 15)
out <- Sys.getenv("PHISPACE_COSMX_MULTISAMPLE_VALIDATION_OUT")
if (nzchar(out)) write.table(data.frame(metric = names(metrics), value = metrics),
                             out, sep = "\t", quote = FALSE, row.names = FALSE)

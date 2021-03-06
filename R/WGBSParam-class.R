# Copyright (C) 2015 Peter Hickey
#
# This file is part of methsim.
#
# methsim is free software: you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 2 of the License, or
# (at your option) any later version.
#
# methsim is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with methsim  If not, see <http://www.gnu.org/licenses/>.

### =========================================================================
### WGBSParam: An S4 class to store the parameters used to simulate a
### SimulatedBS object.
### -------------------------------------------------------------------------
###

### - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
### Design
###
### list(SimulatedMethylome, AveCov, ErrorRate, SequencingType, ReadLength)
### SimulatedMethylome: A SimulatedMethylome object.
###             AveCov: The average sequencing coverage to simulate.
###          ErrorRate: The error rate (combined sequencing error and
###                     bisulfite-conversion error) to use in the simulation.
###     SequencingType: The sequencing type: 'SE' (single-end) or 'PE'
###                     (paired-end).
###         ReadLength: The read-length.

# TODO: Create a VIRTUAL class that WGBSParam inherits from. Eventually
# RRBSParam, ERRBSParam, etc. will also inherit from this VIRTUAL class.
#' WGBSParam class
#'
#' An S4 class for the parameters used by
#' \code{\link{simulate,WGBSParam-method}}.
#'
#' @include SimulatedMethylome-class.R
#'
#' @aliases WGBSParam
#'
#' @export
setClass("WGBSParam",
         slots = list(
           SimulatedMethylome = "SimulatedMethylome",
           AveCov = "numeric",
           ErrorRate = "numeric",
           SequencingType = "character",
           ReadLength = "integer")
)

### - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
### Validity
###

# TODO: Explicit checks of class types isn't necessary for S4 classes. Leaving
# for now as the conservative option until unit tests are added.
.valid.WGBSParam.SimulatedMethylome <- function(object) {
  msg <- NULL
  if (!is(object@SimulatedMethylome, "SimulatedMethylome")) {
    msg <- Biobase::validMsg(msg, paste0("'SimulatedMethylome' slot must be ",
                                         "a 'SimulatedMethylome' object."))
  }
  msg
}

.valid.WGBSParam.AveCov <- function(object) {
  msg <- NULL
  if (!is.numeric(object@AveCov) ||
      length(object@AveCov) != 1L ||
      isTRUE(object@AveCov <= 0)) {
    msg <- Biobase::validMsg(msg, paste0("'AveCov' slot must be a postive ",
                                         "number."))
  }
  msg
}

.valid.WGBSParam.ErrorRate <- function(object) {
  msg <- NULL
  if (!is.numeric(object@ErrorRate) ||
      length(object@ErrorRate) != 1L ||
      object@ErrorRate < 0 ||
      object@ErrorRate > 1) {
    msg <- Biobase::validMsg(msg, paste0("'ErrorRate' slot must be a number ",
                                         "between 0 and 1."))
  }
  msg
}

.valid.WGBSParam.SequencingType <- function(object) {
  msg <- NULL
  if (!is.character(object@SequencingType) ||
     length(object@SequencingType) != 1L ||
     (!object@SequencingType %in% c("SE", "PE"))) {
    msg <- Biobase::validMsg(msg, paste0("'SequencingType' slot must be 'SE' ",
                                         "(single-end) or 'PE' (paired-end)."))
  }
}

.valid.WGBSParam.ReadLength <- function(object) {
  msg <- NULL
  if (!is.integer(object@ReadLength) ||
      length(object@ReadLength) != 1L ||
      object@ReadLength < 1)
    msg <- Biobase::validMsg(msg, paste0("'ReadLength' slot must be a ",
                                         "positive integer."))
}

.valid.WGBSParam <- function(object) {
  # Include all .valid.WGBSParam.* functions in this vector
  msg <- c(.valid.WGBSParam.SimulatedMethylome(object),
           .valid.WGBSParam.AveCov(object),
           .valid.WGBSParam.ErrorRate(object),
           .valid.WGBSParam.SequencingType(object),
           .valid.WGBSParam.ReadLength(object))

  if (is.null(msg)) {
    return(TRUE)
  } else{
    msg
  }
}

S4Vectors::setValidity2("WGBSParam", .valid.WGBSParam)

### - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
### Constructor
###

#' @export
WGBSParam <- function(SimulatedMethylome,
                    AveCov = 30L,
                    ErrorRate = 0.01,
                    SequencingType = "SE",
                    ReadLength = 100L) {

  # Avoid problem when user specifies ReadLength as numeric, e.g., 100 vs. 100L.
  ReadLength <- as.integer(ReadLength)

  # TODO: Argument checks
  new("WGBSParam",
      SimulatedMethylome = SimulatedMethylome,
      AveCov = AveCov,
      ErrorRate = ErrorRate,
      SequencingType = SequencingType,
      ReadLength = ReadLength)
}

### - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
### seqlevels()
###

setMethod("seqlevels",
          "WGBSParam",
          function(x) {
            seqlevels(x@SimulatedMethylome)
          }
)

### - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
### seqlengths()
###

setMethod("seqlengths",
          "WGBSParam",
          function(x) {
            seqlengths(x@SimulatedMethylome)
          }
)

### - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
### simulate()
###

# A helper function called by simulate,WGBSParam-method
.simulateWGBSParam <- function(i, object, seqlevels, simplify, BPPARAM) {

  # Need to simulate compute a transition matrix, P, for all components.
  # object@MixtureWeights
  n_components <- ncol(object@SimulatedMethylome)

  # Sample read start sites based on uniform sampling with given
  # average sequencing coverage (aveCov).
  # TODO: This assumes constant readLength; this code will need
  # modification if this assumption is changed.
  n_reads <- as.list(trunc(object@AveCov / object@ReadLength *
                             seqlengths(object)[seqlevels]))
  # TODO: Perhaps the number of reads per-chromosome should be
  # sampled from a multinomial(sum(n_reads), n_reads)?
  # Don't simulate read_start in parallel, e.g., via bpmapply().
  # It needlessly complicates things (reproducibility of random
  # numbers when generated in parallel is hard) and any speed ups are
  # swamped by the running times of other steps in this function.
  read_start <- mapply(function(n, seqlength) {
    .sampleReadStart(n, seqlength)
  }, n = n_reads, seqlength = seqlengths(object)[seqlevels], SIMPLIFY = FALSE)
  # Sorting makes things easier to keep track of, and sorting an
  # integer vector is easier than sorting more complicated objects (e.g.,
  # GRanges objects).
  read_start <- bplapply(read_start, sort, BPPARAM = BPPARAM)

  # Compute the transition probabilities.
  # TODO: The order of the Markov chain (mc_order) is currently hard-coded.
  mc_order <- 1L
  P <- bplapply(seq_len(n_components),
                function(i, object, mc_order) {
                  .computeP(assay(object@SimulatedMethylome, "MarginalProb",
                                  withDimnames = FALSE)[, i, drop = FALSE],
                            assay(object@SimulatedMethylome, "LOR",
                                  withDimnames = FALSE)[, i, drop = FALSE],
                            mc_order)
                }, object = object, mc_order = mc_order, BPPARAM = BPPARAM)

  # TODO: This is currently not RNG-safe since random
  # numbers are generated within the parallel process.
  # Find reads that overlap methylation loci and then sample a
  # methylation pattern for each such read.
  # TODO: Take care if simulate() itself is being run in parallel
  # (or at least document that it could spawn heaps of processes).
  z <- bplapply(names(read_start), function(seqlevel,
                                            read_start,
                                            object,
                                            P,
                                            simplify) {

    # TODO: This may cause warnings (at least when this isn't run
    # in parallel, which causes warning()s to be suppressed). These
    # warnings will occur if a read runs "off the end" of the
    # seqlevel.
    rs <- read_start[[seqlevel]]
    # Suppress warnings about out-of-bound ranges.
    gr <- suppressWarnings(
      GRanges(seqlevel,
              IRanges(rs, width = object@ReadLength),
              seqinfo = seqinfo(object@SimulatedMethylome))
    )
    # Address the above (possible) warning about out-of-bound ranges.
    gr <- trim(gr)
    ol <- findOverlaps(gr, object@SimulatedMethylome)

    # Find all reads with the same overlaps.
    # This assumes that a read sequences contiguous methylation loci, i.e., no
    # gaps.
    # TODO: Re-write if allowing gaps (i.e., if
    # sequencingType = "PE" is implemented).
    nh <- countQueryHits(ol)
    # Exclude reads with no hits
    nh <- nh[nh > 0L]
    # Assign reads to components of the mixture
    mixture_weights <- as.vector(
      unlist(assay(object@SimulatedMethylome, "MixtureWeights",
                   withDimnames = FALSE)[1, ], use.names = FALSE))
    component <- sample(x = n_components,
                        size = length(nh),
                        replace = TRUE,
                        prob = mixture_weights)
    hits_dt <- data.table(qh = unique(queryHits(ol)),
                          fh = na.omit(selectHits(ol, "first")),
                          nh = nh,
                          component = component,
                          key = c("fh", "nh", "component"))
    hits_dt <- hits_dt[, .N, by = key(hits_dt)]

    # Rcpp can't yet return long vectors nor can mclapply()-based
    # functions. We could get around the Rcpp limitation by processing in
    # suitably sized batches. However, this won't work for the
    # data.table-based portions of this code because it also can't work with
    # long vectors. Furthermore, there is likely to be problems with
    # returning such a large object when running in parallel. Therefore, we
    # throw an error if this occurs. A general solution will be difficult.
    if (sum(hits_dt[, nh] * as.numeric(hits_dt[, N])) >
        .Machine$integer.max) {
      stop(paste0(seqlevel, ": Number of simulated methylation loci ",
                  "> ", .Machine$integer.max, " (.Machine$integer.max). ",
                  "Sorry, this is not yet supported. Try reducing the average",
                  "sequencing coverage ('AveCov' slot of the 'WGBSParam' ",
                  "object)."))
    }

    # Simulate N paths for each row of hits_dt, stratified by mixture component.
    zz <- .simulatez(hits_dt[, fh],
                     hits_dt[, nh],
                     hits_dt[, N],
                     hits_dt[, component],
                     assay(object@SimulatedMethylome,
                           "MarginalProb", withDimnames = FALSE),
                     P)

    # Introduce sequencing error + bisulfite-conversion error i.e.,
    # flip elements of z[[i]]$z s.t. Prob(flip) = object@errorRate.
    # TODO: RNG at C++ level if possible
    .simulateErrorInPlace(zz$z,
                          runif(length(zz$z)),
                          object@ErrorRate)
    setDT(zz)
    zz <- cbind(zz, pos = start(object@SimulatedMethylome)[zz[, h]])
    zz[, h := NULL]
    setcolorder(zz, c("pos", "readID", "z"))

    if (!simplify) {
      zz
    } else {
      return(.makePosAndCounts(zz, size = simplify))
    }
  }, read_start = read_start, object = object, P = P, simplify = simplify,
  BPPARAM = BPPARAM)

  # Don't rbindlist(z). Instead, keeping as list will actually save memory (no
  # need to retain seqnames for every row) and allow easier parallelisation by
  # seqlevel. But must ensure seqlevels are set as names(z).
  names(z) <- names(read_start)
  seqinfo <- seqinfo(object@SimulatedMethylome)
  methinfo <- methinfo(object@SimulatedMethylome)

  if (!simplify) {
    # Construct SimulatedBS object.
    sbs <- new("SimulatedBS",
               z = z,
               seqinfo = seqinfo,
               methinfo = methinfo,
               SampleName = paste("sim", i, sep = "_"))
    return(sbs)
  } else {
    seqnames <- Rle(names(z), sapply(lapply(z, "[[", "pos"), nrow))
    pos <- do.call(rbind, lapply(z, "[[", "pos"))
    counts <- lapply(seq_len(2 ^ simplify), function(i, z) {
      matrix(unlist(lapply(lapply(z, "[[", "counts"), "[[", i),
                    use.names = FALSE), ncol = 1L)
    }, z = z)
    names(counts) <- MethylationTuples:::.makeMethPatNames(simplify)
    counts <- lapply(counts, `colnames<-`, paste("sim", i, sep = "_"))
    MethPat(assays = counts,
            rowRanges = MTuples(GTuples(seqnames, pos, "*", seqinfo = seqinfo),
                              methinfo = methinfo))
  }
}

# TODO: Should user-messages be suppressible via suppressMessages() or a
# 'verbose' option.
#' Simulate a bisulfite-sequencing experiment.
#'
#' @param object A \code{\link{WGBSParam}} object.
#' @param nsim The number of samples to simulate using the parameters given in
#' \code{object}. Additional samples will be technical replicates.
#' @param seed An object specifying if and how the random number generator
#' should be initialized ('seeded'). For the "WGBSParam" method, either
#' \code{NULL} or an integer that will be used in a call to
#' \code{base::\link[base]{set.seed}} before simulating the samples. If set,
#' the value is saved as the "\code{seed}" attribute of the returned value. The
#' default, \code{NULL}, will not change the random generator state, and return
#' \code{\link{.Random.seed}} as the "\code{seed}" attribute, see 'Value'.
#' @param seqlevels A character vector of
#' \code{GenomeInfoDb::\link[GenomeInfoDb]{seqlevels}} at which to
#' bisulfite-sequencing reads. If missing, the default is to use all available
#' seqlevels.
#' @param simplify An integer specifying whether, and by how much, the object
#' should be simplified, see 'Value'.
#' @param BPPARAM an optional
#' \code{BiocParallel::\link[BiocParallel]{BiocParallelParam}} instance
#' determining the parallel back-end to be used during evaluation.
#'
#' @return The return value depends on the value of \code{simplify}. The
#' default (\code{simplify = 0}) means no simplification and the returned
#' object is a \code{list} of length \code{nsim} containing
#' \code{\link{SimulatedBS}} objects. If \code{simplify} is greater than zero,
#' the returned object is a
#' \code{MethylationTuples::\link[MethylationTuples]{MethPat}} object with
#' \code{\link[MethylationTuples]{size} = simplify} and \code{ncol = simplify}.
#'
#' @note Currently only simulates whole-genome bisulfite-sequencing data.
#'
#' @section Warnings:
#' \itemize{
#'  \item Reads are \strong{not} yet simulated for circular seqlevels such as
#'        'chrM' (mitochondrial DNA).
#'  \item Only single-end sequencing ('SE') is currently supported.
#'  \item This is currently not RNG-safe since random numbers are generated
#'  within the parallel process and at the \code{Rcpp} level. Therefore,
#'  results may not be reproducible, even given the same \code{seed}.
#'  \strong{This is a work in progress and will be fixed.}
#'  \item The \code{nsim} simulations are currently simulated in
#'  \strong{serial} (but steps of each simulation may be run in parallel).
#' }
#'
#' @export
setMethod("simulate",
          "WGBSParam",
          function(object,
                   nsim = 1,
                   seed = NULL,
                   seqlevels,
                   simplify = 0L,
                   BPPARAM = bpparam()) {

            # Argument checks
            # Only single-end sequencing currently supported
            if (object@SequencingType != "SE") {
              stop(paste0("Only single-end sequencing is currently supported.",
                          "\nPlease modify the 'WGBSParam' object accordingly."))
            }
            # TODO: Is this the best way to set default seqlevels? Can't use
            # seqlevels = seqlevels(object@PartitionedMethylome) in function
            # signature because of 'recursive default argument reference' error.
            # TODO: Propose a seqlevelsInUse,SummarizedExperiment-method.
            valid_seqlevels <- GenomeInfoDb::seqlevelsInUse(
              rowRanges(object@SimulatedMethylome))
            if (missing(seqlevels)) {
              # Only use seqlevels that are "active" in the SimulatedMethylome
              # object
              seqlevels <- valid_seqlevels
            } else {
              # Check that supplied seqlevels are valid
              if (!all(seqlevels %in% valid_seqlevels)) {
              stop(paste0("Unexpected seqlevels.\n",
                          paste0(seqlevels[!seqlevels %in% valid_seqlevels],
                                 collapse = ", "), " are not seqlevels of ",
                          "'WGBSParam'."))
              }
            }
            if (simplify < 0 || simplify != as.integer(simplify)) {
              stop(paste0("'simplify' must be an integer greater than or equal
                          to zero."))
            }
            simplify <- as.integer(simplify)

            # TODO: Will need to revisit how seed is set and (pseudo) random
            # numbers are generated due to the use of BiocParallel and Rcpp*.
            # This chunk for handling RNG generation is based on
            # stats:::simulate.lm.
            if (!exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)) {
              runif(1)
            }
            if (is.null(seed)) {
              rng_state <- get(".Random.seed", envir = .GlobalEnv)
            } else {
              r_seed <- get(".Random.seed", envir = .GlobalEnv)
              set.seed(seed)
              rng_state <- structure(seed, kind = as.list(RNGkind()))
              on.exit(assign(".Random.seed", r_seed, envir = .GlobalEnv))
            }

            # TODO (long term): Support stranded data.
            warning("Currently only simulates unstranded data.")
            # TOOD: Add support for paired-end reads.
            warning("Currently only simulates single-end reads.")
            # TODO: Fix RNG
            warning("Random number generation is not yet reproducible.")

            if (nsim >= 2) {
              message("Simulating ", nsim, " bisulfite-sequencing samples...")
            } else {
              message("Simulating ", nsim, " bisulfite-sequencing sample...")
            }

            # TODO: Circular chromosomes are hard. While the read automatically
            # gets wrapped around by GRanges(), it makes subsequent functions,
            # e.g., asMethPat(), more complicated. So, for now, I do not allow
            # simulation of reads for circular chromosomes.
            is_circ <- isCircular(
              seqinfo(object@SimulatedMethylome))[seqlevels]
            if (any(is_circ)) {
              warning(paste0("No reads will be simulated for ",
                             paste0(seqlevels[is_circ], collapse = ", "),
                             " (circular seqlevels not yet supported)."))
            }
            # Remove circular seqlevels from seqlevels.
            seqlevels <- seqlevels[!is_circ]
            if (length(seqlevels) == 0L) {
              # TODO: Return the "empty" object instead of a warning message.
              stop("No reads simulated (all seqlevels are circular).")
            }

            # TODO: Allow simulation in parallel.
            # Simulate nsim objects in *serial*.
            val <- lapply(seq_len(nsim),
                          .simulateWGBSParam,
                          object = object, seqlevels = seqlevels,
                          simplify = simplify, BPPARAM = BPPARAM)
            names(val) <- paste("sim", seq_len(nsim), sep = "_")

            if (simplify) {
              # Combine MethPat objects into one.
              # TODO: Why doesn't do.call(combine, val) work? Check out
              # other combine methods, e.g., combine,data.frame-method.
              val <- Reduce(combine, val)
            }
            # Ensure "seed" is set as an attribute of the returned value.
            attr(val, "seed") <- rng_state
            val
          }
)

### - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
### getters/setters
###
# TODO (long term)

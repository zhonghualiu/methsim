// Copyright (C) 2015 Peter Hickey
//
// This file is part of methsim.
//
// methsim is free software: you can redistribute it and/or modify it
// under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 2 of the License, or
// (at your option) any later version.
//
// methsim is distributed in the hope that it will be useful, but
// WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with methsim  If not, see <http://www.gnu.org/licenses/>.

#include <Rcpp.h>

using namespace Rcpp;

//' Sample Z.
//'
//' Simulate sequencing reads by sampling a subset of rows from a given column
//' of W for each read.
//'
//' @param Z an integer matrix where Z[i, j] is the methylation state of the
//' i-th methylation locus on the j-th pseud-haplotype.
//' @param sampled_W an integer vector of length equal to the number of reads.
//' Each element is the pseudo-haplotype from which each read is to be sampled,
//' i.e., Z[, j].
//' @param fh an integer vector of length equal to the number of reads. Each
//' element is the position of the first methylation loci ("first hit") from
//' which read is to be sampled, i.e., Z[i, ].
//' @param cqh an integer vector of length equal to the number of reads. Each
//' element is the number of methylation loci that each read overlaps.
//'
//' @keywords internal
//'
//' @return a list of length equal to the number of simulated reads. Each list
//' element is the sequenced/sampled methylation state for that read.
// [[Rcpp::export(".sampleZ")]]
List sampleZ(IntegerMatrix Z, IntegerVector sampled_W, IntegerVector fh,
             IntegerVector cqh) {

  // Variable checks
  if ((sampled_W.length() != fh.length()) ||
      (fh.length())!= cqh.length()) {
    Rcpp::stop("length(sampled_W) != length(fh) != length(cqh).");
  }
  // Check that we won't try to access out-of-bounds elements of Z (row-wise)
  if ((max(fh + cqh) - 1) > Z.nrow()) {
    Rcpp::stop("max(fh + cqh - 1) > nrow(Z).");
  }
  // Check that we won't try to access out-of-bounds elements of Z (col-wise)
  if (max(sampled_W) > Z.ncol()) {
    Rcpp::stop("max(sampled_W) > ncol(Z).");
  }
  if (min(cqh) < 1) {
    Rcpp::stop("min(cqh) < 1.");
  }

  // Initialise variables
  int n = sampled_W.length();
  List z(n);
  std::vector<int> zz;
  int col_idx;
  int row_idx;

  // i loops over reads.
  for (int i = 0; i < n; i++) {

    // j loops over methylation loci in the i-th read.
    for (int j = 0; j < cqh[i]; j++) {
      row_idx = fh[i] + j - 1; // -1 for C++ indexing
      col_idx = sampled_W[i] - 1; // -1 for C++ indexing
      zz.push_back(Z(row_idx, col_idx));
    }

    z[i] = zz;
    zz.clear();
  }

  return z;
}

//' Sample Z but return as a vector.
//'
//'
//' Identical to sampleZ() but returning a std::vector<int> rather than a List.
//' Simulate sequencing reads by sampling a subset of rows from a given column
//' of W for each read.
//'
//' @param Z an integer matrix where Z[i, j] is the methylation state of the
//' i-th methylation locus on the j-th pseud-haplotype.
//' @param sampled_W an integer vector of length equal to the number of reads.
//' Each element is the pseudo-haplotype from which each read is to be sampled,
//' i.e., Z[, j].
//' @param fh an integer vector of length equal to the number of reads. Each
//' element is the position of the first methylation loci ("first hit") from
//' which read is to be sampled, i.e., Z[i, ].
//' @param cqh an integer vector of length equal to the number of reads. Each
//' element is the number of methylation loci that each read overlaps.
//'
//' @note Unlike with sampleZ(), sampleZvec() has no information about which
//' read each methylation call belongs to.
//'
//' @keywords internal
//'
//' @return a vector of length equal to sum(cqh). Each element is the
//' sequenced/sample methylation state of a particular read.
// [[Rcpp::export(".sampleZVec")]]
Rcpp::IntegerVector sampleZvec(IntegerMatrix Z,
                               IntegerVector sampled_W,
                               IntegerVector fh,
                               IntegerVector cqh) {

  // Variable checks
  if ((sampled_W.length() != fh.length()) ||
      (fh.length())!= cqh.length()) {
    Rcpp::stop("length(sampled_W) != length(fh) != length(cqh).");
  }
  // Check that we won't try to access out-of-bounds elements of Z (row-wise)
  if ((max(fh + cqh) - 1) > Z.nrow()) {
    Rcpp::stop("max(fh + cqh - 1) > nrow(Z).");
  }
  // Check that we won't try to access out-of-bounds elements of Z (col-wise)
  if (max(sampled_W) > Z.ncol()) {
    Rcpp::stop("max(sampled_W) > ncol(Z).");
  }
  if (min(cqh) < 1) {
    Rcpp::stop("min(cqh) < 1.");
  }

  // Initialise variables
  int n = sum(cqh);
  Rcpp::IntegerVector z(n);
  int col_idx;
  int row_idx;

  // i loops over reads.
  for (int i = 0; i < n; i++) {

    // j loops over methylation loci in the i-th read.
    for (int j = 0; j < cqh[i]; j++) {
      row_idx = fh[i] + j - 1; // -1 for C++ indexing
      col_idx = sampled_W[i] - 1; // -1 for C++ indexing
      z[i + j] = Z(row_idx, col_idx);
    }
  }

  return z;
}

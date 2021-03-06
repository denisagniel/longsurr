% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/get_delta_s.R
\name{get_delta_s}
\alias{get_delta_s}
\title{Estimate residual treatment effect}
\usage{
get_delta_s(y_t = NULL, y_c = NULL, X_t = NULL, X_c = NULL)
}
\arguments{
\item{y_t}{vector of outcomes in the treatment arm.}

\item{y_c}{vector of outcomes in the control arm.}

\item{X_t}{matrix of surrogate values in the treatment arm.}

\item{X_c}{matrix of surrogate values in the control arm.}
}
\value{
list containing matrices \code{X_t} and \code{X_c}, which are the smoothed surrogate values for the treated and control groups, respectively, for use in downstream analyses
}
\description{
Estimate residual treatment effect
}
\examples{
library(dplyr)
library(longsurr)
obs_data <- 
generate_discontinuous_data(n = 50, n_i = 5, delta_s = 0.5, 
k = 1, s_y = 0.1, s_x = 0.1)$obs_ds

head(obs_data)
presmooth_X <- presmooth_data(obs_data)

wide_ds <- full_data \%>\% 
dplyr::select(id, a, tt, x, y) \%>\%
tidyr::spread(tt, x) 

y_t <- wide_ds \%>\%
filter(a == 1) \%>\%
pull(y)
y_c <- wide_ds \%>\%
filter(a == 0) \%>\%
pull(y)
X_t <- presmooth_X$X_t
X_c <- presmooth_X$X_c

estimate_surrogate_value(y_t = y_t, y_c = y_c, 
X_t = X_t, X_c = X_c, method = 'linear')

}

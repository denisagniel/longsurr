dc_fit_fn <- function(full_data, obs_data) {
  # browser()
  wide_ds <- full_data %>%
    dplyr::select(id, a, tt, x, y) %>%
    spread(tt, x) 
  wide_ds_0 <- wide_ds %>%
    filter(a == 0)
  wide_ds_1 <- wide_ds %>%
    filter(a == 1)
  X_t <- wide_ds_1 %>%
    dplyr::select(`-1`:`1`) %>%
    as.matrix
  y_t <- wide_ds_1 %>%
    pull(y)
  X_c <- wide_ds_0 %>%
    dplyr::select(`-1`:`1`) %>%
    as.matrix
  y_c <- wide_ds_0 %>%
    pull(y)
  
  n <- nrow(wide_ds)/2
  deltahat <- mean(y_t) - mean(y_c)
  
  
  select <- dplyr::select
  oracle_delta_s <- get_delta_s(y_t = y_t,
                                y_c = y_c,
                                X_t = X_t,
                                X_c = X_c) %>%
    gather(estimator, delta_s) %>%
    mutate(type = 'oracle')
  # browser()
  
  select <- dplyr::select
  c(trt_xhat_wide, ctrl_xhat_wide, trt_scores, ctrl_scores) %<-%
    presmooth_data(obs_data)
  # browser()
  obs_delta_s <- get_delta_s(y_t = y_t, y_c = y_c, 
                             X_t = trt_xhat_wide,
                             X_c = ctrl_xhat_wide) %>%
    gather(estimator, delta_s) %>%
    mutate(type = 'smoothed')
  
  x_sum <- obs_data %>%
    group_by(id, y, a) %>%
    summarise(xbar = mean(x),
              x_change = x[tt == max(tt)] - x[tt == min(tt)]) %>%
    ungroup
  
  naive_res <- x_sum %>%
    summarise(delta_s_mean = R.s.estimate(sone = xbar[a == 1],
                                          szero = xbar[a == 0],
                                          yone = y[a == 1],
                                          yzero = y[a == 0])$delta.s,
              delta_s_change = R.s.estimate(sone = x_change[a == 1],
                                            szero = x_change[a == 0],
                                            yone = y[a == 1],
                                            yzero = y[a == 0])$delta.s) %>%
    gather(estimator, delta_s) %>%
    mutate(type = 'naive')
  full_res <- oracle_delta_s %>%
    full_join(obs_delta_s) %>%
    full_join(naive_res) %>%
    mutate(deltahat = deltahat,
           R = 1 - delta_s/deltahat)
  full_res
}


dc_sim <- function(n, n_i, s_y = 0.5, s_x = 0.5, k, delta, B, run, tmpdir) {
  library(dplyr)
  library(here)
  library(purrr) 
  library(zeallot)
  library(readr)
  library(glue)
  library(longsurr)
  library(refund)
  library(mgcv)
  library(Rsurrogate)
  library(tidyr)
  library(fda.usc)
  select <- dplyr::select
  # browser()
  print(glue('This is sim {run} for sample size {n}, number of observations {n_i},  k {k}, and delta {delta}, using {B} bootstrap samples.'))
  
  c(full_data, obs_data) %<-%
    generate_discontinuous_data(n = n, n_i = n_i, delta_s = delta, k = k, s_y = s_y, s_x = s_x)
  
  
  select <- dplyr::select
  res <- dc_fit_fn(full_data, obs_data)
  
  # browser()
  id_data <- full_data %>%
    select(id, y, a) %>%
    distinct
  if (B > 0) {
    boot_list <- map(1:B, function(b) {
      print(b)
      boot_data <- id_data %>%
        sample_frac(replace = TRUE) %>%
        arrange(id) %>%
        mutate(old_id = id,
               id = 1:(2*n))
      boot_full_data <- boot_data %>%
        merge(full_data, by.x = c('old_id', 'a', 'y'), 
              by.y = c('id', 'a', 'y')) %>%
        arrange(a, old_id, tt)
      boot_obs_data <- boot_data %>%
        merge(obs_data, by.x = c('old_id', 'a', 'y'), 
              by.y = c('id', 'a', 'y')) 
      
      boot_fit <- dc_fit_fn(boot_full_data, boot_obs_data)
      
      boot_fit
    })
    
    boot_ests <- bind_rows(boot_list, .id = 'boot')
    # browser()
    
    boot_vars <- boot_ests %>%
      group_by(estimator, type) %>%
      summarise(var_delta_s = var(delta_s, na.rm = TRUE),
                var_delta = var(deltahat, na.rm = TRUE),
                var_R = var(R, na.rm = TRUE),
                low_q_delta_s = quantile(delta_s, 0.025, na.rm = TRUE),
                high_q_delta_s = quantile(delta_s, 0.975, na.rm = TRUE),
                low_q_delta = quantile(deltahat, 0.025, na.rm = TRUE),
                high_q_delta = quantile(deltahat, 0.975, na.rm = TRUE),
                low_q_R = quantile(R, 0.025, na.rm = TRUE),
                high_q_R = quantile(R, 0.975, na.rm = TRUE))
    full_res <- res %>%
      full_join(boot_vars)
  } else full_res <- res
  full_res <- 
    full_res %>%
    mutate(n = n,
           n_i = n_i,
           delta = delta,
           B = B,
           run = run)
  saveRDS(full_res,
          glue('{tmpdir}/dc-res_n{n}_ni{n_i}_delta{delta}_B{B}_{run}.rds')
  )
  full_res
}

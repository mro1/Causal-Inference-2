## cheng_hoekstra.R ------------------------------------------------------------
## Kyle Butts, CU Boulder Economics
## 
## Various Difference-in-Differences Estimators with Cheng and Hoekstra dataset.

library(haven)
library(tidyverse)
library(fixest) 
library(did2s)
library(did)
library(bacondecomp)

castle <- haven::read_dta('https://github.com/scunning1975/mixtape/raw/master/castle.dta')

# Never treated have `effyear` = Inf
castle[is.na(castle$effyear), ]$effyear <- 0
castle$rel_year = castle$year - castle$effyear
castle[castle$effyear == 0, ]$rel_year <- -1
castle$treat = castle$year >= castle$effyear

# 1. TWFE Event-study regression -----------------------------------------------

# estimate the effect on log(homicide)
es_twfe <- feols(
  l_homicide ~ i(rel_year, ref = -1) | sid + year, 
  castle, cluster = ~ sid
) 

coefplot(es_twfe)

# 2. Callaway and Santa'Anna ---------------------------------------------------

# Estimating the effect on log(homicide)
atts <- att_gt(
  yname = "l_homicide",
  tname = "year",
  idname = "sid",
  gname = "effyear",
  clustervars = "sid",
  # They require g to be equal to 0
  data = castle,
  # no covariates
  xformla = NULL, 
  # with covariates
  # xformla = ~ X_Iyear_2010, 
  # set the comparison group which is either "nevertreated" or "notyettreated" 
  control_group = "nevertreated"
)

es_cs <- aggte(atts, type = "dynamic")
ggdid(es_cs)


# 3. Imputation Estimator ------------------------------------------------------

# Note the point estimates will be identical to `didimputation` and the Mundlak regression

es_imputation <- did2s(
  yname = "l_homicide",
  first_stage = ~ 1 | sid + year, 
  second_stage = ~ i(rel_year, ref = -1s), 
  treatment = "treat", 
  cluster_var = "sid",
  data = castle
)

coefplot(es_imputation)


# 4. Sun and Abraham -----------------------------------------------------------

es_sa = feols(
  l_homicide ~ sunab(effyear, year) | sid + year,
  data = castle, cluster = ~ sid
)

coefplot(es_sa)



# 5. Stacking Estimator --------------------------------------------------------

# Loop through each `effyear` and create our dataset
stacked <- NULL
# Get groups except for never-treated 0
groups <- setdiff(unique(castle$effyear), 0)

for(g in groups) {
  stacked <- bind_rows(stacked, 
    castle |> 
      filter(effyear == g | effyear == 0 | year < effyear) |>
      filter((rel_year >= -5 & rel_year <= 4) | effyear == 0) |>
      mutate(stack_id = g)
  )
}

feols(
  l_homicide ~ i(rel_year, ref = -1) | sid^stack_id + year^stack_id, 
  data = stacked, cluster ~ sid^stack_id
) |> 
  coefplot()



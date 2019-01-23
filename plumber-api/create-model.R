library(ggplot2) ## for dataset
library(readr) ## for write_rds
data(diamonds)

model <- lm(price ~ carat, data = diamonds)

write_rds(model, "lm-model.rds")


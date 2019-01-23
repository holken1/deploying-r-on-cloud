# read model
model <- readRDS("lm-model.rds")

#* Score using linear model
#* @param carat The carat value of the diamond
#* @get /score-lm
function(carat) {
  list(price = predict(model, newdata = data.frame(carat = as.numeric(carat))))
}

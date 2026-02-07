# -------------------- 0. Setup --------------------

# Install packages 
install.packages("glmnet")
install.packages("broom")
install.packages("ggplot2")
library(glmnet)
library(ggplot2)
library(broom)

# -------------------- 1. Paths --------------------


file_path <- "~/ECL298/input_data"
save_path <- "~/ECL298/output_data" 



# -------------------- 2. Load data --------------------

df <- read.csv(file.path(file_path, "Lasso_Model_Input_Variables_1979_2023_v2.csv"))
head(df)


# Drop rows with missing yield
df <- df[!is.na(df$yield_kg_ha), ]

# -------------------- 3. Build feature set --------------------

cols_exclude <- c("county", "year", "yield_kg_ha")
feature_cols <- setdiff(colnames(df), cols_exclude)

# Add squared terms for non-linear relationship
for (col in feature_cols) {
  df[[paste0(col, "_sq")]] <- df[[col]]^2
}
squared_cols <- paste0(feature_cols, "_sq")
feature_cols <- c(feature_cols, squared_cols)

head(df)

# County fixed effects via model.matrix
county_dummies <- model.matrix(~ county - 1, data = df)   # one column per county, no intercept
colnames(county_dummies) <- gsub("county", "county_", colnames(county_dummies))
head(df)

# Time trend within each county
time_trend <- df$year - min(df$year) + 1   # starts from 1
time_trend_mat <- sweep(county_dummies, 1, time_trend, "*")
colnames(time_trend_mat) <- gsub("^county_", "trend_", colnames(time_trend_mat))

df_nonclim <- cbind(as.data.frame(county_dummies), as.data.frame(time_trend_mat))
nonclim_cols <- colnames(df_nonclim)

df_all <- cbind(df, df_nonclim)
df_all_full <- df_all   # keep a copy BEFORE outlier removal

head(df_all)

feature_cols <- c(feature_cols, nonclim_cols)

# -------------------- 4. Prepare X and Y --------------------

X <- as.matrix(df_all[, feature_cols])
Y <- df_all$yield_kg_ha

# -------------------- 5. Remove influential outliers (Cook's distance) --------------------

ols_df <- data.frame(Y = Y, X)
ols_model <- lm(Y ~ ., data = ols_df)

cooks_d <- cooks.distance(ols_model)
threshold <- 4 / length(Y)
mask <- cooks_d < threshold

X <- X[mask, , drop = FALSE]
Y <- Y[mask]
df_all <- df_all[mask, ]

# Optional: plot Cook's distance
png(file.path(save_path, "cooks_distance_plot.png"), width = 900, height = 600)
plot(cooks_d, pch = 20, main = "Cook's Distance", xlab = "Observation", ylab = "Cook's distance")
abline(h = threshold, col = "red", lty = 2)
dev.off()

# -------------------- 6. Fit LASSO with cross-validation (standardized features) --------------------

# Manually standardize X so coefficients are for standardized features
X_scaled <- scale(X)
scaler_mean <- attr(X_scaled, "scaled:center")
scaler_sd <- attr(X_scaled, "scaled:scale")

# Guard against zero variance
scaler_sd[scaler_sd == 0] <- 1

alphas <- c(5, 4, 3, 2, 1, 0.5, 0.1, 0.05, 0.01, 0.005, 0.001)

set.seed(45)
lasso_cv <- cv.glmnet(
  X_scaled, Y,
  alpha = 1,
  lambda = alphas,
  standardize = FALSE,
  nfolds = 5,
  maxit = 1e+06
)

selected_alpha <- lasso_cv$lambda.min
cat("Selected alpha:", selected_alpha, "\n")

# R^2 on full (filtered) data
Y_hat_all <- as.numeric(predict(lasso_cv, newx = X_scaled, s = "lambda.min"))
r2_overall <- 1 - sum((Y - Y_hat_all)^2) / sum((Y - mean(Y))^2)
cat("Overall R^2:", r2_overall, "\n")

# Coefficients for standardized features (including intercept)
coef_standardized <- coef(lasso_cv, s = "lambda.min")

# Save standardized coefficients
write.csv(as.matrix(coef_standardized),
          file.path(save_path, "standardized_coef_lasso_m2.csv"),
          row.names = TRUE)

# -------------------- 7. Plot standardized coefficients (excluding county/trend) --------------------

coef_mat <- as.matrix(coef_standardized)

coef_df <- data.frame(
  term = rownames(coef_mat),
  estimate = as.numeric(coef_mat[, 1]),
  row.names = NULL
)

coef_df_plot <- subset(
  coef_df,
  !grepl("^county_", term) &
    !grepl("^trend_", term) &
    term != "(Intercept)"
)

png(file.path(save_path, "standardized_lasso_coefs.png"), width = 1200, height = 800)
ggplot(coef_df_plot, aes(x = reorder(term, estimate), y = estimate)) +
  geom_col() +
  coord_flip() +
  theme_bw() +
  labs(
    title = "Standardized LASSO Coefficients",
    x = "Feature",
    y = "Coefficient"
  )
dev.off()

# -------------------- 8. Predict for all observations (before outlier removal) --------------------

X_full <- as.matrix(df_all_full[, feature_cols])

# Scale using training (filtered) mean & sd
X_full_scaled <- sweep(X_full, 2, scaler_mean, FUN = "-")
X_full_scaled <- sweep(X_full_scaled, 2, scaler_sd, FUN = "/")

Y_pred_full <- as.numeric(predict(lasso_cv, newx = X_full_scaled, s = "lambda.min"))

df_pred <- df_all_full
df_pred$y_pred <- Y_pred_full

png(file.path(save_path, "observed_vs_predicted_by_county.png"), width = 900, height = 700)
ggplot(df_pred, aes(x = yield_kg_ha, y = y_pred, color = county)) +
  geom_point(alpha = 0.8) +
  theme_bw() +
  labs(title = "Observed vs Predicted Yield by County",
       x = "Observed Yield (kg/ha)",
       y = "Predicted Yield (kg/ha)")
dev.off()

# -------------------- 9. Unstandardize coefficients --------------------

# Drop intercept for unstandardization step
coef_df_noint <- subset(coef_df, term != "(Intercept)")

# Reorder scaler_sd to match feature_cols order
# coef_df_noint$term should correspond to columns in X_scaled
# In glmnet, terms are named like "V1", "V2", ... if X has no colnames
# so we set colnames(X) = feature_cols before fitting
# (Back-fill now for clarity)
# NOTE: this assumes coef order matches column order of X_scaled.
colnames(X_scaled) <- feature_cols

coef_standardized <- coef(lasso_cv, s = "lambda.min")
coef_std_vec <- as.numeric(coef_standardized[-1])  # remove intercept
names(coef_std_vec) <- feature_cols

unstd_coefs <- coef_std_vec / scaler_sd
unstd_df <- data.frame(
  Feature = names(unstd_coefs),
  Coefficient = as.numeric(unstd_coefs),
  row.names = NULL
)

write.csv(unstd_df,
          file.path(save_path, "unstandardized_coef_lasso_m2.csv"),
          row.names = FALSE)

# Plot unstandardized coefficients (excluding county/trend)
unstd_plot_df <- subset(unstd_df,
                        !grepl("^county_", Feature) &
                          !grepl("^trend_", Feature))

png(file.path(save_path, "unstandardized_lasso_coefs.png"), width = 1200, height = 800)
ggplot(unstd_plot_df, aes(x = reorder(Feature, Coefficient), y = Coefficient)) +
  geom_col() +
  coord_flip() +
  theme_bw() +
  labs(title = "Unstandardized LASSO Coefficients",
       x = "Feature",
       y = "Coefficient")
dev.off()

# -------------------- 10. 70-30 Train/Test Validation (100 iterations) --------------------

run_lasso_validation <- function(X_mat, Y_vec, n_iter, alphas, save_csv_path) {
  n <- length(Y_vec)
  
  r2_train_inbuilt <- numeric(n_iter)
  r2_test_inbuilt  <- numeric(n_iter)
  r2_test_manual   <- numeric(n_iter)
  
  set.seed(123)
  
  for (i in 1:n_iter) {
    # 70-30 split
    train_idx <- sample(seq_len(n), size = floor(0.7 * n))
    test_idx  <- setdiff(seq_len(n), train_idx)
    
    X_train <- X_mat[train_idx, , drop = FALSE]
    X_test  <- X_mat[test_idx, , drop = FALSE]
    y_train <- Y_vec[train_idx]
    y_test  <- Y_vec[test_idx]
    
    # Fit LASSO with default glmnet standardization
    lcv <- cv.glmnet(
      X_train, y_train,
      alpha = 1,
      lambda = alphas,
      nfolds = 5
    )
    
    # Predictions
    yhat_train <- as.numeric(predict(lcv, newx = X_train, s = "lambda.min"))
    yhat_test  <- as.numeric(predict(lcv, newx = X_test,  s = "lambda.min"))
    
    # Train R^2 (inbuilt style)
    sst_train <- sum((y_train - mean(y_train))^2)
    ssr_train <- sum((y_train - yhat_train)^2)
    r2_train_inbuilt[i] <- 1 - ssr_train / sst_train
    
    # Test R^2 (inbuilt style)
    sst_test <- sum((y_test - mean(y_test))^2)
    ssr_test <- sum((y_test - yhat_test)^2)
    r2_test_inbuilt[i] <- 1 - ssr_test / sst_test
    
    # Manual R^2 for test (same formula as above, kept separate for clarity)
    r2_test_manual[i] <- 1 - ssr_test / sst_test
  }
  
  cat("Iterations:", n_iter, "\n")
  cat("Average Train R^2 (inbuilt):", mean(r2_train_inbuilt), "\n")
  cat("Average Test  R^2 (inbuilt):", mean(r2_test_inbuilt), "\n")
  cat("Average Test  R^2 (manual): ", mean(r2_test_manual), "\n")
  
  results_df <- data.frame(
    Iteration = 1:n_iter,
    R2_Score_Lasso_Inbuilt_Train = r2_train_inbuilt,
    R2_Score_Lasso_Inbuilt_Test  = r2_test_inbuilt,
    R2_Score_Lasso_Manual_Test   = r2_test_manual
  )
  
  write.csv(results_df, save_csv_path, row.names = FALSE)
}

cat("Running 70-30 validation for 100 iterations...\n")
run_lasso_validation(
  X_mat = X,
  Y_vec = Y,
  n_iter = 100,
  alphas = alphas,
  save_csv_path = file.path(save_path, "lasso_m2_70_30_validation_results_100it.csv")
)

cat("Lasso_Model_v2.R finished successfully.\n")
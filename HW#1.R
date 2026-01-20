# installing ISLR package
install.packages("ISLR")
library(ISLR)
library(dplyr)

#choosing college dataset - and exploring the dataset
head(College)
names(College)
dim(College)
summary(College)


#creating df with selected columns

df <- College[, -c(3, 4, 6, 8, 14, 15)]
df$Private <- as.factor(df$Private)

#checking correlation among variables
cor(df[, -1])

#normalizing the variables

df_scaled <- df %>%
  mutate(across(-Private, scale))

#building logistic regression model

logit_model <- glm(Private ~ ., data = df_scaled, family = binomial)
summary(logit_model)

#Now building regression model with
#K-fold Cross validation

k <- 10
n <- nrow(df)

folds <- sample(rep(1:k, length.out = n))

accuracy = numeric(k)

for (i in 1:k){
  #split data
  train_data <- df[folds != i,]
  test_data <- df[folds == k,]
  #scale using the training data
  x_train <- train_data[, -1]
  x_test <- test_data[, -1]

  means <- apply(x_train, 2, mean)
  sds <- apply(x_train, 2, sd)

  x_train_scaled <- scale(x_train, center = means, scale = sds)
  x_test_scaled <- scale(x_test, center = means, scale = sds)
  
  train_scaled <- data.frame(
    Private = train_data$Private,
    x_train_scaled
  )

  test_scaled <- data.frame(
    Private = test_data$Private,
    x_test_scaled
  )
  #fit regression
  model <- glm(Private ~ ., data = test_scaled, family = binomial)

  #predict probabilities
  prob <- predict(model, test_scaled, type = "response")

  #convert to class level
  pred <- ifelse(prob > 0.5, "Yes", "No")
  pred <- factor(pred, levels = c("Yes", "No"))

  #Accuracy
  accuracy[k] <- mean(pred == test_scaled$Private)
}

#cross-validated performance

mean(accuracy)
sd(accuracy)

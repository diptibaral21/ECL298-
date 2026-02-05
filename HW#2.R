# installing ISLR package
install.packages("ISLR")
library(ISLR)
library(dplyr)
library(randomForest)

#choosing college dataset - and exploring the dataset
head(College)
names(College)
dim(College)
summary(College)

#creating df with selected columns

college_df <- College[, -c(3, 4, 6, 8, 14, 15)]
college_df$Private <- as.factor(college_df$Private)

#fitting regression tree
#first we create a training set, and fit the tree to the trainig data

set.seed(1)
train <- sample(1:nrow(college_df), nrow(college_df)/2)
bag_college <- randomForest(
    Private ~ ., 
    data = college_df, 
    subset = train, 
    mtry = 4, 
    importance = TRUE)
bag_college

#variable importance

varImpPlot(bag_college)

#Random forest has low misclassification rates, especially for private colleges (Yes). OOB error rate indicates ~7.5% overall error on unseen data.
#The 5 most influential predictors are F.undergrad, Outstate, Apps, perc.Alumni and Room Board
# ECL298
This repository is to document my works from ECL298 class, winter quarter 2026 with Dr. Robert Hijmans. 

HW#1: R script that shows a form of regression and k-fold cross-validation 

-- For this HW I am using the dataset : College from ISLR package that has information related to a large number of US Colleges from the 1995 issue of US News and World Report. I am builiding a logistic regreesion model to predict whether a ceratin school is private or not using the following data from College Dataset: Apps, Top10perc, F.Undergrad, Outstate, Room.Board, Books, Personal, PhD, Terminal, S.F.Ratio, Expend student, and Grad.Rate. 

College Data Format:
A data frame with 777 observations on the following 18 variables. 
- Private: A factor with levels No and Yes indicating private or public university
- Apps: Number of applications received 
- Accept: Number of applications accepted 
- Enroll: Number of new students enrolled 
- Top10perc: Pct. new students from top 10% of H.S. class 
- Top25perc: Pct. new students from top 25% of H.S. class 
- F.Undergrad: Number of fulltime undergraduates 
- P.Undergrad: Number of parttime undergraduates 
- Outstate: Out-of-state tuition 
- Room.Board: Room and board costs 
- Books: Estimated book costs 
- Personal: Estimated personal spending 
- PhD: Pct. of faculty with Ph.D.’s 
- Terminal: Pct. of faculty with terminal degree 
- S.F.Ratio: Student/faculty ratio 
- perc.alumni: Pct. alumni who donate 
- Expend: Instructional expenditure per student 
- Grad.Rate: Graduation rate
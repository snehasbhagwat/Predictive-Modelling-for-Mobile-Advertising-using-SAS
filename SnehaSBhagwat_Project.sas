ODS HTML;

ODS LISTING CLOSE;

ODS GRAPHICS ON;
LIBNAME PRJ_DATA 'H:\Predictive Project';

/* Importing data into a data set */
DATA AdsData;
 set PRJ_DATA.DATA;
RUN;

/* Finding distinct values in categorical variables */
PROC SQL;
	select distinct publisher_id_class as Publishers from AdsData;
QUIT;
PROC SQL;
	select distinct device_make_class as Manufacturers from AdsData;
QUIT;
PROC SQL;
	select distinct device_os_class as OSVersion from AdsData;
QUIT;
PROC SQL;
	select count(distinct device_height) as Height from AdsData;
QUIT;
PROC SQL;
	select count(distinct device_width) as Width from AdsData;
QUIT;

/* Converting the device_platform_class which is a categorical variable to binary variable */
/* 1 = iOS and 0 = Android */
DATA AdsData;
 set AdsData;
 if (device_platform_class = 'iOS') then device_platform_class = 1;
 else device_platform_class = 0;
RUN;

/* Finding correlation between different variables */
PROC CORR data=AdsData;
RUN; 

/********************* TRAIN TEST SPLITTING *******************/
PROC SURVEYSELECT data=AdsData out=AdsData_sampled outall samprate=0.7 seed=100;
RUN;
DATA AdsData_training AdsData_test;
 set AdsData_sampled;
 if selected then output AdsData_training; 
 else output AdsData_test;
RUN;

/********************* MODEL BUILDING *******************/
/* Creating a smaller sample of train data set */
DATA trainsample; 
 set AdsData_training; 
 call streaminit(1);
 if rand('uniform') > 0.70;
RUN;

/* ASE in train sample and test data */
/* Forward Selection without interaction terms */
PROC GLMSELECT data=trainsample testdata=AdsData_test seed=10 plots=ase;
 class publisher_id_class(split) device_make_class(split) device_os_class(split) device_platform_class(split) wifi(split);
 linear: model install = publisher_id_class device_make_class device_os_class device_platform_class wifi device_height device_width device_volume resolution
  /selection=forward(select=sl sle=0.05) stats=all showpvalues hierarchy=single;
 performance buildsscp=incremental;
RUN;

/* Backward elimination without interaction terms */
PROC GLMSELECT data=trainsample testdata=AdsData_test seed=10 plots=ase;
 class publisher_id_class(split) device_make_class(split) device_os_class(split) device_platform_class(split) wifi(split);
 linear: model install = publisher_id_class device_make_class device_os_class device_platform_class wifi device_height device_width device_volume resolution 
  /selection=backward(select=sl sls=0.05) stats=all showpvalues hierarchy=single;
RUN; 

/* Stepwise Selection without interaction terms */
PROC GLMSELECT data=trainsample testdata=AdsData_test seed=1 plots=ase;
 class publisher_id_class(split) device_make_class(split) device_os_class(split) device_platform_class(split) wifi(split);
 linear: model install = publisher_id_class device_make_class device_os_class device_platform_class wifi device_height device_width device_volume resolution 
  /selection=stepwise(select=sl) stats=all showpvalues hierarchy=single;
 performance buildsscp=incremental;
RUN;

/* Forward Selection with interaction terms */
PROC GLMSELECT data=trainsample testdata=AdsData_test seed=10 plots=ase;
 class publisher_id_class(split) device_make_class(split) device_os_class(split) device_platform_class(split) wifi(split);
 linear: model install = publisher_id_class|device_make_class|device_os_class|device_platform_class|wifi|device_height|device_width|device_volume|resolution @2
  /selection=forward(select=sl sle=0.05) stats=all showpvalues hierarchy=single;
 performance buildsscp=incremental;
RUN;

/* Backward Elimination with interaction terms */
PROC GLMSELECT data=trainsample testdata=AdsData_test seed=10 plots=ase;
 class publisher_id_class(split) device_make_class(split) device_os_class(split) device_platform_class(split) wifi(split);
 linear: model install = publisher_id_class|device_make_class|device_os_class|device_platform_class|wifi|device_height|device_width|device_volume|resolution @2
  /selection=backward(select=sl sls=0.05) stats=all showpvalues hierarchy=single;
 performance buildsscp=incremental;
RUN;

/* Stepwise Selection with interaction terms */
PROC GLMSELECT data=trainsample testdata=AdsData_test seed=10 plots=ase;
 class publisher_id_class(split) device_make_class(split) device_os_class(split) device_platform_class(split) wifi(split);
 linear: model install = publisher_id_class|device_make_class|device_os_class|device_platform_class|wifi|device_height|device_width|device_volume|resolution @2
  /selection=stepwise(select=sl) stats=all showpvalues hierarchy=single;
 performance buildsscp=incremental;
RUN;

/* Backward Elimination with interaction terms and AIC for elimination */
PROC GLMSELECT data=trainsample testdata=AdsData_test seed=10 plots=ase;
 class publisher_id_class(split) device_make_class(split) device_os_class(split) device_platform_class(split) wifi(split);
 linear: model install = publisher_id_class|device_make_class|device_os_class|device_platform_class|wifi|device_height|device_width|device_volume|resolution @2
  /selection=backward(select=aic) stats=all showpvalues hierarchy=single;
 performance buildsscp=incremental;
RUN;

/* Backward Elimination with interaction terms and Mallows Cp for elimination */
PROC GLMSELECT data=trainsample testdata=AdsData_test seed=10 plots=ase;
 class publisher_id_class(split) device_make_class(split) device_os_class(split) device_platform_class(split) wifi(split);
 linear: model install = publisher_id_class|device_make_class|device_os_class|device_platform_class|wifi|device_height|device_width|device_volume|resolution @2
  /selection=backward(select=cp) stats=all showpvalues hierarchy=single;
 performance buildsscp=incremental;
RUN;

/* Stepwise with 5 fold cross validation */
PROC GLMSELECT data=trainsample testdata=AdsData_test seed=10 plots=all;
 class publisher_id_class(split) device_make_class(split) device_os_class(split) device_platform_class(split) wifi(split);
 linear: model install = publisher_id_class|device_make_class|device_os_class|device_platform_class|wifi|device_height|device_width|device_volume|resolution @2
  /selection=stepwise(select=cv) stats=all showpvalues hierarchy=single cvmethod=random(5);
 performance buildsscp=incremental;
RUN;

/* Stepwise with 10 fold cross validation */
PROC GLMSELECT data=trainsample testdata=AdsData_test seed=10 plots=all;
 class publisher_id_class(split) device_make_class(split) device_os_class(split) device_platform_class(split) wifi(split);
 linear: model install = publisher_id_class|device_make_class|device_os_class|device_platform_class|wifi|device_height|device_width|device_volume|resolution @2
  /selection=stepwise(select=cv) stats=all showpvalues hierarchy=single cvmethod=random(10);
 performance buildsscp=incremental;
RUN;

/* Stepwise with 5 fold cross validation and considering height and width as categorical variables */
PROC GLMSELECT data=trainsample testdata=AdsData_test seed=10 plots=all;
 class publisher_id_class(split) device_make_class(split) device_os_class(split) device_platform_class(split) wifi(split) device_height(split) device_width(split);
 linear: model install = publisher_id_class|device_make_class|device_os_class|device_platform_class|wifi|device_height|device_width|device_volume|resolution @2
  /selection=stepwise(select=cv) stats=all showpvalues hierarchy=single cvmethod=random(5);
 performance buildsscp=incremental;
RUN;

/* Backward Elimination with p-value criteria and considering height and width as categorical variables */
PROC GLMSELECT data=trainsample testdata=AdsData_test seed=10 plots=ase;
 class publisher_id_class(split) device_make_class(split) device_os_class(split) device_platform_class(split) wifi(split) device_height(split) device_width(split);
 linear: model install = publisher_id_class|device_make_class|device_os_class|device_platform_class|wifi|device_height|device_width|device_volume|resolution @2
  /selection=backward(select=sl) stats=all showpvalues hierarchy=single;
 performance buildsscp=incremental;
RUN;

/* Best Subset */
PROC GLMMOD data=trainsample outdesign=SubsetModel noprint; 
 class publisher_id_class device_make_class device_os_class device_platform_class wifi;
 model install = publisher_id_class device_make_class device_os_class device_platform_class wifi device_height device_width device_volume resolution / noint;
run;
PROC REG data=SubsetModel plots=none;
 model install = col2-col38 /selection=cp adjrsq aic bic best=10;
QUIT;

/********************* RUNNING BACKWARD ELIMINATION ON ENTIRE TRAIN DATASET *******************/

/* Backward Elimination with interaction terms */
PROC GLMSELECT data=AdsData_training testdata=AdsData_test seed=10 plots=ase outdesign=LinearProbModel;
 class publisher_id_class(split) device_make_class(split) device_os_class(split) device_platform_class(split) wifi(split);
 linear: model install = publisher_id_class|device_make_class|device_os_class|device_platform_class|wifi|device_height|device_width|device_volume|resolution @2
  /selection=backward(select=sl sls=0.05) stats=all showpvalues hierarchy=single;
 performance buildsscp=incremental;
RUN;

PROC CONTENTS data=LinearProbModel varnum;
RUN;

%put &_GLSMod;   

/********************* LOGISTIC REGRESSION *******************/

/* Counting number of 1s and 0s in install column */
PROC FREQ data=AdsData;
  table install;
RUN;

/* Forward Selection with interaction terms */
PROC HPLOGISTIC data=AdsData seed=10;
 class publisher_id_class(ref='1') device_make_class(ref='1') device_os_class(ref='1') device_platform_class(ref='1') wifi(ref='1');
 model install(event='1') = publisher_id_class|device_make_class|device_os_class|device_platform_class|wifi|device_height|device_width|device_volume|resolution @2;
 selection method=forward (select=sl sle=0.05) hierarchy=single;
RUN;

/* Stepwise Selection with interaction terms */
PROC HPLOGISTIC data=AdsData seed=10;
 class publisher_id_class(ref='1') device_make_class(ref='1') device_os_class(ref='1') device_platform_class(ref='1') wifi(ref='1');
 model install(event='1') = publisher_id_class|device_make_class|device_os_class|device_platform_class|wifi|device_height|device_width|device_volume|resolution @2;
 selection method=stepwise (select=sl) hierarchy=single;
RUN;

/* Forward Selection with interaction terms and using ASE to choose the model */
PROC HPLOGISTIC data=AdsData seed=10;
 class publisher_id_class(ref='1') device_make_class(ref='1') device_os_class(ref='1') device_platform_class(ref='1') wifi(ref='1');
 model install(event='1') = publisher_id_class|device_make_class|device_os_class|device_platform_class|wifi|device_height|device_width|device_volume|resolution @2;
 partition fraction(test=0.1 validate=0.1); 
 selection method=forward (select=sl choose=validate) hierarchy=single;
RUN;

/* Stepwise with interaction terms and using ASE to choose the model */
PROC HPLOGISTIC data=AdsData seed=10;
 class publisher_id_class(ref='1') device_make_class(ref='1') device_os_class(ref='1') device_platform_class(ref='1') wifi(ref='1');
 model install(event='1') = publisher_id_class|device_make_class|device_os_class|device_platform_class|wifi|device_height|device_width|device_volume|resolution @2;
 partition fraction(test=0.1 validate=0.1); 
 selection method=stepwise (select=sl choose=validate) hierarchy=single;
RUN;

/* Forward Selection with interaction terms, AIC Criteria and using ASE to choose the model */
PROC HPLOGISTIC data=AdsData seed=10;
 class publisher_id_class(ref='1') device_make_class(ref='1') device_os_class(ref='1') device_platform_class(ref='1') wifi(ref='1');
 model install(event='1') = publisher_id_class|device_make_class|device_os_class|device_platform_class|wifi|device_height|device_width|device_volume|resolution @2;
 partition fraction(test=0.1 validate=0.1); 
 selection method=forward (select=aic choose=validate) hierarchy=single;
RUN;

/* Stepwise with interaction terms, AIC Criteria and using ASE to choose the model */
PROC HPLOGISTIC data=AdsData seed=10;
 class publisher_id_class(ref='1') device_make_class(ref='1') device_os_class(ref='1') device_platform_class(ref='1') wifi(ref='1');
 model install(event='1') = publisher_id_class|device_make_class|device_os_class|device_platform_class|wifi|device_height|device_width|device_volume|resolution @2;
 partition fraction(test=0.1 validate=0.1); 
 selection method=stepwise (select=aic choose=validate) hierarchy=single;
RUN;

/* Considering device_height and device_width categorical variables */
/* Forward Selection with interaction terms and using ASE to choose the model */
PROC HPLOGISTIC data=AdsData seed=10;
 class publisher_id_class(ref='1') device_make_class(ref='1') device_os_class(ref='1') device_platform_class(ref='1') wifi(ref='1') device_height(ref='640') device_width(ref='640');
 model install(event='1') = publisher_id_class|device_make_class|device_os_class|device_platform_class|wifi|device_height|device_width|device_volume|resolution @2;
 partition fraction(test=0.1 validate=0.1); 
 selection method=backward (select=sl choose=validate) hierarchy=single;
RUN;

/* Stepwise with interaction terms and using ASE to choose the model */
PROC HPLOGISTIC data=AdsData seed=10;
 class publisher_id_class(ref='1') device_make_class(ref='1') device_os_class(ref='1') device_platform_class(ref='1') wifi(ref='1') ;
 model install(event='1') = publisher_id_class|device_make_class|device_os_class|device_platform_class|wifi|device_height|device_width|device_volume|resolution @2;
 partition fraction(test=0.1 validate=0.1); 
 selection method=stepwise (select=sl choose=validate) hierarchy=single;
RUN;

/* Storing and running final model */
PROC HPLOGISTIC data=AdsData seed=10 outest;
 ods output ParameterEstimates=LogitModel;
 class publisher_id_class(ref='1') device_make_class(ref='1') device_os_class(ref='1') device_platform_class(ref='1') wifi(ref='1');
 model install(event='1') = publisher_id_class|device_make_class|device_os_class|device_platform_class|wifi|device_height|device_width|device_volume|resolution @2;
 partition fraction(test=0.1 validate=0.1); 
 selection method=stepwise (select=sl choose=validate) hierarchy=single;
RUN;

/* Running model using Proc Logistic */
PROC LOGISTIC data=AdsData;
 class publisher_id_class(ref='1') device_make_class(ref='1') device_os_class(ref='1') device_platform_class(ref='1') wifi(ref='1');
 logit: model install(event='1') = publisher_id_class device_make_class wifi device_height;
RUN;

/********************* LOGISTIC REGRESSION WITH MODELING OF RARE EVENTS *******************/

/* Oversampling */
/*PROC SORT data=AdsData;
 by install;
RUN;
PROC SURVEYSELECT data=AdsData out=OversampledData method=urs rate=(0.01,1) seed = 10 outhits;
 strata install;
RUN;*/ /* Alternate method */

DATA OversampledData;
  set AdsData;
  if install=1 or (install=0 and ranuni(98765)<0.8/99) then output;
RUN;

PROC FREQ data=OversampledData;
  table install / out=spct(where=(install=1) rename=(percent=spct));
RUN;

PROC FREQ data=AdsData;
 table install / out=fpct(where=(install=1) rename=(percent=fpct));
RUN;

/* Running model using Proc Logistic */
PROC LOGISTIC data=OversampledData;
 class publisher_id_class(ref='1') device_make_class(ref='1') device_os_class(ref='1') wifi(ref='1');
 logit: model install(event='1') = publisher_id_class device_make_class wifi device_height;
 output out=outData;
RUN;

/* Adjusting intercept */ 
/* Referred this code from: Source: http://support.sas.com/kb/22/601.html */
DATA OversampledData;
 set OversampledData;
 if _n_=1 then set fpct(keep=fpct);
 if _n_=1 then set spct(keep=spct);
 p1=fpct/100; r1=spct/100;
 w=p1/r1; if install=0 then w=(1-p1)/(1-r1);
 off=log( (r1*(1-p1)) / ((1-r1)*p1) );
RUN;

PROC LOGISTIC data=OversampledData;
 class publisher_id_class(ref='1') device_make_class(ref='1') device_os_class(ref='1') wifi(ref='1');
 model install(event='1') = publisher_id_class device_make_class wifi device_height;
 output out=outData p=pnowt;
RUN;

/* Adjusted Model */
PROC LOGISTIC data=outData;
 class publisher_id_class(ref='1') device_make_class(ref='1') device_os_class(ref='1') wifi(ref='1'); 
 model install(event='1') = publisher_id_class device_make_class wifi device_height; weight w;
RUN;

/********************* GENERATING ROC TABLE AND FINDING LOWEST COST *******************/

/* Linear Probability Model */
/* Running Linear Probability model on Sampled Dataset */
PROC GLMSELECT data=AdsData_sampled testdata=AdsData_test seed=10 plots=ase outdesign=LinearProbModel1;
 class publisher_id_class(split) device_make_class(split) device_os_class(split) device_platform_class(split) wifi(split);
 linear: model install = publisher_id_class|device_make_class|device_os_class|device_platform_class|wifi|device_height|device_width|device_volume|resolution @2
  /selection=backward(select=sl sls=0.05) stats=all showpvalues hierarchy=single;
 performance buildsscp=incremental;
RUN;

PROC CONTENTS data=LinearProbModel1 varnum;
RUN;

%put &_GLSMod; 

DATA select;
 set AdsData_sampled;
 keep selected;
RUN;

DATA merged;
 merge select LinearProbModel1;
RUN;

PROC REG data=merged;
 model install = &_GLSMod;
 weight selected;
 output out=LinearModel_predict p=linear_predictions;
RUN;
QUIT;

/* Plotting ROC curve based on predictions from linear model */
PROC LOGISTIC data=LinearModel_predict plots=roc(id=prob);
 model install (event='1') = &_GLSMod / nofit;
 roc pred=linear_predictions;
 where selected=0;
RUN;

/* Making ROC Table for Linear Probability Model */
/* 0.05 level */
DATA ROC_Table1 (keep=ProbabilityLevel FP FN);
 set LinearModel_predict;
 where selected=0;
 ProbabilityLevel=0.05;
 if linear_predictions > 0.05 then PredictedValue=1;
 if install=1 and PredictedValue=0 then FN=1;
 if install=0 and PredictedValue=1 then FP=1;
RUN;
/* 0.045 level */
DATA ROC_Table2 (keep=ProbabilityLevel FP FN);
 set LinearModel_predict;
 where selected=0;
 ProbabilityLevel=0.045;
 if linear_predictions > 0.045 then PredictedValue=1;
 if install=1 and PredictedValue=0 then FN=1;
 if install=0 and PredictedValue=1 then FP=1;
RUN;
/* 0.040 level */
DATA ROC_Table3 (keep=ProbabilityLevel FP FN);
 set LinearModel_predict;
 where selected=0;
 ProbabilityLevel=0.040;
 if linear_predictions > 0.040 then PredictedValue=1;
 if install=1 and PredictedValue=0 then FN=1;
 if install=0 and PredictedValue=1 then FP=1;
RUN;
/* 0.035 level */
DATA ROC_Table4 (keep=ProbabilityLevel FP FN);
 set LinearModel_predict;
 where selected=0;
 ProbabilityLevel=0.035;
 if linear_predictions > 0.035 then PredictedValue=1;
 if install=1 and PredictedValue=0 then FN=1;
 if install=0 and PredictedValue=1 then FP=1;
RUN;
/* 0.030 level */
DATA ROC_Table5 (keep=ProbabilityLevel FP FN);
 set LinearModel_predict;
 where selected=0;
 ProbabilityLevel=0.03;
 if linear_predictions > 0.03 then PredictedValue=1;
 if install=1 and PredictedValue=0 then FN=1;
 if install=0 and PredictedValue=1 then FP=1;
RUN;
/* 0.025 level */
DATA ROC_Table6 (keep=ProbabilityLevel FP FN);
 set LinearModel_predict;
 where selected=0;
 ProbabilityLevel=0.025;
 if linear_predictions > 0.025 then PredictedValue=1;
 if install=1 and PredictedValue=0 then FN=1;
 if install=0 and PredictedValue=1 then FP=1;
RUN;
/* 0.020 level */
DATA ROC_Table7 (keep=ProbabilityLevel FP FN);
 set LinearModel_predict;
 where selected=0;
 ProbabilityLevel=0.02;
 if linear_predictions > 0.02 then PredictedValue=1;
 if install=1 and PredictedValue=0 then FN=1;
 if install=0 and PredictedValue=1 then FP=1;
RUN;
/* 0.015 level */
DATA ROC_Table8 (keep=ProbabilityLevel FP FN);
 set LinearModel_predict;
 where selected=0;
 ProbabilityLevel=0.015;
 if linear_predictions > 0.015 then PredictedValue=1;
 if install=1 and PredictedValue=0 then FN=1;
 if install=0 and PredictedValue=1 then FP=1;
RUN;
/* 0.010 level */
DATA ROC_Table9 (keep=ProbabilityLevel FP FN);
 set LinearModel_predict;
 where selected=0;
 ProbabilityLevel=0.010;
 if linear_predictions > 0.010 then PredictedValue=1;
 if install=1 and PredictedValue=0 then FN=1;
 if install=0 and PredictedValue=1 then FP=1;
RUN;
/* 0.005 level */
DATA ROC_Table10 (keep=ProbabilityLevel FP FN);
 set LinearModel_predict;
 where selected=0;
 ProbabilityLevel=0.005;
 if linear_predictions > 0.005 then PredictedValue=1;
 if install=1 and PredictedValue=0 then FN=1;
 if install=0 and PredictedValue=1 then FP=1;
RUN;
/* 0.001 level */
DATA ROC_Table11 (keep=ProbabilityLevel FP FN);
 set LinearModel_predict;
 where selected=0;
 ProbabilityLevel=0.001;
 if linear_predictions > 0.001 then PredictedValue=1;
 if install=1 and PredictedValue=0 then FN=1;
 if install=0 and PredictedValue=1 then FP=1;
RUN;

/* 0.050 level */
PROC SQL;
  create table Table1 as select distinct ProbabilityLevel, count(FP) as FalsePositiveCount, count(FN) as FalseNegativeCount from ROC_Table1;
QUIT;
/* 0.045 level */
PROC SQL;
  create table Table2 as select distinct ProbabilityLevel, count(FP) as FalsePositiveCount, count(FN) as FalseNegativeCount from ROC_Table2;
QUIT;
/* 0.040 level */
PROC SQL;
  create table Table3 as select distinct ProbabilityLevel, count(FP) as FalsePositiveCount, count(FN) as FalseNegativeCount from ROC_Table3;
QUIT;
/* 0.035 level */
PROC SQL;
  create table Table4 as select distinct ProbabilityLevel, count(FP) as FalsePositiveCount, count(FN) as FalseNegativeCount from ROC_Table4;
QUIT;
/* 0.030 level */
PROC SQL;
  create table Table5 as select distinct ProbabilityLevel, count(FP) as FalsePositiveCount, count(FN) as FalseNegativeCount from ROC_Table5;
QUIT;
/* 0.025 level */
PROC SQL;
  create table Table6 as select distinct ProbabilityLevel, count(FP) as FalsePositiveCount, count(FN) as FalseNegativeCount from ROC_Table6;
QUIT;
/* 0.020 level */
PROC SQL;
  create table Table7 as select distinct ProbabilityLevel, count(FP) as FalsePositiveCount, count(FN) as FalseNegativeCount from ROC_Table7;
QUIT;
/* 0.015 level */
PROC SQL;
  create table Table8 as select distinct ProbabilityLevel, count(FP) as FalsePositiveCount, count(FN) as FalseNegativeCount from ROC_Table8;
QUIT;
/* 0.010 level */
PROC SQL;
  create table Table9 as select distinct ProbabilityLevel, count(FP) as FalsePositiveCount, count(FN) as FalseNegativeCount from ROC_Table9;
QUIT;
/* 0.005 level */
PROC SQL;
  create table Table10 as select distinct ProbabilityLevel, count(FP) as FalsePositiveCount, count(FN) as FalseNegativeCount from ROC_Table10;
QUIT;
/* 0.001 level */
PROC SQL;
  create table Table11 as select distinct ProbabilityLevel, count(FP) as FalsePositiveCount, count(FN) as FalseNegativeCount from ROC_Table11;
QUIT;

/* Union of all the SQL Tables */
PROC SQL;
 create table ROC_Linear as
 select * from Table1
 union
 select * from Table2
 union
 select * from Table3
 union
 select * from Table4
 union
 select * from Table5
 union
 select * from Table6
 union
 select * from Table7
 union
 select * from Table8
 union
 select * from Table9
 union
 select * from Table10
 union
 select * from Table11;
QUIT;

/* Finding total cost of misclassification for each probability */
DATA ROC_Linear_Table;
 set ROC_Linear;
 Linear_mscost = 1*FalsePositiveCount + 100*FalseNegativeCount;
RUN;

/* Sorting Data set to find out lowest cost and threshold associated with it */
PROC SORT data = ROC_Linear_Table out = ROC_Linear_Table;
 by Linear_mscost;
RUN;

/* Logistic Regression Model */
/*Estimating the model on train data */
PROC LOGISTIC data=AdsData_training outmodel=LogitModelROC;
 class publisher_id_class(ref='1') device_make_class(ref='1') device_os_class(ref='1') device_platform_class(ref='1') wifi(ref='1');
 logit: model install(event='1') = publisher_id_class device_make_class wifi device_height;
RUN;

/* Using estimated model to score test data and create a roc table */
PROC LOGISTIC inmodel=LogitmodelROC;
 score data=AdsData_test outroc=Ads_logit_roc;
RUN;

/* ROC Curve */
PROC LOGISTIC data=AdsData_training;
 class publisher_id_class(ref='1') device_make_class(ref='1') device_os_class(ref='1') device_platform_class(ref='1') wifi(ref='1');
 logit: model install(event='1') = publisher_id_class device_make_class wifi device_height;
 score data=AdsData_test out=Ads_logit_predict;
RUN;

PROC LOGISTIC data=Ads_logit_predict plots=roc(id=prob);
 class publisher_id_class(ref='1') device_make_class(ref='1') device_os_class(ref='1') device_platform_class(ref='1') wifi(ref='1');
 model install(event='1') = publisher_id_class  device_make_class wifi device_height /nofit;
 roc pred=p_1;
RUN;

/* Finding total cost of misclassification for each probability */
DATA Ads_logit_roc;
 set Ads_logit_roc;
 mscost = 1*_FALPOS_ + 100*_FALNEG_;
RUN;

/* Sorting Data set to find out lowest cost and threshold associated with it */
PROC SORT data = Ads_logit_roc out = Ads_logit_roc;
 by mscost;
RUN;

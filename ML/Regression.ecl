﻿IMPORT * FROM $;
IMPORT ML.mat as Mat;
/*
	The object of the regression module is to generate a regression model.
  A regression model relates the dependent variable Y to a function of
	the independent variables X, and a vector of unknown parameters Beta.
		Y = f(X,Beta)
	A regression model is an algorithm that estimates the unknown parameters 
  Beta so that a regression function Y = f(X,Beta) can be constructed
*/
EXPORT Regression := MODULE

// OrdinaryLeastSquares, aka LinearLeastSquares, the simplest and most common estimator 
// Beta = (Inv(X'*X)*X')*Y
EXPORT OLS(DATASET(Types.NumericField) X,DATASET(Types.NumericField) Y) := MODULE
  mX_0 := Types.ToMatrix(X);
	SHARED mX := Mat.InsertColumn(mX_0, 1, 1.0); // Insert X1=1 column 
	SHARED mXt := Mat.Trans(mX);
	mY := Types.ToMatrix(Y);
	SHARED Betas := Mat.Mul (Mat.Mul(Mat.Inv( Mat.Mul(mXt, mX) ), mXt), mY);
	// We want to return the data so that the ID field reflects the 'column number' of the variable we were targeting
	rBetas := Types.FromMatrix( Mat.Trans(Betas) );
	// We also need to move the 'constant' term into column 0
	sBetas := PROJECT(rBetas,TRANSFORM(Types.NumericField,SELF.Number := LEFT.Number-1,SELF := LEFT));
  EXPORT Beta := sBetas;
	
	// use calculated estimator to predict Y values
	Y_estM := Mat.Trans(Mat.Mul(Mat.Trans(Betas) , mXt));	
	Y_est := Types.FromMatrix(Y_estM);
	// Y.number = number*2; Y_est.number = number*2+1;
	Y_est1 := PROJECT(Y_est, TRANSFORM(Types.NumericField, SELF.number := 2*LEFT.number+1; SELF := LEFT));
	Y1 := PROJECT(Y, TRANSFORM(Types.NumericField, SELF.number := 2*LEFT.number; SELF := LEFT));

	SHARED corr_ds := Correlate(Y1+Y_est1).Simple;

	CoRec := RECORD
		Types.t_fieldnumber number;
		Types.t_fieldreal   RSquared;
  END;

	CoRec getResult(corr_ds le) :=TRANSFORM 
		SELF.number := le.left_number/2; 
		SELF.RSquared := le.pearson*le.pearson ;
	END;
	// R^2 : square of the correlation coefficient between the observed and modeled (predicted) data values
	// Statistic that gives information about the goodness of fit of a model
	// It estimates the fraction of the variance in Y that is explained by X
  EXPORT RSquared := PROJECT(corr_ds(left_number&1=0,left_number+1=right_number), getResult(LEFT));	
	
	K := COUNT(FieldAggregates(X).Cardinality); // # of independent (explanatory) variables
	Singles := FieldAggregates(Y).Simple;
	tmpRec := RECORD
		RECORDOF(Singles);
		Types.t_fieldreal	RSquared;
	END;
	
	Singles1 := JOIN(Singles, RSquared, LEFT.number=RIGHT.number, 
					TRANSFORM(tmpRec,  SELF.RSquared := RIGHT.RSquared, SELF := LEFT));
	
	AnovaRec := RECORD
		Types.t_fieldnumber 	number;
		Types.t_RecordID			Model_DF; // Degrees of Freedom
		Types.t_fieldreal			Model_SS; // Sum of Squares
		Types.t_fieldreal			Model_MS; // Mean Square
		Types.t_fieldreal			Model_F;  // F-value
		Types.t_RecordID			Error_DF; // Degrees of Freedom
		Types.t_fieldreal			Error_SS; 
		Types.t_fieldreal			Error_MS;	
		Types.t_RecordID	  	Total_DF; // Degrees of Freedom
		Types.t_fieldreal			Total_SS;	// Sum of Squares
	END;

	AnovaRec getResult(tmpRec le) :=TRANSFORM 
		SST := le.var*le.countval;
		SSM := SST*le.RSquared;
		
		SELF.number := le.number; 
		SELF.Total_SS := SST;
		SELF.Model_SS := SSM; 
		SELF.Error_SS := SST - SSM;
		SELF.Model_DF := k;
		SELF.Error_DF := le.countval-k-1;
		SELF.Total_DF := le.countval-1;
		SELF.Model_MS := SSM/k; 
		SELF.Error_MS := (SST - SSM)/(le.countval-k-1); 
	  SELF.Model_F := (SSM/k)/((SST - SSM)/(le.countval-k-1));
	END;

	// http://www.stat.yale.edu/Courses/1997-98/101/anovareg.htm
	// Tested using the "Healthy Breakfast" dataset
  EXPORT Anova := PROJECT(Singles1, getResult(LEFT));	
END;
END;
*1.	Data Import
	Import the data from the provided excel file into SAS using Proc Import;
	
FILENAME REFFILE '/home/u63025740/BAN110/Life Expectancy Data (2).xlsx';
options validvarname=v7;

PROC IMPORT DATAFILE=REFFILE DBMS=XLSX OUT=rawData;
	GETNAMES=YES;
RUN;

*2. Data Cleaning
	2.1. Extract relevant data from the original dataset;
* Before extract data, we made assumption that
	 any zero values from the columns are same as missing values;

data extractData;
	set rawData (keep=country Year status Life_expectancy Adult_Mortality 
		infant_deaths Hepatitis_B gdp population percentage_expenditure _BMI 
		under_five_deaths Income_composition_of_resources Schooling Total_expenditure);

	if Life_expectancy=0 then
		Life_expectancy=.;
	if Adult_Mortality=0 then
		Adult_Mortality=.;
	if infant_deaths=0 then
		infant_deaths=.;
	if Hepatitis_B=0 then
		Hepatitis_B=.;
	if gdp=0 then
		gdp=.;
	if population=0 then
		population=.;
	if percentage_expenditure=0 then
		percentage_expenditure=.;
	if _BMI=0 then
		_BMI=.;
	if under_five_deaths=0 then
		under_five_deaths=.;
	if Income_composition_of_resources=0 then
		Income_composition_of_resources=.;
	if Schooling=0 then
		Schooling=.;
	if Total_expenditure=0 then
		Total_expenditure=.;
run;

*2.2. Convert a numeric column to character column or vice versa: 
	according to the result of PROC CONTENTS, format of all variables is correct;

PROC CONTENTS DATA=extractData;
RUN;

*2.3.	Create a new column based on existing columns and use it in your analysis
 	Creating a mean of mortality rate based on existing columns and number percentage of without HepatitisB vaccination
 	New columns will be created after data cleaning process;
 
*2.4. Identify missing values and remove / replace using an appropriate technique;

proc means data=extractData NMISS mean;
run;

proc format;
	value $missfmt ' '='Missing' other='Not Missing';
run;

proc freq data=extractData;
	format _CHAR_ $missfmt.;
	tables _CHAR_ / missing missprint nocum nopercent;
run;

* character values do not have missings;

* find mean for each country;
proc means data=extractData n mean std;
	class country;
	output out=temp(drop=_type_ _freq_) mean=std= /autoname;
run;

* The output data still contains missing value 
	since some countries' whole column data is missing;
proc means data=temp nmiss;
run;

* So we replace those missing values by overall mean;
proc standard data=temp replace out=Mean_Std;
run;

proc means data=Mean_Std nmiss;
run;

* replacing missing values with mean of each variable by country;
proc sort data=extractData out=sortE;
	by country;
run;

proc sort data=Mean_Std out=sortM;
	by country;
run;

data noMissing;
	merge sortE sortM;
	by country;

	if Life_expectancy=. then
		Life_expectancy=Life_expectancy_mean;
	if Adult_Mortality=. then
		Adult_Mortality=Adult_Mortality_mean;
	if infant_deaths=. then
		infant_deaths=infant_deaths_mean;
	if Hepatitis_B=. then
		Hepatitis_B=Hepatitis_B_mean;
	if gdp=. then
		gdp=gdp_mean;
	if population=. then
		population=population_mean;
	if percentage_expenditure=. then
		percentage_expenditure=percentage_expenditure_mean;
	if _BMI=. then
		_BMI=_BMI_mean;
	if under_five_deaths=. then
		under_five_deaths=under_five_deaths_mean;
	if Income_composition_of_resources=. then
		Income_composition_of_resources=Income_composition_of_res_mean;
	if Schooling=. then
		Schooling=Schooling_mean;
	if Total_expenditure=. then
		Total_expenditure=Total_expenditure;

	if country ne '';
	keep country year status Life_expectancy Adult_Mortality infant_deaths Hepatitis_B 
		gdp population percentage_expenditure _BMI under_five_deaths 
		Income_composition_of_resources Schooling Total_expenditure;
run;

proc means data=noMissing NMISS mean;
run;

*2.5. Use built-in SAS function(s) to perform data cleaning;
* Identify if data contains any duplicates by setting country and year as primary key;

data findDuplicate;
   set noMissing;
   PK = compress(cat(country, year),' ');
run;

proc sort data=findDuplicate out=demo;
   by PK;
run;

data duplicateL;
	set demo;
	by PK;
	if first.PK=0 or last.PK=0 then output;
run;

proc print data=duplicateL;
run;
* No result is shown from PROC PRINT, there has no duplicate for this dataset;

*2.6. Identify outliers and deal with them in an appropriate manner;
*observing outliers using proc univariate;

proc univariate data=noMissing;
	histogram / normal;
run;

* deleting outliers of some important columns;

proc means data=noMissing;
	var Life_expectancy Adult_Mortality gdp population;
	output out=Mean_Std1(drop=_type_ _freq_) mean=std= /autoname;
run;

data lifeExpentancy_clean;
	set noMissing;

	if _n_=1 then
		set Mean_Std1;

	if Life_expectancy_Mean - 2*Life_expectancy_StdDev<=Life_expectancy <=Life_expectancy_Mean + 2*Life_expectancy_StdDev;

	if Adult_Mortality_Mean - 2*Adult_Mortality_StdDev<=Adult_Mortality <=Adult_Mortality_Mean + 2*Adult_Mortality_StdDev;

	if gdp_Mean - 2*gdp_StdDev<=gdp <=gdp_Mean + 2*gdp_StdDev;

	if population_Mean - 2*population_StdDev<=population <=population_Mean + 2*population_StdDev;
	* generating new columns for further analysis;
	Nonvaccine_Hepatit_B=100-Hepatitis_B;
	drop Life_expectancy_Mean Life_expectancy_StdDev Adult_Mortality_Mean 
		Adult_Mortality_StdDev gdp_Mean gdp_StdDev population_Mean population_StdDev;
run;

proc univariate data=lifeExpentancy_clean;
	histogram / normal;
run;

*3	Joining and Merging;
* Import the raw data;
proc import out=suicide (rename=('country-year'n=country_year)) 
		datafile='/home/u63025740/BAN110/Suicide Rate Data.csv' dbms=csv 
		Replace;
	getnames=yes;
	guessingrows=28000;
run;

proc print data=suicide (obs=10);
run;

* clean the outsourced data;
proc sort data=suicide out=suicide_sorted;
	by country_year;
run;

data suicide_clean;
	set suicide_sorted;
	format suicide_total 10. population_total comma14.0 suicide_per_100K_pop 5.2;
	by country_year;

	if first.country_year then
		do;
			suicide_total=0;
			population_total=0;
		end;
	suicide_total + suicides_no;
	population_total + population;
	suicide_per_100K_pop=(suicide_total/population_total)*100000;

	if last.country_year;
	drop sex age suicides_no population population_total generation 
		'HDI for year'n 'suicides/100k pop'n ' gdp_for_year ($) 'n 
		'gdp_per_capita ($) 'n;
run;

proc print data=suicide_clean (obs=10);
run;

* setting primary key from life expentacy data;
data lifeExpentancy_country_year;
	set lifeExpentancy_clean;
	country_year=cat(strip(country), year);
run;

proc sort data=lifeExpentancy_country_year out=lifeExpentancy_sorted;
	by country_year;
run;

* merging two data;
data lifeExpentancy_final;
	merge lifeExpentancy_sorted(in=lifeExp) suicide_clean(in=suic);
	by country_year;
	if lifeExp and suic;
run;

proc print data=lifeExpentancy_final (obs=1000);
run;

proc means data=lifeExpentancy_final;
run;


* section 4
question1
We are a pharmaceutical company and we have launched a new drug that is supposed to help
 with depression, anxiety, and other disorders and we want to launch this drug into a 
 new country so we use this data to get the suicide rates per 100k and launch 
 the drug in the country with highest suicide rates.;

*SAS solution;
proc means data=lifeExpentancy_final max;
	var suicide_per_100K_pop;
	output out=Maximum(drop=_type_ _freq_) max= /autoname;
run;

proc print data=Maximum;
run;

data lifeExpentancy_final3 (keep=country) ;
set lifeExpentancy_final;
if _n_= 1 then set Maximum;
if suicide_per_100K_pop=suicide_per_100K_pop_Max;
run;
proc print noobs;
run;

*SQL solution;
proc sql;
	select country from lifeExpentancy_final 
		where Status='Developed' and year=2015 group by country HAVING 
		SUM(suicide_per_100K_pop)=(SELECT MAX(sum) FROM (SELECT country, 
		SUM(suicide_per_100K_pop) AS sum FROM lifeExpentancy_final WHERE 
		Status='Developed' AND year=2015 GROUP BY country));
quit;

*question2
We are a pharmaceutical company, looking to expand our vaccine for Hepatitis B into the international market.
First, we get the number of latest year -olds (%) who have not taken the Hepatitis B (HepB)  vaccine.
Then we multiply GDP per capita with the GDP % they are willing to spend on health.
 This will give us the absolute amount of GDP per capita they are willing to spend on health.
Next, we multiply the number of unvaccinated children by the absolute amount of GDP per capita they are willing to spend on health.
 This new variable created will help us know the biggest potential market that we should tap.;

data potential_countries (keep= country Nonvaccine_Hepatit_B SpendOnHealth budget);
set lifeExpentancy_final;
SpendOnHealth= GDP*Total_expenditure/100 ;
budget= SpendOnHealth*Nonvaccine_Hepatit_B/100 ;
where year=2014;
format budget Dollar9.3
SpendOnHealth Dollar9.3;
run;
proc sort data=potential_countries;
by descending budget;
run;

*question3
as a pharmacy company partnering with WHO we want to build a model to calculate
 the coefficient of each variable on life expectancy and build a model to be able
 to predict life expectancy of different countries;
 
 proc reg data=lifeExpentancy_clean;
 model Life_expectancy=Adult_Mortality infant_deaths Hepatitis_B gdp 
 population percentage_expenditure under_five_deaths
 Income_composition_of_resources Schooling Total_expenditure year/
 selection= backward;
 
 
 
 




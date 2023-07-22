*1.	Extract relevant data from the original dataset;
FILENAME REFFILE '/home/u63025740/BAN110/Life Expectancy Data (2).xlsx';
options validvarname=v7;
PROC IMPORT DATAFILE=REFFILE
	DBMS=XLSX
	OUT=rawData;
	GETNAMES=YES;
RUN;

PROC CONTENTS DATA=rawData; RUN;

*2. 2.	Convert a numeric column to character column or vice versa: 
format of all variables is correct;

*3.3.	Create a new column based on existing columns and use it in your analysis
 Creating a mean of mortality rate based on existing columns and number percentage of without HepatitisB vaccination. ;

proc means data=rawData NMISS mean;
run;

data lifeExpentancy1;
set rawData (keep= country Year status
Life_expectancy
Adult_Mortality
infant_deaths
Hepatitis_B
gdp
population
percentage_expenditure _BMI
under_five_deaths
Income_composition_of_resources
Schooling);
Avg_Mortality_Rate= ((Adult_Mortality/10)+(Infant_deaths/10))/2;
Nonvaccine_Hepatit_B=100-Hepatitis_B;
run;


*4.	Identify missing values and remove / replace using an appropriate technique;  

proc means data=lifeExpentancy1 NMISS mean;
run;

proc format;
	value $missfmt ' '='Missing' other='Not Missing';
run;

proc freq data=lifeExpentancy1;
	format _CHAR_ $missfmt.;
	tables _CHAR_ / missing missprint nocum nopercent;
run;
* character values do not have missings;

* replacing missing values with mean of each variable;

proc Standard data=lifeExpentancy1 replace out=lifeExpentancy2;
	var Life_expectancy Schooling Adult_Mortality _BMI Income_composition_of_resources
	Avg_Mortality_Rate gdp population Hepatitis_B Nonvaccine_Hepatit_B ;
run;

proc means data=lifeExpentancy2 NMISS mean;
run;
*5. 5.	Use built-in SAS function(s) to perform data cleaning, e.g., extracting year from the data column etc.
year column is already extracted;

*6.	Identify outliers and deal with them in an appropriate manner;

*observing outliers using proc univariate;
proc univariate data= lifeExpentancy2;
 histogram / normal;
 run; 
 
* deleting outliers of some important columns;
proc means data=lifeExpentancy2;
	var Life_expectancy Adult_Mortality gdp population;
	output out=Mean_Std(drop=_type_ _freq_) mean= std= /autoname;
run;

proc print data=Mean_Std;
run;

data lifeExpentancy_clean;
	set lifeExpentancy2;
	if _n_= 1 then set Mean_Std;
	if Life_expectancy_Mean - 2*Life_expectancy_StdDev<=Life_expectancy <= Life_expectancy_Mean + 2*Life_expectancy_StdDev;
	if Adult_Mortality_Mean - 2*Adult_Mortality_StdDev<=Adult_Mortality <= Adult_Mortality_Mean + 2*Adult_Mortality_StdDev;
	if gdp_Mean - 2*gdp_StdDev<=gdp <= gdp_Mean + 2*gdp_StdDev;
	if population_Mean - 2*population_StdDev<=population <= population_Mean + 2*population_StdDev;
	drop Life_expectancy_Mean Life_expectancy_StdDev Adult_Mortality_Mean Adult_Mortality_StdDev gdp_Mean gdp_StdDev population_Mean population_StdDev
run;


proc univariate data= lifeExpentancy_clean;
 histogram / normal;
 run;
 








proc import out=suicide (rename =('country-year'n = country_year)) datafile='/home/u63025740/BAN110/Suicide Rate Data.csv' dbms=csv Replace;
getnames=yes;
guessingrows=28000;
run;

proc print data=suicide (obs=10);
run;


proc sort data=suicide out=suicide_sorted;
by country_year;
run;


data suicide_clean;
set suicide_sorted;
format suicide_total 10. population_total comma14.0 suicide_per_100K_pop 5.2;
by country_year;
if first.country_year then do;
suicide_total=0;
population_total =0;
end;
suicide_total + suicides_no;
population_total + population;
suicide_per_100K_pop = (suicide_total/population_total)*100000;
if last.country_year;
drop sex age suicides_no population population_total generation 'HDI for year'n 'suicides/100k pop'n ' gdp_for_year ($) 'n 'gdp_per_capita ($) 'n;
run;


proc print data=suicide_clean (obs=10);
run;


data lifeExpentancy_country_year;
set lifeExpentancy_clean;
country_year=cat(strip(country),year);
run;


proc sort data=lifeExpentancy_country_year out=lifeExpentancy_sorted;
by country_year;
run;

data lifeExpentancy_final;
merge lifeExpentancy_sorted(in=lifeExp) suicide_clean(in=suic);
by country_year;
if lifeExp and suic;
run;

proc print data=lifeExpentancy_final (obs=1000);
run;
proc means data=lifeExpentancy_final;
run;



proc sql;
select country, sum(suicide_per_100K_pop) as sum from lifeExpentancy_final
where Status='Developed' and year=2015
group by country
HAVING SUM(suicide_per_100K_pop) = (
    SELECT MAX(sum) FROM (
        SELECT country, SUM(suicide_per_100K_pop) AS sum
        FROM lifeExpentancy_final
        WHERE Status='Developed' AND year=2015
        GROUP BY country));
quit;






options ls=72 nodate;
libname worklib '/folders/myfolders/sasuser.v94';


* Import IPO data from Excel;

proc import datafile="/folders/myfolders/sasuser.v94/IPOsFrom1970To2006.xls"
	dbms=xls
	out=worklib.ipo REPLACE;
  	sheet="IPO";
run;

data d;
	set worklib.ipo;
	if high=-9999 then high=.;
	if low=-9999 then low=.;
	if amend_high=-9999 then amend_high=.;
	if amend_low=-9999 then amend_low=.;
	offer_date_sas=mdy(int(mod(offer_date,10000)/100),mod(offer_date,100),int(offer_date/10000));
	year_ipo=year(offer_date_sas);
	dollar_width=high-low;
	perc_width=(high-low)/low;
	expected_price=(high+low)/2;
	delta_offer=(offer_price-expected_price)/expected_price;
	ret=100*(close_price-offer_price)/offer_price;
	if offer_price<low then
		subsample="Offer below range";
	else
		if offer_price>high then
			subsample="Offer over range";
		else
			subsample="Offer in range";
	label 
		delta_offer="% change in offer price"
	   offer_date_sas="Offering Date";
	format 
	   offer_date_sas date9.;
	if 19720101<=offer_date<=19821231 then period="period1";
	if 19830101<=offer_date<=19870930 then period="period2";
	if 19871001<=offer_date<=19911231 then period="period3";
	if 19920101<=offer_date<=19951231 then period="period4";
	if 19960101<=offer_date<=19991231 then period="period5";
	if 20000101<=offer_date<=20061231 then period="period6";
run;

* Compute market power based on the number of offerings;
* underwritten by each underwriter in the period;

data d1;
	set d;
	where period="period1";
run;

proc sort data=d1;by first_uwr;run;

proc means data=d1 noprint;
	output out=d1_uwr_all 
		n(permno)=num_issues_all;
run;

proc means data=d1 noprint;
	output out=d1_uwr 
		n(permno)=num_issues;
	by first_uwr;
run;

data d1_uwr;
	if _n_=1 then set d1_uwr_all;
	set d1_uwr;
	market_power=num_issues/num_issues_all;
	label 
		market_power="Market share";
run;

proc sql;
create table b as
select 
	d1.*,
	d1_uwr.market_power
from 
	d1 left join d1_uwr
on 
	d1.first_uwr=d1_uwr.first_uwr
order by
    offer_date_sas;
quit;

* Generate table with basic statistics;

*proc sort data=b;
*	by subsample;
*run;

*proc means data=b noprint;
*	output out=b_stats_1 
		n(permno)=num_issues
		mean(dollar_width)=dollar_width
		mean(perc_width)=perc_width
		mean(expected_price)=expected_price
        mean(offer_price)=offer_price
		mean(ret)=ret
		median(dollar_width)=mdollar_width
		median(perc_width)=mperc_width
		median(expected_price)=mexpected_price
        median(offer_price)=moffer_price;
*run;

*data b_stats_1;
*	set b_stats_1;
*	subsample="All IPOs";
*run;

*proc means data=b noprint;
*	output out=b_stats_2 
		n(permno)=num_issues
		mean(dollar_width)=dollar_width
		mean(perc_width)=perc_width
		mean(expected_price)=expected_price
        mean(offer_price)=offer_price
		mean(ret)=ret
		median(dollar_width)=mdollar_width
		median(perc_width)=mperc_width
		median(expected_price)=mexpected_price
        median(offer_price)=moffer_price;
*	by subsample;
*run;

*data b_stats;
*	set b_stats_1 b_stats_2;
*run;

*proc print data=b_stats label noobs;
*	title 'Basic statistics: IPOs 1972.01-1982.12';
*	var subsample num_issues dollar_width perc_width expected_price offer_price ret;
*	label
		num_issues="Number of issues"
		dollar_width="Dollar width"
		perc_width="Percent width"
		expected_price="Expected offer"
		offer_price="Actual offer"
        ret="Initial returns";
*run;

*proc print data=b_stats label noobs;
*	var subsample num_issues mdollar_width mperc_width mexpected_price moffer_price;
*	label
		num_issues="Number of issues"
		mdollar_width="Median dollar width"
		mperc_width="Median percent width"
		mexpected_price="Median expected offer"
		moffer_price="Median ctual offer";
*run;

* Run regression and analyze its results for different period;

proc reg data=b;
	title '1972.01-1982.12 Regression results';
	model ret=delta_offer market_power;
	ODS OUTPUT ParameterEstimates=parms_out;
run;
* outest=reg tableout noprint;
quit;

%table(parms_out);

*create a cute table;
data parms;
	set parms_out;
	tvalue2=put(tvalue,7.2); 
	if probt<0.1 then p='*  ';
	if probt<0.05 then p='** '; 
	if probt<0.01 then p='***';
	T=compress('['||tvalue2||']'); 
	PARAM=compress(put(estimate,7.3)||p);
run;
proc transpose data=parms out=parms1;
var param T p;
by variable;
run;
data parms1;
set parms1;
by variable;
if first.variable=0 then variable=.;
run;

data d2;
	set d;
	where period="period2";
run;

proc sort data=d2;by first_uwr;run;

proc means data=d2 noprint;
	output out=d2_uwr_all 
		n(permno)=num_issues_all;
run;

proc means data=d2 noprint;
	output out=d2_uwr 
		n(permno)=num_issues;
	by first_uwr;
run;

data d2_uwr;
	if _n_=1 then set d2_uwr_all;
	set d2_uwr;
	market_power=num_issues/num_issues_all;
	label 
		market_power="Market share";
run;

proc sql;
create table b as
select 
	d2.*,
	d2_uwr.market_power
from 
	d2 left join d2_uwr
on 
	d2.first_uwr=d2_uwr.first_uwr
order by
    offer_date_sas;
quit;

* Generate table with basic statistics;

proc sort data=b;
	by subsample;
run;

proc means data=b noprint;
	output out=b_stats_1 
		n(permno)=num_issues
		mean(dollar_width)=dollar_width
		mean(perc_width)=perc_width
		mean(expected_price)=expected_price
        mean(offer_price)=offer_price
		mean(ret)=ret
		median(dollar_width)=mdollar_width
		median(perc_width)=mperc_width
		median(expected_price)=mexpected_price
        median(offer_price)=moffer_price;
run;

data b_stats_1;
	set b_stats_1;
	subsample="All IPOs";
run;

proc means data=b noprint;
	output out=b_stats_2 
		n(permno)=num_issues
		mean(dollar_width)=dollar_width
		mean(perc_width)=perc_width
		mean(expected_price)=expected_price
        mean(offer_price)=offer_price
		mean(ret)=ret
		median(dollar_width)=mdollar_width
		median(perc_width)=mperc_width
		median(expected_price)=mexpected_price
        median(offer_price)=moffer_price;
	by subsample;
run;

data b_stats;
	set b_stats_1 b_stats_2;
run;

proc print data=b_stats label noobs;
	title 'Basic statistics: IPOs 1983.01-1987.09';
	var subsample num_issues dollar_width perc_width expected_price offer_price ret;
	label
		num_issues="Number of issues"
		dollar_width="Dollar width"
		perc_width="Percent width"
		expected_price="Expected offer"
		offer_price="Actual offer"
        ret="Initial returns";
run;

proc print data=b_stats label noobs;
	var subsample num_issues mdollar_width mperc_width mexpected_price moffer_price;
	label
		num_issues="Number of issues"
		mdollar_width="Median dollar width"
		mperc_width="Median percent width"
		mexpected_price="Median expected offer"
		moffer_price="Median ctual offer";
run;

* Run regression and analyze its results for different period;

proc reg data=b;
title '1983.01-1987.09 Regression results';
model ret=delta_offer market_power/acov spec dw dwprob;
	output out=reg_data 
		residual=r
		predicted=p;
run;
quit;

data d3;
	set d;
	where period="period3";
run;

proc sort data=d3;by first_uwr;run;

proc means data=d3 noprint;
	output out=d3_uwr_all 
		n(permno)=num_issues_all;
run;

proc means data=d3 noprint;
	output out=d3_uwr 
		n(permno)=num_issues;
	by first_uwr;
run;

data d3_uwr;
	if _n_=1 then set d3_uwr_all;
	set d3_uwr;
	market_power=num_issues/num_issues_all;
	label 
		market_power="Market share";
run;

proc sql;
create table b as
select 
	d3.*,
	d3_uwr.market_power
from 
	d3 left join d3_uwr
on 
	d3.first_uwr=d3_uwr.first_uwr
order by
    offer_date_sas;
quit;

* Generate table with basic statistics;

proc sort data=b;
	by subsample;
run;

proc means data=b noprint;
	output out=b_stats_1 
		n(permno)=num_issues
		mean(dollar_width)=dollar_width
		mean(perc_width)=perc_width
		mean(expected_price)=expected_price
        mean(offer_price)=offer_price
		mean(ret)=ret
		median(dollar_width)=mdollar_width
		median(perc_width)=mperc_width
		median(expected_price)=mexpected_price
        median(offer_price)=moffer_price;
run;

data b_stats_1;
	set b_stats_1;
	subsample="All IPOs";
run;

proc means data=b noprint;
	output out=b_stats_2 
		n(permno)=num_issues
		mean(dollar_width)=dollar_width
		mean(perc_width)=perc_width
		mean(expected_price)=expected_price
        mean(offer_price)=offer_price
		mean(ret)=ret
		median(dollar_width)=mdollar_width
		median(perc_width)=mperc_width
		median(expected_price)=mexpected_price
        median(offer_price)=moffer_price;
	by subsample;
run;

data b_stats;
	set b_stats_1 b_stats_2;
run;

proc print data=b_stats label noobs;
	title 'Basic statistics: IPOs 1987.10-1991.12';
	var subsample num_issues dollar_width perc_width expected_price offer_price ret;
	label
		num_issues="Number of issues"
		dollar_width="Dollar width"
		perc_width="Percent width"
		expected_price="Expected offer"
		offer_price="Actual offer"
        ret="Initial returns";
run;

proc print data=b_stats label noobs;
	var subsample num_issues mdollar_width mperc_width mexpected_price moffer_price;
	label
		num_issues="Number of issues"
		mdollar_width="Median dollar width"
		mperc_width="Median percent width"
		mexpected_price="Median expected offer"
		moffer_price="Median ctual offer";
run;

* Run regression and analyze its results for different period;

proc reg data=b;
title '1987.10-1991.12 Regression results';
model ret=delta_offer market_power/acov spec dw dwprob;
	output out=reg_data 
		residual=r
		predicted=p;
run;
quit;

data d4;
	set d;
	where period="period4";
run;

proc sort data=d4;by first_uwr;run;

proc means data=d4 noprint;
	output out=d4_uwr_all 
		n(permno)=num_issues_all;
run;

proc means data=d4 noprint;
	output out=d4_uwr 
		n(permno)=num_issues;
	by first_uwr;
run;

data d4_uwr;
	if _n_=1 then set d4_uwr_all;
	set d4_uwr;
	market_power=num_issues/num_issues_all;
	label 
		market_power="Market share";
run;

proc sql;
create table b as
select 
	d4.*,
	d4_uwr.market_power
from 
	d4 left join d4_uwr
on 
	d4.first_uwr=d4_uwr.first_uwr
order by
    offer_date_sas;
quit;

* Generate table with basic statistics;

proc sort data=b;
	by subsample;
run;

proc means data=b noprint;
	output out=b_stats_1 
		n(permno)=num_issues
		mean(dollar_width)=dollar_width
		mean(perc_width)=perc_width
		mean(expected_price)=expected_price
        mean(offer_price)=offer_price
		mean(ret)=ret
		median(dollar_width)=mdollar_width
		median(perc_width)=mperc_width
		median(expected_price)=mexpected_price
        median(offer_price)=moffer_price;
run;

data b_stats_1;
	set b_stats_1;
	subsample="All IPOs";
run;

proc means data=b noprint;
	output out=b_stats_2 
		n(permno)=num_issues
		mean(dollar_width)=dollar_width
		mean(perc_width)=perc_width
		mean(expected_price)=expected_price
        mean(offer_price)=offer_price
		mean(ret)=ret
		median(dollar_width)=mdollar_width
		median(perc_width)=mperc_width
		median(expected_price)=mexpected_price
        median(offer_price)=moffer_price;
	by subsample;
run;

data b_stats;
	set b_stats_1 b_stats_2;
run;

proc print data=b_stats label noobs;
	title 'Basic statistics: IPOs 1992.01-1995.12';
	var subsample num_issues dollar_width perc_width expected_price offer_price ret;
	label
		num_issues="Number of issues"
		dollar_width="Dollar width"
		perc_width="Percent width"
		expected_price="Expected offer"
		offer_price="Actual offer"
        ret="Initial returns";
run;

proc print data=b_stats label noobs;
	var subsample num_issues mdollar_width mperc_width mexpected_price moffer_price;
	label
		num_issues="Number of issues"
		mdollar_width="Median dollar width"
		mperc_width="Median percent width"
		mexpected_price="Median expected offer"
		moffer_price="Median ctual offer";
run;

* Run regression and analyze its results for different period;

proc reg data=b;
title '1992.01-1995.12 Regression results';
model ret=delta_offer market_power/acov spec dw dwprob;
	output out=reg_data 
		residual=r
		predicted=p;
run;
quit;

data d5;
	set d;
	where period="period5";
run;

proc sort data=d5;by first_uwr;run;

proc means data=d5 noprint;
	output out=d5_uwr_all 
		n(permno)=num_issues_all;
run;

proc means data=d5 noprint;
	output out=d5_uwr 
		n(permno)=num_issues;
	by first_uwr;
run;

data d5_uwr;
	if _n_=1 then set d5_uwr_all;
	set d5_uwr;
	market_power=num_issues/num_issues_all;
	label 
		market_power="Market share";
run;

proc sql;
create table b as
select 
	d5.*,
	d5_uwr.market_power
from 
	d5 left join d5_uwr
on 
	d5.first_uwr=d5_uwr.first_uwr
order by
    offer_date_sas;
quit;

* Generate table with basic statistics;

proc sort data=b;
	by subsample;
run;

proc means data=b noprint;
	output out=b_stats_1 
		n(permno)=num_issues
		mean(dollar_width)=dollar_width
		mean(perc_width)=perc_width
		mean(expected_price)=expected_price
        mean(offer_price)=offer_price
		mean(ret)=ret
		median(dollar_width)=mdollar_width
		median(perc_width)=mperc_width
		median(expected_price)=mexpected_price
        median(offer_price)=moffer_price;
run;

data b_stats_1;
	set b_stats_1;
	subsample="All IPOs";
run;

proc means data=b noprint;
	output out=b_stats_2 
		n(permno)=num_issues
		mean(dollar_width)=dollar_width
		mean(perc_width)=perc_width
		mean(expected_price)=expected_price
        mean(offer_price)=offer_price
		mean(ret)=ret
		median(dollar_width)=mdollar_width
		median(perc_width)=mperc_width
		median(expected_price)=mexpected_price
        median(offer_price)=moffer_price;
	by subsample;
run;

data b_stats;
	set b_stats_1 b_stats_2;
run;

proc print data=b_stats label noobs;
	title 'Basic statistics: IPOs 1996.01-1999.12';
	var subsample num_issues dollar_width perc_width expected_price offer_price ret;
	label
		num_issues="Number of issues"
		dollar_width="Dollar width"
		perc_width="Percent width"
		expected_price="Expected offer"
		offer_price="Actual offer"
        ret="Initial returns";
run;

proc print data=b_stats label noobs;
	var subsample num_issues mdollar_width mperc_width mexpected_price moffer_price;
	label
		num_issues="Number of issues"
		mdollar_width="Median dollar width"
		mperc_width="Median percent width"
		mexpected_price="Median expected offer"
		moffer_price="Median ctual offer";
run;

* Run regression and analyze its results for different period;

proc reg data=b;
title '1996.01-1999.12 Regression results';
model ret=delta_offer market_power/acov spec dw dwprob;
	output out=reg_data 
		residual=r
		predicted=p;
run;
quit;

data d6;
	set d;
	where period="period6";
run;

proc sort data=d6;by first_uwr;run;

proc means data=d6 noprint;
	output out=d6_uwr_all 
		n(permno)=num_issues_all;
run;

proc means data=d6 noprint;
	output out=d6_uwr 
		n(permno)=num_issues;
	by first_uwr;
run;

data d6_uwr;
	if _n_=1 then set d6_uwr_all;
	set d6_uwr;
	market_power=num_issues/num_issues_all;
	label 
		market_power="Market share";
run;

proc sql;
create table b as
select 
	d6.*,
	d6_uwr.market_power
from 
	d6 left join d6_uwr
on 
	d6.first_uwr=d6_uwr.first_uwr
order by
    offer_date_sas;
quit;

* Generate table with basic statistics;

proc sort data=b;
	by subsample;
run;

proc means data=b noprint;
	output out=b_stats_1 
		n(permno)=num_issues
		mean(dollar_width)=dollar_width
		mean(perc_width)=perc_width
		mean(expected_price)=expected_price
        mean(offer_price)=offer_price
		mean(ret)=ret
		median(dollar_width)=mdollar_width
		median(perc_width)=mperc_width
		median(expected_price)=mexpected_price
        median(offer_price)=moffer_price;
run;

data b_stats_1;
	set b_stats_1;
	subsample="All IPOs";
run;

proc means data=b noprint;
	output out=b_stats_2 
		n(permno)=num_issues
		mean(dollar_width)=dollar_width
		mean(perc_width)=perc_width
		mean(expected_price)=expected_price
        mean(offer_price)=offer_price
		mean(ret)=ret
		median(dollar_width)=mdollar_width
		median(perc_width)=mperc_width
		median(expected_price)=mexpected_price
        median(offer_price)=moffer_price;
	by subsample;
run;

data b_stats;
	set b_stats_1 b_stats_2;
run;

proc print data=b_stats label noobs;
	title 'Basic statistics: IPOs2000.01-2006.12';
	var subsample num_issues dollar_width perc_width expected_price offer_price ret;
	label
		num_issues="Number of issues"
		dollar_width="Dollar width"
		perc_width="Percent width"
		expected_price="Expected offer"
		offer_price="Actual offer"
        ret="Initial returns";
run;

proc print data=b_stats label noobs;
	var subsample num_issues mdollar_width mperc_width mexpected_price moffer_price;
	label
		num_issues="Number of issues"
		mdollar_width="Median dollar width"
		mperc_width="Median percent width"
		mexpected_price="Median expected offer"
		moffer_price="Median ctual offer";
run;

* Run regression and analyze its results for different period;

proc reg data=b;
title '2000.01-2006.12 Regression results';
model ret=delta_offer market_power/acov spec dw dwprob;
	output out=reg_data 
		residual=r
		predicted=p;
run;
quit;


* get the firms' founding days and their age;
proc import datafile="/folders/myfolders/sasuser.v94/age19752019.xls"
	dbms=xls
	out=worklib.age REPLACE;
run;

data a;
	set worklib.age;
	drop offer_date ipo_name;
	permno1=permno*1;
	drop permno;
	rename permno1=permno;
run;


* get the firms' total assets;
data e;
	set worklib.ipo_total_assets;
run;

* merge the tables and get new variables we need;
proc sql;
create table c as
select distinct
	b.*,
	a.founding_year,
	e.data6
from 
	b,a,e
where
	a.permno=b.permno and
	e.permno=b.permno
order by
    offer_date_sas;
quit;

data c;
	set c;
	where 19830101<=offer_date<=19870930;
run;

data c;
	set c;
	age=year_ipo-founding_year;
	lage=log(1+age);
	lsize=log(1+data6);
	rename data6=size;
run;

* Generate table with basic statistics;
data c;
	set c;
	where 19830101<=offer_date<=19870930;
run;


proc means data=c noprint;
	output out=c_stats 
		n(permno)=observations
		mean(age)=mean_age
		mean(size)=mean_size
		mean(lage)=mean_lage
		mean(lsize)=mean_lsize
		median(age)=m_age
		median(size)=m_size
		median(lage)=m_lage
		median(lsize)=m_lsize
		min(age)=min_age
		min(size)=min_size
		min(lage)=min_lage
		min(lsize)=min_lsize
		max(age)=max_age
		max(size)=max_size
		max(lage)=max_lage
		max(lsize)=max_lsize;
run;

proc print data=c_stats label noobs;
	title 'Basic statistics: IPOs 1983.01-1987.09';
	var observations
		mean_age
		mean_size
		mean_lage
		mean_lsize
		m_age
		m_size
		m_lage
		m_lsize
		min_age
		min_size
		min_lage
		min_lsize
		max_age
		max_size
		max_lage
		max_lsize;
	label
		observations="observations"
		mean_age="mean of age"
		mean_size="mean of size"
		mean_lage="mean of lage"
		mean_lsize="mean of lsize"
		m_age="median of age"
		m_size="median of size"
		m_lage="median of lage"
		m_lsize="median of lsize"
		min_age="min of age"
		min_size="min of size"
		min_lage="min of lage"
		min_lsize="min of lsize"
		max_age="max of age"
		max_size="max of size"
		max_lage="max of lage"
		max_lsize="max of lsize";
run;


* Run regression and analyze its results for different period;


proc reg data=c;
title '1983.01-1987.09 Regression results';
model ret=delta_offer market_power age/acov spec dw dwprob;
	output out=reg_data 
		residual=r
		predicted=p;
	ods output acovest=d_white_errors
	           parameterestimates=d_paramest;
run;quit;

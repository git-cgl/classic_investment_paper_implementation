/******************************************************
Name:   l9_ff_w
Date:   11/21/2016
Description: immplements the Fama and French (1993) 
             examination of the 3-factor model
******************************************************/
options MPRINT SYMBOLGEN MLOGIC nonumber nocenter nodate ls=132; 

libname worklib '/folders/myfolders/sasuser.v94/l9';

%macro  build_25_portfolios(num_cycles=);
%do i=1 %to &num_cycles;
  %let year_cycle=1962+&i;

  *Collect all NYSE, AMEX, Nasdaq data;
  proc sql;
  create table d as
  select
	  d_cst_size.*,
  	  (year(d_cst_size.date)*100+month(d_cst_size.date))
          as month
  from
   	  worklib.d_cst_size
  where
      year(date)=&year_cycle and month(date)=6 and 
      prc^=. and shrout^=.
  order by
      month,permno;
  quit;

  data d;
	set d;
	rename data60=be;
run;

data d;
set d;
     size=abs(prc)*shrout;

	if size_prev_year^=. and size_prev_year^=0 and  
        be^=. then
		beme=1000*be/size_prev_year;
	else
		beme=.;	
run;

  %*Now look specifically at NYSE stocks;
  data d_nyse;
	set d;
	where hexcd=1 and size^=. and beme^=. and beme>0;

  *Define NYSE breakpoints for 25 portfolios formed on;
  *size and book-to-market (independently);

  proc sort data=d_nyse;
	by size;

  data d_nyse;
	set d_nyse nobs=num_records;

	portfolio_size=int(5*(_n_-1)/num_records)+1;

  proc means data=d_nyse noprint;
	by portfolio_size ;
	output out=d_stats
		min(size)=min_size;

  proc sql;
  create table d_nyse_size as		
  select
	a.portfolio_size,
	a.min_size,
	b.min_size as max_size
  from
	d_stats as a left join d_stats as b
  on
 	a.portfolio_size+1=b.portfolio_size;
    
  proc sort data=d_nyse;
	by beme;

  data d_nyse;
	set d_nyse nobs=num_records;

	portfolio_beme=int(5*(_n_-1)/num_records)+1;

  proc means data=d_nyse noprint;
	by portfolio_beme ;
	output out=d_stats
		min(beme)=min_beme;

  proc sql;
  create table d_nyse_beme as		
  select
	a.portfolio_beme,
	a.min_beme,
	b.min_beme as max_beme
  from
	d_stats as a left join d_stats as b
  on
 	a.portfolio_beme+1=b.portfolio_beme;
    
  proc sql;
  create table d_nyse_breakpoints as
  select
	d_nyse_size.*,
	d_nyse_beme.*
  from
	d_nyse_size,d_nyse_beme;

  data d_nyse_breakpoints;
  	set d_nyse_breakpoints;

	if portfolio_size=1 then min_size=-999999;
	if portfolio_beme=1 then min_beme=-999999;
	if portfolio_size=5 then max_size=999999999;
	if portfolio_beme=5 then max_beme=999999999;

  *Define the portfolio for each stock in the;
  *NYSE/AMEX/NASDAQ using NYSE breakpoints;
  proc sql;
  create table d_portfolio as
  select 
	d.*,
	d_nyse_breakpoints.portfolio_size,
	d_nyse_breakpoints.portfolio_beme
  from	
	d,d_nyse_breakpoints
 where 
	d.beme^=. and d.beme>0 and
	d_nyse_breakpoints.min_size<=d.size<d_nyse_breakpoints.max_size and
	d_nyse_breakpoints.min_beme<=d.beme<d_nyse_breakpoints.max_beme
  order by
	permno,portfolio_size desc,portfolio_beme desc;

  *Populate the portfolio dataset; 
  proc sql;
  create table d_portfolio as
  select
	d_portfolio.permno,
     	d_portfolio.portfolio_size,
	d_portfolio.portfolio_beme,
	d_portfolio.size_prev_year,
	d_portfolio.size_june,
	d_portfolio.size,
	d_portfolio.beme,
	d_ff.ret,
	d_ff.prc,
	d_ff.shrout,
	d_ff.date
  from
	d_portfolio left join worklib.d_ff
  on
	d_portfolio.permno=d_ff.permno and
	mdy(7,1,&year_cycle)<=d_ff.date
                         <=mdy(6,30,&year_cycle+1)
  order by
	permno,date;
quit;

  
  %if &i=1 %then
  %do;
     data worklib.ff_25_portfolios;
  	set d_portfolio;
  %end;
  %else
  %do;
      proc append base=worklib.ff_25_portfolios
           data=d_portfolio;
      run;
  %end;
%end;
%mend build_25_portfolios;

%build_25_portfolios(num_cycles=29);



proc import datafile="/folders/myfolders/sasuser.v94/l9/ff_factors.xls"
	dbms=xls
	out=worklib.ff_factors REPLACE;
run;

*Match the portfolio dataset with FF factors;
proc sql;
create table ff_factors as
select
	ff_factors.smb,
	ff_factors.hml,
	ff_factors.date,
	ff_factors.mktrf as rm_rf,
	ff_factors.rf/100 as rf
from
	worklib.ff_factors
order by
	date;
quit;

*Compute vw returns on 25 portfolios;
data d;
	set worklib.ff_25_portfolios;	
	size_ret=size*ret;

proc sort data=d;
	by date portfolio_size portfolio_beme;

proc means data=d noprint;
	output out=d_portfolio
		sum(size_ret size)=size_ret size;
	by date portfolio_size portfolio_beme;

data d_portfolio;
	set d_portfolio;
	vwret=size_ret/size;
run;

data d_portfolio;
	set d_portfolio;
	time=100*year(date)+month(date);
run;

proc sql;
create table d_portfolio as
select
	d_portfolio.portfolio_size,
	d_portfolio.portfolio_beme,
	d_portfolio.date,
	d_portfolio.vwret as vwret,
	100*(d_portfolio.vwret - ff_factors.rf) as vwret_rf,
	100*ff_factors.rf as rf,
	ff_factors.rm_rf,
	ff_factors.smb,
	ff_factors.hml
from
	d_portfolio,ff_factors
where
	d_portfolio.time=ff_factors.date
order by
	portfolio_size,portfolio_beme;
quit;

*Compute time-series regressions on 25 portfolios vw returns;
proc reg data=d_portfolio outest=out_reg outseb noprint;
	model vwret_rf=rm_rf smb hml;
	by portfolio_size portfolio_beme;
	
*Prepare printout with t-stats and all;
proc sql;
create table out_reg_stats as
select
	out_reg_1.portfolio_size,
	out_reg_1.portfolio_beme,
	out_reg_1.intercept,
	out_reg_1.intercept/out_reg_2.intercept as
          t_intercept,
	out_reg_1.rm_rf,
	out_reg_1.rm_rf/out_reg_2.rm_rf as t_rm_rf,
	out_reg_1.smb,
	out_reg_1.smb/out_reg_2.smb as t_smb,
	out_reg_1.hml,
	out_reg_1.hml/out_reg_2.hml as t_hml
from
	out_reg as out_reg_1,out_reg as out_reg_2
where
	out_reg_1._type_="PARMS" and
	out_reg_2._type_="SEB" and
	out_reg_1.portfolio_size=out_reg_2.portfolio_size and 
	out_reg_1.portfolio_beme=out_reg_2.portfolio_beme;

proc transpose data=out_reg_stats out=d_stats_int prefix=int;
	by portfolio_size;
	var intercept;
	id portfolio_beme;

proc transpose data=out_reg_stats out=d_stats_t_int prefix=t_int;
	by portfolio_size;
	var t_intercept;
	id portfolio_beme;

proc transpose data=out_reg_stats out=d_stats_rm_rf prefix=rm_rf;
	by portfolio_size;
	var rm_rf;
	id portfolio_beme;

proc transpose data=out_reg_stats out=d_stats_t_rm_rf prefix=t_rm_rf;
	by portfolio_size;
	var t_rm_rf;
	id portfolio_beme;

proc transpose data=out_reg_stats out=d_stats_smb prefix=smb;
	by portfolio_size;
	var smb;
	id portfolio_beme;

proc transpose data=out_reg_stats out=d_stats_t_smb prefix=t_smb;
	by portfolio_size;
	var t_smb;
	id portfolio_beme;

proc transpose data=out_reg_stats out=d_stats_hml prefix=hml;
	by portfolio_size;
	var hml;
	id portfolio_beme;

proc transpose data=out_reg_stats out=d_stats_t_hml prefix=t_hml;
	by portfolio_size;
	var t_hml;
	id portfolio_beme;

data d_stats;
	merge 
           d_stats_int d_stats_t_int
           d_stats_rm_rf d_stats_t_rm_rf
           d_stats_smb d_stats_t_smb
           d_stats_hml d_stats_t_hml;
	by portfolio_size;

proc print data=d_stats;
	title 'Stats on Intercept';
	var portfolio_size int1-int5 t_int1-t_int5;

proc print data=d_stats;
	title 'Stats on rm-rf';
	var portfolio_size rm_rf1-rm_rf5 t_rm_rf1-t_rm_rf5;

proc print data=d_stats;
	title 'Stats on SMB';
	var portfolio_size smb1-smb5 t_smb1-t_smb5;

proc print data=d_stats;
	title 'Stats on HML';
	var portfolio_size hml1-hml5 t_hml1-t_hml5;
run;



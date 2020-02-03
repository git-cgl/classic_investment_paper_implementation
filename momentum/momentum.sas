libname worklib '/folders/myfolders/sasuser.v94/l5';

%macro run_cycle(first_year,num_cycles,j,k);
%do i=1 %to &num_cycles;
	%let num1=mod(&i-1,4);
	%let num2=(&i-1-&num1)/4;
	%let num=&num1*3+1;
	%let year_cycle=&first_year+&num2+1;
  
data param;
	year_cycle=&year_cycle;
	num=&num;
run;
  
proc sql;
create table msf_data as
select 
	msf.permno,
	msf.ret,
    msf.date,
	msf.hexcd,
    param.*
from
    param left join worklib.msf 
on
    (hexcd=1 or hexcd=2) and date>=mdy(num,1,year_cycle-1) and date<mdy(num,1,year_cycle+1);
quit;

data msf_data;
    set msf_data;
    month=year(date)*100+month(date);
    keep year_cycle permno month ret;
run;

proc print data=msf_data(obs=5);
   	title 'Generating Data for This Year';
  	var year_cycle month;
run;

*This step is not necessary, right? yes;

data d;
	set msf_data;
run;

* Number months;

proc sort data=d out=d_months(keep=month) nodupkeys;
    by month;
run;

data d_months;
    set d_months;
    i+1;
run;

proc sort data=d;
	by month;
run;

data d;
	merge d d_months;
	by month;
run;

* starting 9 month before the cycle date;

proc sort data=d;
  	by permno;
run;

proc means data=d noprint;
  	var ret;
  	output out=d_stats n=n_ret;
  	by permno;
  	where i>13-&j and i<=13+&k;
run;

* Keep only securities with returns in all 85 months;
data d;
    merge d d_stats;
    by permno;
    if n_ret=&j+&k;
run;

* Compute past average returns;

proc sort data=d;
    by year_cycle permno;
run;

proc means data=d noprint;
    output out=d_avgret 
      mean(ret)=avgret
      n(ret)=n_avgret;
    where i>13-&j and i<=13;
    by year_cycle permno;
run;

proc sort data=d_avgret;
    by avgret;
run;

* Define winners and losers;

data winner loser;
    set d_avgret nobs=num_records;
	percentile=_n_/num_records;
    if percentile<=0.1 then output loser;
    if percentile>=0.9 then output winner;
run;
 
proc sort data=winner;
	by permno;
run;

proc sort data=loser;
       by permno;
run;

data d;
    merge 
      d(keep=permno i month ret year_cycle) 
      winner(keep=permno in=in_winner)
      loser(keep=permno in=in_loser);;
    by permno;    

    winner=in_winner;
    if in_winner or in_loser;
    if i>13 and i<=13+&k;
run;
    
proc sort data=d;
  	by year_cycle month;
run;

* Get average abnormal returns;

proc means data=d noprint;
    var ret;
    output out=winner_stats 
       mean(ret)=avg_ret_winner
       n(ret)=n_avg_ret_winner;
    by year_cycle month;
    where winner=1;
run;

proc means data=d noprint;
    var ret;
    output out=loser_stats 
       mean(ret)=avg_ret_loser
       n(ret)=n_avg_ret_loser;
    by year_cycle month;
    where winner=0;
run;

* Get cumulative abnormal returns;

data d_stats;
    merge loser_stats winner_stats;
    by year_cycle month;
    m=_n_;
run;

proc print data=d_stats;
run;
%if &i=1 %then
  %do;
		data d_cycles;
			set d_stats;
		run;
  %end;
  %else
  %do;
    proc append base=d_cycles data=d_stats;
    run;
  %end;
%end;
%mend run_cycle;
%run_cycle(1964,100,9,3);

data d;
	set d_cycles;
	ret_buy_sell=avg_ret_winner-avg_ret_loser;
run;

proc means data=d noprint;
	var avg_ret_winner avg_ret_loser ret_buy_sell;
	output out=d_stats
	    mean(avg_ret_winner)=avg_ret_winner
	    t(avg_ret_winner)=t_stats_winner
	 
	    mean(avg_ret_loser)=avg_ret_loser
	    t(avg_ret_loser)=t_stats_loser
	    mean(ret_buy_sell)=avg_ret_buy_sell
	    t(ret_buy_sell)=t_stats_buy_sell;
run;
data d_stats;
	set d_stats;
	ret_buy_sell=avg_ret_winner-avg_ret_loser;
run;
proc means data=d_stats noprint;
	var ret_buy_sell;
	output out=d_stats1
		t(ret_buy_sell)=t_stats_buysell;
run;
	
*data winner;
*  	 set d_stats;
*	 avg_ret=avg_ret_winner;
*	 winner=1;
*	 keep m avg_ret winner;

*data loser;
*  	 set d_stats;
*	 avg_ret=avg_ret_loser;
*	 winner=0;
*	 keep m avg_ret winner;

*data obs_0;
*    input m winner avg_ret;
*    datalines;
*  0 0 0
*  0 1 0
  ;

*  data d_gplot;
*     set obs_0 winner loser ;

*	 if winner=1 then
	 	sample="Winner";
*	 else
	 	if winner=0 then
	 		sample="Loser";
*	 	else 
	 		sample="buy-sell";
*	run;

*  proc sort data=d_gplot;
*  	by winner;
  	
*  proc export data=d_gplot
	outfile='/folders/myfolders/sasuser.v94/l5/dplot.xls'
	dbms=xls replace;
*  run;

  *symbol1 color=green interpol=spline value=dot; 
  *symbol2 color=red interpol=spline value=triangle;
  *axis1 order=0 to %eval(12*&param_years) by 1 label=('Month');
  *axis2 label=('CAR');

  *proc gplot data=d_gplot;
	*plot cum_ret*m=sample/vref=0 haxis=axis1 vaxis=axis2 ;
  *run;

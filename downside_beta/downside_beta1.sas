options mprint;
libname worklib '/folders/myfolders/sasuser.v94/midterm';
*select data we need;	
proc sql;
create table all_data as
select 
	fullsample_0620.stkcd,
	fullsample_0620.prc_change_pct as ret,
    fullsample_0620.trddt as date,
    fullsample_0620.year,
    fullsample_0620.month,
    fullsample_0620.dsmvtll as size  
from
    worklib.fullsample_0620;
quit;

data all_data;
    set all_data;
    yearmonth=year(date)*100+month(date);
run;

proc sort data=all_data;
	by stkcd date;
run;

data all_data;
	set all_data;
	if stkcd=lag(stkcd) then
		lsize=lag(size);
	else
		lsize=".";
run;

*define excess return;
proc sort data=all_data;
	by date;
run;

*value weight to get daily market ret;
proc means data=all_data noprint;
	var ret;
	weight lsize;
	output out=d1(drop=_type_ _freq_)
	mean(ret)=m_ret;
	by date;
	where lsize^=.;
run;

data all_data;
	merge all_data d1;
	by date;
	ar=ret-m_ret;
run;
* Keep only securities with returns in all days;
proc sort data=all_data;
	by stkcd yearmonth;
run;

proc means data=all_data noprint;
	output out=d1(drop=_type_ _freq_)
	n(ret)=n_ret;
	by stkcd yearmonth;
run;

proc sort data=d1;
	by yearmonth;
run;

proc means data=d1 noprint;
	output out=d11(drop=_type_ _freq_)
	max(n_ret)=max_ret;
	by yearmonth;
run;

data d1;
    merge d1 d11;
    by yearmonth;
    if n_ret=max_ret;
run;

proc sort data=d1;
	by stkcd yearmonth;
run;


data all_data;
	merge all_data d1;
	by stkcd yearmonth;
	if n_ret^=.;
run;

*creat indicator to select months;

data indct;
	set all_data;
	keep yearmonth;
run;

proc sort data=indct nodupkey;
	by yearmonth;
run;

data indct;
	set indct;
	ind=_n_;
run;

proc sort data=all_data;
	by yearmonth;
run;	

data all_data;
	merge all_data indct;
	by yearmonth;
run;


*****************************************************
*****************************************************
*macro;

%macro run_cycle(numcycle);
%do i=1 %to &numcycle;
	%let m=12+&i;
	
* data test;

data test;
	set all_data;
	where &m-12<=ind<=&m;
run;


*define downside beta;

data test;
	set test;
	if m_ret>0 then downside=0;
	else downside=1;
run;


*calculate beta for individual stocks;
data test1;
	set test;
	if &m-12<=ind<=&m-1;
run;

proc sort data=test1;
	by stkcd;
run;

proc reg data=test1 outest =test_1(rename=(m_ret=beta)) noprint;	
	model ar=m_ret;
	by stkcd;
run;

data res;
	set test_1(keep=stkcd _rmse_);
	ind=&m;
run;

*calculate downsidebeta for individual stocks(by regression);

data d_test;
	set test1;
	if downside=1;
run;

proc sort data=d_test;
	by stkcd;
run;

proc reg data=d_test outest =test_d(rename=(m_ret=d_beta)) noprint;	
	model ar=m_ret;
	by stkcd;
run;

* sigel portfolio rank;
proc sort data=test_d;
	by d_beta;
run;

proc rank data=test_d out=d1 group=5;
   var d_beta;
   ranks rrank;
run;

*calculate upsidebeta for individual stocks;

data u_test;
	set test1;
	if downside=0;
run;

proc sort data=u_test;
	by stkcd;
run;

proc reg data=u_test outest =test_u(rename=(m_ret=u_beta)) noprint;	
	model ar=m_ret;
	by stkcd;
run;

*calculate portfolio returns and beta(value weighted);
proc sort data=d1;
	by stkcd;
run;

proc sort data=test;
	by stkcd;
run;

data test;
	merge test d1(keep=stkcd rrank);
	by stkcd;
	if rrank^=.;
run;

*get the stkcd monthly return on month t;

data test2;
	set test;
	where ind=&m;
	l_ar=log(1+ar/100);
run;

proc sort data=test2;
	by stkcd date;
run;

proc means data=test2 noprint;
	output out=test_m(drop=_type_ _freq_)
	sum(l_ar)=l_ar;
	by stkcd;
run;

data test_m;
	set test_m;
	ret=(exp(l_ar)-1)*100;
run;


* use the size before the first day of t month as the stkcd size;

proc sort data=test2 nodupkey;
	by stkcd;
run;

data test_m;
	merge test_m test2;
	by stkcd;
run;
	
*get the factor-adjusted return;

proc sort data=test;
	by rrank;
run;

proc reg data=test outest =test_a(rename=(intercept=adjret)) noprint;	
	model ar=m_ret;
	by rrank;
run;

data all;
	merge d1(keep=stkcd d_beta rrank) 
		  test_1(keep=stkcd beta) 
		  test_u(keep=stkcd u_beta)
		  test_m(keep=stkcd ret lsize);
	by stkcd;
run;

proc sort data=all;
	by rrank;
run;

proc means data=all noprint;
	var ret beta d_beta u_beta;
	weight lsize;
	output out=result(drop=_type_ _freq_)
	mean(ret)=returns
	mean(beta)=beta
	mean(d_beta)=d_beta
	mean(u_beta)=u_beta;
	by rrank;
run;


data result;
	merge result test_a(keep=rrank adjret);
	by rrank;
run;

data result;
	set result;	
	ind=&m;
	format returns adjret beta d_beta u_beta 5.3;
run;


*find the return differences;
data low high;
	set result;
	if rrank=0 then output low;
	if rrank=4 then output high;
run;

data low;
	set low;
	rename returns=r_low;
	rename adjret=adj_low;
	rename beta=b_low;
	rename d_beta=db_low;
	rename u_beta=ub_low;
run;

data high;
	set high;
	rename returns=r_high;
	rename adjret=adj_high;
	rename beta=b_high;
	rename d_beta=db_high;
	rename u_beta=ub_high;
run;

data diff;
	merge low high;
	ret_d=r_high-r_low;
	adjret_d=adj_high-adj_low;
	beta_d=b_high-b_low;
	d_beta_d=db_high-db_low;
	u_beta_d=ub_high-ub_low;
run;

data diff;
	set diff;
	keep ind ret_d adjret_d beta_d d_beta_d u_beta_d;
	format ret_d adjret_d beta_d d_beta_d u_beta_d 5.3;
run;

%if &i=1 %then
  %do;
		data d_cycles;
			set result;
		run;
		
		data f_diff;
			set diff;
		run;
		
		data worklib.d_res;
			set res;
		run;
  %end;
  %else
  %do;
    proc append base=d_cycles data=result;
    run;
    
    proc append base=f_diff data=diff;
    run;
    
    proc append base=worklib.d_res data=res;
    run;
  %end;
%end;
%mend run_cycle;
%run_cycle(30);

proc means data=f_diff noprint;
	output out=diff(drop=_type_ _freq_)
	mean(ret_d)=ret_d
	mean(adjret_d)=adjret_d
	mean(beta_d)=beta_d
	mean(d_beta_d)=d_beta_d
	mean(u_beta_d)=u_beta_d
	t(ret_d)=t_stats
	t(adjret_d)=t;
run;

proc sort data=d_cycles;
	by rrank;
run;

proc sort data=d_cycles;
	by rrank;
run;

proc means data=d_cycles noprint;
	output out=cycles(drop=_type_ _freq_)
	mean(returns)=ret
	mean(adjret)=adjret
	mean(beta)=beta
	mean(d_beta)=d_beta
	mean(u_beta)=u_beta;
	by rrank;
run;


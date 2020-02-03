*option mprint;
%macro event_study(d_p,permno_p,date_p,lwindow,rwindow,graph_p,title_p);
libname worklib '/folders/myfolders/sasuser.v94/l4';
*calculate ar for all the events;
*	by date;
proc sort data=worklib.dsf_all out=ret;
	by date;
proc sort data=worklib.mktret_daily out=mret;
	by date;
data a;
merge ret mret;
	by date;
run;
*calculate car for event1;
proc sort data=a;
	by permno;
proc sort data=worklib.&d_p out=dp;
	by &permno_p;

proc sql;
create table b as
select distinct
	dp.&permno_p,
	dp.&date_p,
	a.date,
	a.ret,
	a.vwretd
from dp,a
where dp.&permno_p=a.permno
order by &permno_p,date;
quit;

proc means data=b noprint; 
	var &permno_p;
	by &permno_p;
	output out=b_stats(drop=_type_ _freq_)
	n=num_before;
	where date<&date_p;
run;


data b;
	merge b b_stats;
	by &permno_p;
	if first.&permno_p then 
		rel_day=-num_before;
	else
		rel_day =rel_day +1;
	retain rel_day;
	if &date_p=. then delete;
run;

data b;
	set b;
	if &lwindow<=rel_day<=&rwindow;
	ar=ret-vwretd;
run;

proc sort data=b;
	by &permno_p rel_day;

data b;
	set b;
	by &permno_p;
	if  first.&permno_p then
		car=ar;
	else
		car=car+ar;
	retain car;
run;

proc sort data=b;
	by rel_day;
	
proc means data=b noprint;
	var car ar;
	output out=b_stats(drop=_type_)
	mean(ar)=aar
	t(ar)=t_ar
	mean(car)=acar
	t(car)=t_car
	n(car)=n;
	by rel_day;
run;

proc print data=b_stats label noobs;
	title &title_p;
	var rel_day aar t_ar acar t_car n;
	label
		rel_day="Day"
		aar="Average MAR(%)"
		t_ar="t-statistic"
		acar="Average CMAR(%)"
		t_car="t-statistic"
		n="N";
run;

%if graph_p=1 %then
%do;
	axis1
		label=('Day')
		order=-5 to 5 by 1
		width=3;
	axis2
		label=('CAR')
		order=0 to 0.04 by 0.005
		width=3;
	proc gplot data=b_stats;
		title &title_p;
		plot acar*rel_day/haxis=axis1 vaxis=axis2;
	run;
%end;
%mend event_study;

%event_study(quiet_ev,permno,quiet_period_end,-5,5,0,Quiet Periods);
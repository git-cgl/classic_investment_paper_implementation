options ls=80;
libname worklib '/folders/myfolders/sasuser.v94';

* Merge ipo and recommendation;

proc sort data=worklib.recommendation out=rec;
	by cusip;

proc sort data=worklib.ipos_1996_2000 out=ipo;
	by cusip;

data iporec;
	merge ipo rec;
	if anndats=. then delete;
	by cusip;
run;

proc sort data=iporec;
	by permno anndats;

proc sort data=iporec nodupkey; 
	by permno;
run;



*calculat ar;

proc sort data=worklib.assignmentreturns out=ret;
	by date;

proc sort data=worklib.market_returns out=mret;
	by date;

data a;
merge ret mret;
	by date;
	ar=ret-vwretd;
run;


* another way to merge these tables;
proc sql;
create table b as
select distinct
     ret.*,
	 mret.vwretd
from
     ret left join mret
on
     ret.date = mret.date
order by
     permno,date;
quit;

data b;
	set b;
	ar= ret-vwretd;
run;

* Compute cumulative abnormal returns;

proc sql;
	create table c as
	select distinct
		a.ar,
		a.date,
		iporec.*
	from
		iporec,a
	where
		iporec.permno=a.permno and
		iporec.anndats-50<=a.date<=iporec.anndats+50
	order by
		permno,date;
quit;

data c;
 set c;
 if ar=. then delete;
run;


proc means data=c noprint;
	var permno;
	by permno;
	output out=c_stats(drop=_type_ _freq_)
	n=num_before;
	where date<anndats;
run;

data d;
	merge c c_stats;
	by permno;
	if first.permno then
	rel_day=-num_before;
	else
	rel_day= rel_day +1;
	retain rel_day;
run;

data d;
	set d;
	if -5<=rel_day<=5;
run;

proc sort data=d;
	by permno rel_day;

data d;
	set d;
	by permno;
	if  first.permno then
		car=ar;
	else
		car=car+ar;
	retain car;
run;

* Get averages and plot graph;

data d;
	set d;
	if ireccd=1 then sample="strong buy";
	else if ireccd=2 then sample="buy";
	else sample="the others";
	retain sample;
run;

proc sort data=d;
by sample rel_day;

proc means data=d noprint;
	var car ar;
	output out=d_stats(drop=_type_ _freq_)
	n(ar)=nar
	mean(ar)=aar
	t(ar)=t_ar
	n(car)=ncar
	mean(car)=acar
	t(car)=t_car;
	by sample rel_day;
run;


symbol1
color=green interpol=spline width=1 value=square;
symbol2
color=red interpol=spline width=1 value=triangle;
axis1
label=('announcement day')
order=-20 to 20 by 4
width=3;
axis2
label=('CAR')
order=-0.1 to 3 by 0.2
width=3;

proc gplot data=d_stats;
plot acar*rel_day=sample/haxis=axis1 vaxis=axis2;
run;
quit;

**************************************;
**************************************;
**************************************;

proc sql;
	create table e as
	select distinct
		a.ar,
		a.date,
		iporec.*
	from
		iporec,a
	where 
		iporec.permno=a.permno and
		iporec.offer_date-5<=a.date<=iporec.offer_date+55
	order by
		permno,offer_date;
quit;

data e;
 set e;
 end_date=offer_date+25;
 retain end_date;
run;

proc means data=e noprint;
var permno;
by permno;
output out=e_stats(drop=_type_ _freq_)
n=num_before;
where date<end_date;
run;

data f;
merge e e_stats;
by permno;
if first.permno then
rel_day=-num_before;
else
rel_day= rel_day +1;
retain rel_day;
run;

data f;
set f;
if -5<=rel_day<=5;
run;

data f;
set f;
by permno;
if first.permno then
car=ar;
else
car=car+ar;
retain car;
run;

* Get averages and plot graph?????;

data f;
set f;
if end_date-2<=anndats<=end_date+2 then  
sample="with initiations";
else
sample="without initiations";
retain sample;
run;

proc sort data=f;
by sample rel_day;

proc means data=f noprint;
var car ar;
output out=f_stats(drop=_type_ _freq_)
n(ar)=ar
mean(ar)=aar
t(ar)=t_ar
n(car)=ncar
mean(car)=acar
t(car)=t_car;
by sample rel_day;
run;


symbol1
color=green interpol=spline width=1 value=square;
symbol2
color=red interpol=spline width=1 value=triangle;
axis1
label=('the end of quiet period')
order=-4 to 4 by 1
width=3;
axis2
label=('CAR')
order=-0.8 to 0 by 0.1
width=3;

proc gplot data=f_stats;
plot acar*rel_day=sample/haxis=axis1 vaxis=axis2;
run;
quit;
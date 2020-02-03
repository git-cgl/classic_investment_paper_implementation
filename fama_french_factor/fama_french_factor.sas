/******************************************************
Description: collect data for FF factors
******************************************************/

libname worklib '/folders/myfolders/sasuser.v94/l9';

*Collect monthly data for stocks, 1963-1992;

data permno_shrcd;
    set worklib.permno_shrcd;
run;

data crspcusip;
    set worklib.crspcusip;
run;

proc sql;
create table d_ff as
select
    msf.permno,
    msf.ret,
    msf.prc,
    msf.shrout,
    msf.hsiccd,
    msf.hexcd,
    msf.date
from
    worklib.msf
where
    msf.hexcd<=3 and 1962<=year(msf.date)<=1992;

%*Collect compustat data and size of previous year;
data d_june;
    set d_ff;
    where month(date)=6 and 1963<=year(date)<=1992;

    if prc^=. and shrout^=. then
        size_june=abs(prc)*shrout;
    else
        size_june=.;
 

%* Collect sharecode;

proc sql;
create table d_june as
select distinct
    d_june.*,
    permno_shrcd.shrcd
from
    d_june left join permno_shrcd
on
    d_june.permno=permno_shrcd.permno and
    permno_shrcd.initial_date<=d_june.date and
    d_june.date<=permno_shrcd.final_date
order by
    permno,date,shrcd;
run;

proc sort data=d_june nodupkeys;
    by permno date;
run;


data d_june;
    set d_june;
    where shrcd^=. and 10<=shrcd<=12;
run;

proc sql;
create table d_cst as
select
    d_june.*,
    crspcusip.gvkey
from
    d_june left join crspcusip
on
    d_june.permno=crspcusip.permno and
    year(d_june.date)-1>=crspcusip.begyear and
    year(d_june.date)-1<=crspcusip.endyear;
run;


%* Collect sharecode;

data compann;
set worklib.compann;
where indfmt='INDL' and datafmt='STD' and consol='C' and popsrc='D';
if SEQ>0;                         /* Shareholders' Equity */
  PREF=PSTK;                      /* Preferred stock - Redemption Value */
  if missing(pref) then PREF=PSTKR; /* Preferred stock - Liquidating Value */
  data60 = sum(SEQ, TXDB, -PREF); /* Deferred taxes  and Investment Tax Credit */
  label data60 = "Book Value of Equity";
  rename at=data6;				/*Assets - Total/Liabilities and Stockholders' Equity*/
  rename EPSPX=data53;			/*Earnings per Share*/
  newgvkey=input(gvkey,8.);
run;

data compann;
	set compann;
	drop gvkey;
	rename newgvkey=gvkey;
run;

proc sql;
create table d_cst as
select
	d_cst.*,
	compann.data60,
	compann.data6,
	compann.data53,
	compann.datadate as compustat_date
from
	d_cst left join compann
on
	d_cst.gvkey=compann.gvkey and
	year(d_cst.date)-1=year(compann.datadate)        /*period t-1*/
order by
	date,permno;
run;


*Collect market size as of december of previous year;
proc sql;
create table d_cst_size as
select
	d_cst.*,
        (abs(d_ff.prc)*d_ff.shrout) as size_prev_year,
	d_ff.date as date_prev_year
from
	d_cst left join d_ff
on
	d_cst.permno=d_ff.permno and
	month(d_ff.date)=12 and 
	year(d_ff.date)=year(d_cst.date)-1
order by
	date, permno;
run;


data d_cst_size;
	set d_cst_size;
	where size_prev_year^=. and data6^=. and data60^=. and data53^=.;
run;

data worklib.d_cst_size;
    set d_cst_size;

data worklib.d_ff;
    set d_ff;
run;

  *Collect all NYSE, AMEX, Nasdaq data;
  proc sql;
  create table d as
  select
	  d_cst_size.*,
  	  (year(d_cst_size.date)*100+month(d_cst_size.date)) as month
  from
   	  worklib.d_cst_size
  where
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
	if size_prev_year^=. and size_prev_year^=0 and be^=. then
		beme=1000*be/size_prev_year;
	else
		beme=.;	
run;

%*Now look specifically at NYSE stocks;
proc univariate data=d noprint;
	where hexcd=1 and beme>0;
	var size;
	by month;
	output out=nyse_size median=sizemedn;
run;

proc univariate data=d noprint;
	where hexcd=1 and beme>0;
	var beme;
	by month;
	output out=nyse_beme pctlpts=30 70 pctlpre=beme;
run;

proc sql;
	create table d_1 as 
	select 
		d.*,
		nyse_size.sizemedn,
		nyse_beme.beme30,
		nyse_beme.beme70
	from 
		d,nyse_size,nyse_beme
	where
		d.month=nyse_size.month=nyse_beme.month;
quit;

data d_1;
	set d_1;
	if size<=sizemedn then 
		portfolio_size="s";
	else 
		portfolio_size="b";
		if beme<=beme30 then
			portfolio_beme="l";
		else 
 			if beme30<beme<=beme70 then
 				portfolio_beme="m";
 			else
 				portfolio_beme="h";
run;

proc sql;
	create table d_2 as 
	select 
		d_ff.*,
		d_1.portfolio_size,
		d_1.portfolio_beme
	from 
		d_1,worklib.d_ff
	where
		d_ff.permno=d_1.permno and
		mdy(7,1,year(d_1.date))<=d_ff.date<=mdy(6,30,year(d_1.date)+1);
run;

*compute market return;
proc sort data=d_2;
	by permno date;
run;

data d_2;
	set d_2;
	if permno=lag(permno) then
		lsize=lag(abs(prc))*lag(shrout);
	else
		lsize=".";
run;

proc sort data=d_2;
	by date permno;
run;

proc means data=d_2 noprint;
	weight lsize;
	output out=d_mktret
	mean(ret)=mktret_1;
	by date;
	where lsize^=.;
run;

*compute smb&hml;
data d_2;
	set d_2;
	if portfolio_size="s" and portfolio_beme="l" then
		portfolio="sl";
	if portfolio_size="s" and portfolio_beme="m" then
		portfolio="sm";
	if portfolio_size="s" and portfolio_beme="h" then
		portfolio="sh";
	if portfolio_size="b" and portfolio_beme="l" then
		portfolio="bl";
	if portfolio_size="b" and portfolio_beme="m" then
		portfolio="bm";
	if portfolio_size="b" and portfolio_beme="h" then
		portfolio="bh";
run;
		
proc sort data=d_2;
	by date portfolio;
run;

proc means data=d_2 noprint;
	weight lsize;
	output out=d_3
	mean(ret)=ret;
	by date portfolio;
	where lsize^=.;
run;

proc transpose data=d_3 out=d_4;
	by date;
	id portfolio;
	var ret;
run;

data factors;
	set d_4;
	smb_1=((sl+sm+sh)-(bl+bm+bh))/3;
	hml_1=((bh+sh)-(bl+sl))/2;
run;

data factors;
	set factors;
	keep date smb_1 hml_1;
run;

proc import datafile="/folders/myfolders/sasuser.v94/l9/ff_factors.xls"
	dbms=xls
	out=worklib.ff_factors REPLACE;
run;

proc sql;
	create table compare as
	select 
		factors.*,
		d_mktret.mktret_1,
		ff_factors.*
	from 
		factors, d_mktret,worklib.ff_factors
	where
		year(factors.date)*100+month(factors.date)=year(d_mktret.date)*100+month(d_mktret.date)=ff_factors.date;
quit;

proc corr data=compare;
	var smb_1 smb;
run;
proc corr data=compare;
	var hml_1 hml;
run;
proc corr data=compare;
	var mktret_1 mktrf;
run;

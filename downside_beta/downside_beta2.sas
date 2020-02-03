options MPRINT SYMBOLGEN MLOGIC nonumber nocenter nodate ls=132; 
libname worklib 'D:\BookHouse\中财\投资学\课件\MID';

data d1;
	set worklib.fullsample_0620;
run;

data d1;
set d1;
if clsprc^=0 & clsprc^=. & Dsmvosd^=0 & Dsmvosd^=.;
run;

/*个股月度收益率（连续复利）*/

proc sort data=d1;
	by stkcd trddt;
run;

proc expand data=d1 out=ret method=none;
	by stkcd;
	convert clsprc=lag_clsprc /transformout=(lag 1);
run;

data ret;
	set ret;
	ret=clsprc/lag_clsprc;
	log_ret=log(ret);
run;

/*我认为上面算对数收益率的两步不需要加1*/
/*ret = clsprc/lag_clsprc-1; log_ret = log(1+ret)*/

proc sort data=ret;
	by stkcd year month;
run;

proc means data=ret noprint;
	output out=msf
	sum(log_ret)=log_ret;
by stkcd year month;
run;

data msf;
set msf;
	monthlyret=exp(log_ret)-1;
drop _TYPE_ _FREQ_;
run;

data indct;
set msf;
	yearmonth=100*year+month;
keep year month yearmonth;
run;

proc sort data=indct nodupkey;
	by yearmonth;
run;

data indct;
	set indct;
	sequence=_n_;
run;

/*按市值加权市场月度收益率*/

proc sort data=d1;
	by trddt stkcd;

proc means data=d1 noprint;
	var clsprc;
	weight Dsmvosd;
	by trddt;
	id year month;
	output out=makindex(drop=_TYPE_ _FREQ_)
		mean(clsprc)=makindex;
run;

proc expand data=makindex out=makindex(drop=time) method=none;
	convert makindex=lag_makindex/transformout=(lag 1);
run;

data makindex;
	set makindex;
	makret=log(makindex/lag_makindex);
run;

proc sort data=makindex;
	by year month;

proc means data=makindex noprint;
	var makret;
	by year month;
	output out=makindex1(keep=year month lag_makret)
		sum(makret)=lag_makret;
run;

data makindex1;
	set makindex1;
	monthly_makret=exp(lag_makret)-1;
run;

/*月度size,做法：每个月Dsmvosd求均值*/
proc sort data=d1;
	by year month stkcd;
run;

proc means data=d1 noprint;
	var dsmvosd;
	by year month stkcd;
	output out=dsize(keep=year month stkcd monthlysize)
		mean(dsmvosd)=monthlysize;
run;

data dsize;
	set dsize;
	yearmonth=year*100+month;
run;



/*并表(序数日期，个股月度收益率，市场月度收益率)*/

proc sort data=msf;by year month;run;
proc sort data=makindex1;by year month;run;

data d2;
	merge 
		indct 
		msf(keep=stkcd year month monthlyret) 
		makindex1(keep=year month monthly_makret);
	by year month;
run;

proc sql;
create table d2 as
select
	d2.*,
	dsize.monthlysize
from d2 left join dsize
on d2.yearmonth=dsize.yearmonth and d2.stkcd=dsize.stkcd;
quit;

data d2;
set d2;
if monthlyret^=0 & monthlyret^=.;
monthlyar=monthlyret-monthly_makret;
run;

proc sort data=d2;
by stkcd yearmonth;
run;

proc expand data=d2 out=d2(drop=time) method=none;
	convert monthlysize=lag1_monthlysize/transformout=(lag 1);
	by stkcd;
run;



%macro Q2(monthcycle=);
%do i=1 %to &monthcycle;
%let m=12+&i;
/*求downside beta(对个股过去12个月数据进行timeseries regression)*/

/*%let m=12+15;*/

	data test;
	set d2;
	where &m-12<=sequence<=&m-1;
	if monthly_makret>0 then delete;
	run;

	proc sort data=test;by stkcd yearmonth;run;

	proc reg data=test outest =dbeta(rename=(monthly_makret=down_beta)) noprint;	
		model monthlyar=monthly_makret;
		by stkcd;
		output out=d_res
			residual=r;
	run;

	proc means data=d_res noprint;
		var r;
		by stkcd;
		output out=d_skew(keep=stkcd res_skew)
			skew(r)=res_skew;
	run;

	/*选取第13个月的个股收益率数据，并与基于过去12个月回归得到的downside beta数据合并*/

	data d3;
	set d2;
	where sequence=&m;

	proc sql;
	create table d4 as
	select
		d3.*,
		dbeta.stkcd,
		dbeta.down_beta,
		d_skew.res_skew
	from d3
	join dbeta on d3.stkcd=dbeta.stkcd
	join d_skew on d3.stkcd=d_skew.stkcd;
	quit;

	data d4;
	set d4;
	if down_beta^=. & down_beta^=0 & res_skew^=. & res_skew^=0;
	run;

	proc rank data=d4 out=g_beta groups=5;
		var down_beta;
		ranks rankbeta;
	run;

	proc sort data=g_beta;by rankbeta;run;

	proc rank data=g_beta out=g_beta_skew groups=5;
		var res_skew;
		ranks rankskew;
		by rankbeta;
	run;

	proc sort data=g_beta_skew;by yearmonth rankbeta rankskew;run;

	proc means data=g_beta_skew noprint;
		var monthlyar;
		by yearmonth rankbeta rankskew;
		output out=ret_25g(keep=yearmonth rankbeta rankskew pret)
			mean(monthlyar)=pret;
	run;

	proc sort data=ret_25g;by yearmonth rankskew rankbeta;run;

	proc transpose data=ret_25g out=ret_25g_t prefix=beta;
		var pret;
		by yearmonth rankskew;
		id rankbeta;
	run;

	%if i=1 %then %do;
		data dc;
		set ret_25g_t;
	%end;
	%else %do;
		proc append base=dc data=ret_25g_t;
		run;
	%end;
%end;
%mend Q2;

%Q2(monthcycle=29);

/*dc中，从2017年6月到2018年3月出现全部为确实值，是因为要限制求downside beta的回归中要限制市场收益率为负
导致回归使用的数据只有两个月，回归后求残差，其中一个是0或者都是0，这就导致求偏度时，分母(标准差)为0，所以
偏度全部都是缺失值*/

/*每个月，同一skew下，用beta4组减beta0组，得到同样的skew组内由于beta不一样产生的差值*/

/*方法3 求两次diff*/

data dc;
set dc;
if yearmonth^=.;
diff=beta4-beta0;
run;

/*新建序数时间变量，然后合并到dc中*/

data intym;
	set dc;
	keep yearmonth;
run;

proc sort data=intym nodupkey;
by yearmonth;
run;

data intym;
	set intym;
	sequence=_n_;
run;

data dc;
	merge dc intym;
	by yearmonth;
run;

%macro manipulating(cycle=);
%do i=1 %to &cycle;

	data dc1;
	set dc;
	if sequence=&i;
	run;

	proc transpose data=dc1 out=dc1_t prefix=skew;
		var diff;
		by yearmonth;
		id rankskew;
	run;

	%if i=1 %then %do;
		data dcf;
		set dc1_t;
	%end;
	%else %do;
		proc append base=dcf data=dc1_t;
		run;
	%end;
%end;
%mend manipulating;

%manipulating(cycle=19);

data dcf;
set dcf;
drop _NAME_;
diff=skew4-skew1;
run;

proc means data=dcf noprint;
	var diff;
	output out=final(keep=mdd t_mdd)
		mean(diff)=mdd
		t(diff)=t_mdd;
run;

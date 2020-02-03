options MPRINT SYMBOLGEN MLOGIC nonumber nocenter nodate ls=132; 
libname worklib '';

data d1;
	set worklib.fullsample_0620;
run;

data d1;
set d1;
if clsprc^=0 & clsprc^=. & Dsmvosd^=0 & Dsmvosd^=.;
run;



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

/*����Ϊ��������������ʵ���������Ҫ��1*/
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

/*����ֵ��Ȩ�г��¶�������*/

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

/*�¶�size,������ÿ����Dsmvosd���ֵ*/
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

/*�¶�pe,����ÿ����pe���ֵ*/
proc sort data=d1;
	by year month stkcd;
run;

proc means data=d1 noprint;
	var pe;
	by year month stkcd;
	output out=dpe(keep=year month stkcd monthlype)
		mean(pe)=monthlype;
run;

data dpe;
	set dpe;
	yearmonth=year*100+month;
run;

/*�¶�turnover������ÿ�������ֵ*/
proc sort data=d1;
	by year month stkcd;
run;

proc means data=d1 noprint;
	var turnover;
	by year month stkcd;
	output out=dto(keep=year month stkcd monthlyto)
		mean(turnover)=monthlyto;
run;

data dto;
	set dto;
	yearmonth=year*100+month;
run;



/*����(�������ڣ������¶������ʣ��г��¶�������)*/

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
	dsize.monthlysize,
	dpe.monthlype,
	dto.monthlyto
from d2 
left join dsize on d2.yearmonth=dsize.yearmonth and d2.stkcd=dsize.stkcd
left join dpe on d2.yearmonth=dpe.yearmonth and d2.stkcd=dpe.stkcd
left join dto on d2.yearmonth=dto.yearmonth and d2.stkcd=dto.stkcd;
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



%macro Q3(monthcycle=);
%do i=1 %to &monthcycle;
%let m=12+&i;
/*��downside beta(�Ը��ɹ�ȥ12�������ݽ���timeseries regression)*/

/*%let m=12+15;*/

/*��downside beta*/

	data db_test;
		set d2;
		where &m-12<=sequence<=&m-1;
		if monthly_makret>0 then delete;
	run;

	proc sort data=db_test;by stkcd yearmonth;run;


	proc reg data=db_test outest =d_down_beta(rename=(monthly_makret=down_beta)) noprint;	
		model monthlyar=monthly_makret;
		by stkcd;
	run;

/*���,momentum,Residual Volatility*/

	data test;
	set d2;
	where &m-12<=sequence<=&m-1;
/*	if monthly_makret>0 then delete;*/
	run;

	proc sort data=test;by stkcd yearmonth;run;

/*beta�к��е��������*/

	proc reg data=test outest =d_beta(rename=(monthly_makret=beta)) noprint;	
		model monthlyar=monthly_makret;
		by stkcd;
		output out=d_res
			residual=r;
	run;

/*d_std��Ϊ���£�����ǰʮ���£������׼���Residual Volatility*/

	proc means data=d_res noprint;
		var r;
		by stkcd;
		output out=d_std(keep=stkcd res_std)
			std(r)=res_std;
	run;

/*d_momentum��Ϊ����momentum*/
	
	data test;
	set test;
	log_ret=log(1+monthlyret);
	run;

	proc sort data=test;by stkcd yearmonth;

	proc means data=test noprint;
		var log_ret;
		by stkcd;
		output out=d_momentum(keep=stkcd mom)
			sum(log_ret)=mom;
	run;

/*��size��log of market cap��*/

	proc sort data=test;by stkcd;run;

	proc means data=test noprint;
		var monthlysize;
		by stkcd;
		output out=d_size(keep=stkcd size_12m)
			mean(monthlysize)=size_12m;
	run;

	data d_size;
	set d_size;
	log_size=log(size_12m);
	drop size_12m;
	run;

/*��Book-to-Price*/
	proc sort data=test;by stkcd;run;

	proc means data=test noprint;
		var monthlype;
		by stkcd;
		output out=d_bp(keep=stkcd bp)
			mean(monthlype)=bp;
	run;

/*��Liquidity*/
	proc sort data=test;by stkcd;run;

	proc means data=test noprint;
		var monthlyto;
		by stkcd;
		output out=d_liq(keep=stkcd liq)
			mean(monthlyto)=liq;
	run;

/*��Non-linear size*/
	data dnls;
		set test;
		mscube=(monthlysize)**3;
		keep stkcd yearmonth monthlysize mscube;
	run;

	proc sort data=dnls;by stkcd;run;

	proc reg data=dnls noprint;
		model mscube=monthlysize;
		by stkcd;
		output out=d_size_res
			residual=r;
	run;

	proc means data=d_size_res noprint;
		var r;
		by stkcd;
		output out=d_nls(keep=stkcd nls)
			mean(r)=nls;
	run;

	data d_factor;
	merge
		d_down_beta(keep=stkcd down_beta) d_beta(keep=stkcd beta) d_momentum d_size d_std d_bp d_liq d_nls;
	by stkcd;
	run;

	data d_factor;
	set d_factor;
	label 
		res_std=
		nls=;
	run;

	proc corr data=d_factor outp=d_cor noprint;
		var down_beta beta mom log_size res_std bp liq nls;
	run;

	data d_cor;
		set d_cor;
		yearmonth=&m;
		drop down_beta _TYPE_  _NAME_;
		if _NAME_="down_beta";	
	run;



	%if i=1 %then %do;
		data dc;
		set d_cor;
	%end;
	%else %do;
		proc append base=dc data=d_cor;
		run;
	%end;
%end;
%mend Q3;

%Q3(monthcycle=29);


proc means data=dc norpint;
	var beta mom log_size res_std bp liq nls;
	output out=dcor(keep=cbeta cmom clog_size cres_std cbp cliq cnls)
		mean(beta mom log_size res_std bp liq nls)=cbeta cmom clog_size cres_std cbp cliq cnls;
run;



%macro Factor(monthcycle=);
%do i=1 %to &monthcycle;
%let m=12+&i;

/*%let m=12+1;*/

/*��������*/
	data db_test;
		set d2;
		where &m-12<=sequence<=&m-1;
		if monthly_makret>0 then delete;
	run;

	proc sort data=db_test;by stkcd yearmonth;run;

	proc reg data=db_test outest =d_down_beta(rename=(monthly_makret=down_beta)) noprint;	
		model monthlyar=monthly_makret;
		by stkcd;
	run;


	data test;
	set d2;
	where &m-12<=sequence<=&m-1;
	run;

	proc sort data=test;by stkcd yearmonth;run;
	
	proc reg data=test outest =d_beta(rename=(monthly_makret=beta)) noprint;	
		model monthlyar=monthly_makret;
		by stkcd;
	run;

	data t_factor;
	merge
		d_down_beta(keep=stkcd down_beta)
		d_beta(keep=stkcd beta);
	by stkcd;
	run;

/*fama france��������*/

/*��downside beta������*/

	proc univariate noprint data=t_factor;
		var down_beta;
		output out=g_d pctlpts=30 70 pctlpre=pct;
	run;

	data _null_;
		set g_d;
		call symput("g30",pct30);
		call symput("g70",pct70);
	run;

	data t_factor;
		set t_factor;
		if down_beta<&g30 then g_down_beta="dl";
		else if &g30<=down_beta<=&g70 then g_down_beta="dm";
		else g_down_beta="dh";
	run;

	/*��beta������*/
	proc univariate noprint data=t_factor;
		var beta;
		output out=g_b pctlpts=30 70 pctlpre=pct;
	run;

	data _null_;
		set g_b;
		call symput("b30",pct30);
		call symput("b70",pct70);
	run;

	data t_factor;
		set t_factor;
		if beta<&b30 then g_beta="bl";
		else if &b30<=beta<=&b70 then g_beta="bm";
		else g_beta="bh";
	run;

	data d3;
		set d2;
		where sequence=&m;
	run;

	proc sql;
	create table all as
	select	
		d3.stkcd,
		d3.yearmonth,
		d3.monthlyar,
		d3.monthlysize,
		t_factor.g_down_beta,
		t_factor.g_beta
	from d3 
	join t_factor on d3.stkcd=t_factor.stkcd
	order by g_down_beta,g_beta;
	quit;

	/*�����downside beta�����HML*/

	proc means data=all noprint;
		var monthlyar;
		weight monthlysize;
		by yearmonth g_down_beta g_beta;
		output out=gr(keep=yearmonth g_down_beta g_beta m_ar)
			mean(monthlyar)=m_ar;
	run;

	proc sort data=gr;
	by yearmonth g_down_beta;
	run;

	proc means data=gr noprint;
		var m_ar;
		by yearmonth g_down_beta;
		output out=dbr(keep=yearmonth g_down_beta db_ar)
			mean(m_ar)=db_ar;
	run;

	proc sql;
	create table dbhml as
	select
		d1.yearmonth,
		(d1.db_ar - d2.db_ar) as dbhml
	from
		dbr as d1
	join
		dbr as d2
	on d1.yearmonth=d1.yearmonth and d1.g_down_beta="dh" and d2.g_down_beta="dl";	
	quit;

	/*�����beta�����HML*/

	proc sort data=gr;
	by yearmonth g_beta;
	run;

	proc means data=gr noprint;
		var m_ar;
		by yearmonth g_beta;
		output out=br(keep=yearmonth g_beta b_ar)
			mean(m_ar)=b_ar;
	run;

	proc sql;
	create table bhml as
	select
		b1.yearmonth,
		(b1.b_ar - b2.b_ar) as bhml
	from
		br as b1
	join
		br as b2
	on b1.yearmonth=b1.yearmonth and b1.g_beta="bh" and b2.g_beta="bl";
	quit;	


	%if &i=1 %then %do;
	     data c_dbhml;
	  	 set dbhml;

		 data c_bhml;
	  	 set bhml;
	%end;
	%else %do;
	      proc append base=c_dbhml data=dbhml;
		  run;
	      
		  proc append base=c_bhml data=bhml;
		  run;
	%end;
%end;
%mend Factor;

%Factor(monthcycle=29);






%macro FF(monthcycle=);
%do i=1 %to &monthcycle;
%let m=12+&i;

/*%let m=12+1;*/

/*��������*/
	data db_test;
		set d2;
		where &m-12<=sequence<=&m-1;
		if monthly_makret>0 then delete;
	run;

	proc sort data=db_test;by stkcd yearmonth;run;

	proc reg data=db_test outest =d_down_beta(rename=(monthly_makret=down_beta)) noprint;	
		model monthlyar=monthly_makret;
		by stkcd;
	run;


	data test;
	set d2;
	where &m-12<=sequence<=&m-1;
	run;

	proc sort data=test;by stkcd yearmonth;run;
	
	proc reg data=test outest =d_beta(rename=(monthly_makret=beta)) noprint;	
		model monthlyar=monthly_makret;
		by stkcd;
	run;

	data t_factor;
	merge
		d_down_beta(keep=stkcd down_beta)
		d_beta(keep=stkcd beta);
	by stkcd;
	run;

	proc rank data=t_factor out=g_d5 groups=5;
		var down_beta;
		ranks rankdb;
	run;

	proc rank data=t_factor out=g_b5 groups=5;
		var beta;
		ranks rankb;
	run;

	data ff25;
	merge 
		g_d5(keep=stkcd rankdb)
		g_b5(keep=stkcd rankb);
	run;

	data d4;
	set d2;
	where sequence=&m;
	run;

	proc sql;
	create table ff25ret as
	select
		ff25.rankdb,
		ff25.rankb,
		d4.stkcd,
		d4.yearmonth,
		d4.monthlyar,
		d4.monthly_makret
	from ff25
	left join d4 on ff25.stkcd=d4.stkcd;
	quit;


	%if i=1 %then %do;
		data c_ff25ret;
		set ff25ret;
	%end;
	%else %do;
		proc append base=c_ff25ret data=ff25ret;
		run;
	%end;
%end;
%mend FF;

%FF(monthcycle=29);


/*ÿ���·�25�飬�ۼ�29���£�Ȼ��Ѹ�������ڶ�������������Ӻϲ���*/

proc sql;
	create table dff as
	select 
		c_ff25ret.*,
		c_bhml.bhml,
		c_dbhml.dbhml
	from c_ff25ret
	join c_bhml on c_ff25ret.yearmonth=c_bhml.yearmonth
	join c_dbhml on c_ff25ret.yearmonth=c_dbhml.yearmonth;
quit;

data dff;
set dff;
if rankdb^=.;
if rankb^=.;
run;

proc sort data=dff;
by rankdb rankb;
run;

proc reg data=dff outest=out_reg outseb noprint;
	model monthlyar=monthly_makret bhml dbhml;
	by rankdb rankb;
run;

proc sql;
create table out_reg_stats as
select
	o1.rankdb,
	o1.rankb,

	o1.Intercept,
	o1.Intercept/o2.Intercept as t_intercept,

	o1.monthly_makret,
	o1.monthly_makret/o2.monthly_makret as t_monthly_makret,

	o1.bhml,
	o1.bhml/o2.bhml as t_bhml,

	o1.dbhml,
	o1.dbhml/o2.dbhml as t_dbhml

from out_reg as o1
join out_reg as o2
on 
	o1.rankdb=o2.rankdb and o1.rankb=o2.rankb
	and o1._TYPE_="PARMS"
	and o2._TYPE_="SEB";
quit;

proc transpose data=out_reg_stats out=d_stats_int prefix=int;
	by rankdb;
	var intercept;
	id rankb;
run;

proc transpose data=out_reg_stats out=d_stats_t_int prefix=t_int;
	by rankdb;
	var t_intercept;
	id rankb;
run;

proc transpose data=out_reg_stats out=d_stats_mr prefix=mr;
	by rankdb;
	var monthly_makret;
	id rankb;
run;

proc transpose data=out_reg_stats out=d_stats_t_mr prefix=t_mr;
	by rankdb;
	var t_monthly_makret;
	id rankb;
run;

proc transpose data=out_reg_stats out=d_stats_bhml prefix=bhml;
	by rankdb;
	var bhml;
	id rankb;
run;

proc transpose data=out_reg_stats out=d_stats_t_bhml prefix=t_bhml;
	by rankdb;
	var t_bhml;
	id rankb;
run;

proc transpose data=out_reg_stats out=d_stats_dbhml prefix=dbhml;
	by rankdb;
	var dbhml;
	id rankb;
run;

proc transpose data=out_reg_stats out=d_stats_t_dbhml prefix=t_dbhml;
	by rankdb;
	var t_dbhml;
	id rankb;
run;

data d_stats;
	merge
		d_stats_int d_stats_t_int
		d_stats_mr d_stats_t_mr
		d_stats_bhml d_stats_t_bhml
		d_stats_dbhml d_stats_t_dbhml;
	by rankdb;
run;

proc print data=d_stats;
	title 'Stats on Intercept';
	var rankdb int0-int4 t_int0-t_int4;
run;

proc print data=d_stats;
	title 'Stats on makret';
	var rankdb mr0-mr4 t_mr0-t_mr4;
run;

proc print data=d_stats;
	title 'Stats on bhml';
	var rankdb bhml0-bhml4 t_bhml0-t_bhml4;
run;

proc print data=d_stats;
	title 'Stats on dbhml';
	var rankdb dbhml0-dbhml4 t_dbhml0-t_dbhml4;
run;

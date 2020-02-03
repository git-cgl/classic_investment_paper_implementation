options MPRINT SYMBOLGEN MLOGIC nonumber nocenter nodate ls=132; 
libname worklib 'D:\BookHouse\�в�\Ͷ��ѧ\�μ�\MID';

data d1;
	set worklib.fullsample_0620;
run;

data d1;
set d1;
if clsprc^=0 & clsprc^=. & Dsmvosd^=0 & Dsmvosd^=.;
run;

/*�����¶������ʣ�����������*/

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
/*��downside beta(�Ը��ɹ�ȥ12�������ݽ���timeseries regression)*/

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

	/*ѡȡ��13���µĸ������������ݣ�������ڹ�ȥ12���»ع�õ���downside beta���ݺϲ�*/

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

/*dc�У���2017��6�µ�2018��3�³���ȫ��Ϊȷʵֵ������ΪҪ������downside beta�Ļع���Ҫ�����г�������Ϊ��
���»ع�ʹ�õ�����ֻ�������£��ع����в����һ����0���߶���0����͵�����ƫ��ʱ����ĸ(��׼��)Ϊ0������
ƫ��ȫ������ȱʧֵ*/

/*ÿ���£�ͬһskew�£���beta4���beta0�飬�õ�ͬ����skew��������beta��һ�������Ĳ�ֵ*/

/*����3 ������diff*/

data dc;
set dc;
if yearmonth^=.;
diff=beta4-beta0;
run;

/*�½�����ʱ�������Ȼ��ϲ���dc��*/

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

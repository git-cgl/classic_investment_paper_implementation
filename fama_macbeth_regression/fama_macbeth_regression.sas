
options MPRINT SYMBOLGEN MLOGIC;

libname worklib '/folders/myfolders/sasuser.v94/l6';


%macro fm(num_cycles=);

proc sql;
create table msf_data as
select
    msf.permno,
    msf.ret,
    msf.date,
    msf.prc*msf.shrout as size 
from
    worklib.msf
where
    hexcd=1 and 1958<=year(date)<=1991;

data d_fm;
	set msf_data;
run;

%do i=1 %to &num_cycles;
  %let year_cycle=1958+(&i-1)*4;

  proc sql;
  create table d as
  select
  	  d_fm.*,
  	  (year(d_fm.date)*100+month(d_fm.date)) as month
  from
   	  d_fm
  where
      &year_cycle-6<=year(date)<=&year_cycle+9;

 * Number months;
  proc sort data=d out=d_months(keep=month) nodupkeys;
    by month;

  data d_months;
    set d_months;
    i+1;

  * Get market return;
  proc sort data=d;
    by month;

  proc means data=d noprint;
    by month;
    output out=d_mkt_return
        mean(ret)=market_ret;

  proc sort data=d;
    by month;

  data d;
    merge
      d(keep=month permno ret date size)
      d_mkt_return(keep=month market_ret)
      d_months(keep=month i);
    by month;

	year_cycle=&year_cycle;
    if ret^=.;

  * Keep only securities with returns in all months;
  * of the estimation period and at least 48 months;
  * of the formation period;
  proc sort data=d;
    by permno;

  proc means data=d noprint;
    var ret;
    output out=d_stats_form (drop=_type_ _freq_) n=n_ret_form;
    by permno;
	where (&year_cycle=1958 and 1<=i<=48) or (&year_cycle^=1958 and 1<=i<=84);

  proc means data=d noprint;
    var ret;
    output out=d_stats_test (drop=_type_ _freq_) n=n_ret_test;
    by permno;
	where (&year_cycle=1958 and 49<=i<=48+60) or (&year_cycle^=1958 and 85<=i<=84+60);

  data d;
    merge d d_stats_form d_stats_test;
    by permno;

    if n_ret_form>=48 and n_ret_test=60;
  
  * Compute betas on the portfolio formation;
  * period, i.e., i=1 thru 84 or i thru 48  ;
  * if first cycle;

  proc reg data=d outest=data_reg(rename=(market_ret=beta)) noprint;
    model ret=market_ret;
    by permno;
	where (&year_cycle=1958 and 1<=i<=48) or (&year_cycle^=1958 and 1<=i<=84);

  data d_size;
  	set d(keep=permno size i);
  	where (&year_cycle=1958 and i=48) or (&year_cycle^=1958 and i=84);
  run;
  
  proc sql;
  create table d1 as
  select
	d_size.size,
	data_reg.*
  from
	d_size left join data_reg
  on
	d_size.permno=data_reg.permno;
  quit;
  


  *Define portfolios according to the partition;
  *defined in Fama and MacBeth;
  
  proc sort data=d1;by size;run;
  proc rank data=d1 out=d1 group=5;
  var size;
  ranks sizerank;
  run;
  proc sort data=d1; by sizerank; run;
  proc rank data=d1 out=d1 group=5;
  var beta;
  ranks betarank;
  run;
  
  proc sql;
  create table d as
  select
	d.*,
	d1.sizerank,
	d1.betarank
  from
	d left join d1
  on
	d.permno=d1.permno;
	
	
	
  %do year_testing=1 %to 4;

    *Recompute beta thru estimation period;
    proc reg data=d outest=data_reg(rename=(market_ret=beta)) noprint;
      model ret=market_ret;
      by permno;
      where (&year_cycle=1958 and 49<=i<=48+(5+&year_testing-1)*12) or
            (&year_cycle^=1958 and 85<=i<=84+(5+&year_testing-1)*12);
  
  data d_size;
  	set d(keep=permno size i);
  	where (&year_cycle=1958 and i=48+(5+&year_testing-1)*12) or
            (&year_cycle^=1958 and i=84+(5+&year_testing-1)*12);
  run;
  
  
    proc sql;
    create table d_year as
    select
	  d.permno,
	  d.date,
	  d.ret,
	  d.month,
	  d.market_ret,
	  d.i,
	  d.year_cycle,
	  d.sizerank,
	  d.betarank,
	  d_size.size,
	  data_reg.beta
    from
	  d, data_reg,d_size
    where
	  d.permno=data_reg.permno and
	  d.permno=d_size.permno and 
	  year(d.date)=&year_cycle+5+&year_testing
    order by
      permno,date;

    %if &i=1 and &year_testing=1 %then
    %do;
  	  data d_testing;
	  	set d_year;
    %end;
    %else
    %do;
      proc append base=d_testing data=d_year;
      run;
    %end;
  %end;
%end;

*Compute portfolio returns and betas;
proc sort data=d_testing;
	by sizerank betarank month;

proc means data=d_testing noprint;
	var beta size ret;
	by sizerank betarank month;
	output out=d_reg
		mean(beta)=beta
		mean(size)=size
		mean(ret)=ret;

*Compute monthly CS regressions;
proc sort data=d_reg;
	by month;

proc reg data=d_reg outest=d_reg_output(keep=month intercept beta size) noprint;
	model ret=beta size;
	by month;

*Summarize the CS coefficients;
proc means data=d_reg_output noprint;	
	var intercept beta size month;
	output out=d_fm_output
		mean(intercept beta size)=mean_intercept mean_beta mean_size
		stddev(intercept beta size)=std_intercept std_beta std_size
		n(intercept beta size)=n_intercept n_beta n_size
 		min(month)=starting_month
 		max(month)=ending_month;
	where 196701<=month<=198406;

data d_fm_output_1;
	set d_fm_output;

	t_intercept=mean_intercept/(std_intercept/sqrt(n_intercept));
	t_beta=mean_beta/(std_beta/sqrt(n_beta));
	t_size=mean_size/(std_size/sqrt(n_size));
	sample="1967-6/84" ;

proc means data=d_reg_output noprint;	
	var intercept beta month size;
	output out=d_fm_output
		mean(intercept beta size)=mean_intercept mean_beta mean_size
		stddev(intercept beta size)=std_intercept std_beta std_size
		n(intercept beta size)=n_intercept n_beta n_size
 		min(month)=starting_month
 		max(month)=ending_month;
	where 196701<=month<=197712;

data d_fm_output_2;
	set d_fm_output;

	t_intercept=mean_intercept/(std_intercept/sqrt(n_intercept));
	t_beta=mean_beta/(std_beta/sqrt(n_beta));
	t_size=mean_size/(std_size/sqrt(n_size));
	sample="1967-77" ;

proc means data=d_reg_output noprint;	
	var intercept beta month size;
	output out=d_fm_output
		mean(intercept beta size)=mean_intercept mean_beta mean_size
		stddev(intercept beta size)=std_intercept std_beta std_size
		n(intercept beta size)=n_intercept n_beta n_size
 		min(month)=starting_month
 		max(month)=ending_month;
	where 196701<=month<=199112;

data d_fm_output_3;
	set d_fm_output;

	t_intercept=mean_intercept/(std_intercept/sqrt(n_intercept));
	t_beta=mean_beta/(std_beta/sqrt(n_beta));
	t_size=mean_size/(std_size/sqrt(n_size));
	sample="1967-91" ;

data d_fm_output;
	set d_fm_output_1
	    d_fm_output_2
		d_fm_output_3;

proc print data=d_fm_output label;
	var sample n_intercept starting_month ending_month mean_intercept t_intercept
	    mean_beta t_beta mean_size t_size;
	label 
	    starting_month="Start"
	    ending_month="End"
        n_intercept="months"
 		mean_intercept="delta0"
        t_intercept="t(delta0)"
        mean_beta="delta1"
        t_beta="t(delta1)"
        mean_size="delta2"
        t_size="t(delta2)";
	format
		mean_intercept mean_beta mean_size 5.4
        t_intercept t_beta t_size 4.4;
run;
%mend fm;

%fm(num_cycles=7);


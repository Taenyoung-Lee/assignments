options yearcutoff=1850;
filename rain "/home/u64002670/time_series/강릉강수량_s.csv" encoding="euc-kr";
/* CSV 파일 불러오기 */
proc import datafile=rain
    out=work.rain_raw dbms=csv replace;
    getnames=yes;
run;

/* 2) DATETIME(초) → DATE(일) → 월초로 정렬, 강수량 표준화 */
data work.series;
    set work.rain_raw;
    /* 일시가 숫자형 DATETIME. 로 읽힌 경우: datepart로 '일' 단위 추출 */
    date = intnx('month', datepart("일시"n), 0, 'b');  /* 그 달의 월초 날짜 */
    format date yymmn7.;  /* 1911-10 형태로 보이게 */
    precip = "강수량(mm)"n;
    keep date precip;
run;

proc sgplot data=work.series;
    title "강릉 월별 강수량(원자료)";
    series x=date y=precip;
    xaxis label="날짜";
    yaxis label="강수량 (mm)";
run;

PROC ARIMA DATA=series;
    /*원본 데이터의 정상성 확인*/
    IDENTIFY VAR=precip;
    TITLE "원본 데이터 ACF/PACF";
RUN;


PROC ARIMA DATA=series;
    /*원본 데이터의 정상성 확인*/
    IDENTIFY VAR=precip(12);
    TITLE "원본 데이터 ACF/PACF";
RUN;

proc arima data=series;
   identify var=precip(12) nlag=36
            stationarity=(adf=(0,12)); /* 단위근 점검 */
            
   title "계절 1차 차분 후: 식별 단계";
run;



/**********************************************/
/**********************************************/
/**********************************************/
/**********************************************/

proc sql;
   drop table IDENTIFY_STAT ; 
   create table IDENTIFY_STAT 
   (p   integer ,
   q   integer ,
   sp integer ,
   sq integer ,
   AIC   real) ; 
quit;

/***** 와 의 에 대하여  를 계산하여 저장하는 SAS macro 프로그램임 *****/
/***** 다른 시계열 자료에 대해서도 자료의 이름과 변수명만 변경하여 사용하면 됨 *****/

%macro Select_order;

%do sp = 0 % to 2 ;
%do sq = 0 % to 2 ;
%do p = 0 % to 3 ;
%do q = 0 % to 3 ;
%if &p. > 0 or &q. > 0 or &sp. > 0 or &sq. >0 %then %do ; 

%if &p. = 0 %then %let p1= 0 ;  %else %if &p.=1 %then %let p1 = 1 ;
%else %if &p.=2 %then %let p1=1  ; %else %if &p.=3 %then %let p1=1 ;
%if &p. = 0 %then %let p2= 0 ;  %else %if &p.=1 %then %let p2 = 0 ; 
%else %if &p.=2 %then %let p2=2  ; %else %if &p.=3 %then %let p2=2 ;
%if &p. = 0 %then %let p3= 0 ;  %else %if &p.=1 %then %let p3 = 0 ;
%else %if &p.=2 %then %let p3=0  ; %else %if &p.=3 %then %let p3=3 ;


%if &q. = 0 %then %let q1= 0 ;  %else %if &q.=1 %then %let q1 = 1 ;
%else %if &q.=2 %then %let q1=1  ; %else %if &q.=3 %then %let q1=1 ;
%if &q. = 0 %then %let q2= 0 ;  %else %if &q.=1 %then %let q2 = 0 ;
%else %if &q.=2 %then %let q2=2  ; %else %if &q.=3 %then %let q2=2 ;
%if &q. = 0 %then %let q3= 0 ;  %else %if &q.=1 %then %let q3 = 0 ;
%else %if &q.=2 %then %let q3=0  ; %else %if &q.=3 %then %let q3=3 ;

%if &sp. = 0 %then %let ssp1 = 0 ; %else %if &sp. = 1 %then %let ssp1 = 12 ; 
%else %if &sp. = 2 %then %let ssp1 = 12 ;
%if &sp. = 0 %then %let ssp2 = 0 ; %else %if &sp. = 1 %then %let ssp2 = 0 ;
%else %if &sp. = 2 %then %let ssp2 = 24 ;
%if &sq. = 0 %then %let ssq1 = 0 ; %else %if &sq. = 1 %then %let ssq1 = 12 ;
%else %if &sq. = 2 %then %let ssq1 = 12 ;
%if &sq. = 0 %then %let ssq2 = 0 ; %else %if &sq. = 1 %then %let ssq2 = 0 ; %else %if &sq. = 2 %then %let ssq2 = 24 ;

proc arima data = series ;   /***** 자료 이름 입력 *****/
   identify var = precip(12) ;    /***** 변수명 입력 *****/
   estimate p = (&p1. ,&p2.,&p3.)(&ssp1. , &ssp2. )   
            q = (&q1.,&q2.,&q3.)(&ssq1. , &ssq2.) method=ml outstat = tmp_AIC ;
run; quit; 

proc sql;
   insert into IDENTIFY_STAT
   select  &p. , &q., &sp.,&sq.  ,_value_
   from tmp_AIC
   where _stat_ = 'AIC' ; 
quit;

%end; %end; %end; %end; %end; 

%mend Select_order;

ods html close;
%Select_order();
ods html;


/***** 최소의 AIC값을 갖는 차수를 선택하여 출력함 *****/

proc sql ; 
   create table IDENTIFY_STAT as
   select * 
   from IDENTIFY_STAT
   order by AIC ;
quit ;

proc print data = IDENTIFY_STAT (obs=5);
	var p q sp sq AIC ;
run;

/* 모수추정 결과
p:2 2
q:2 2
sp:1 0
sq:1 2
*/

proc arima data=series;

   identify var=precip(12) nlag=36 noprint;

   /* p=2, q=2, sp=1, sq=1  ->  (2,0,2) x (1,1,1)_12 */
   estimate p=(1 2)(12) q=(1 2)(12) method=ml plot;

   forecast lead=12 out=fore;
run; quit;
proc arima data=series;

   identify var=precip(12) nlag=36 noprint;

   /* p=2, q=2, sp=1, sq=1  ->  (2,0,2) x (1,1,1)_12 */
   estimate p=(1 2)(12) q=(1 2)(12) method=ml noint plot ;
   forecast lead=12 out=fore;
run; quit;



/**** 모형 적합 후의 잔차 시계열그림 ****/
proc print data=fore;run;
 data res ;
   set fore ;
   t=_n_ ;
run ;

symbol1 i = join v = none l=1 c=black;
proc gplot data=res ;
   label RESIDUAL=residual ;
   plot residual*t=1 ;
run ;

/*모형  적합 잔차의 SACF, SPACF, 포트맨토검정 SAS 결과*/
proc arima data=res plots(unpack)=series(corr) ;
   identify var=residual nlag=24 ;
run ;quit;




/* 원본 series에서 가장 이른 월을 기준 시작월로 잡습니다. */

proc sort data=series out=series_sorted;
   by date;  /* ← yymmn7. 형식으로 보이는 원본 월 변수명 */
run;

data _null_;
   set series_sorted(obs=1);
   length digits $8;
   /* 문자형(예: '202401', '2024-01')인지, 숫자형(202401 또는 이미 SAS date)인지 분기 */
   if vtype(date)='C' then do;
      digits = compress(date,,'kd');                  /* 숫자만 추출 */
      if length(digits)=6 then d = input(cats(digits,'01'), yymmdd8.); /* 'YYYYMM01' */
      else d = input(cats(strip(date),'-01'), anydtdte.);             
   end;
   else do; /* 숫자형 */
      /* 6자리(YYYYMM)이면 코드로 보고 월 첫날의 SAS date로 변환, 
         그 외는 이미 SAS date라고 간주(필요시 임계값 로직으로 보강 가능) */
      if 100000 <= date < 1000000 then d = mdy(mod(date,100), 1, floor(date/100));
      else d = date;
   end;

   call symputx('start', d);   /* 매크로 변수 &start로 저장 */
run;
data fore2;
   set fore;
   date = intnx('month', &start, _N_-1, 'b');  /* 시작월 + (행번호-1)개월 */
   format date yymon7.;                        /* 예: 2024Jan */
run;
data fore_sep;
   set fore2;
   if not missing(precip) then y_actual = precip;
   else y_actual = .;

   if missing(precip) then y_fcst = forecast;
   else y_fcst = .;
run;

proc sgplot data=fore_sep(where=(year(date)>=2023));
   series x=date y=y_actual / legendlabel='Actual';
   series x=date y=y_fcst   / legendlabel='Forecast' lineattrs=(pattern=shortdash);
   band   x=date lower=l95 upper=u95 / transparency=0.5 legendlabel='95% PI';  /* 전구간 PI */
   

   xaxis display=(nolabel) grid;
   yaxis label='precip';
   keylegend / position=topright;
run;

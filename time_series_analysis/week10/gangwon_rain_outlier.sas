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
/*  */
/* proc sql; */
/*    drop table IDENTIFY_STAT ;  */
/*    create table IDENTIFY_STAT  */
/*    (p   integer , */
/*    q   integer , */
/*    sp integer , */
/*    sq integer , */
/*    AIC   real) ;  */
/* quit; */
/*  */
/* **** 와 의 에 대하여  를 계산하여 저장하는 SAS macro 프로그램임 **** */
/* **** 다른 시계열 자료에 대해서도 자료의 이름과 변수명만 변경하여 사용하면 됨 **** */
/*  */
/* %macro Select_order; */
/*  */
/* %do sp = 0 % to 2 ; */
/* %do sq = 0 % to 2 ; */
/* %do p = 0 % to 3 ; */
/* %do q = 0 % to 3 ; */
/* %if &p. > 0 or &q. > 0 or &sp. > 0 or &sq. >0 %then %do ;  */
/*  */
/* %if &p. = 0 %then %let p1= 0 ;  %else %if &p.=1 %then %let p1 = 1 ; */
/* %else %if &p.=2 %then %let p1=1  ; %else %if &p.=3 %then %let p1=1 ; */
/* %if &p. = 0 %then %let p2= 0 ;  %else %if &p.=1 %then %let p2 = 0 ;  */
/* %else %if &p.=2 %then %let p2=2  ; %else %if &p.=3 %then %let p2=2 ; */
/* %if &p. = 0 %then %let p3= 0 ;  %else %if &p.=1 %then %let p3 = 0 ; */
/* %else %if &p.=2 %then %let p3=0  ; %else %if &p.=3 %then %let p3=3 ; */
/*  */
/*  */
/* %if &q. = 0 %then %let q1= 0 ;  %else %if &q.=1 %then %let q1 = 1 ; */
/* %else %if &q.=2 %then %let q1=1  ; %else %if &q.=3 %then %let q1=1 ; */
/* %if &q. = 0 %then %let q2= 0 ;  %else %if &q.=1 %then %let q2 = 0 ; */
/* %else %if &q.=2 %then %let q2=2  ; %else %if &q.=3 %then %let q2=2 ; */
/* %if &q. = 0 %then %let q3= 0 ;  %else %if &q.=1 %then %let q3 = 0 ; */
/* %else %if &q.=2 %then %let q3=0  ; %else %if &q.=3 %then %let q3=3 ; */
/*  */
/* %if &sp. = 0 %then %let ssp1 = 0 ; %else %if &sp. = 1 %then %let ssp1 = 12 ;  */
/* %else %if &sp. = 2 %then %let ssp1 = 12 ; */
/* %if &sp. = 0 %then %let ssp2 = 0 ; %else %if &sp. = 1 %then %let ssp2 = 0 ; */
/* %else %if &sp. = 2 %then %let ssp2 = 24 ; */
/* %if &sq. = 0 %then %let ssq1 = 0 ; %else %if &sq. = 1 %then %let ssq1 = 12 ; */
/* %else %if &sq. = 2 %then %let ssq1 = 12 ; */
/* %if &sq. = 0 %then %let ssq2 = 0 ; %else %if &sq. = 1 %then %let ssq2 = 0 ; %else %if &sq. = 2 %then %let ssq2 = 24 ; */
/*  */
/* proc arima data = series ;   /***** 자료 이름 입력 **** */
/*    identify var = precip(12) ;    /***** 변수명 입력 **** */
/*    estimate p = (&p1. ,&p2.,&p3.)(&ssp1. , &ssp2. )    */
/*             q = (&q1.,&q2.,&q3.)(&ssq1. , &ssq2.) method=ml outstat = tmp_AIC ; */
/* run; quit;  */
/*  */
/* proc sql; */
/*    insert into IDENTIFY_STAT */
/*    select  &p. , &q., &sp.,&sq.  ,_value_ */
/*    from tmp_AIC */
/*    where _stat_ = 'AIC' ;  */
/* quit; */
/*  */
/* %end; %end; %end; %end; %end;  */
/*  */
/* %mend Select_order; */
/*  */
/* ods html close; */
/* %Select_order(); */
/* ods html; */
/*  */
/*  */
/* **** 최소의 AIC값을 갖는 차수를 선택하여 출력함 **** */
/*  */
/* proc sql ;  */
/*    create table IDENTIFY_STAT as */
/*    select *  */
/*    from IDENTIFY_STAT */
/*    order by AIC ; */
/* quit ; */
/*  */
/* proc print data = IDENTIFY_STAT (obs=5); */
/* 	var p q sp sq AIC ; */
/* run; */
/*  */
/* 모수추정 결과 */
/* p:2 2 */
/* q:2 2 */
/* sp:1 0 */
/* sq:1 2 */


proc arima data=series;

   identify var=precip(12) nlag=36 noprint;

   /* p=2, q=2, sp=1, sq=1  ->  (2,0,2) x (1,1,1)_12 */
   estimate p=(1 2)(12) q=(1 2)(12) method=ml noint plot;

   forecast lead=12 out=fore;
run; quit;
proc arima data=series;

   identify var=precip(12) nlag=36 noprint;

   /* p=2, q=2, sp=0, sq=2  ->  (2,0,2) x (0,1,2)_12 */
   estimate p=(1 2) q=(1 2)(12 24) method=ml noint plot;
   forecast lead=12 out=fore;
run; quit;
/*거의 유사함*/



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


/*아웃라이어 탐지*/
proc arima data=series;

    identify var=precip(12) nlag=36 noprint;


    estimate p=(1 2)(12) q=(1 2)(12) method=ml noint plot;



    outlier maxnum=100
    alpha=0.01; 

    /* 4. 예측 (이상치가 보정된 모델로 예측 수행) */
/*     forecast lead=12 out=fore; */
run; quit;





/*개입분석 시작*/
/* 이상치로 지목된 행 번호(Obs)에 해당하는 날짜 확인 */
data outlier_check;
    set work.series;
    obs_num = _n_; /* 행 번호 생성 */
    
    /* 궁금한 Obs 번호들을 나열 */
    if obs_num in (56, 262, 103, 69, 117, 273);
    
    keep obs_num date precip;
run;

proc print data=outlier_check;
    title "이상치 시점의 실제 날짜 확인";
    format date yymmn7.; /* 2002-08 형태로 출력 */
run;

data work.intervention_data;
    set work.series;
    
    /* 1. 모든 펄스 변수 0으로 초기화 */
    pulse_Rusa = 0;   /* 2002년 루사 (Obs 56) */
    pulse_Mitag = 0;  /* 2019년 미탁 (Obs 262) */

    pulse_Maemi = 0;  /* 2003년 매미 (Obs 69) */
    pulse_Misac_Hisun = 0;   /* 2020년 마이삭/하이선 (Obs 273) */

    /* 2. 해당 시점에만 1로 설정 (Pulse) */
    if _n_ = 56 then pulse_Rusa = 1;
    if _n_ = 262 then pulse_Mitag = 1;

    if _n_ = 69 then pulse_Maemi = 1;
    if _n_ = 273 then pulse_Misac_Hisun = 1;
run;

/* ARIMA 개입 분석 실행 */
proc arima data=work.intervention_data;
    identify var=precip(12) 
             crosscorr=(pulse_Rusa(12) pulse_Mitag(12)  pulse_Maemi(12) pulse_Misac_Hisun(12)) 
             nlag=36 noprint;

    estimate p=(1 2)(12) q=(1 2)(12) method=ml noint 
             /* 5개의 태풍 효과를 모델에 반영 */
             input=(pulse_Rusa pulse_Mitag pulse_Maemi pulse_Misac_Hisun)
             plot;

    forecast lead=12 out=fore_intv;
    title "강릉 강수량 개입 분석 (주요 태풍 반영)";
run; quit;
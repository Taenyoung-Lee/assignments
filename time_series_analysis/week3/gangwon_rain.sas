/* CSV 파일 불러오기 */
PROC IMPORT DATAFILE="/home/u64002670/time_series/kangwon_rain.xlsx"  
    OUT=work.rain
    DBMS=xlsx
    REPLACE;
    GETNAMES=YES; 
RUN;
proc print data=work.rain(obs=5); run;

DATA rain_ts;
    SET work.rain;
    
    MONTH = INPUT(COMPRESS(월별, '월'), 8.);
    
    DATE = MDY(MONTH, 1, 연도);
    
    FORMAT DATE YYMMDD10.;
    
    KEEP DATE 전체;
RUN;

PROC SORT DATA=rain_ts;
    BY DATE;
RUN;

PROC SGPLOT DATA=rain_ts;
    TITLE "강원도 월별 전체 강수량 (1993-2023)";
    SERIES X=DATE Y=전체;
    XAXIS LABEL="날짜";
    YAXIS LABEL="강수량 (mm)";
RUN;

proc print data=rain_ts(obs=5); run;


PROC ARIMA DATA=rain_ts;
    /*원본 데이터의 정상성 확인*/
    IDENTIFY VAR=전체;
    TITLE "원본 데이터 ACF/PACF";
RUN;

/*--------------------------------------------------------------------*/
/*--------------------------------------------------------------------*/
/*--------------------------------------------------------------------*/
/*--------------------------------------------------------------------*/
/*--------------------------------------------------------------------*/
PROC ARIMA DATA=rain_ts;
    IDENTIFY VAR=전체(1);
    TITLE "1차 차분 데이터 ACF/PACF";
RUN;

PROC ARIMA DATA=rain_ts;
    IDENTIFY VAR=전체(1,12);
    TITLE "계절성 및 1차 차분 데이터 ACF/PACF";
RUN;



/* rain_ts 데이터셋의 전체 관측치 수를 n_actual 이라는 매크로 변수에 저장 */
DATA _NULL_;
    IF 0 THEN SET rain_ts NOBS=n;
    CALL SYMPUTX('n_actual', n);
    STOP;
RUN;
PROC ARIMA DATA=rain_ts;
    /* ID 구문 없이 실행 */
    IDENTIFY VAR=전체(1,12);
    ESTIMATE q=(1)(12) METHOD=ML;
    FORECAST LEAD=24 OUT=forecast_result;
    TITLE "SARIMA(0,1,1)(0,1,1)12 모델 추정 및 예측";
RUN;
DATA plot_data_manual;
    /* 1. 원본 데이터(rain_ts)를 그대로 가져옵니다. */
    /* 마지막 행을 읽을 때의 날짜를 last_date 변수에 저장합니다. */
    SET rain_ts END=last_actual;
    RETAIN last_date;
    last_date = DATE;
    OUTPUT; /* 원본 데이터 한 행씩 출력 */

    /* 2. 원본 데이터의 마지막 행까지 모두 읽었다면, 예측 데이터를 붙입니다. */
    IF last_actual THEN DO;
        /* 24개월 예측이므로 24번 반복 */
        DO i = 1 TO 24;
            /* forecast_result에서 예측값 부분을 순서대로 읽어옴 */
            /* (원본 개수 + i)번째 행이 예측값임 */
            obs_to_read = &n_actual. + i;
            SET forecast_result POINT=obs_to_read;

            /* 마지막 실제 날짜(last_date)를 기준으로 i개월 후의 날짜를 계산 */
            DATE = INTNX('MONTH', last_date, i);
            
            /* 예측 기간에는 실제 강수량('전체') 값이 없으므로 결측값으로 처리 */
            전체 = .;
            
            OUTPUT; /* 계산이 완료된 예측 데이터 한 행씩 출력 */
        END;
    END;
    
    /* 사용한 변수 정리 */
    DROP last_date obs_to_read i;
RUN;
PROC SGPLOT DATA=plot_data_manual;
    TITLE "강원도 강수량 실제값 및 예측값 비교 (수동 생성)";
    BAND X=DATE UPPER=U95 LOWER=L95 / FILLATTRS=(COLOR="lightgray") LEGENDLABEL="95% 신뢰구간";
    SERIES X=DATE Y=전체 / LINEATTRS=(COLOR=Blue THICKNESS=2) LEGENDLABEL="실제 강수량";
    SERIES X=DATE Y=FORECAST / LINEATTRS=(COLOR=Red PATTERN=Dash THICKNESS=2) LEGENDLABEL="예측 강수량";
    XAXIS LABEL="날짜";
    YAXIS LABEL="강수량 (mm)" VALUES=(0 to 800 by 200);
RUN;

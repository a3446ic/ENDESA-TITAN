create or replace PACKAGE BODY         ENEL_ECO_FICHERO as

v_eot date := to_date('22000101','YYYYMMDD');
   v_contador_debug integer; 
    v_classifierid         CS_CLASSIFIER.classifierid%TYPE;
    v_DESCRIPCION        CS_CLASSIFIER.DESCRIPTION%TYPE;
    v_STAGE                CS_GENERICCLASSIFIER.Genericattribute1%TYPE;
    v_SECUENCIA            CS_GENERICCLASSIFIER.Genericattribute2%TYPE;
    v_ARGUMENTOS        CS_GENERICCLASSIFIER.Genericattribute3%TYPE;
    v_PERIODICIDAD        CS_GENERICCLASSIFIER.Genericattribute4%TYPE;
    v_ACTIVO            CS_GENERICCLASSIFIER.Genericboolean1%TYPE;
    filas number; --Para el DEBUG de los INSERT

procedure w_debug ( txt IN VARCHAR2, valor IN Number)
AS
    proc_name VARCHAR2(50 CHAR) := $$PLSQL_UNIT ; -- Nombre del procedimiento para DEBUG

begin
    insert into ENELEXT.ENEL_debug(tenantid, datetime,text,VALUE) VALUES (SUBSTR (USER,1,4),SYSDATE, proc_name || ' ' || txt, valor);
    select v_contador_debug + 1 into v_contador_debug from dual;
    commit;
end;


procedure p_Actualiza_Fechas ( iPeriodo In VARCHAR2, iProveedorAct IN VARCHAR2,iSecondFileType IN VARCHAR2)
AS
    v_OutputFileName    ODX_CODEMAP_CONFIG.INFA_OUTPUT_FILETYPES_OUTBOUND%TYPE;
    v_Longitud_Fechas    integer;
    v_Longitud_Interfaz    integer;
    v_FechaYYYYMM VARCHAR2(6 CHAR);


begin

      select length('AAAAMM') into v_Longitud_Fechas    from dual;
    select length(iProveedorAct) into v_Longitud_Interfaz from dual; -- Donde XXX es el c?digo de proveedor

    -- 
        SELECT to_char(PER.STARTDATE,'YYYYMM') into v_FechaYYYYMM
                FROM CS_PERIOD PER 
                --WHERE per.PERIODSEQ=periodSeq and PER.REMOVEDATE = v_eot and rownum < 2;
                WHERE PER.periodseq= (select csp.periodseq +1 
                                        from cs_period csp
                                        where csp.name= iperiodo)  and PER.REMOVEDATE = v_eot;


      select      replace(INFA_OUTPUT_FILETYPES_OUTBOUND,
                   substr( INFA_OUTPUT_FILETYPES_OUTBOUND, 
                           instr(INFA_OUTPUT_FILETYPES_OUTBOUND,iProveedorAct), v_Longitud_Interfaz + v_Longitud_Fechas),
                           iProveedorAct ||  v_FechaYYYYMM)

    into v_OutputFileName
    from ENELEXT.ODX_CODEMAP_CONFIG 
    where secondary_filetype=iSecondFileType;



    update     ENELEXT.ODX_CODEMAP_CONFIG 
    set INFA_OUTPUT_FILETYPES_OUTBOUND=v_OutputFileName
    where secondary_filetype=iSecondFileType;  

    commit;

    w_debug('Nombre fichero salida actualizado en ODX_CODEMAP_CONFIG.INFA_OUTPUT_FILETYPES_OUTBOUND :'|| v_OutputFileName,  v_contador_debug);


end;


   ---------------- Procedimiento principal -------------

  PROCEDURE RUN(calendar IN VARCHAR2,calendarSeq IN VARCHAR2,groupid IN VARCHAR2,period IN VARCHAR2,periodSeq IN VARCHAR2,processingUnit IN VARCHAR2,processingUnitSeq IN VARCHAR2,stage IN VARCHAR2,userName IN VARCHAR2,triggerFilename IN VARCHAR2,tenantId IN VARCHAR2,salidacontrol out varchar2) IS

    v_Interfaz_Proceso  nvarchar2(50);
    v_stagetype     CS_STAGETYPE.name%TYPE;
    v_txtFechaLiquidacion VARCHAR2(10);
    v_Estado VARCHAR2(50);
    v_checkCountEstado integer;
    v_FechaYYYYMM VARCHAR2(6 CHAR);


  begin

  --Iniciamos el contador del Debug
  v_contador_debug := 0;

    w_debug('empieza',v_contador_debug);

    salidacontrol :='Procedure ECO comenzando';
    w_debug(' Procedure starting...', v_contador_debug);
    w_debug('Argumentos del proceso ',V_CONTADOR_DEBUG);
    w_debug('Argumento: calendar             : ['||calendar           ||']',V_CONTADOR_DEBUG); 
    w_debug('Argumento: calendarSeq          : ['||calendarSeq        ||']',V_CONTADOR_DEBUG); 
    w_debug('Argumento: groupid              : ['||groupid            ||']',V_CONTADOR_DEBUG); 
    w_debug('Argumento: period               : ['||period             ||']',V_CONTADOR_DEBUG); 
    w_debug('Argumento: periodSeq            : ['||periodSeq          ||']',V_CONTADOR_DEBUG); 
    w_debug('Argumento: processingUnit       : ['||processingUnit     ||']',V_CONTADOR_DEBUG); 
    w_debug('Argumento: processingUnitSeq    : ['||processingUnitSeq  ||']',V_CONTADOR_DEBUG); 
    w_debug('Argumento: stage                : ['||stage              ||']',V_CONTADOR_DEBUG); 
    w_debug('Argumento: userName             : ['||userName           ||']',V_CONTADOR_DEBUG); 
    w_debug('Argumento: triggerFilename      : ['||triggerFilename    ||']',V_CONTADOR_DEBUG); 
    w_debug('Argumento: tenantId             : ['||tenantId           ||']',V_CONTADOR_DEBUG); 

     BEGIN
     LOOP
        DELETE FROM ENELEXT.ENEL_ECO_INF WHERE  ROWNUM <= 10000;
        EXIT WHEN SQL%ROWCOUNT = 0;
        COMMIT;
     END LOOP;
   END;
     BEGIN
     LOOP
        DELETE FROM ENELEXT.ENEL_ECO_INF_TF WHERE  ROWNUM <= 10000;
        EXIT WHEN SQL%ROWCOUNT = 0;
        COMMIT;
     END LOOP;
   END;

    IF(PROCESSINGUNIT='MENSUAL') THEN

    v_Interfaz_Proceso := 'CCPP_ECO_CicloFacturacion';  

    p_Actualiza_Fechas(period, v_Interfaz_Proceso,'SHPOSPOST'); 

    w_debug('Inicio Truncado de la tablas ENELEXT.ENEL_ECO_INF', v_contador_debug);

    w_debug('Fin Truncado de la tablas ENELEXT.ENEL_ECO_INF', v_contador_debug);    

    insert into enelext.enel_eco_inf(periodo,canal,actividad,subactividad, idproveedor, name ,pds ,importe)
        select periodo, canal, actividad, subactividad, idproveedor, name, pds, importe
        from enel_eco_final
        WHERE PERIODO= PERIOD OR PERIODO IS NULL;       

    END IF;



    IF(PROCESSINGUNIT='MENSUAL TF') THEN

    v_Interfaz_Proceso := 'TF_ECO_CicloFacturacion';  

    p_Actualiza_Fechas(period, v_Interfaz_Proceso,'SHPOSTF'); 

    w_debug('Inicio Truncado de la tablas ENELEXT.ENEL_ECO_INF_TF', v_contador_debug);
    w_debug('Fin Truncado de la tablas ENELEXT.ENEL_ECO_INF_TF', v_contador_debug);    

    insert into enelext.enel_eco_inf_tf(periodo,canal,actividad,subactividad, idproveedor, name ,pds ,importe)
        select periodo, canal, actividad, subactividad, idproveedor, name, pds, importe
        from enel_eco_final_TF
        WHERE PERIODO= PERIOD OR PERIODO IS NULL;       

    END IF;

    salidacontrol :='Procedure ECO finalizado correctamente.';


    END;

END;
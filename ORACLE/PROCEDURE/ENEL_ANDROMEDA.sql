create or replace PACKAGE BODY         ENEL_ANDROMEDA as
/******************************************************************************
   NAME:       ENEL_ANDROMEDA
   PURPOSE:    Generate Output data for ANDROMEDA interface

   REVISIONS:
   Ver        Date        Author           Description
   ---------  ----------  ---------------  ------------------------------------
   1.0        06/07/2017  Sergio Soriano. Created this package.
   1.1        30/10/2017  Marcos Rodellar Guardar si se ha producido la LIQUDACION
                                          de un periodo y ProcessingUnit, para no 
                                          volver a generar datos de salida    
   2.0        09/01/2018  Marcos Rodellar Se modifica la inserción del periodo de Liquidación
                                          con nuevos campos                   
******************************************************************************/

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
   
   ---------------- Procedimiento para insertar en cs_debug -------------
     
procedure w_debug ( txt IN VARCHAR2, valor IN Number)
AS
    proc_name VARCHAR2(50 CHAR) := $$PLSQL_UNIT ; -- Nombre del procedimiento para DEBUG
    
begin
    insert into ENELEXT.ENEL_debug(tenantid, datetime,text,VALUE) VALUES (SUBSTR (USER,1,4),SYSDATE, proc_name || ' ' || txt, valor);
    select v_contador_debug + 1 into v_contador_debug from dual;
    commit;
end;


---------------- Procedimiento para obtener los datos del interfaz de la clasificaci?n-------------
     
procedure p_Datos_Interfaz ( iInterfaz IN VARCHAR2)
AS
        
begin
    
select
        c.classifierid,C.DESCRIPTION,gc.Genericattribute1 as STAGE,gc.Genericattribute2 as SECUENCIA,
        gc.Genericattribute3 as ARGUMENTOS,gc.Genericattribute4 as PERIODICIDAD,
        gc.Genericboolean1 as ACTIVO
    into 
       v_classifierid,         
        v_DESCRIPCION,        
        v_STAGE,                
        v_SECUENCIA,
        v_ARGUMENTOS,    
        v_PERIODICIDAD,
        v_ACTIVO            
            from CS_CLASSIFIER c 
            inner join CS_GENERICCLASSIFIER gc on C.CLASSIFIERSEQ=GC.CLASSIFIERSEQ 
                    and    gc.TENANTID = 'ENEL' 
                       and gc.REMOVEDATE  = v_eot  and gc.islast=1
            inner join CS_CATEGORY_CLASSIFIERS ccc on  ccc.CLASSIFIERSEQ = c.CLASSIFIERSEQ 
                    and ccc.TENANTID = 'ENEL' 
                       and CCC.REMOVEDATE= v_eot and CCC.ISLAST=1
            inner join CS_CATEGORYTREE ct on CCC.CATEGORYTREESEQ=CT.CATEGORYTREESEQ 
                    and ct.TENANTID = 'ENEL' 
                       and ct.REMOVEDATE= v_eot and ct.ISLAST=1
            INNER JOIN CS_GENERICCLASSIFIERTYPE GCT ON GCT.GENERICCLASSIFIERTYPESEQ = C.SELECTORID
                AND C.TENANTID = 'ENEL' 
                AND C.REMOVEDATE = v_eot
            Where CT.NAME='Salida' 
                AND GCT.NAME ='Interfaz'
                and GCT.TENANTID = 'ENEL' 
                  and c.classifierid=iInterfaz and
                  c.REMOVEDATE= v_eot and c.ISLAST=1;

          w_debug('Datos del Interfaz en Clasificacion: ',v_contador_debug);
        w_debug('Clasificacion.classifierid: ['||v_classifierid     ||']',v_contador_debug);    
        w_debug('Clasificacion.DESCRIPCION : ['||v_DESCRIPCION         ||']',v_contador_debug);
        w_debug('Clasificacion.STAGE       : ['||v_STAGE               ||']',v_contador_debug);        
        w_debug('Clasificacion.SECUENCIA   : ['||v_SECUENCIA           ||']',v_contador_debug);        
        w_debug('Clasificacion.ARGUMENTOS  : ['||v_ARGUMENTOS          ||']',v_contador_debug);            
        w_debug('Clasificacion.PERIODICIDAD: ['||v_PERIODICIDAD        ||']',v_contador_debug);        
        w_debug('Clasificacion.ACTIVO      : ['||v_ACTIVO              ||']',v_contador_debug);                    
                    
    
  
end;

   ---------------- Procedimiento para iactualizar las fechas del fichero de salida -------------
     
procedure p_Actualiza_Fechas ( iProveedorAct IN VARCHAR2,iSecondFileType IN VARCHAR2)
AS
    v_OutputFileName    ODX_CODEMAP_CONFIG.INFA_OUTPUT_FILETYPES_OUTBOUND%TYPE;
    v_Longitud_Fechas    integer;
    v_Longitud_Interfaz    integer;
    
   
begin

      select length('AAAAMMDD_HHMISS') into v_Longitud_Fechas    from dual;
    select length(iProveedorAct||'_') into v_Longitud_Interfaz from dual; -- Donde XXX es el c?digo de proveedor
    
   
      select replace(INFA_OUTPUT_FILETYPES_OUTBOUND,
                    substr(
                    INFA_OUTPUT_FILETYPES_OUTBOUND,instr(INFA_OUTPUT_FILETYPES_OUTBOUND,iProveedorAct||'_')+v_Longitud_Interfaz,v_Longitud_Fechas),
                    to_char(sysdate,'YYYYmmdd_hh24miss'))
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
    

    salidacontrol :='Procedure ANDROMEDA comenzando';
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

    CASE stage 
        WHEN 'Reward__'  then v_Interfaz_Proceso := 'ENEL_PRESTAINSTA_RDO_D_CA_DIARIO';  
        WHEN 'Post__'    then v_Interfaz_Proceso := 'ENEL_PRESTAINSTA_CIERRE_M_CA_POST';
        WHEN 'Pay__'     then v_Interfaz_Proceso := 'ENEL_PRESTAINSTA_RDO_D_CA_TOTAL';
        ELSE 
            BEGIN
                w_debug('stage '||stage||' No contemplado. Salimos...', v_contador_debug);
                RETURN;
            END;
    end CASE;
    
    p_Datos_Interfaz(v_Interfaz_Proceso);

    ----------------------------------------------------------------------------------
    -- Este activo o no el interfaz, borramos las tablas de salida                     --
    -- Esto se hace as? para que el mapping continue y genere un fichero vac?o         --
    -- Al estar esta opci?n: ENELEXT.ODX_CODEMAP_CONFIG.SKIP_EMPTY_OUTPUT='YES'     --
    -- No envia el fichero                                                             --
    
    --------------- Borrado de las tablas que utilizamos --------------
    
    w_debug('Inicio Truncado de la tablas ENELEXT.ENEL_ANDROMEDA_INF', v_contador_debug);
        execute immediate 'truncate table ENELEXT.ENEL_ANDROMEDA_INF';
    w_debug('Fin Truncado de la tablas ENELEXT.ENEL_ANDROMEDA_INF', v_contador_debug);    
    
    if v_ACTIVO <> 1 then
        w_debug('Interfaz '||v_Interfaz_Proceso||' NO ACTIVO. Salimos...', v_contador_debug);
        salidacontrol :='Salida '||v_Interfaz_Proceso||' no activa.';
        RETURN;
    else 
        w_debug('Interfaz '||v_Interfaz_Proceso||' ACTIVO.', v_contador_debug);
    end if;
    
    
    -- Comprobamos si coincide stage y secuencia -- 
    -- Ejemplo: un stage Reward__ que viene de una secuencia CompenasteAndPay no se deber ejecutar --
  
    -- stage: stage de la llamada desde el StageHook
    -- v_STAGE. Valor del stage en la clasificacion
    -- v_SECUENCIA: Valor de la secuencia en la clasificaci?n
    -- Obtenemos la secuencia, puesto que no es un par?metro del StageHook --
    -- Al no tener la fecha y hora, nos debemos quedar con la ultima ejecucion de ese stage correcta --
    
    -- S?lo se genera fichero de vuelta a Andr?meda cuando el usuari coincide con el de los argumentos
    -- y adem?s el stage es Reward. Es decir, PipelineUser
    If  stage = 'Reward__' then
        if userName=v_ARGUMENTOS then   
            w_debug('Stage Reward y usuario '||userName||'. Lanzamos fichero.',   v_contador_debug);
        else
            w_debug('Stage Reward y usuario '||userName||'. No lanzamos fichero. Solo se lanza para usuario '||v_ARGUMENTOS ,   v_contador_debug);
            RETURN;
        end if;
    end if;

    -- S?lo se genera fichero de vuelta a Andr?meda cuando el usuari coincide con el de los argumentos
    -- y adem?s el stage es Reward. Es decir, PipelineUserPay
    If  stage = 'Pay__' then
        if userName=v_ARGUMENTOS then   
            w_debug('Stage Pay y usuario '||userName||'. Lanzamos fichero.',   v_contador_debug);
        else
            w_debug('Stage Pay y usuario '||userName||'. No lanzamos fichero. Solo se lanza para usuario '||v_ARGUMENTOS ,   v_contador_debug);
            RETURN;
        end if;
    end if;

    --------------- Actualizamos el nombre del fichero de salida con la fecha y hora de hoy --------------
  
    CASE stage 
        WHEN 'Reward__'  then p_Actualiza_Fechas(v_Interfaz_Proceso,'SHPOSTREWARD');  
        WHEN 'Post__'    then p_Actualiza_Fechas(v_Interfaz_Proceso,'SHPOSPOST');
        WHEN 'Pay__'     then p_Actualiza_Fechas(v_Interfaz_Proceso,'SHPOSTPAY');
        ELSE 
            BEGIN
                w_debug('stage '||stage||' No contemplado. Salimos...', v_contador_debug);
                RETURN ;
            END;
    end CASE;
            
    --------------- Creacion de ENEL_ANDROMEDA_TEMP --------------
  
    w_debug('Inicio Carga de la tabla de ENELEXT.ENEL_ANDROMEDA_INF.', v_contador_debug);
    
    
    --------------- Comprobar si es una ejecucion por StageHook o manual ---------------------------
    -- Si es manual, no comprobamos secuencia, puesto que entenemos que se quiere generar fichero --    
    if  triggerFilename = 'EJECUCION_MANUAL' then
        w_debug('Peticion de ejecucion manual con periodo '||period, v_contador_debug);
    else
        w_debug('Peticion de ejecucion StageHook con periodo '|| period, v_contador_debug);
--        if v_stagetype <> v_SECUENCIA then
--            begin
--                w_debug('La secuencia de la ejecucion '||v_stagetype||' y de la clasificacion '|| v_SECUENCIA ||' no coincide. Salimos  ', v_contador_debug);
--                RETURN;
--            end;
--        end if;    
    end if; 

    -- En caso de stage 'Post__', se actualizan los datos de Pte. Liquidar a Liquidado
    
    IF stage = 'Post__'    THEN
        w_debug('Inicio actualización de estado Liquidado en ENEL_ANDROMEDA_FINAL ' || ' filas.',v_contador_debug);
        v_txtFechaLiquidacion := to_char(SYSDATE, 'DD/MM/YYYY');
        v_Estado := 'Liquidado';

        -- Si no existe, Se inserta la marca de PERIODO LIQUIDADO para evitar que se vuelvan a generar datos para ANDROMEDA de ese periodo
        SELECT count(ESTADO)
            into v_checkCountEstado
        from ENELEXT.ENEL_PERIODOS_LIQUIDADOS epl 
        where epl.PERIODO = period and EPL.PROCESSINGUNITSEQ=processingUnitSeq;
            
        IF v_checkCountEstado = 0 THEN
            -- No existe Periodo Liquidado, se inserta en la tabla
            --    INSERT INTO ENELEXT.ENEL_PERIODOS_LIQUIDADOS (PERIODO,PROCESSINGUNITSEQ, PROCESSINGUNIT, ESTADO)
            --    VALUES ( period, processingUnitSeq, processingUnit, v_Estado);
            
            -- Se extrae el mes del periodo en formato YYYYMM
            SELECT to_char(PER.STARTDATE,'YYYYMM') into v_FechaYYYYMM
            FROM CS_PERIOD PER 
            WHERE PER.NAME= period  and PER.REMOVEDATE = v_eot;
                
            -- No existe Periodo Liquidado, se inserta en la tabla
            --   INSERT INTO ENELEXT.ENEL_PERIODOS_LIQUIDADOS (PERIODO,PROCESSINGUNITSEQ, PROCESSINGUNIT, ESTADO, PERIODSEQ, YYYYMM )
            --   VALUES ( period, processingUnitSeq, processingUnit, v_Estado, periodSeq, v_FechaYYYYMM );
               
            COMMIT;

            w_debug('Se inserta la marca en ENEL_PERIODOS_LIQUIDADOS: ' || period || ' - processingUnitSeq: ' || to_char(PROCESSINGUNITSEQ) ,v_contador_debug);

        END IF; 
                       
        -- Se actualizan los datos de la tabla final en estado Pte Liquidar             
        UPDATE ENEL_ANDROMEDA_FINAL SET ESTADO = v_Estado, FECHA_LIQUIDACION = v_txtFechaLiquidacion
        WHERE PERIODO = period and ESTADO = 'Pte. Liquidar';
        
        filas := sql%rowcount;
            
        COMMIT;
            
        w_debug('Fin actualización de estado Liquidado en ENEL_ANDROMEDA_FINAL : ' || to_char(filas) || ' filas. Fecha Liquidación: ' || v_txtFechaLiquidacion ,v_contador_debug);

        -- Extraer datos de ENEL_E4E_FINAL para la tabla del informe/Interfaz. Tabla: ENEL_ANDROMEDA_INF
        INSERT INTO ENELEXT.ENEL_ANDROMEDA_INF (ORDERID, LINENUMBER, SUBLINENUMBER, EVENTTYPEID, TIPO_REGISTRO, TIPO_CREDITO, PERIODO_LIQUIDACION, IMPORTE_COMISION, 
                                                IMPORTE_PRECALCULADO, CONCEPTO_LIQUIDACION, PROVEEDOR, CREDITSEQ, FECHA_CALCULO, FECHA_LIQUIDACION, ESTADO, CODIGO_COMERCIAL,
                                                OBSERVACIONES, DATASOURCE)
        
        SELECT ORDERID, LINENUMBER, SUBLINENUMBER, EVENTTYPEID, TIPO_REGISTRO, TIPO_CREDITO, PERIODO_LIQUIDACION, IMPORTE_COMISION, IMPORTE_PRECALCULADO, 
                CONCEPTO_LIQUIDACION, PROVEEDOR, CREDITSEQ, FECHA_CALCULO, FECHA_LIQUIDACION, ESTADO, CODIGO_COMERCIAL, OBSERVACIONES, DATASOURCE
        FROM ENELEXT.ENEL_ANDROMEDA_FINAL
        WHERE PERIODO = period 
            and ESTADO = 'Liquidado';
        
        filas := sql%rowcount;
        COMMIT;

    ELSE
        -- Extraer datos de ENEL_E4E_FINAL para la tabla del informe/Interfaz. Tabla: ENEL_ANDROMEDA_INF
        INSERT INTO ENELEXT.ENEL_ANDROMEDA_INF (ORDERID, LINENUMBER, SUBLINENUMBER, EVENTTYPEID, TIPO_REGISTRO, TIPO_CREDITO, PERIODO_LIQUIDACION, IMPORTE_COMISION, 
                                                IMPORTE_PRECALCULADO, CONCEPTO_LIQUIDACION, PROVEEDOR, CREDITSEQ, FECHA_CALCULO, FECHA_LIQUIDACION, ESTADO, CODIGO_COMERCIAL, 
                                                OBSERVACIONES, DATASOURCE )
        
        SELECT ORDERID, LINENUMBER, SUBLINENUMBER, EVENTTYPEID, TIPO_REGISTRO, TIPO_CREDITO, PERIODO_LIQUIDACION, IMPORTE_COMISION, IMPORTE_PRECALCULADO, 
                    CONCEPTO_LIQUIDACION, PROVEEDOR, CREDITSEQ, FECHA_CALCULO, FECHA_LIQUIDACION, ESTADO, CODIGO_COMERCIAL, OBSERVACIONES, DATASOURCE
        FROM ENELEXT.ENEL_ANDROMEDA_FINAL
        WHERE PERIODO = period  
        and ESTADO <> 'Liquidado';
        
        filas := sql%rowcount;
        COMMIT;

    END IF;
        
    w_debug('Fin Carga de la tabla de ENELEXT.ENEL_ANDROMEDA_INF: ' || to_char(filas) || ' filas.',v_contador_debug);

    EXECUTE IMMEDIATE 'ANALYZE TABLE ENELEXT.ENEL_ANDROMEDA_INF COMPUTE STATISTICS FOR ALL INDEXES';
    w_debug('Fin Actualizacion Indices ENELEXT.ENEL_ANDROMEDA_INF.',v_contador_debug);
    w_debug('Fin del proceso.', v_contador_debug);
          
    salidacontrol :='Procedure ANDROMEDA finalizado correctamente.';
    
end;

end;
create or replace PACKAGE BODY         ENEL_SCAWEB as
/******************************************************************************
   NAME:       ENEL_SCAWEB
   PURPOSE:

   REVISIONS:
   Ver        Date        Author           Description
   ---------  ----------  ---------------  ------------------------------------
   1.0        06/07/2017  Sergio Soriano. Created this package.
   1.1        08/11/2017  Marcos Rodellar Cambio en p_GeneraXML_Proveedor, al generar 
                                          linea XML, nos aseguramos que si el CONCEPTO 
                                          tiene un caracter < se sustiye por &lt;
                                          y si tiene caracter > se sustiye por &gt;
   2.0        09/01/2018  Marcos Rodellar Se añade la nueva tabla para liqudación mensual de scaweb
                                          con el objetivo de volcarlo a fichero                                            
   
******************************************************************************/

   -- v_eot date := to_date('22000101','YYYYMMDD');
   v_eot DATE := TO_DATE('22000101','yyyymmdd');
   
   v_contador_debug integer; 
   filas integer;
    v_classifierid         CS_CLASSIFIER.classifierid%TYPE;
    v_DESCRIPCION        CS_CLASSIFIER.DESCRIPTION%TYPE;
    v_STAGE                CS_GENERICCLASSIFIER.Genericattribute1%TYPE;
    v_SECUENCIA            CS_GENERICCLASSIFIER.Genericattribute2%TYPE;
    v_ARGUMENTOS        CS_GENERICCLASSIFIER.Genericattribute3%TYPE;
    v_PERIODICIDAD        CS_GENERICCLASSIFIER.Genericattribute4%TYPE;
    v_ACTIVO            CS_GENERICCLASSIFIER.Genericboolean1%TYPE;
    
    
       
   ---------------- Procedimiento para insertar en cs_debug -------------
     
procedure w_debug ( txt IN VARCHAR2, valor IN Number)
AS
    proc_name VARCHAR2(50 CHAR) := $$PLSQL_UNIT ; -- Nombre del procedimiento para DEBUG
    
begin
    insert into ENELEXT.ENEL_debug(tenantid, datetime,text,VALUE) VALUES (SUBSTR (USER,1,4),SYSDATE, proc_name || ' ' || txt, valor);
    select v_contador_debug + 1 into v_contador_debug from dual;
    commit;
end;



   ---------------- Procedimiento para iactualizar las fechas del fichero de salida -------------
     
procedure p_Actualiza_Fechas ( iCadenaAct IN VARCHAR2,iSecondFileType IN VARCHAR2)
AS
    v_OutputFileName    ODX_CODEMAP_CONFIG.INFA_OUTPUT_FILETYPES_OUTBOUND%TYPE;
    v_Longitud_Fechas    integer;
    v_Longitud_Interfaz    integer;
    
begin


      select length('AAAAMMDD_HHMISS') into v_Longitud_Fechas    from dual;
    select length(iCadenaAct||'_') into v_Longitud_Interfaz from dual; -- Donde XXX es el c?digo de proveedor
        
      select replace(INFA_OUTPUT_FILETYPES_OUTBOUND,
                    substr(
                    INFA_OUTPUT_FILETYPES_OUTBOUND,instr(INFA_OUTPUT_FILETYPES_OUTBOUND,iCadenaAct)+v_Longitud_Interfaz,v_Longitud_Fechas),
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

    

    --------------- Generamos lineas para el XML --------------
procedure p_GeneraXML_Proveedor ( iProveedor IN VARCHAR2, iPeriodo IN VARCHAR2)
AS
    iFilas integer;    
begin

        insert into ENELEXT.ENEL_SCAWEB_LIQUIDACION_INF (ORDEN,LINE,PROVEEDOR)
        --select 1 as ORDEN, '<?xml version="1.0" encoding="UTF-8" ?>' as LINE, iProveedor as PROVEEDOR from DUAL;
        select 1 as ORDEN, '<?xml version="1.0" encoding="UTF-8" ?>' as LINE, TRIM(to_char(iProveedor, '000')) as PROVEEDOR from DUAL;
             
        insert into ENELEXT.ENEL_SCAWEB_LIQUIDACION_INF(ORDEN,LINE,PROVEEDOR)
        --select 2 as ORDEN,'<dataroot xmlns:od="urn:schemas-microsoft-com:officedata" generated="2017-02-07T12:27:29">' as LINE ,iProveedor as PROVEEDOR from DUAL;
        select 2 as ORDEN,'<dataroot xmlns:od="urn:schemas-microsoft-com:officedata" generated="2017-02-07T12:27:29">' as LINE, TRIM(to_char(iProveedor, '000'))  as PROVEEDOR from DUAL;
        
        insert into ENELEXT.ENEL_SCAWEB_LIQUIDACION_INF(ORDEN,LINE,PROVEEDOR)
        select 3 as ORDEN,'<liqxml> <pr>'||A.PROVEEDOR||'</pr>'||  
        '<al>'||A.ANO_LIQUIDACION||'</al>'||
        '<ml>'||A.MES_LIQUIDACION||'</ml>'||
        '<cai>'||A.CODIGO_AGENTE_INTERNO||'</cai>'||
        '<cto>'|| CASE 
                    WHEN INSTR( A.CONCEPTO, '<')>0  THEN REPLACE( A.CONCEPTO, '<' , '&' || 'lt;' )
                    WHEN INSTR( A.CONCEPTO, '>')>0 THEN REPLACE( A.CONCEPTO, '>' , '&' || 'gt;' )
                    ELSE A.CONCEPTO  
                END      ||'</cto>'||
        '<ca>'||A.CANTIDAD||'</ca>'||
        '<it>'||A.IMPORTE||'</it>'||
        '<fa>'||A.FECHA_ALTA||'</fa>'||
        '<ob>'||A.OBSERVACIONES||'</ob> </liqxml>' as LINE,
         TRIM(to_char(A.PROVEEDOR, '000')) as PROVEEDOR from ENELEXT.ENEL_SCAWEB_LIQUIDACION A
         where A.PROVEEDOR=iProveedor and PERIODO = iPeriodo ;
            
        filas := sql%rowcount;
           
        insert into ENELEXT.ENEL_SCAWEB_LIQUIDACION_INF(ORDEN,LINE,PROVEEDOR)
        --select 4 as ORDEN,'</dataroot>' as LINE, iProveedor as PROVEEDOR from DUAL;
        select 4 as ORDEN,'</dataroot>' as LINE, TRIM(to_char(iProveedor, '000')) as PROVEEDOR from DUAL;
        
        w_debug('Fin Carga parrafo liqxml Proveedor '||iProveedor||' en ENELEXT.ENEL_SCAWEB_LIQUIDACION_INF: '|| to_char(filas) || ' filas.', v_contador_debug);
          
    commit;
end;


procedure p_GeneraXML_Proveedor_TF ( iProveedor IN VARCHAR2, iPeriodo IN VARCHAR2)
AS
    iFilas integer;    
begin

        insert into ENELEXT.ENEL_SCAWEB_LIQUIDACION_INF_TF (ORDEN,LINE,PROVEEDOR)
        --select 1 as ORDEN, '<?xml version="1.0" encoding="UTF-8" ?>' as LINE, iProveedor as PROVEEDOR from DUAL;
        select 1 as ORDEN, '<?xml version="1.0" encoding="UTF-8" ?>' as LINE, TRIM(to_char(iProveedor, '000')) as PROVEEDOR from DUAL;
             
        insert into ENELEXT.ENEL_SCAWEB_LIQUIDACION_INF_TF(ORDEN,LINE,PROVEEDOR)
        --select 2 as ORDEN,'<dataroot xmlns:od="urn:schemas-microsoft-com:officedata" generated="2017-02-07T12:27:29">' as LINE ,iProveedor as PROVEEDOR from DUAL;
        select 2 as ORDEN,'<dataroot xmlns:od="urn:schemas-microsoft-com:officedata" generated="2017-02-07T12:27:29">' as LINE, TRIM(to_char(iProveedor, '000'))  as PROVEEDOR from DUAL;
        
        insert into ENELEXT.ENEL_SCAWEB_LIQUIDACION_INF_TF(ORDEN,LINE,PROVEEDOR)
        select 3 as ORDEN,'<liqxml> <pr>'||A.PROVEEDOR||'</pr>'||  
        '<al>'||A.ANO_LIQUIDACION||'</al>'||
        '<ml>'||A.MES_LIQUIDACION||'</ml>'||
        '<cai>'||A.CODIGO_AGENTE_INTERNO||'</cai>'||
        '<cto>'|| CASE 
                    WHEN INSTR( A.CONCEPTO, '<')>0  THEN REPLACE( A.CONCEPTO, '<' , '&' || 'lt;' )
                    WHEN INSTR( A.CONCEPTO, '>')>0 THEN REPLACE( A.CONCEPTO, '>' , '&' || 'gt;' )
                    ELSE A.CONCEPTO  
                END      ||'</cto>'||
        '<ca>'||A.CANTIDAD||'</ca>'||
        '<it>'||A.IMPORTE||'</it>'||
        '<fa>'||A.FECHA_ALTA||'</fa>'||
        '<ob>'||A.OBSERVACIONES||'</ob> </liqxml>' as LINE,
         TRIM(to_char(A.PROVEEDOR, '000')) as PROVEEDOR from ENELEXT.ENEL_SCAWEB_LIQUIDACION_TF A
         where A.PROVEEDOR=iProveedor and PERIODO = iPeriodo ;
            
        filas := sql%rowcount;
           
        insert into ENELEXT.ENEL_SCAWEB_LIQUIDACION_INF_TF(ORDEN,LINE,PROVEEDOR)
        --select 4 as ORDEN,'</dataroot>' as LINE, iProveedor as PROVEEDOR from DUAL;
        select 4 as ORDEN,'</dataroot>' as LINE, TRIM(to_char(iProveedor, '000')) as PROVEEDOR from DUAL;
        
        w_debug('Fin Carga parrafo liqxml Proveedor '||iProveedor||' en ENELEXT.ENEL_SCAWEB_LIQUIDACION_INF_TF: '|| to_char(filas) || ' filas.', v_contador_debug);
          
    commit;
end;


    --------------- Generamos lineas para el XML --------------
procedure p_Liquidacion_Scaweb ( iPeriodo IN VARCHAR2)
AS
   
begin

        w_debug('Inicio Carga ENEL_LIQSCAWEB_INF', v_contador_debug);

          INSERT INTO ENELEXT.ENEL_LIQSCAWEB_INF (ORDERID, LINENUMBER, SUBLINENUMBER, EVENTTYPEID, IMPORTE, UNIDAD, VALOR_1, UNIDAD_1, PRODUCTO_SCAWEB , CODIGO_PDS_OCAP, CICLO_FACTURACION,ESTADO,PROVEEDOR)
           SELECT ORDERID, LINENUMBER, SUBLINENUMBER, EVENTTYPEID, IMPORTE, UNIDAD, VALOR_1, UNIDAD_1, PRODUCTO_SCAWEB , CODIGO_PDS_OCAP, CICLO_FACTURACION,ESTADO,IDPROVEEDOR
           FROM ENELEXT.ENEL_LIQSCAWEB_FINAL
           WHERE PERIODO = iPeriodo;
            
        filas := sql%rowcount;
           
        w_debug('Fin Carga ENEL_LIQSCAWEB_INF: '|| to_char(filas) || ' filas.', v_contador_debug);
          
    commit;
end;


procedure p_Liquidacion_Scaweb_TF ( iPeriodo IN VARCHAR2)
AS
   
begin

        w_debug('Inicio Carga ENEL_LIQSCAWEB_INF_TF', v_contador_debug);

          INSERT INTO ENELEXT.ENEL_LIQSCAWEB_INF_TF (ORDERID, LINENUMBER, SUBLINENUMBER, EVENTTYPEID, IMPORTE, UNIDAD, VALOR_1, UNIDAD_1, PRODUCTO_SCAWEB , CODIGO_PDS_OCAP, CICLO_FACTURACION,ESTADO,PROVEEDOR)
           SELECT ORDERID, LINENUMBER, SUBLINENUMBER, EVENTTYPEID, IMPORTE, UNIDAD, VALOR_1, UNIDAD_1, PRODUCTO_SCAWEB , CODIGO_PDS_OCAP, CICLO_FACTURACION,ESTADO,IDPROVEEDOR
           FROM ENELEXT.ENEL_LIQSCAWEB_FINAL_TF
           WHERE PERIODO = iPeriodo;
            
        filas := sql%rowcount;
           
        w_debug('Fin Carga ENEL_LIQSCAWEB_INF_TF: '|| to_char(filas) || ' filas.', v_contador_debug);
          
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





   ---------------- Procedimiento principal -------------

    PROCEDURE RUN(calendar IN VARCHAR2,calendarSeq IN VARCHAR2,groupid IN VARCHAR2,period IN VARCHAR2,periodSeq IN VARCHAR2,processingUnit IN VARCHAR2,processingUnitSeq IN VARCHAR2,stage IN VARCHAR2,userName IN VARCHAR2,triggerFilename IN VARCHAR2,tenantId IN VARCHAR2,salidacontrol out varchar2) IS
  
     v_Interfaz_Proceso  nvarchar2(50);
    v_Nombre_Fichero_Liq  nvarchar2(50);
    CURSOR cursor_Listado_Proveedores is Select DISTINCT PROVEEDOR From ENELEXT.ENEL_SCAWEB_LIQUIDACION Where PERIODO = period ;
    c_Elemento_Proveedor nvarchar2(50);
     
   
  begin
  
  --Iniciamos el contador del Debug
  v_contador_debug := 0;
 

      salidacontrol :='Procedure SCAWEB comenzando';
  
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
    
    IF(PROCESSINGUNIT= 'MENSUAL') THEN
    
    v_Interfaz_Proceso := 'ENEL_SWEB_M_CSW';
    p_Datos_Interfaz(v_Interfaz_Proceso);
    
     
    ----------------------------------------------------------------------------------
    -- Este activo o no el interfaz, borramos las tablas de salida                     --
    -- Este caso es especial, puesto que se genera un fichero comprimido con todos los proveedores --
       
      --------------- Borrado de las tablas que utilizamos --------------
    w_debug('Inicio Truncado de la tablas ENELEXT.ENEL_SCAWEB_LIQUIDACION_INF', v_contador_debug);
    execute immediate 'truncate table ENELEXT.ENEL_SCAWEB_LIQUIDACION_INF';
    w_debug('Fin Truncado de la tablas ENELEXT.ENEL_SCAWEB_LIQUIDACION_INF', v_contador_debug);   
    
    -- tabla de actualización mensual de Liquidación en SCAWEB
    w_debug('Inicio Truncado de la tablas ENELEXT.ENEL_LIQSCAWEB_INF', v_contador_debug);
    execute immediate 'truncate table ENELEXT.ENEL_LIQSCAWEB_INF';
    w_debug('Fin Truncado de la tablas ENELEXT.ENEL_LIQSCAWEB_INF', v_contador_debug);  
    
    --------------- Comprobar si est? activo el interfaz  --------------
     
    if v_ACTIVO <> 1 then
        w_debug('Interfaz '||v_Interfaz_Proceso||' NO ACTIVO. Salimos...', v_contador_debug);
        salidacontrol :='Salida '||v_Interfaz_Proceso||' no activa.';
        RETURN;
    else 
        w_debug('Interfaz '||v_Interfaz_Proceso||' ACTIVO.', v_contador_debug);
    end if;
    
     
    
    --------------- Comprobar si es una ejecuci?n por StageHook o manual --------------
    
    if  triggerFilename = 'EJECUCION_MANUAL' then
    
        w_debug('Peticion de ejecucion manual con periodo '||period, v_contador_debug);
        
    else
        w_debug('Peticion de ejecucion StageHook con periodo '|| period, v_contador_debug);
        
    end if; 
  
  
      
  --------------- Creacion de ENEL_SCAWEB_TEMP --------------
    w_debug('Inicio Carga de la tabla de ENELEXT.ENEL_SCAWEB_LIQUIDACION_INF.', v_contador_debug);
    
    OPEN cursor_Listado_Proveedores;
    LOOP
        FETCH cursor_Listado_Proveedores INTO c_Elemento_Proveedor;
        EXIT WHEN cursor_Listado_Proveedores%NOTFOUND;
           
        p_GeneraXML_Proveedor(c_Elemento_Proveedor, period);
        
    END LOOP;
    CLOSE cursor_Listado_Proveedores;
    
    w_debug('Fin Carga de la tabla de ENELEXT.ENEL_SCAWEB_LIQUIDACION_INF',v_contador_debug);

    -- Se actualiza fecha en el nombre de fichero 
    v_Nombre_Fichero_Liq:='ENEL_CAPTACION_CIERRE_M_CS_POST';
    p_Actualiza_Fechas(v_Nombre_Fichero_Liq,'SHPOSPOST');
    
    -- Se genera traspasan datos para fichero de liquidación de Scaweb
    p_Liquidacion_Scaweb(period);    
   
    --------------- Actualizaci?n de estad?sticas --------------
    EXECUTE IMMEDIATE 'ANALYZE TABLE ENELEXT.ENEL_SCAWEB_LIQUIDACION_INF COMPUTE STATISTICS FOR ALL INDEXES';
    w_debug('Fin Actualizacion Indices ENELEXT.ENEL_SCAWEB_LIQUIDACION_INF.',v_contador_debug);
            
    END IF;
    
    
    IF(PROCESSINGUNIT= 'MENSUAL TF') THEN
    
     v_Interfaz_Proceso := 'ENEL_SWEB_M_TF_CSW';
    p_Datos_Interfaz(v_Interfaz_Proceso);
    
     
    ----------------------------------------------------------------------------------
    -- Este activo o no el interfaz, borramos las tablas de salida                     --
    -- Este caso es especial, puesto que se genera un fichero comprimido con todos los proveedores --
       
      --------------- Borrado de las tablas que utilizamos --------------
    w_debug('Inicio Truncado de la tablas ENELEXT.ENEL_SCAWEB_LIQUIDACION_INF_TF', v_contador_debug);
    execute immediate 'truncate table ENELEXT.ENEL_SCAWEB_LIQUIDACION_INF_TF';
    w_debug('Fin Truncado de la tablas ENELEXT.ENEL_SCAWEB_LIQUIDACION_INF_TF', v_contador_debug);   
    
    -- tabla de actualización mensual de Liquidación en SCAWEB
    w_debug('Inicio Truncado de la tablas ENELEXT.ENEL_LIQSCAWEB_INF_TF', v_contador_debug);
    execute immediate 'truncate table ENELEXT.ENEL_LIQSCAWEB_INF_TF';
    w_debug('Fin Truncado de la tablas ENELEXT.ENEL_LIQSCAWEB_INF_TF', v_contador_debug);  
    
    --------------- Comprobar si est? activo el interfaz  --------------
     
    if v_ACTIVO <> 1 then
        w_debug('Interfaz '||v_Interfaz_Proceso||' NO ACTIVO. Salimos...', v_contador_debug);
        salidacontrol :='Salida '||v_Interfaz_Proceso||' no activa.';
        RETURN;
    else 
        w_debug('Interfaz '||v_Interfaz_Proceso||' ACTIVO.', v_contador_debug);
    end if;
    
     
    
    --------------- Comprobar si es una ejecuci?n por StageHook o manual --------------
    
    if  triggerFilename = 'EJECUCION_MANUAL' then
    
        w_debug('Peticion de ejecucion manual con periodo '||period, v_contador_debug);
        
    else
        w_debug('Peticion de ejecucion StageHook con periodo '|| period, v_contador_debug);
        
    end if; 
  
  
      
  --------------- Creacion de ENEL_SCAWEB_TEMP --------------
    w_debug('Inicio Carga de la tabla de ENELEXT.ENEL_SCAWEB_LIQUIDACION_INF_TF.', v_contador_debug);
    
    OPEN cursor_Listado_Proveedores;
    LOOP
        FETCH cursor_Listado_Proveedores INTO c_Elemento_Proveedor;
        EXIT WHEN cursor_Listado_Proveedores%NOTFOUND;
           
        p_GeneraXML_Proveedor_TF(c_Elemento_Proveedor, period);
        
    END LOOP;
    CLOSE cursor_Listado_Proveedores;
    
    w_debug('Fin Carga de la tabla de ENELEXT.ENEL_SCAWEB_LIQUIDACION_INF_TF',v_contador_debug);

    -- Se actualiza fecha en el nombre de fichero 
   /* v_Nombre_Fichero_Liq:='ENEL_CAPTACION_CIERRE_M_CS_POST';
    p_Actualiza_Fechas(v_Nombre_Fichero_Liq,'SHPOSPOST');*/
    
    -- Se genera traspasan datos para fichero de liquidación de Scaweb
    p_Liquidacion_Scaweb_TF(period);    
   
    --------------- Actualizaci?n de estad?sticas --------------
    EXECUTE IMMEDIATE 'ANALYZE TABLE ENELEXT.ENEL_SCAWEB_LIQUIDACION_INF_TF COMPUTE STATISTICS FOR ALL INDEXES';
    w_debug('Fin Actualizacion Indices ENELEXT.ENEL_SCAWEB_LIQUIDACION_INF_TF.',v_contador_debug);
    
    end if; 
    --------------- Fin proceso --------------------------------
    w_debug('Fin del proceso.', v_contador_debug);
    salidacontrol :='Procedure SCAWEB finalizado correctamente.';
    
  end;

end;
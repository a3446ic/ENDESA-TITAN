create or replace PACKAGE BODY         ENEL_ACTUALIZA_TEMPORALES AS
/******************************************************************************
   NAME:       ENEL_ACTUALIZA_TEMPORALES
   PURPOSE:

   REVISIONS:
   Ver        Date        Author           Description
   ---------  ----------  ---------------  ------------------------------------
   1.0        02/03/2018  Marcos Rodellar ACTUALIZA SOLO TABLAS TEMPORALES 

                                                
******************************************************************************/

    v_eot DATE := TO_DATE('22000101','yyyymmdd');
     v_periodo VARCHAR2(50 BYTE);
     v_contador_debug integer; 
     v_classifierid         CS_CLASSIFIER.classifierid%TYPE;
    v_DESCRIPCION        CS_CLASSIFIER.DESCRIPTION%TYPE;
    v_STAGE                CS_GENERICCLASSIFIER.Genericattribute1%TYPE;
    v_SECUENCIA            CS_GENERICCLASSIFIER.Genericattribute2%TYPE;
    v_ARGUMENTOS        CS_GENERICCLASSIFIER.Genericattribute3%TYPE;
    v_PERIODICIDAD        CS_GENERICCLASSIFIER.Genericattribute4%TYPE;
    v_ACTIVO            CS_GENERICCLASSIFIER.Genericboolean1%TYPE;
    filas number; --Para el DEBUG de los INSERT

/******************************
    Debug en ENELEXT.ENEL_DEBUB
******************************/
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




function f_Primer_Dia_Periodo(iperiodseq varchar2) return date as
    v_Primer_Dia date;
  begin
    SELECT PER.STARTDATE INTO v_Primer_Dia
    FROM CS_PERIOD PER 
    WHERE PER.PERIODSEQ=iperiodseq 
      AND PER.REMOVEDATE = to_date('2200-01-01','YYYY-MM-DD');
      
     return v_Primer_Dia;
  end;

-- Se calcula el primer día del mes siguiente al actual 
function f_Primer_Dia_Periodo_Siguiente(iperiodseq varchar2) return date as
    v_Primer_Dia date;
  begin
    SELECT ADD_MONTHS( PER.STARTDATE , 1 ) INTO v_Primer_Dia
    FROM CS_PERIOD PER 
    WHERE PER.PERIODSEQ=iperiodseq 
      AND PER.REMOVEDATE = to_date('2200-01-01','YYYY-MM-DD');
      
     return v_Primer_Dia;
  end;


function f_Ultimo_Dia_Periodo(iperiodseq varchar2) return date as
    v_Ultimo_Dia date;
  begin
    SELECT PER.ENDDATE  - 1 INTO v_Ultimo_Dia
    FROM CS_PERIOD PER 
    WHERE PER.PERIODSEQ=iperiodseq 
      AND PER.REMOVEDATE = to_date('2200-01-01','YYYY-MM-DD');
      
     return v_Ultimo_Dia;
  end;
  
----------------- f_CodigoMes -----------------------------------------------------------------------

function f_CodigoMes(idate date) return varchar2 as
    v_CodigoMes varchar2(1);
  begin

    -- Se extrae un código de mes de modo que Enero es A , Febrero B .... hasta Diciembre que es L
    -- ASCII('A') = 65  y ASCII('L') = 76
    -- Metodo:
    --  Se extrae numero de mes: extract(month from idate) 
    --  Se suma 64 y ese código ascci se convierte a carácter con chr
  
        SELECT chr(extract(month from idate) + 64)
        INTO  v_CodigoMes
        FROM DUAL;  
      
     return v_CodigoMes;
  end;  
  
  -- EXtraer el codigo del mes : Enero: A, Febrero:B .... Diciembre:L


-- se comprueba si el informe sobre el que se van a generar los datos pertenece a la lista de informes. Para 'ALL', se devuelve que si existe
function f_ExisteInformeEnLista(iInforme in varchar2, iListaInformes in varchar2 ) return boolean as   
    v_existe BOOLEAN;
    
begin  
    
    -- Si lista de INFORMES es 'ALL', se devuelve como que existe siempre
    IF iListaInformes = 'ALL' THEN
        v_existe := true;
    ELSIF INSTR( iListaInformes, iInforme ) > 0 THEN
    -- Si el nombre del informe existe en la lista que se ha pasado como parametro (ejecución manual), se devuelve que existe (true)   
        v_existe := true;
    ELSE
    -- Si el nombre del informe no existe en la lista que se ha pasado como parametro (ejecución manual), se devuelve que no existe (false)
        v_existe := false;
    END IF; 

    if v_existe then
        w_debug(' SI ExisteInformeEnLista: '||iInforme ||' ListaInformes: '||iListaInformes ,  v_contador_debug);
    else
        w_debug(' NO ExisteInformeEnLista: '||iInforme ||' ListaInformes: '||iListaInformes ,  v_contador_debug);
    end if;
    
    return v_existe;
    
end;

--------- Volcar datos de las tablas de Transacciones a una Temporal general para usar como base en todas las demas extracciones 
---------- Tabla ENEL_TXN_TEMP ----

procedure p_Temporal_Transacciones (  iprocessingUnitSeq IN VARCHAR2, iperiod IN VARCHAR2,iperiodseq IN VARCHAR2, itenantId IN VARCHAR2 )
AS
      
    
begin


    w_debug('Inicio Truncado de la tabla ENEL_TXN_TEMP.', v_contador_debug);
    EXECUTE IMMEDIATE 'TRUNCATE TABLE ENELEXT.ENEL_TXN_TEMP';
    w_debug('Fin Truncado de la tabla ENEL_TXN_TEMP.', v_contador_debug);

    w_debug('Cargando tabla ENEL_TXN_TEMP. Periodo:'|| iperiod ,  v_contador_debug);

     INSERT INTO ENELEXT.ENEL_TXN_TEMP( TENANTID, PERIODSEQ, PERIODO, SALESORDERSEQ, SALESTRANSACTIONSEQ, ORDERID, LINENUMBER, SUBLINENUMBER, EVENTYPEID, COMPENSATIONDATE, ACCOUNTINGDATE, 
                                        PRODUCTID, GENERICATTRIBUTE1, GENERICATTRIBUTE2, GENERICATTRIBUTE3, GENERICATTRIBUTE4, GENERICATTRIBUTE5, GENERICATTRIBUTE6, GENERICATTRIBUTE7, 
                                        GENERICATTRIBUTE8, GENERICATTRIBUTE9, GENERICATTRIBUTE10, GENERICATTRIBUTE11, GENERICATTRIBUTE12, GENERICATTRIBUTE13, GENERICATTRIBUTE14, 
                                        GENERICATTRIBUTE15, GENERICATTRIBUTE16, GENERICATTRIBUTE17, GENERICATTRIBUTE18,GENERICATTRIBUTE19, GENERICATTRIBUTE20, 
                                        GENERICATTRIBUTE21, GENERICNUMBER1, GENERICNUMBER2, GENERICNUMBER3, GENERICDATE3, GENERICDATE4, GENERICDATE5, GENERICBOOLEAN2, 
                                        PONUMBER, DATASOURCE, TAD_ADDRESS1, TAD_CITY, TAD_STATE, TAD_POSTALCODE, TAD_INDUSTRY, TAD_GEOGRAPHY, 
                                        TAS_POSITIONNAME, TAS_GENERICATTRIBUTE1, TAS_GENERICATTRIBUTE2, TAS_GENERICNUMBER1, TAS_GENERICNUMBER2, 
                                        TEX0_GENERICATTRIBUTE4, TEX0_GENERICATTRIBUTE5, TEX0_GENERICATTRIBUTE6, TEX0_GENERICATTRIBUTE7, TEX0_GENERICATTRIBUTE8, 
                                        TEX0_GENERICATTRIBUTE9, TEX0_GENERICATTRIBUTE10, TEX0_GENERICATTRIBUTE11, TEX0_GENERICATTRIBUTE12, 
                                        TEX0_GENERICATTRIBUTE13, TEX0_GENERICATTRIBUTE14, TEX0_GENERICATTRIBUTE15, 
                                        TEX0_GENERICATTRIBUTE16, TEX0_GENERICATTRIBUTE17, TEX0_GENERICDATE3, TEX0_GENERICDATE4, TEX0_GENERICBOOLEAN1, 
                                        TEX0_GENERICNUMBER1, TEX0_GENERICNUMBER2, TEX0_GENERICNUMBER3, TEX0_GENERICNUMBER4, TEX0_GENERICNUMBER5, PROCESSINGUNITSEQ      )
          SELECT 
            TXN.TENANTID ,
            PER.PERIODSEQ,
            PER.NAME,
            TXN.SALESORDERSEQ,
            TXN.SALESTRANSACTIONSEQ,
            ordtxn.orderid,
            TXN.LINENUMBER,
            TXN.SUBLINENUMBER,
            ETYPE.EVENTTYPEID,
            TXN.COMPENSATIONDATE,
            TXN.ACCOUNTINGDATE,  -- Fecha que indica el ciclo de facturacion
            TXN.PRODUCTID as Producto,
            TXN.GENERICATTRIBUTE1 as Tipo_Servicio,
            TXN.GENERICATTRIBUTE2 as Nombre_Servicio,
            TXN.GENERICATTRIBUTE3 as Estado_GA3,        
            TXN.GENERICATTRIBUTE4 as Estado_Liquidacion,
            TXN.GENERICATTRIBUTE5 As Motivo_Resultado,
            TXN.GENERICATTRIBUTE6,
            TXN.GENERICATTRIBUTE7,        
            TXN.GENERICATTRIBUTE8 As IDMARCA,
            TXN.GENERICATTRIBUTE9 As IDMODELO,
            TXN.GENERICATTRIBUTE10,
            TXN.GENERICATTRIBUTE11,
            TXN.GENERICATTRIBUTE12,
            TXN.GENERICATTRIBUTE13,
            TXN.GENERICATTRIBUTE14,
            TXN.GENERICATTRIBUTE15,
            TXN.GENERICATTRIBUTE16,
            TXN.GENERICATTRIBUTE17,
            TXN.GENERICATTRIBUTE18,
            TXN.GENERICATTRIBUTE19 as Codigo_comercial,
            TXN.GENERICATTRIBUTE20 as Incidencia,
            TXN.GENERICATTRIBUTE21 as SubProducto,
            TXN.GENERICNUMBER1 as Duracion,
            TXN.GENERICNUMBER2 as Plazo,        
            TXN.GENERICNUMBER3 as Paquetizacion,
            TXN.GENERICDATE3 as Fecha_Firma,
            TXN.GENERICDATE4 as Fecha_Alta,        
            TXN.GENERICDATE5 as Fecha_Baja,        
            TXN.GENERICBOOLEAN2 as SS_Garantia,        
            TXN.PONUMBER as Contrato,
            TXN.DATASOURCE,
            TXNADD.ADDRESS1 AS Calle ,   
            TXNADD.CITY  AS Municipio ,
            TXNADD.STATE AS Provincia ,
            TXNADD.POSTALCODE as Código_Postal,
            TXNADD.INDUSTRY as Latitud,
            TXNADD.GEOGRAPHY as Longitud,
            TXNASS.POSITIONNAME,
            TXNASS.GENERICATTRIBUTE1 as Comercial,
            TXNASS.GENERICATTRIBUTE2 as UsuarioCRM,
            TXNASS.GENERICNUMBER1 as Calidad_Tecnica_Gas,
            TXNASS.GENERICNUMBER2 as Calidad_Tecnica_Luz,
            etxn0.GENERICATTRIBUTE4 as FechaMaximaInicial,
            etxn0.GENERICATTRIBUTE5 as Fecha_Validacion,
            etxn0.GENERICATTRIBUTE6 as FechaMaxima,
            etxn0.GENERICATTRIBUTE7 as InicioTrabajos,
            etxn0.GENERICATTRIBUTE8 as FinTrabajos,
            etxn0.GENERICATTRIBUTE9 as FechaSolicitdaCliente,
            etxn0.GENERICATTRIBUTE10 as FechaHora_Apertura,
            etxn0.GENERICATTRIBUTE11 as Fecha_Prevista,
            etxn0.GENERICATTRIBUTE12 as FormaPago,                        
            etxn0.GENERICATTRIBUTE13 as Num_Pedido_CRM,
            etxn0.GENERICATTRIBUTE14 as Num_Contrato_SVE,
            etxn0.GENERICATTRIBUTE15 as Tarifa,
            etxn0.GENERICATTRIBUTE16 as EmpresaEntrante,          
            etxn0.GENERICATTRIBUTE17 as ComercializadoraSal,            
            etxn0.GENERICDATE3 as Fecha_Plataforma,
            etxn0.GENERICDATE4 as Fecha_Registro,
            etxn0.GENERICBOOLEAN1 as Hidden_Firma,
            etxn0.GENERICNUMBER1 as Num_Validaciones,
            etxn0.GENERICNUMBER2 as Num_Insistencias,
            etxn0.GENERICNUMBER3 as Num_Insistencias_App,
            etxn0.GENERICNUMBER4 as Num_CambiosNoLocalizado,
            etxn0.GENERICNUMBER5 as Num_FueraPlazoCLiente,
            TXN.PROCESSINGUNITSEQ
        
          FROM CS_PERIOD per    
          INNER JOIN CS_SALESTRANSACTION txn
               ON TXN.COMPENSATIONDATE between PER.STARTDATE and PER.ENDDATE - 1
               AND TXN.TENANTID = itenantId
               AND TXN.MODELSEQ = 0
               AND TXN.PROCESSINGUNITSEQ = iprocessingUnitSeq
          INNER JOIN CS_SALESORDER ordtxn
               ON TXN.SALESORDERSEQ = ORDTXN.SALESORDERSEQ
               AND ORDTXN.REMOVEDATE = v_eot
               AND ORDTXN.PROCESSINGUNITSEQ = iprocessingUnitSeq
          INNER JOIN CS_EVENTTYPE etype
               ON TXN.EVENTTYPESEQ = etype.DATATYPESEQ
               AND ETYPE.REMOVEDATE  = v_eot
          LEFT JOIN CS_GASALESTRANSACTION etxn0   
               ON txn.SALESTRANSACTIONSEQ = etxn0.SALESTRANSACTIONSEQ
               AND etxn0.PAGENUMBER = 0
/*               
          LEFT JOIN CS_TRANSACTIONADDRESS txnadd 
               ON txn.SALESTRANSACTIONSEQ  = TXNADD.SALESTRANSACTIONSEQ
 --         LEFT JOIN  CS_ADDRESSTYPE addtype
         INNER JOIN  CS_ADDRESSTYPE addtype
               ON TXNADD.ADDRESSTYPESEQ = ADDTYPE.ADDRESSTYPESEQ
               AND ADDTYPE.ADDRESSTYPEID ='BILLTO'
*/
-- Se hace el LEFT JOIN sobre una subquery de CS_TRANSACTIONADDRESS con un INNER JOIN con el Tipo de ADdress "BILLTO" por que si no las TXN sin dirección se pierden o se pueden duplicar las que si tienen otros tipos  
          LEFT JOIN  
            (Select * FROM  CS_TRANSACTIONADDRESS txnaddress 
                      INNER JOIN  CS_ADDRESSTYPE addtype
                        ON txnaddress.ADDRESSTYPESEQ = ADDTYPE.ADDRESSTYPESEQ
                        AND ADDTYPE.ADDRESSTYPEID ='BILLTO' ) TXNADD
                ON txn.SALESTRANSACTIONSEQ  = TXNADD.SALESTRANSACTIONSEQ    
                                               
          LEFT JOIN CS_TRANSACTIONASSIGNMENT txnass
               ON txn.SALESTRANSACTIONSEQ  = txnass.SALESTRANSACTIONSEQ   
          WHERE  PER.TENANTID =  itenantId
               AND PER.REMOVEDATE = v_eot 

               AND PER.PERIODSEQ = iperiodseq;

    filas := sql%rowcount;
    COMMIT;

    w_debug('Fin Carga de la tabla ENEL_TXN_TEMP: '|| to_char(filas) || ' filas.', v_contador_debug);

    EXECUTE IMMEDIATE 'ANALYZE TABLE ENELEXT.ENEL_TXN_TEMP COMPUTE STATISTICS FOR ALL INDEXES';
    w_debug('Fin Actualizacion Indices ENELEXT.ENEL_TXN_TEMP.',v_contador_debug);
    
end;

--------- Volcar datos de la tabla de Créditos a una Temporal general para usar como base en todas las demas extracciones 
---------- Tabla ENEL_CREDIT_TEMP ----

procedure p_Temporal_Creditos (  iprocessingUnitSeq IN VARCHAR2, iperiod IN VARCHAR2,iperiodseq IN VARCHAR2, itenantId IN VARCHAR2 )
AS
      
    
begin


    w_debug('Inicio Truncado de la tabla ENEL_CREDIT_TEMP.', v_contador_debug);
    EXECUTE IMMEDIATE 'TRUNCATE TABLE ENELEXT.ENEL_CREDIT_TEMP';
    w_debug('Fin Truncado de la tabla ENEL_CREDIT_TEMP.', v_contador_debug);

    w_debug('Cargando tabla ENEL_CREDIT_TEMP. Periodo:'|| iperiod ,  v_contador_debug);

     INSERT INTO ENELEXT.ENEL_CREDIT_TEMP( TENANTID, PERIODSEQ, PERIODO, PIPELINERUNSEQ, PIPELINERUNDATE, NAME, CREDITSEQ, SALESORDERSEQ, SALESTRANSACTIONSEQ, PAYEESEQ, POSITIONSEQ, COMPENSATIONDATE,  
                                           CREDITTYPEID, CREDITTYPEDESCRIPT, VALUE, PREADJUSTEDVALUE, GENERICATTRIBUTE1, GENERICATTRIBUTE2, GENERICATTRIBUTE3, GENERICATTRIBUTE4, 
                                           GENERICATTRIBUTE5, GENERICATTRIBUTE6, GENERICATTRIBUTE7, GENERICATTRIBUTE8, GENERICATTRIBUTE9, GENERICATTRIBUTE10, GENERICATTRIBUTE11, 
                                           GENERICATTRIBUTE12, GENERICATTRIBUTE13, GENERICATTRIBUTE14,GENERICATTRIBUTE15, GENERICBOOLEAN1, GENERICBOOLEAN2, GENERICDATE1, 
                                           GENERICNUMBER1, GENERICNUMBER2, GENERICNUMBER3      )
          SELECT 
            credit.TENANTID,
            credit.PERIODSEQ,
            iperiod PERIODO,
            credit.PIPELINERUNSEQ,
            credit.PIPELINERUNDATE,
            credit.NAME,
            CREDIT.CREDITSEQ,
            CREDIT.SALESORDERSEQ,        
            CREDIT.SALESTRANSACTIONSEQ,
            CREDIT.PAYEESEQ,
            CREDIT.POSITIONSEQ,
            CREDIT.COMPENSATIONDATE,
            CTYPE.CREDITTYPEID,           
            CTYPE.DESCRIPTION,             -- Tipo de Comisión
            credit.VALUE,                  --Importe Comision
            credit.PREADJUSTEDVALUE,
            credit.GENERICATTRIBUTE1,      -- Concepto Liquidación
            credit.GENERICATTRIBUTE2,      -- Proveedor
            credit.GENERICATTRIBUTE3,      -- Servicio
            credit.GENERICATTRIBUTE4,      -- Prestador - PDS                        
            credit.GENERICATTRIBUTE5,      -- Plazo
            credit.GENERICATTRIBUTE6,      -- Provincia
            credit.GENERICATTRIBUTE7,      -- Zona
            credit.GENERICATTRIBUTE8,      -- Producto
            credit.GENERICATTRIBUTE9,      -- Solicitud de servicio
            credit.GENERICATTRIBUTE10,     -- Equipamiento            
            credit.GENERICATTRIBUTE11,     -- CodigoPostal
            credit.GENERICATTRIBUTE12,     -- Modalidad de Pago            
            credit.GENERICATTRIBUTE13,     --MotivoResultado
            credit.GENERICATTRIBUTE14,     --Descripción Concepto Liquidación
            credit.GENERICATTRIBUTE15,     --Observaciones Ajustes Manuales
            credit.GENERICBOOLEAN1,         --Incluir_En_Pagos
            credit.GENERICBOOLEAN2,        -- S/S Garantía
            credit.GENERICDATE1,           --FechaCalculo
            credit.GENERICNUMBER1,
            credit.GENERICNUMBER2,
            credit.GENERICNUMBER3
        
        FROM CS_CREDIT credit
        
            INNER JOIN CS_PLRUN p ON CREDIT.PIPELINERUNSEQ = P.PIPELINERUNSEQ 
                                     AND P.MODELSEQ = 0   -- Solo se tienen en cuenta las ejecuciones que no son de simulacion
                                             
            INNER JOIN CS_CREDITTYPE ctype ON credit.CREDITTYPESEQ = ctype.DATATYPESEQ 
                                                AND ctype.TENANTID = itenantId
                                                AND ctype.REMOVEDATE  = v_eot
        WHERE
            credit.TENANTID = itenantId 
            AND credit.PROCESSINGUNITSEQ = iprocessingUnitSeq 
            AND credit.PERIODSEQ =  iperiodseq; 
            

    filas := sql%rowcount;
    COMMIT;

    w_debug('Fin Carga de la tabla ENEL_CREDIT_TEMP: '|| to_char(filas) || ' filas.', v_contador_debug);

    EXECUTE IMMEDIATE 'ANALYZE TABLE ENELEXT.ENEL_CREDIT_TEMP COMPUTE STATISTICS FOR ALL INDEXES';
    w_debug('Fin Actualizacion Indices ENELEXT.ENEL_CREDIT_TEMP.',v_contador_debug);
    
end;

--------- Volcar datos de la tabla de Incentivos a una Temporal general para usar como base en todas las demas extracciones 
---------- Tabla ENEL_INCEN_TEMP ----

procedure p_Temporal_Incentivos (  iprocessingUnitSeq IN VARCHAR2, iperiod IN VARCHAR2,iperiodseq IN VARCHAR2, itenantId IN VARCHAR2 )
AS
      
    
begin

    w_debug('Inicio Truncado de la tabla ENEL_INCEN_TEMP.', v_contador_debug);
    EXECUTE IMMEDIATE 'TRUNCATE TABLE ENELEXT.ENEL_INCEN_TEMP';
    w_debug('Fin Truncado de la tabla ENEL_INCEN_TEMP.', v_contador_debug);

    w_debug('Cargando tabla ENEL_INCEN_TEMP. Periodo:'|| iperiod ,  v_contador_debug);

     INSERT INTO ENELEXT.ENEL_INCEN_TEMP(  TENANTID, PERIODSEQ, PERIODO, PIPELINERUNSEQ, PIPELINERUNDATE, INCENTIVESEQ, PAYEESEQ, POSITIONSEQ, NAME, VALUE,
                                           GENERICATTRIBUTE1, GENERICATTRIBUTE2, GENERICATTRIBUTE3, GENERICATTRIBUTE4, GENERICATTRIBUTE16, 
                                           GENERICNUMBER1, GENERICNUMBER2, GENERICNUMBER3, GENERICNUMBER4, GENERICNUMBER5, GENERICNUMBER6, 
                                           GENERICBOOLEAN1, GENERICDATE1, GENERICDATE2    )
          SELECT 
            incent.TENANTID,
            incent.PERIODSEQ,
            iperiod PERIODO,
            incent.PIPELINERUNSEQ,
            incent.PIPELINERUNDATE,
            incent.INCENTIVESEQ,
            incent.PAYEESEQ,
            incent.POSITIONSEQ,
            incent.NAME,
            incent.VALUE,                  --Importe Incentivo
            incent.GENERICATTRIBUTE1,      -- Concepto Liquidación
            incent.GENERICATTRIBUTE2,      -- Proveedor
            incent.GENERICATTRIBUTE3,      -- Descripción
            incent.GENERICATTRIBUTE4,      -- Tramo                     
            incent.GENERICATTRIBUTE16,     -- Nombre Cuota
            incent.GENERICNUMBER1,         -- Objetivo
            incent.GENERICNUMBER2,         -- Realizado
            incent.GENERICNUMBER3,         -- % Consecucion
            incent.GENERICNUMBER4,         -- Tarifa
            incent.GENERICNUMBER5,         -- Importe unitario
            incent.GENERICNUMBER6,         -- Target Incentive
            incent.GENERICBOOLEAN1,         
            incent.GENERICDATE1,           --Fecha Inicio
            incent.GENERICDATE2           --Fecha Final            

        FROM CS_INCENTIVE incent
        
            INNER JOIN CS_PLRUN p ON incent.PIPELINERUNSEQ = P.PIPELINERUNSEQ 
                                     AND P.MODELSEQ = 0   -- Solo se tienen en cuenta las ejecuciones que no son de simulacion
       WHERE
            incent.TENANTID = itenantId 
            AND incent.PROCESSINGUNITSEQ = iprocessingUnitSeq 
            AND incent.PERIODSEQ =  iperiodseq
            AND incent.GENERICATTRIBUTE1 is not null;

    filas := sql%rowcount;
    COMMIT;

    w_debug('Fin Carga de la tabla ENEL_INCEN_TEMP: '|| to_char(filas) || ' filas.', v_contador_debug);

    EXECUTE IMMEDIATE 'ANALYZE TABLE ENELEXT.ENEL_INCEN_TEMP COMPUTE STATISTICS FOR ALL INDEXES';
    w_debug('Fin Actualizacion Indices ENELEXT.ENEL_INCEN_TEMP.',v_contador_debug);
    
end;         

--------- Volcar datos de la tabla de Depósitos a una Temporal general para usar como base en todas las demas extracciones 
---------- Tabla ENEL_DEPOSIT_TEMP ----

procedure p_Temporal_Depositos (  iprocessingUnitSeq IN VARCHAR2, iperiod IN VARCHAR2,iperiodseq IN VARCHAR2, itenantId IN VARCHAR2 )
AS
      
    
begin

    w_debug('Inicio Truncado de la tabla ENEL_DEPOSIT_TEMP.', v_contador_debug);
    EXECUTE IMMEDIATE 'TRUNCATE TABLE ENELEXT.ENEL_DEPOSIT_TEMP';
    w_debug('Fin Truncado de la tabla ENEL_DEPOSIT_TEMP.', v_contador_debug);

    w_debug('Cargando tabla ENEL_DEPOSIT_TEMP. Periodo:'|| iperiod ,  v_contador_debug);

     INSERT INTO ENELEXT.ENEL_DEPOSIT_TEMP( TENANTID, PERIODSEQ, PERIODO, PIPELINERUNSEQ, PIPELINERUNDATE, DEPOSITSEQ, PAYEESEQ, POSITIONSEQ, NAME, VALUE, 
                                            PREADJUSTEDVALUE, EARNINGCODEID, EARNINGGROUPID, COMMENTS, GENERICATTRIBUTE1, GENERICATTRIBUTE2    )

         SELECT
            depo.TENANTID,
            depo.PERIODSEQ,
            iperiod PERIODO,
            depo.PIPELINERUNSEQ,
            depo.PIPELINERUNDATE,
            depo.DEPOSITSEQ ,
            depo.PAYEESEQ,
            depo.POSITIONSEQ,
            depo.NAME,
            depo.VALUE,                  --Importe
            depo.PREADJUSTEDVALUE,
            depo.EARNINGCODEID,
            depo.EARNINGGROUPID,
            depo.COMMENTS,
            depo.GENERICATTRIBUTE1,      -- Actividad
            depo.GENERICATTRIBUTE2     
        
        FROM CS_DEPOSIT depo
        
          INNER JOIN CS_PLRUN p ON depo.PIPELINERUNSEQ = P.PIPELINERUNSEQ 
                                     AND P.MODELSEQ = 0   -- Solo se tienen en cuenta las ejecuciones que no son de simulacion
       WHERE
            depo.TENANTID = itenantId 
            AND depo.PROCESSINGUNITSEQ = iprocessingUnitSeq 
            AND depo.PERIODSEQ =  iperiodseq;

    filas := sql%rowcount;
    COMMIT;

    w_debug('Fin Carga de la tabla ENEL_DEPOSIT_TEMP: '|| to_char(filas) || ' filas.', v_contador_debug);

    EXECUTE IMMEDIATE 'ANALYZE TABLE ENELEXT.ENEL_DEPOSIT_TEMP COMPUTE STATISTICS FOR ALL INDEXES';
    w_debug('Fin Actualizacion Indices ENELEXT.ENEL_DEPOSIT_TEMP.',v_contador_debug);
    
end;         

--------- Volcar datos de clasificaci?n a una Temporal de Proveedores. 
---------- Tabla ENEL_PROVEEDORES_TEMP ----

procedure p_Temporal_Proveedores ( iperiod IN VARCHAR2,iperiodseq IN VARCHAR2, itenantId IN VARCHAR2 )
AS
    v_ultimo_dia_periodo  date;
    
begin

    w_debug('Inicio Truncado de la tabla ENEL_PROVEEDORES_TEMP.', v_contador_debug);
    EXECUTE IMMEDIATE 'TRUNCATE TABLE ENELEXT.ENEL_PROVEEDORES_TEMP';
    w_debug('Fin Truncado de la tabla ENEL_PROVEEDORES_TEMP.', v_contador_debug);

    v_ultimo_dia_periodo := f_Ultimo_Dia_Periodo(iperiodseq);

    w_debug('Cargando tabla ENEL_PROVEEDORES_TEMP. Periodo:'|| iperiod ||' Periodseq: '||iperiodseq ||' TenantId: '||itenantId || ' Ult.Dia Period:' || v_ultimo_dia_periodo,  v_contador_debug);
      
     INSERT INTO ENELEXT.ENEL_PROVEEDORES_TEMP(    TENANTID,PERIODSEQ,IDPROVEEDOR,DESCRIPCION,DESCRIPCION_CORTA, FICHERO,CECO,
                                                    WBE_FINAL_IMPUTACION,DETALLE_ACTIVIDAD,ACTIVIDAD,SOCIEDAD,
                                                    CENTRO_LOGISTICO,GR_COMPRAS,TIPO_PAGO, ORG_VENTAS, FECHA_INICIO_VIGOR,FECHA_FIN_VIGOR)
         SELECT 
            itenantId TENANTID,
            iperiodseq PERIDOSEQ,
            C.CLASSIFIERID IDPROVEEDOR,
            C.NAME DESCRIPCION,
            GC.GENERICATTRIBUTE8 DESCRIPCION_CORTA,
            C.DESCRIPTION FICHERO,
            GC.GENERICATTRIBUTE1 CECO,
            GC.GENERICATTRIBUTE2 WBE_FINAL_IMPUTACION,
            GC.GENERICATTRIBUTE3 DETALLE_ACTIVIDAD,
            GC.GENERICATTRIBUTE4 ACTIVIDAD,
            GC.GENERICATTRIBUTE5 SOCIEDAD,
            GC.GENERICATTRIBUTE6 CENTRO_LOGISTICO, 
            GC.GENERICATTRIBUTE7 GR_COMPRAS,
            GC.GENERICATTRIBUTE8 TIPO_PAGO,  -- Nuevo v2.0  
            GC.GENERICATTRIBUTE9 ORG_VENTAS, -- Nuevo v2.0            
            C.EFFECTIVESTARTDATE FECHA_INICIO_VIGOR,
            C.EFFECTIVEENDDATE FECHA_FIN_VIGOR
        FROM CS_GENERICCLASSIFIERTYPE GCT
        INNER JOIN CS_CLASSIFIER C ON GCT.GENERICCLASSIFIERTYPESEQ = C.SELECTORID
            AND C.TENANTID = itenantId 
            AND C.REMOVEDATE = v_eot
            AND C.EFFECTIVESTARTDATE <= v_ultimo_dia_periodo
            AND C.EFFECTIVEENDDATE >= v_ultimo_dia_periodo            
--            AND C.ISLAST = 1
        INNER JOIN CS_GENERICCLASSIFIER GC ON C.CLASSIFIERSEQ = GC.CLASSIFIERSEQ
          --  AND GC.EFFECTIVESTARTDATE <= PD.ENDDATE AND GC.EFFECTIVEENDDATE >= PD.ENDDATE
            AND GC.TENANTID = itenantId
            AND GC.REMOVEDATE = v_eot
            AND GC.EFFECTIVESTARTDATE <= v_ultimo_dia_periodo
            AND GC.EFFECTIVEENDDATE >= v_ultimo_dia_periodo              
--            AND GC.ISLAST = 1
         WHERE GCT.NAME  like 'Proveedor%';
    filas := sql%rowcount;
    COMMIT;

    w_debug('Fin Carga de la tabla ENEL_PROVEEDORES_TEMP: '|| to_char(filas) || ' filas.', v_contador_debug);

    EXECUTE IMMEDIATE 'ANALYZE TABLE ENELEXT.ENEL_PROVEEDORES_TEMP COMPUTE STATISTICS FOR ALL INDEXES';
    w_debug('Fin Actualizacion Indices ENELEXT.ENEL_PROVEEDORES_TEMP.',v_contador_debug);
    
end;

--------- Volcar datos de clasificaci?n a una Temporal de Proveedores. 
---------- Tabla ENEL_PROVEEDORES_TEMP ----

procedure p_Temporal_Equipamientos ( iperiod IN VARCHAR2,iperiodseq IN VARCHAR2, itenantId IN VARCHAR2 )
AS
    v_ultimo_dia_periodo  date;
    
begin

    w_debug('Inicio Truncado de la tabla ENEL_EQUIPAMIENTO_TEMP.', v_contador_debug);
    EXECUTE IMMEDIATE 'TRUNCATE TABLE ENELEXT.ENEL_EQUIPAMIENTO_TEMP';
    w_debug('Fin Truncado de la tabla ENEL_EQUIPAMIENTO_TEMP.', v_contador_debug);

    v_ultimo_dia_periodo := f_Ultimo_Dia_Periodo(iperiodseq);

    w_debug('Cargando tabla ENEL_EQUIPAMIENTO_TEMP. Periodo:'|| iperiod ||' Periodseq: '||iperiodseq ||' TenantId: '||itenantId || ' Ult.Dia Period:' || v_ultimo_dia_periodo,  v_contador_debug);

     INSERT INTO ENELEXT.ENEL_EQUIPAMIENTO_TEMP( TENANTID,PERIODSEQ,EQUIPAMIENTO, IDMARCA, MARCA, IDMODELO, MODELO, IDTIPO,
                                                 TIPO, LITROS, POTENCIAKW,FECHA_INICIO_VIGOR,FECHA_FIN_VIGOR )
          SELECT 
            itenantId TENANTID,
            iperiodseq PERIDOSEQ,
            C.CLASSIFIERID EQUIPAMIENTO,
            GC.GENERICATTRIBUTE1 IDMARCA,
            GC.GENERICATTRIBUTE2 MARCA,
            GC.GENERICATTRIBUTE3 IDMODELO,
            GC.GENERICATTRIBUTE4 MODELO,
            GC.GENERICATTRIBUTE5 IDTIPO, 
            GC.GENERICATTRIBUTE6 TIPO,
            GC.GENERICNUMBER1 LITROS,
            GC.GENERICNUMBER2 POTENCIAKW,
            C.EFFECTIVESTARTDATE FECHA_INICIO_VIGOR,
            C.EFFECTIVEENDDATE FECHA_FIN_VIGOR

        FROM CS_GENERICCLASSIFIERTYPE GCT
        INNER JOIN CS_CLASSIFIER C ON GCT.GENERICCLASSIFIERTYPESEQ = C.SELECTORID
            AND C.TENANTID = itenantId 
            AND C.REMOVEDATE = v_eot
            AND C.EFFECTIVESTARTDATE <= v_ultimo_dia_periodo
            AND C.EFFECTIVEENDDATE >= v_ultimo_dia_periodo            
--            AND C.ISLAST = 1
        INNER JOIN CS_GENERICCLASSIFIER GC ON C.CLASSIFIERSEQ = GC.CLASSIFIERSEQ
          --  AND GC.EFFECTIVESTARTDATE <= PD.ENDDATE AND GC.EFFECTIVEENDDATE >= PD.ENDDATE
            AND GC.TENANTID = itenantId
            AND GC.REMOVEDATE = v_eot
            AND GC.EFFECTIVESTARTDATE <= v_ultimo_dia_periodo
            AND GC.EFFECTIVEENDDATE >= v_ultimo_dia_periodo              
--            AND GC.ISLAST = 1            

         WHERE GCT.NAME ='Equipamiento';

    filas := sql%rowcount;
    COMMIT;

    w_debug('Fin Carga de la tabla ENEL_EQUIPAMIENTO_TEMP: '|| to_char(filas) || ' filas.', v_contador_debug);
    
end;

--------- Volcar datos de clasificaci?n a una Temporal de Proveedores. 
---------- Tabla ENEL_OPERACIONES_TEMP ----

procedure p_Temporal_Operaciones ( iperiod IN VARCHAR2,iperiodseq IN VARCHAR2, itenantId IN VARCHAR2 )
AS
    v_ultimo_dia_periodo  date;
    
begin

    w_debug('Inicio Truncado de la tabla ENEL_OPERACIONES_TEMP.', v_contador_debug);
    EXECUTE IMMEDIATE 'TRUNCATE TABLE ENELEXT.ENEL_OPERACIONES_TEMP';
    w_debug('Fin Truncado de la tabla ENEL_OPERACIONES_TEMP.', v_contador_debug);

    v_ultimo_dia_periodo := f_Ultimo_Dia_Periodo(iperiodseq);

    w_debug('Cargando tabla ENEL_OPERACIONES_TEMP. Periodo:'|| iperiod ||' Periodseq: '||iperiodseq ||' TenantId: '||itenantId || ' Ult.Dia Period:' || v_ultimo_dia_periodo,  v_contador_debug);

     INSERT INTO ENELEXT.ENEL_OPERACIONES_TEMP( TENANTID, PERIODSEQ, OPERACIONID, TIPO_ENTRADA, TIPO_OPERACION, SUBTIPO_OPERACION, 
                                                AGRUPA_EN_FACTURA, FECHA_INICIO_VIGOR, FECHA_FIN_VIGOR)
          SELECT 
            itenantId TENANTID,
            iperiodseq PERIDOSEQ,
            C.CLASSIFIERID OPERACIONID,
            GC.GENERICATTRIBUTE1 TIPO_ENTRADA,
            GC.GENERICATTRIBUTE2 TIPO_OPERACION,
            GC.GENERICATTRIBUTE3 SUBTIPO_OPERACION,
            GC.GENERICBOOLEAN1 AGRUPA_EN_FACTURA,
            C.EFFECTIVESTARTDATE FECHA_INICIO_VIGOR,
            C.EFFECTIVEENDDATE FECHA_FIN_VIGOR

        FROM CS_GENERICCLASSIFIERTYPE GCT
        INNER JOIN CS_CLASSIFIER C ON GCT.GENERICCLASSIFIERTYPESEQ = C.SELECTORID
            AND C.TENANTID = itenantId 
            AND C.REMOVEDATE = v_eot
            AND C.EFFECTIVESTARTDATE <= v_ultimo_dia_periodo
            AND C.EFFECTIVEENDDATE >= v_ultimo_dia_periodo            
--            AND C.ISLAST = 1
        INNER JOIN CS_GENERICCLASSIFIER GC ON C.CLASSIFIERSEQ = GC.CLASSIFIERSEQ
          --  AND GC.EFFECTIVESTARTDATE <= PD.ENDDATE AND GC.EFFECTIVEENDDATE >= PD.ENDDATE
            AND GC.TENANTID = itenantId
            AND GC.REMOVEDATE = v_eot
            AND GC.EFFECTIVESTARTDATE <= v_ultimo_dia_periodo
            AND GC.EFFECTIVEENDDATE >= v_ultimo_dia_periodo              
--            AND GC.ISLAST = 1    

         WHERE GCT.NAME ='Operacion';

    filas := sql%rowcount;
    COMMIT;

    w_debug('Fin Carga de la tabla ENEL_EQUIPAMIENTO_TEMP: '|| to_char(filas) || ' filas.', v_contador_debug);
    
end;
--------- Volcar datos de Productos a una Temporal. 
---------- Tabla ENEL_PRODUCTOS_TEMP ----

procedure p_Temporal_Productos ( iperiod IN VARCHAR2,iperiodseq IN VARCHAR2, itenantId IN VARCHAR2 )
AS
    v_ultimo_dia_periodo  date;
    
begin

    w_debug('Inicio Truncado de la tabla ENEL_PRODUCTOS_TEMP.', v_contador_debug);
    EXECUTE IMMEDIATE 'TRUNCATE TABLE ENELEXT.ENEL_PRODUCTOS_TEMP';
    w_debug('Fin Truncado de la tabla ENEL_PRODUCTOS_TEMP.', v_contador_debug);

    v_ultimo_dia_periodo := f_Ultimo_Dia_Periodo(iperiodseq);

    w_debug('Cargando tabla ENEL_PRODUCTOS_TEMP. Periodo:'|| iperiod ||' Periodseq: '||iperiodseq ||' TenantId: '||itenantId || ' Ult.Dia Period:' || v_ultimo_dia_periodo,  v_contador_debug);

     INSERT INTO ENELEXT.ENEL_PRODUCTOS_TEMP( TENANTID, PERIODSEQ, PRODUCTID, DESCRIPTION, NAME, FAMILIA, PROVEEDOR_PRESTACION, PROVEEDOR_CAPTACION, 
                                              SEGMENTO, TIPO, FECHA_INICIO_VIGOR, FECHA_FIN_VIGOR)
          SELECT 
            itenantId TENANTID,
            iperiodseq PERIODSEQ,
            C.CLASSIFIERID AS PRODUCTID,
            C.DESCRIPTION,
            C.NAME,
            PROD.GENERICATTRIBUTE1 as FAMILIA,
            PROD.GENERICATTRIBUTE2 as PROVEEDOR_PRESTACION,
            PROD.GENERICATTRIBUTE3 as PROVEEDOR_CAPTACION,
            PROD.GENERICATTRIBUTE4 as SEGMENTO,
            PROD.GENERICATTRIBUTE5 as TIPO,
            C.EFFECTIVESTARTDATE FECHA_INICIO_VIGOR,
            C.EFFECTIVEENDDATE FECHA_FIN_VIGOR
            
          FROM CS_PRODUCT PROD 
       
          INNER JOIN CS_CLASSIFIER C ON C.CLASSIFIERSEQ = PROD.CLASSIFIERSEQ
                                     AND C.TENANTID = itenantId
                                     AND C.REMOVEDATE = v_eot
                                     AND C.EFFECTIVESTARTDATE <= v_ultimo_dia_periodo
                                     AND C.EFFECTIVEENDDATE >= v_ultimo_dia_periodo                                     
                                     --AND C.ISLAST = 1
          WHERE PROD.REMOVEDATE = v_eot
             AND PROD.EFFECTIVESTARTDATE <= v_ultimo_dia_periodo
             AND PROD.EFFECTIVEENDDATE >= v_ultimo_dia_periodo; 

    filas := sql%rowcount;
    COMMIT;

    w_debug('Fin Carga de la tabla ENEL_PRODUCTOS_TEMP: '|| to_char(filas) || ' filas.', v_contador_debug);
    
end;
--------- Volcar datos de clasificacion a una Temporal de Contratos 
---------- Tabla ENEL_E4E_CONTRATOS_TEMP ----
procedure p_Temporal_Contratos_E4E ( iperiod IN VARCHAR2,iperiodseq IN VARCHAR2, itenantId IN VARCHAR2 )
AS
    v_ultimo_dia_periodo  date;
    
begin

    w_debug('Inicio Truncado de la tabla ENEL_E4E_CONTRATOS_TEMP.', v_contador_debug);
    EXECUTE IMMEDIATE 'TRUNCATE TABLE ENELEXT.ENEL_E4E_CONTRATOS_TEMP';
    w_debug('Fin Truncado de la tabla ENEL_E4E_CONTRATOS_TEMP.', v_contador_debug);

    v_ultimo_dia_periodo := f_Ultimo_Dia_Periodo(iperiodseq);

    w_debug('Cargando tabla ENEL_E4E_CONTRATOS_TEMP. Periodo:'|| iperiod ||' Periodseq: '||iperiodseq ||' TenantId: '||itenantId || ' Ult.Dia Period:' || v_ultimo_dia_periodo,  v_contador_debug);
      
     INSERT INTO ENELEXT.ENEL_E4E_CONTRATOS_TEMP(TENANTID,PERIODSEQ,ID,PDS,ACTIVIDAD_DETALLADA,ACTIVIDAD,
                                              CIF,COD_CONTRATO,POS_DOC,TEXTO_BREVE,CODIGO_SERVICIO,
                                             ORG_COMPRAS,CONDICIONES_PAGO, FECHA_INICIO_VIGOR,FECHA_FIN_VIGOR)
            SELECT 
            itenantId TENANTID,
            iperiodseq PERIDOSEQ,
            C.CLASSIFIERID ID,
            GC.GENERICATTRIBUTE2 PDS,
            GC.GENERICATTRIBUTE5 ACTIVIDAD_DETALLADA,
            GC.GENERICATTRIBUTE4 ACTIVIDAD,
            GC.GENERICATTRIBUTE1 CIF,
            GC.GENERICATTRIBUTE3 COD_CONTRATO,
            GC.GENERICATTRIBUTE7 POS_DOC,
            GC.GENERICATTRIBUTE6 TEXTO_BREVE,
            GC.GENERICATTRIBUTE8 CODIGO_SERVICIO,
            GC.GENERICATTRIBUTE9 ORG_COMPRAS,
            GC.GENERICATTRIBUTE10 CONDICIONES_PAGO,            
            C.EFFECTIVESTARTDATE FECHA_INICIO_VIGOR,
            C.EFFECTIVEENDDATE FECHA_FIN_VIGOR
            
        FROM CS_GENERICCLASSIFIERTYPE GCT
        INNER JOIN CS_CLASSIFIER C ON GCT.GENERICCLASSIFIERTYPESEQ = C.SELECTORID
            AND C.TENANTID = itenantId 
            AND C.REMOVEDATE = v_eot
            AND C.EFFECTIVESTARTDATE <= v_ultimo_dia_periodo
            AND C.EFFECTIVEENDDATE >= v_ultimo_dia_periodo            
--            AND C.ISLAST = 1
        INNER JOIN CS_GENERICCLASSIFIER GC ON C.CLASSIFIERSEQ = GC.CLASSIFIERSEQ
          --  AND GC.EFFECTIVESTARTDATE <= PD.ENDDATE AND GC.EFFECTIVEENDDATE >= PD.ENDDATE
            AND GC.TENANTID = itenantId
            AND GC.REMOVEDATE = v_eot
            AND GC.EFFECTIVESTARTDATE <= v_ultimo_dia_periodo
            AND GC.EFFECTIVEENDDATE >= v_ultimo_dia_periodo              
--            AND GC.ISLAST = 1               
            
         WHERE GCT.NAME ='Contrato';

    filas := sql%rowcount;
    COMMIT;

    w_debug('Fin Carga de la tabla ENEL_E4E_CONTRATOS_TEMP: '|| to_char(filas) || ' filas.', v_contador_debug);

    EXECUTE IMMEDIATE 'ANALYZE TABLE ENELEXT.ENEL_E4E_CONTRATOS_TEMP COMPUTE STATISTICS FOR ALL INDEXES';
    w_debug('Fin Actualizacion Indices ENELEXT.ENEL_E4E_CONTRATOS_TEMP.',v_contador_debug);
    
end;



--------- Volcar datos de Posiciones y participantes a una Temporal de PDS   -------- 
--------- Tabla: ENEL_PDS_TEMP  --------
procedure p_Temporal_Pds (  iprocessingUnitSeq IN VARCHAR2, iperiod IN VARCHAR2,iperiodseq IN VARCHAR2, itenantId IN VARCHAR2 )
AS
      
    
begin

    w_debug('Inicio Truncado de la tabla ENEL_PDS_TEMP.', v_contador_debug);
    EXECUTE IMMEDIATE 'TRUNCATE TABLE ENELEXT.ENEL_PDS_TEMP';
    w_debug('Fin Truncado de la tabla ENEL_PDS_TEMP.', v_contador_debug);


    w_debug('Cargando tabla ENEL_PDS_TEMP. Periodo:'|| iperiod ||' Periodseq: '||iperiodseq ||' TenantId: '||itenantId ,  v_contador_debug);
      
     INSERT INTO ENELEXT.ENEL_PDS_TEMP(   PERIODSEQ, RULEELEMENTOWNERSEQ, PAYEESEQ, PAYEEID, PDS, NOMBRE_FISCAL, CIF, NOMBRE_CUENTA, CALLE, COD_POSTAL, 
                                          PROVINCIA, POBLACION, TIPO_IMPOSITIVO, PAR_PROVEEDOR, CODIGODEUDOR, NOMBRE_COMERCIAL, IMPORTE_UB, FECHA_CONTRATACION, 
                                          TIPO_PRESTADOR, COMUNIDAD_AUTONOMA, TERRITORIO, ZONA, POS_NOMBRE_COMERCIAL, CANAL, SUBCANAL, DELEGACION, 
                                          BASE_COMISION, FECHA_INI_VIGENCIA,TERMINATIONDATE,TITLE_NAME,CANAL_CALCULOS,TIPO_POSICION )
         SELECT 
                   PER.PERIODSEQ, 
                   POS.RULEELEMENTOWNERSEQ, 
                   PAR.PAYEESEQ,
                   PAYEE.PAYEEID, 
                   POS.NAME PDS, 
                   PAR.LASTNAME NOMBRE_FISCAL,
                   PAR.GENERICATTRIBUTE1 AS CIF,
                   PAR.GENERICATTRIBUTE2 AS NOMBRE_CUENTA,
                   PAR.GENERICATTRIBUTE3 AS CALLE,
                   PAR.GENERICATTRIBUTE4 AS COD_POSTAL,
                   PAR.GENERICATTRIBUTE5 AS PROVINCIA,
                   PAR.GENERICATTRIBUTE6 AS POBLACION,
                   PAR.GENERICATTRIBUTE7 AS TIPO_IMPOSITIVO,
                   PAR.GENERICATTRIBUTE8 AS CODIGOE4E,  -- PAR_PROVEEDOR
                   PAR.GENERICATTRIBUTE9 AS CODIGODEUDOR,                   
                   PAR.GENERICATTRIBUTE10 AS NOMBRE_COMERCIAL,
                   PAR.GENERICNUMBER1 AS IMPORTE_UB,
                   PAR.GENERICDATE1 AS FECHA_CONTRATACION,
                   POS.GENERICATTRIBUTE1 AS TIPO_PRESTADOR,
                   POS.GENERICATTRIBUTE2 AS COMUNIDAD_AUTONOMA,
                   POS.GENERICATTRIBUTE3 AS TERRITORIO,
                   POS.GENERICATTRIBUTE4 AS ZONA,
                   POS.GENERICATTRIBUTE5 AS POS_NOMBRE_COMERCIAL,
                   POS.GENERICATTRIBUTE6 AS CANAL,
                   POS.GENERICATTRIBUTE7 AS SUBCANAL,
                   POS.GENERICATTRIBUTE8 AS DELEGACION,
                   POS.GENERICATTRIBUTE10 AS BASE_COMISION,
                   POS.EFFECTIVESTARTDATE,    -- Fecha inicio de vigencia 
                   PAR.TERMINATIONDATE  AS TERMINATIONDATE,
                   TIT.NAME  AS TITLE_NAME,
                   TIT.GENERICATTRIBUTE1 AS CANAL_CALCULOS,
                   TIT.GENERICATTRIBUTE2 AS TIPO_POSICION
                    
        FROM CS_PERIOD per
                  
           JOIN  CS_POSITION pos ON  pos.REMOVEDATE = v_eot
             AND pos.TENANTID = itenantId 
             AND pos.EFFECTIVESTARTDATE <= PER.ENDDATE - 1
             AND pos.EFFECTIVEENDDATE >= PER.ENDDATE - 1
            -- and POS.ISLAST = 1   -- Con esta condición no se quedaba con la versión correcta asociada al fichero
             and POS.PROCESSINGUNITSEQ = iprocessingUnitSeq
                          
        INNER JOIN CS_PARTICIPANT par ON POS.PAYEESEQ = PAR.PAYEESEQ
             AND par.TENANTID = itenantId
             AND par.REMOVEDATE = v_eot
             AND PAR.EFFECTIVESTARTDATE <= PER.ENDDATE - 1
             AND PAR.EFFECTIVEENDDATE >= PER.ENDDATE - 1
             --and PAR.ISLAST = 1 -- Con esta condición no se quedaba con la versión correcta asociada al fichero

        INNER JOIN CS_PAYEE payee ON PAR.PAYEESEQ = PAYEE.PAYEESEQ
              AND PAYEE.REMOVEDATE =  v_eot
              --AND PAYEE.ISLAST =1   -- Con esta condición no se quedaba con la versión correcta asociada al fichero
              AND PAYEE.EFFECTIVESTARTDATE <= PER.ENDDATE - 1
              AND PAYEE.EFFECTIVEENDDATE >= PER.ENDDATE - 1        

        INNER JOIN CS_TITLE tit ON POS.TITLESEQ = TIT.RULEELEMENTOWNERSEQ
              AND TIT.REMOVEDATE = v_eot
              AND TIT.EFFECTIVESTARTDATE <= PER.ENDDATE - 1
              AND TIT.EFFECTIVEENDDATE >= PER.ENDDATE - 1
                            
        WHERE
             per.REMOVEDATE = v_eot
             AND per.PERIODSEQ = iperiodseq
             and par.GENERICATTRIBUTE1 is not null;
        
    filas := sql%rowcount;
    COMMIT;

    w_debug('Fin Carga de la tabla ENEL_PDS_TEMP: '|| to_char(filas) || ' filas.', v_contador_debug);

    EXECUTE IMMEDIATE 'ANALYZE TABLE ENELEXT.ENEL_PDS_TEMP COMPUTE STATISTICS FOR ALL INDEXES';
    w_debug('Fin Actualizacion Indices ENELEXT.ENEL_PDS_TEMP.',v_contador_debug);

end;

-- Extraer datos de Dep?sitos y JOIN con tablas temporales 
-- Tabla: ENEL_E4E_DEPOSIT_TEMP
procedure p_Temporal_Depositos_E4E ( iprocessingUnitSeq IN VARCHAR2, iperiod IN VARCHAR2,iperiodseq IN VARCHAR2, itenantId IN VARCHAR2, iInterfaz_Proceso  IN VARCHAR2)
AS
      
    
begin

    w_debug('Inicio Truncado de la tabla ENEL_E4E_DEPOSIT_TEMP.', v_contador_debug);
    EXECUTE IMMEDIATE 'TRUNCATE TABLE ENELEXT.ENEL_E4E_DEPOSIT_TEMP';
    w_debug('Fin Truncado de la tabla ENEL_E4E_DEPOSIT_TEMP.', v_contador_debug);


    w_debug('Cargando tabla ENEL_E4E_DEPOSIT_TEMP. Periodo:'|| iperiod ||' Periodseq: '||iperiodseq ||' TenantId: '||itenantId ,  v_contador_debug);

    if iInterfaz_Proceso = 'ACTUALIZA_INFORMES_REWARD' THEN

        w_debug('Origen de ENEL_E4E_DEPOSIT_TEMP : CS_DEPOSIT.', v_contador_debug);
    -- Si se ejecuta en la FASE REWARD Utilizamos la tabla de depositos para generar los datos de las tablas porque aun no se han realizado los PAGOS
     INSERT INTO ENELEXT.ENEL_E4E_DEPOSIT_TEMP(    PERIODSEQ,PERIODO, DEPOSITSEQ,POSITIONSEQ,PAYEESEQ,VALUE,PDS,
                                                PAR_PROVEEDOR,NOMBRE_FISCAL, CIF, TIPO_IMPOSITIVO,COD_CONTRATO,POS_DOC,
                                                TEXTO_BREVE,ORG_COMPRAS,CODIGO_SERVICIO, IDPROVEEDOR, FICHERO, SOCIEDAD,CECO,
                                                DESCRIPCION,GR_COMPRAS,CENTRO_LOGISTICO,WBE_FINAL_IMPUTACION, ACTIVIDAD, DETALLE_ACTIVIDAD, TIPO_PAGO, 
                                                POS_FECHA_INI_VIGENCIA, VALOR_OPERACIONES, CODIGODEUDOR,COMUNIDAD_AUTONOMA, ORG_VENTAS,CONDICIONES_PAGO  )
        Select
          DEPO.PERIODSEQ,
          DEPO.PERIODO, 
          MAX(DEPO.DEPOSITSEQ), -- Guardamos la ref. del seq deposito maximo
          DEPO.POSITIONSEQ, 
          DEPO.PAYEESEQ, 
          sum(DEPO.VALUE), 
--          TMP_PDS.PAYEEID,
          TMP_PDS.PDS,
          TMP_PDS.PAR_PROVEEDOR,
          TMP_PDS.NOMBRE_FISCAL,
          TMP_PDS.CIF, 
          TMP_PDS.TIPO_IMPOSITIVO,
          TMP_CONTRA.COD_CONTRATO, 
          TMP_CONTRA.POS_DOC, 
          TMP_CONTRA.TEXTO_BREVE, 
          TMP_CONTRA.ORG_COMPRAS,
          TMP_CONTRA.CODIGO_SERVICIO,
          TMP_PROV.IDPROVEEDOR,
          TMP_PROV.FICHERO,
          TMP_PROV.SOCIEDAD, 
          TMP_PROV.CECO, 
          TMP_PROV.DESCRIPCION, 
          TMP_PROV.GR_COMPRAS, 
          TMP_PROV.CENTRO_LOGISTICO, 
          TMP_PROV.WBE_FINAL_IMPUTACION,
          TMP_PROV.ACTIVIDAD,
          TMP_PROV.DETALLE_ACTIVIDAD,          
          TMP_PROV.TIPO_PAGO,
          TMP_PDS.FECHA_INI_VIGENCIA,
          -- Se separa el valor de las operaciones de OCAPS para mostralo en el BALANCE
          sum(CASE WHEN DEPO.EARNINGGROUPID = '050' and TMP_PDS.TIPO_POSICION = 'OCAP' THEN VALUE ELSE 0 END) as VALOR_OPERACIONES,
          TMP_PDS.CODIGODEUDOR,
          TMP_PDS.COMUNIDAD_AUTONOMA,
          TMP_PROV.ORG_VENTAS,
          TMP_CONTRA.CONDICIONES_PAGO

        FROM ENEL_DEPOSIT_TEMP DEPO
                                             
            INNER JOIN ENEL_PDS_TEMP TMP_PDS ON 
                DEPO.payeeseq=TMP_PDS.payeeseq 
                and DEPO.POSITIONSEQ=TMP_PDS.RULEELEMENTOWNERSEQ
                and DEPO.periodseq=TMP_PDS.periodseq

            INNER JOIN ENEL_PROVEEDORES_TEMP TMP_PROV 
                ON TMP_PROV.IDPROVEEDOR=DEPO.earninggroupid  
                AND DEPO.periodseq=TMP_PROV.periodseq

            --INNER JOIN ENEL_E4E_CONTRATOS_TEMP TMP_CONTRA  
              LEFT JOIN ENEL_E4E_CONTRATOS_TEMP TMP_CONTRA
                ON TMP_CONTRA.periodseq=DEPO.periodseq
                AND TMP_CONTRA.PDS = TMP_PDS.PDS                 
                AND TMP_CONTRA.ACTIVIDAD_DETALLADA=TMP_PROV.DETALLE_ACTIVIDAD
                AND TMP_CONTRA.periodseq=TMP_PROV.periodseq
 
        WHERE DEPO.TENANTID = itenantId
              AND DEPO.periodseq=iperiodseq        
             -- AND DEPO.VALUE > 0  -- Se incluyen los depositos negativos para el informe de Balance de Pagos y se filtran al generar los ficheros E4E y ECS  
              
        GROUP BY 
          DEPO.PERIODSEQ, 
          DEPO.PERIODO, 
          DEPO.POSITIONSEQ, 
          DEPO.PAYEESEQ,  
--          TMP_PDS.PAYEEID,
          TMP_PDS.PDS,
          TMP_PDS.PAR_PROVEEDOR,
          TMP_PDS.NOMBRE_FISCAL,
          TMP_PDS.CIF, 
          TMP_PDS.TIPO_IMPOSITIVO,
          TMP_CONTRA.COD_CONTRATO, 
          TMP_CONTRA.POS_DOC, 
          TMP_CONTRA.TEXTO_BREVE, 
          TMP_CONTRA.ORG_COMPRAS,
          TMP_CONTRA.CODIGO_SERVICIO,
          TMP_PROV.IDPROVEEDOR,
          TMP_PROV.FICHERO,
          TMP_PROV.SOCIEDAD, 
          TMP_PROV.CECO, 
          TMP_PROV.DESCRIPCION, 
          TMP_PROV.GR_COMPRAS, 
          TMP_PROV.CENTRO_LOGISTICO, 
          TMP_PROV.WBE_FINAL_IMPUTACION,
          TMP_PROV.ACTIVIDAD,
          TMP_PROV.DETALLE_ACTIVIDAD,           
          TMP_PROV.TIPO_PAGO,
          TMP_PDS.FECHA_INI_VIGENCIA,
          TMP_PDS.CODIGODEUDOR,
          TMP_PDS.COMUNIDAD_AUTONOMA,
          TMP_PROV.ORG_VENTAS,
          TMP_CONTRA.CONDICIONES_PAGO;
              
        
        filas := sql%rowcount;
        COMMIT;

    ELSE
     -- Si se ejecuta en una FASE que no es REWARD Utilizamos la tabla de PAGOS
      w_debug('Origen de ENEL_E4E_DEPOSIT_TEMP : CS_PAYMENT.', v_contador_debug);
             
     INSERT INTO ENELEXT.ENEL_E4E_DEPOSIT_TEMP(    PERIODSEQ,DEPOSITSEQ,POSITIONSEQ,PAYEESEQ,VALUE,PDS,
                                                PAR_PROVEEDOR,TIPO_IMPOSITIVO,COD_CONTRATO,POS_DOC,
                                                TEXTO_BREVE,ORG_COMPRAS, CODIGO_SERVICIO, IDPROVEEDOR,SOCIEDAD,CECO,
                                                DESCRIPCION,GR_COMPRAS,CENTRO_LOGISTICO,WBE_FINAL_IMPUTACION,ACTIVIDAD, TIPO_PAGO, POS_FECHA_INI_VIGENCIA)
        Select
        PAYM.PERIODSEQ, 
        --DEPO.DEPOSITSEQ, 
        PAYM.PAYMENTSEQ,
        PAYM.POSITIONSEQ, 
        PAYM.PAYEESEQ, 
        PAYM.VALUE, 
        --TMP_PDS.PDS,
        TMP_PDS.PAYEEID,
        TMP_PDS.PAR_PROVEEDOR, 
        TMP_PDS.TIPO_IMPOSITIVO,
        TMP_CONTRA.COD_CONTRATO, 
        TMP_CONTRA.POS_DOC, 
        TMP_CONTRA.TEXTO_BREVE, 
        TMP_CONTRA.ORG_COMPRAS,
        TMP_CONTRA.CODIGO_SERVICIO,
        TMP_PROV.IDPROVEEDOR,
        TMP_PROV.SOCIEDAD, 
        TMP_PROV.CECO, 
        TMP_PROV.DESCRIPCION, 
        TMP_PROV.GR_COMPRAS, 
        TMP_PROV.CENTRO_LOGISTICO, 
        TMP_PROV.WBE_FINAL_IMPUTACION,
        TMP_PROV.ACTIVIDAD,
        TMP_PROV.TIPO_PAGO,        
        TMP_PDS.FECHA_INI_VIGENCIA

        FROM CS_PAYMENT PAYM
            INNER JOIN CS_PLRUN p ON PAYM.TRIALPIPELINERUNSEQ = P.PIPELINERUNSEQ 
                  AND P.MODELSEQ = 0   -- Solo se tienen en cuenta las ejecuciones que no son de simulacion
                                             
            INNER JOIN ENEL_PDS_TEMP TMP_PDS ON 
                PAYM.payeeseq=TMP_PDS.payeeseq 
                and PAYM.POSITIONSEQ=TMP_PDS.RULEELEMENTOWNERSEQ
                and PAYM.periodseq=TMP_PDS.periodseq

            INNER JOIN ENEL_PROVEEDORES_TEMP TMP_PROV 
                ON TMP_PROV.IDPROVEEDOR=PAYM.earninggroupid  
                AND PAYM.periodseq=TMP_PROV.periodseq

            --INNER JOIN ENEL_E4E_CONTRATOS_TEMP TMP_CONTRA  
              LEFT JOIN ENEL_E4E_CONTRATOS_TEMP TMP_CONTRA
                ON TMP_CONTRA.periodseq=PAYM.periodseq
                AND TMP_CONTRA.PDS = TMP_PDS.PDS                 
                AND TMP_CONTRA.ACTIVIDAD_DETALLADA=TMP_PROV.DETALLE_ACTIVIDAD
                AND TMP_CONTRA.periodseq=TMP_PROV.periodseq
 
        WHERE PAYM.TENANTID = itenantId
              AND PAYM.periodseq=iperiodseq        
              AND PAYM.PROCESSINGUNITSEQ =  iprocessingUnitSeq;             
              
        
        filas := sql%rowcount;
        COMMIT;
    END IF;

    w_debug('Fin Carga de la tabla ENEL_E4E_DEPOSIT_TEMP: '|| to_char(filas) || ' filas.', v_contador_debug);

    EXECUTE IMMEDIATE 'ANALYZE TABLE ENELEXT.ENEL_E4E_DEPOSIT_TEMP COMPUTE STATISTICS FOR ALL INDEXES';
    w_debug('Fin Actualizacion Indices ENELEXT.ENEL_E4E_DEPOSIT_TEMP.',v_contador_debug);
    
end;


procedure p_Cabecera_Ficheros_E4E (  iperiod IN VARCHAR2, iFichero IN VARCHAR2 )
AS
    contador integer;  

begin

    w_debug('Inicio Inserccion 4 Registros fijos de cabecera en tabla ENEL_E4E_FINAL para fichero ' || iFichero ,  v_contador_debug);
    contador := 1;
    -- Registro de CABECERA 1 : lista de campos
    INSERT INTO ENEL_E4E_FINAL (PERIODO, ORDEN, CAMPO1, CAMPO2, CAMPO3, CAMPO4, CAMPO5, CAMPO6, CAMPO7, CAMPO8, CAMPO9, CAMPO10, 
                                       CAMPO11, CAMPO12, CAMPO13, CAMPO14, CAMPO15, CAMPO16, CAMPO17, CAMPO18, CAMPO19, CAMPO20, CAMPO21, CAMPO22, FICHERO)
        VALUES (iperiod,contador,'CAMPO1','CAMPO2','CAMPO3','CAMPO4','CAMPO5','CAMPO6','CAMPO7','CAMPO8','CAMPO9',
        'CAMPO10','CAMPO11','CAMPO12','CAMPO13','CAMPO14','CAMPO15','CAMPO16','CAMPO17','CAMPO18','CAMPO19','CAMPO20','CAMPO21','CAMPO22',iFichero);

    -- Registro de CABECERA 2 : CABECERA
    contador := contador + 1;
    INSERT INTO ENEL_E4E_FINAL (PERIODO, ORDEN, CAMPO1, CAMPO2, CAMPO3, CAMPO4, CAMPO5, CAMPO6, CAMPO7, CAMPO8, CAMPO9, CAMPO10, 
                                       CAMPO11, CAMPO12, CAMPO13, CAMPO14, CAMPO15, CAMPO16, CAMPO17, CAMPO18, CAMPO19, CAMPO20, CAMPO21, CAMPO22, FICHERO)
        VALUES (iperiod,contador,'Ref.Orden Entrega','Pos.Orden.Entrega','CABECERA','Contrato','Fecha Pedido','','Sociedad','Cod. Proveedor','CECO Aprob.',
        'Org.Compras','Gr.Compras','Riesgo','Contract Manager','Sit.Trabajo','Nota Cab.','','','','','','','',iFichero);


    -- Registro de CABECERA 3 : POSICION    
    contador := contador + 1;
    INSERT INTO ENEL_E4E_FINAL (PERIODO, ORDEN, CAMPO1, CAMPO2, CAMPO3, CAMPO4, CAMPO5, CAMPO6, CAMPO7, CAMPO8, CAMPO9, CAMPO10, 
                                       CAMPO11, CAMPO12, CAMPO13, CAMPO14, CAMPO15, CAMPO16, CAMPO17, CAMPO18, CAMPO19, CAMPO20, CAMPO21, CAMPO22, FICHERO)
        VALUES (iperiod,contador,'Ref.Orden Entrega','Pos.Orden.Entrega','POSICION','Contrato','','Pos. contrato','Tipo Imp.','Código','Texto breve',
        'Texto posición','Cantidad','Unidad medida','Fecha entrega','Centro log.','Imputación','Tipo impuesto','Ref. para proveedor','Num. Dirección',
        'Dirección','Población','Cod. postal','Nom. solicitante',iFichero);

    -- Registro de CABECERA 4 : SERVICIO
    contador := contador +1;
    INSERT INTO ENEL_E4E_FINAL (PERIODO, ORDEN, CAMPO1, CAMPO2, CAMPO3, CAMPO4, CAMPO5, CAMPO6, CAMPO7, CAMPO8, CAMPO9, CAMPO10, 
                                       CAMPO11, CAMPO12, CAMPO13, CAMPO14, CAMPO15, CAMPO16, CAMPO17, CAMPO18, CAMPO19, CAMPO20, CAMPO21, CAMPO22, FICHERO)
        VALUES (iperiod,contador,'Ref.Orden Entrega','Pos.Orden.Entrega','SERVICIO','Contrato','','Pos. contrato','Línea. Servicio','Cod. Servicio','Texto breve',
        'Cantidad','Imputación','','','','','','','','','','','',iFichero);        

    COMMIT;
    w_debug('Fin Inserccion 4 Registros fijos de cabecera en tabla ENEL_E4E_FINAL para fichero ' || iFichero ,  v_contador_debug);
    
end;

procedure p_Final_E4E_1 ( iperiod IN VARCHAR2,iperiodseq IN VARCHAR2, itenantId IN VARCHAR2 )
AS
    contadorE4E integer;
    contadorECS integer; 
    contadorTabla integer;   
    v_referencia VARCHAR2(20);
    v_fechaInicioPeriodo date;
    v_txtFechaInicioPeriodo VARCHAR2(10);
    v_txtFechaActual VARCHAR2(10);
    v_txtYear VARCHAR2(2);
    v_codMes VARCHAR2(1);
    v_Impuesto VARCHAR2(2);
    v_txtFechaInicio VARCHAR2(10); -- será igual que v_txtFechaInicioPeriodo a no ser que el PDS tenga fechainicio vigencia mayor
    v_codFichero VARCHAR2(4);
begin

    w_debug('Inicio Borrado de la tabla ENEL_E4E_FINAL.', v_contador_debug);

    
    --v_codFichero :='E4E1';  -- v2.0 se asigna el valor dinamicamente en función de la actividad del proveedor
        
   -- EXECUTE IMMEDIATE 'DELETE ENELEXT.ENEL_E4E_FINAL WHERE ....';
   BEGIN
     LOOP
        DELETE FROM ENEL_E4E_FINAL WHERE PERIODO = iperiod AND FICHERO like 'E%1' AND ROWNUM <= 10000;
        EXIT WHEN SQL%ROWCOUNT = 0;
        COMMIT;
     END LOOP;
   END;
    w_debug('Fin Borrado de la tabla ENEL_E4E_FINAL.', v_contador_debug);

    -- Se extrae la fecha inicial del siguiente mes al periodSeq del proceso
    v_fechaInicioPeriodo :=  f_Primer_Dia_Periodo_Siguiente(iperiodseq);
    -- Se convierte a texto en formato DD/MM/YYYY para los registros de salida
    v_txtFechaInicioPeriodo := to_char(v_fechaInicioPeriodo, 'DD/MM/YYYY');
    -- Se convierte a texto el año YY para el código de referencia
    v_txtYear := to_char(v_fechaInicioPeriodo, 'YY');
    -- Se extrae el código asociado al mes, donde Enero = A, Febrero = B, ... Diciembre = L
    v_codMes := f_CodigoMes(v_fechaInicioPeriodo);
    -- Se convierte a texto la fecha actual en formato DD/MM/YYYY para los registros de salida
    v_txtFechaActual := to_char(sysdate, 'DD/MM/YYYY');
    
    w_debug('Referencia fechas. Periodo:'|| iperiod ||' FechaInicioPeriodo Siguiente: '||v_txtFechaInicioPeriodo ||' YY: '||v_txtYear ||' codMes: '||v_codMes || ' FechaActual ' || v_txtFechaActual ,  v_contador_debug);
    
    w_debug('Cargando tabla ENEL_E4E_FINAL. Periodo:'|| iperiod ||' Periodseq: '||iperiodseq ||' TenantId: '||itenantId ,  v_contador_debug);

    w_debug('Insertando Registros de datos en tabla ENEL_E4E_FINAL. Fichero ' || v_codFichero ,  v_contador_debug);
    
     contadorE4E := 4;
     contadorECS := 4;
     
    DECLARE
        CURSOR C_TMPDEPOSITOS IS
            SELECT 
              PERIODSEQ,
              VALUE,
              PDS,
              PAR_PROVEEDOR,
              TIPO_IMPOSITIVO,
              COD_CONTRATO,
              POS_DOC,
              TEXTO_BREVE,
              ORG_COMPRAS,
              IDPROVEEDOR,
              SOCIEDAD,
              CECO,
              DESCRIPCION,
              GR_COMPRAS,
              CENTRO_LOGISTICO,
              WBE_FINAL_IMPUTACION,
              ACTIVIDAD,
              TIPO_PAGO,
              POS_FECHA_INI_VIGENCIA,
              CODIGO_SERVICIO
            FROM ENEL_E4E_DEPOSIT_TEMP
            WHERE PERIODSEQ = iperiodseq 
                  AND COD_CONTRATO is not null    -- Fichero E4E1 contiene los registros con contrato
                  AND VALUE > 0;                  -- Fichero E4E se incluyen solo los positivos 
            REGDEPOSITO C_TMPDEPOSITOS%ROWTYPE;
            
    BEGIN
        OPEN C_TMPDEPOSITOS;
        FETCH C_TMPDEPOSITOS INTO REGDEPOSITO;
        
        WHILE C_TMPDEPOSITOS%FOUND
        LOOP
        
            -- Código de fichero
            CASE REGDEPOSITO.ACTIVIDAD 
                WHEN 'STP'          THEN v_codFichero :='E4E1';
                WHEN 'SSII'         THEN v_codFichero :='E4E1';
                WHEN 'CAPTACIÓN'    THEN v_codFichero :='ECS1';  
                WHEN 'ATC'          THEN v_codFichero :='ECS1';
                ELSE                     v_codFichero :='NOT1';
            END CASE;
                
            -- Se concatenan los valores que forman el código de referencia:
            --    YY + Codigo de PDS + Código de proveedor + Código de Mes (Enero = A, Febrero = B ...)
            v_referencia := v_txtYear || REGDEPOSITO.PDS || REGDEPOSITO.IDPROVEEDOR || v_codMes;

            -- Se determina el código de equivalencia del tipo impositivo
            CASE REGDEPOSITO.TIPO_IMPOSITIVO
                WHEN 'IVA'          THEN v_Impuesto := 'SD';
                WHEN 'IGIC'         THEN v_Impuesto := 'CB';
                WHEN 'IVA Portugal' THEN v_Impuesto := 'KK';
                ELSE                     v_Impuesto := '';
            END CASE;
            
            -- Se determina la fecha de inicio
            IF REGDEPOSITO.POS_FECHA_INI_VIGENCIA > v_fechaInicioPeriodo THEN
                v_txtFechaInicio := to_char(REGDEPOSITO.POS_FECHA_INI_VIGENCIA, 'DD/MM/YYYY');
            ELSE
                v_txtFechaInicio := v_txtFechaInicioPeriodo;
            END IF;
             
            -- Registro de DATOS - CABECERA
            IF v_codFichero = 'E4E1' then
                contadorE4E := contadorE4E +1;
                contadorTabla := contadorE4E;
            ELSIF v_codFichero = 'ECS1' then
                contadorECS := contadorECS +1;
                contadorTabla := contadorECS;
            END IF;    
            
            INSERT INTO ENEL_E4E_FINAL (PERIODO, ORDEN, CAMPO1, CAMPO2, CAMPO3, CAMPO4, CAMPO5, CAMPO6, CAMPO7, CAMPO8, CAMPO9, CAMPO10, 
                                       CAMPO11, CAMPO12, CAMPO13, CAMPO14, CAMPO15, CAMPO16, CAMPO17, CAMPO18, CAMPO19, CAMPO20, CAMPO21, CAMPO22, FICHERO)
                VALUES ( iperiod,
                         contadorTabla,
                         v_referencia,
                         '',
                         'CABECERA', 
                         REGDEPOSITO.COD_CONTRATO,
                         v_txtFechaInicio,
                         '',
                         REGDEPOSITO.SOCIEDAD,
                         REGDEPOSITO.PAR_PROVEEDOR,
                         REGDEPOSITO.CECO,
                         REGDEPOSITO.ORG_COMPRAS,
                         REGDEPOSITO.GR_COMPRAS,
                         'NO',
                         '',
                         'RE',
                         '','','','','','','','',v_codFichero);

            -- Registro de DATOS - POSICION
            IF v_codFichero = 'E4E1' then
                contadorE4E := contadorE4E +1;
                contadorTabla := contadorE4E;
            ELSIF v_codFichero = 'ECS1' then
                contadorECS := contadorECS +1;
                contadorTabla := contadorECS;
            END IF; 
            INSERT INTO ENEL_E4E_FINAL (PERIODO, ORDEN, CAMPO1, CAMPO2, CAMPO3, CAMPO4, CAMPO5, CAMPO6, CAMPO7, CAMPO8, CAMPO9, CAMPO10, 
                                       CAMPO11, CAMPO12, CAMPO13, CAMPO14, CAMPO15, CAMPO16, CAMPO17, CAMPO18, CAMPO19, CAMPO20, CAMPO21, CAMPO22, FICHERO)
                VALUES ( iperiod,
                         contadorTabla,
                         v_referencia,    --CAMPO1
                         '10',
                         'POSICION', 
                         REGDEPOSITO.COD_CONTRATO, --CAMPO4
                         '',
                         REGDEPOSITO.POS_DOC,
                         'P',                      --CAMPO7
                         '',
                         REGDEPOSITO.TEXTO_BREVE,  --CAMPO9
                         REGDEPOSITO.DESCRIPCION,  --CAMPO10
                         -- CAMPO 11 es 1 cuando hay linea de SERVICIO y si no contiene el importe
                         CASE WHEN REGDEPOSITO.TIPO_PAGO = 'SERVICIO' THEN '1' ELSE to_char(REGDEPOSITO.VALUE) END,  --CAMPO11
                         'UA',
                         v_txtFechaActual,
                         REGDEPOSITO.CENTRO_LOGISTICO,
                         REGDEPOSITO.WBE_FINAL_IMPUTACION,
                         v_Impuesto,
                         '','','','','','ES21-01',v_codFichero);            

            IF REGDEPOSITO.TIPO_PAGO = 'SERVICIO' THEN
                -- Registro de DATOS - POSICION
                IF v_codFichero = 'E4E1' then
                 contadorE4E := contadorE4E +1;
                   contadorTabla := contadorE4E;
                ELSIF v_codFichero = 'ECS1' then
                    contadorECS := contadorECS +1;
                   contadorTabla := contadorECS;
                END IF; 
                INSERT INTO ENEL_E4E_FINAL (PERIODO, ORDEN, CAMPO1, CAMPO2, CAMPO3, CAMPO4, CAMPO5, CAMPO6, CAMPO7, CAMPO8, CAMPO9, CAMPO10, 
                                       CAMPO11, CAMPO12, CAMPO13, CAMPO14, CAMPO15, CAMPO16, CAMPO17, CAMPO18, CAMPO19, CAMPO20, CAMPO21, CAMPO22, FICHERO)
                    VALUES ( iperiod,
                             contadorTabla,
                             v_referencia,
                             '10',
                             'SERVICIO', 
                             REGDEPOSITO.COD_CONTRATO,
                             '',
                             REGDEPOSITO.POS_DOC,  -- CAMPO6
                             '10',                     -- CAMPO7
                             REGDEPOSITO.CODIGO_SERVICIO,  --CAMPO8
                             REGDEPOSITO.TEXTO_BREVE,
                             to_char(REGDEPOSITO.VALUE),  --CAMPO10
                             REGDEPOSITO.WBE_FINAL_IMPUTACION, -- CAMPO11
                             '', '', '', '',                    -- CAMPO12 a 15
                             '', '', '', '',                    -- CAMPO16 a 19
                             '', '', '',                        -- CAMPO20 a 22
                             v_codFichero);

            END IF;

                        
            FETCH C_TMPDEPOSITOS INTO REGDEPOSITO;
            
        END LOOP;
        

            
            
        CLOSE C_TMPDEPOSITOS;
    END;
    
    --Si se han insertado registros de datos de E4E, se insertan los registros de cabecera para el fichero E4E2
    if contadorE4E > 4 THEN
    
        p_Cabecera_Ficheros_E4E (  iperiod , 'E4E1' );
        
    end if;
    --Si se han insertado registros de datos ECS, se insertan los registros de cabecera para el fichero ECS2
    if contadorECS > 4 THEN
    
        p_Cabecera_Ficheros_E4E (  iperiod , 'ECS1' );
        
    end if;   
    
    
        w_debug('Fin Carga de la tabla ENEL_E4E_FINAL:  E4E1'|| to_char(contadorE4E) || ' -- ECS1'|| to_char(contadorECS) || ' filas.', v_contador_debug);
    
end;

procedure p_Final_E4E_2 ( iperiod IN VARCHAR2,iperiodseq IN VARCHAR2, itenantId IN VARCHAR2 )
AS
    contadorE4E integer;
    contadorECS integer; 
    contadorTabla integer;   
    v_referencia VARCHAR2(20);
    v_fechaInicioPeriodo date;
    v_txtFechaInicioPeriodo VARCHAR2(10);
    v_txtFechaActual VARCHAR2(10);
    v_txtYear VARCHAR2(2);
    v_codMes VARCHAR2(1);
    v_Impuesto VARCHAR2(2);
    v_txtFechaInicio VARCHAR2(10); -- será igual que v_txtFechaInicioPeriodo a no ser que el PDS tenga fechainicio vigencia mayor
    v_codFichero VARCHAR2(4);
begin

    w_debug('Inicio Borrado de la tabla ENEL_E4E_FINAL.', v_contador_debug);
    
    
    --v_codFichero :='E4E2'; -- v2.0 se asigna el valor dinamicamente en función de la actividad del proveedor


   -- EXECUTE IMMEDIATE 'DELETE ENELEXT.ENEL_E4E_FINAL WHERE ....';
   BEGIN
     LOOP
        DELETE FROM ENEL_E4E_FINAL WHERE PERIODO = iperiod AND FICHERO like 'E%2'  AND ROWNUM <= 10000;
        EXIT WHEN SQL%ROWCOUNT = 0;
        COMMIT;
     END LOOP;
   END;
    w_debug('Fin Borrado de la tabla ENEL_E4E_FINAL.', v_contador_debug);

    -- Se extrae la fecha inicial del siguiente mes al periodSeq del proceso
    v_fechaInicioPeriodo :=  f_Primer_Dia_Periodo_Siguiente(iperiodseq);
    -- Se convierte a texto en formato DD/MM/YYYY para los registros de salida
    v_txtFechaInicioPeriodo := to_char(v_fechaInicioPeriodo, 'DD/MM/YYYY');
    -- Se convierte a texto el año YY para el código de referencia
    v_txtYear := to_char(v_fechaInicioPeriodo, 'YY');
    -- Se extrae el código asociado al mes, donde Enero = A, Febrero = B, ... Diciembre = L
    v_codMes := f_CodigoMes(v_fechaInicioPeriodo);
    -- Se convierte a texto la fecha actual en formato DD/MM/YYYY para los registros de salida
    v_txtFechaActual := to_char(sysdate, 'DD/MM/YYYY');
    
    w_debug('Referencia fechas. Periodo:'|| iperiod ||' FechaInicioPeriodo Siguiente: '||v_txtFechaInicioPeriodo ||' YY: '||v_txtYear ||' codMes: '||v_codMes || ' FechaActual ' || v_txtFechaActual ,  v_contador_debug);
    
    w_debug('Cargando tabla ENEL_E4E_FINAL. Periodo:'|| iperiod ||' Periodseq: '||iperiodseq ||' TenantId: '||itenantId ,  v_contador_debug);

    w_debug('Insertando Registros de datos en tabla ENEL_E4E_FINAL. Fichero ' || v_codFichero ,  v_contador_debug);
    
     contadorE4E := 4;
     contadorECS := 4;
     
    DECLARE
        CURSOR C_TMPDEPOSITOS IS
            SELECT 
              PERIODSEQ,
              VALUE,
              PDS,
              PAR_PROVEEDOR,
              TIPO_IMPOSITIVO,
              COD_CONTRATO,
              POS_DOC,
              TEXTO_BREVE,
              ORG_COMPRAS,
              IDPROVEEDOR,
              SOCIEDAD,
              CECO,
              DESCRIPCION,
              GR_COMPRAS,
              CENTRO_LOGISTICO,
              WBE_FINAL_IMPUTACION,
              ACTIVIDAD,
              TIPO_PAGO,
              POS_FECHA_INI_VIGENCIA,
              CODIGO_SERVICIO
            FROM ENEL_E4E_DEPOSIT_TEMP
            WHERE PERIODSEQ = iperiodseq 
                  AND COD_CONTRATO is null  -- Fichero E4E2 contiene los registros sin contrato (valor nulo)
                  AND VALUE > 0;                  -- Fichero E4E se incluyen solo los positivos
            REGDEPOSITO C_TMPDEPOSITOS%ROWTYPE;
            
    BEGIN
        OPEN C_TMPDEPOSITOS;
        FETCH C_TMPDEPOSITOS INTO REGDEPOSITO;
        
        WHILE C_TMPDEPOSITOS%FOUND
        LOOP
        
            -- Código de fichero
            CASE REGDEPOSITO.ACTIVIDAD 
                WHEN 'STP'          THEN v_codFichero :='E4E2';
                WHEN 'SSII'         THEN v_codFichero :='E4E2';                
                WHEN 'CAPTACIÓN'    THEN v_codFichero :='ECS2';  
                WHEN 'ATC'          THEN v_codFichero :='ECS2';
                ELSE                     v_codFichero :='NOT2';
            END CASE;
            
            -- Se concatenan los valores que forman el código de referencia:
            --    YY + Codigo de PDS + Código de proveedor + Código de Mes (Enero = A, Febrero = B ...)
            v_referencia := v_txtYear || REGDEPOSITO.PDS || REGDEPOSITO.IDPROVEEDOR || v_codMes;

            -- Se determina el código de equivalencia del tipo impositivo
            CASE REGDEPOSITO.TIPO_IMPOSITIVO
                WHEN 'IVA'          THEN v_Impuesto := 'SD';
                WHEN 'IGIC'         THEN v_Impuesto := 'CB';
                WHEN 'IVA Portugal' THEN v_Impuesto := 'KK';
                ELSE                     v_Impuesto := '';
            END CASE;
            
            -- Se determina la fecha de inicio
            IF REGDEPOSITO.POS_FECHA_INI_VIGENCIA > v_fechaInicioPeriodo THEN
                v_txtFechaInicio := to_char(REGDEPOSITO.POS_FECHA_INI_VIGENCIA, 'DD/MM/YYYY');
            ELSE
                v_txtFechaInicio := v_txtFechaInicioPeriodo;
            END IF;
             
            -- Registro de DATOS - CABECERA
            IF v_codFichero = 'E4E2' then
                contadorE4E := contadorE4E +1;
                contadorTabla := contadorE4E;
            ELSIF v_codFichero = 'ECS2' then
                contadorECS := contadorECS +1;
                contadorTabla := contadorECS;
            END IF;          
                         
            INSERT INTO ENEL_E4E_FINAL (PERIODO, ORDEN, CAMPO1, CAMPO2, CAMPO3, CAMPO4, CAMPO5, CAMPO6, CAMPO7, CAMPO8, CAMPO9, CAMPO10, 
                                       CAMPO11, CAMPO12, CAMPO13, CAMPO14, CAMPO15, CAMPO16, CAMPO17, CAMPO18, CAMPO19, CAMPO20, CAMPO21, CAMPO22, FICHERO)
                VALUES ( iperiod,
                         contadorTabla,
                         v_referencia,
                         '',
                         'CABECERA', 
                         REGDEPOSITO.COD_CONTRATO,
                         v_txtFechaInicio,
                         '',
                         REGDEPOSITO.SOCIEDAD,
                         REGDEPOSITO.PAR_PROVEEDOR,
                         REGDEPOSITO.CECO,
                         REGDEPOSITO.ORG_COMPRAS,
                         REGDEPOSITO.GR_COMPRAS,
                         'NO',
                         '',
                         'RE',
                         '','','','','','','','',v_codFichero);

            -- Registro de DATOS - POSICION
            
            IF v_codFichero = 'E4E2' then
                contadorE4E := contadorE4E +1;
                contadorTabla := contadorE4E;
            ELSIF v_codFichero = 'ECS2' then
                contadorECS := contadorECS +1;
                contadorTabla := contadorECS;
            END IF; 
            
            INSERT INTO ENEL_E4E_FINAL (PERIODO, ORDEN, CAMPO1, CAMPO2, CAMPO3, CAMPO4, CAMPO5, CAMPO6, CAMPO7, CAMPO8, CAMPO9, CAMPO10, 
                                       CAMPO11, CAMPO12, CAMPO13, CAMPO14, CAMPO15, CAMPO16, CAMPO17, CAMPO18, CAMPO19, CAMPO20, CAMPO21, CAMPO22, FICHERO)
                VALUES ( iperiod,
                         contadorTabla,
                         v_referencia,
                         '10',
                         'POSICION', 
                         REGDEPOSITO.COD_CONTRATO,
                         '',
                         REGDEPOSITO.POS_DOC,
                         'P',
                         '',
                         REGDEPOSITO.TEXTO_BREVE,
                         REGDEPOSITO.DESCRIPCION,
                         -- CAMPO 11 es 1 cuando hay linea de SERVICIO y si no contiene el importe
                         CASE WHEN REGDEPOSITO.TIPO_PAGO = 'SERVICIO' THEN '1' ELSE to_char(REGDEPOSITO.VALUE) END,  --CAMPO11
                         'UA',
                         v_txtFechaActual,
                         REGDEPOSITO.CENTRO_LOGISTICO,
                         REGDEPOSITO.WBE_FINAL_IMPUTACION,
                         v_Impuesto,
                         '','','','','','ES21-01',v_codFichero);            

            IF REGDEPOSITO.TIPO_PAGO = 'SERVICIO' THEN
                -- Registro de DATOS - servicio
                IF v_codFichero = 'E4E2' then
                  contadorE4E := contadorE4E +1;
                  contadorTabla := contadorE4E;
                ELSIF v_codFichero = 'ECS2' then
                  contadorECS := contadorECS +1;
                  contadorTabla := contadorECS;
                END IF;
             
                INSERT INTO ENEL_E4E_FINAL (PERIODO, ORDEN, CAMPO1, CAMPO2, CAMPO3, CAMPO4, CAMPO5, CAMPO6, CAMPO7, CAMPO8, CAMPO9, CAMPO10, 
                                       CAMPO11, CAMPO12, CAMPO13, CAMPO14, CAMPO15, CAMPO16, CAMPO17, CAMPO18, CAMPO19, CAMPO20, CAMPO21, CAMPO22, FICHERO)
                    VALUES ( iperiod,
                             contadorTabla,
                             v_referencia,
                             '10',
                             'SERVICIO', 
                             REGDEPOSITO.COD_CONTRATO,
                             '',
                             REGDEPOSITO.POS_DOC,  -- CAMPO6
                             '10',                     -- CAMPO7
                             REGDEPOSITO.CODIGO_SERVICIO,  --CAMPO8
                             REGDEPOSITO.TEXTO_BREVE,
                             to_char(REGDEPOSITO.VALUE),  --CAMPO10
                             REGDEPOSITO.WBE_FINAL_IMPUTACION, -- CAMPO11
                             '', '', '', '',                    -- CAMPO12 a 15
                             '', '', '', '',                    -- CAMPO16 a 19
                             '', '', '',                        -- CAMPO20 a 22
                             v_codFichero);

            END IF;
                        
            FETCH C_TMPDEPOSITOS INTO REGDEPOSITO;
            
        END LOOP;
        

            
            
        CLOSE C_TMPDEPOSITOS;
    END;
    
    --Si se han insertado registros de datos de E4E, se insertan los registros de cabecera para el fichero E4E2
    if contadorE4E > 4 THEN
    
        p_Cabecera_Ficheros_E4E (  iperiod , 'E4E2' );
        
    end if;
    --Si se han insertado registros de datos ECS, se insertan los registros de cabecera para el fichero ECS2
    if contadorECS > 4 THEN
    
        p_Cabecera_Ficheros_E4E (  iperiod , 'ECS2' );
        
    end if;   
    
        w_debug('Fin Carga de la tabla ENEL_E4E_FINAL:  E4E2'|| to_char(contadorE4E) || ' -- ECS2'|| to_char(contadorECS) || ' filas.', v_contador_debug);
    
end;

       
procedure p_Final_E4E_Negativos ( iprocessingUnitSeq IN VARCHAR2, iperiod IN VARCHAR2,iperiodseq IN VARCHAR2, itenantId IN VARCHAR2 )
AS
    v_fechaInicioPeriodoSig date;
    v_txtFechaInicioPeriodoSig VARCHAR2(10);
    v_txtFechaActual VARCHAR2(10);
    v_txtYear VARCHAR2(2);
    v_codMes VARCHAR2(1);
    v_maxIDPEDIDO integer;
    
begin
    w_debug('Inicio Borrado de la tabla ENEL_E4E_NEGATIVOS.', v_contador_debug);
   BEGIN
     LOOP
        DELETE FROM ENELEXT.ENEL_E4E_NEGATIVOS WHERE PERIODO = iperiod AND ROWNUM <= 10000;
        EXIT WHEN SQL%ROWCOUNT = 0;
        COMMIT;
     END LOOP;
   END;
    w_debug('Fin Borrado de la tabla ENEL_E4E_NEGATIVOS.', v_contador_debug);

    -- Se extrae la fecha inicial del siguiente mes al periodSeq del proceso
    v_fechaInicioPeriodoSig :=  f_Primer_Dia_Periodo_Siguiente(iperiodseq);
    
    -- Se convierte a texto en formato DD/MM/YYYY para los registros de salida
    v_txtFechaInicioPeriodoSig := to_char(v_fechaInicioPeriodoSig, 'DD/MM/YYYY');
    
    -- Se convierte a texto el año YY para el código de referencia
    v_txtYear := to_char(v_fechaInicioPeriodoSig, 'YY');
    
    -- Se extrae el código asociado al mes, donde Enero = A, Febrero = B, ... Diciembre = L
    v_codMes := f_CodigoMes(v_fechaInicioPeriodoSig);
    
    -- Se convierte a texto la fecha actual en formato DD/MM/YYYY para los registros de salida
    v_txtFechaActual := to_char(sysdate, 'DD/MM/YYYY');
    
    w_debug('Referencia fechas. Periodo:'|| iperiod ||' FechaInicioPeriodo Siguiente: '||v_txtFechaInicioPeriodoSig ||' YY: '||v_txtYear ||' codMes: '||v_codMes || ' FechaActual ' || v_txtFechaActual ,  v_contador_debug);

    select NVL(MAX(IDPEDIDO),0) into v_maxIDPEDIDO  from ENEL_E4E_NEGATIVOS WHERE ESTADO='LIQUIDADO';
    w_debug('Numero máximo de pedido E4E Negativos Liquidado: ' || to_char(v_maxIDPEDIDO) ,  v_contador_debug);
    
    w_debug('Insertando Registros de datos en tabla ENEL_E4E_NEGATIVOS.' ,  v_contador_debug);
    
     INSERT INTO ENELEXT.ENEL_E4E_NEGATIVOS ( PERIODSEQ, PERIODO, DEPOSITSEQ, POSITIONSEQ, PAYEESEQ, PDS, IDPEDIDO, ORG_VENTAS, CANAL_DISTRIBUCION, 
                                              SECTOR, CLASE_PEDIDO, FACTURA_REF, SOLICITANTE_SHIPTO, SOLICITANTE_SOLDTO, NUM_PEDIDO, FECHAPEDIDO, FECHAFACTURA, 
                                              CONDICIONES_PAGO, CONTRATOSEPA, MOTIVOPEDIDO, MONEDA, POSICION, MATERIAL, TEXTO_MATERIAL, CANTIDAD, PRECIO, 
                                              CLASIF_FISCAL_IVA, CLASIF_FISCAL_IGIC, WBE_FINAL_IMPUTACION  )   
        SELECT 
          e4edt.PERIODSEQ,
          e4edt.PERIODO,
          e4edt.DEPOSITSEQ,
          e4edt.POSITIONSEQ,
          e4edt.PAYEESEQ, 
          e4edt.PDS,
          v_maxIDPEDIDO + rownum as IDPEDIDO,
          e4edt.ORG_VENTAS,
          CASE WHEN COMUNIDAD_AUTONOMA = 'CANARIAS' THEN 'CA' ELSE 'CO' END AS CANAL_DISTRIBUCION,
          '39' as SECTOR,
          'ZOAL' as CLASE_PEDIDO,
          '' AS FACTURA_REF,
          e4edt.CODIGODEUDOR Solicitante_ShipTo,
          e4edt.CODIGODEUDOR Solicitante_SoldTo,
          v_txtYear || e4edt.PDS || e4edt.IDPROVEEDOR || v_codMes as NUM_PEDIDO,
          v_txtFechaActual FechaPedido,
          v_txtFechaActual FechaFactura, 
          e4edt.CONDICIONES_PAGO,
          '' ContratoSEPA,
          '' MotivoPedido,
          'EUR' MONEDA,
          '10' POSICION,
          CASE e4edt.SOCIEDAD
                WHEN 'ES21'          THEN 'ZES000013'
                WHEN 'ES29'          THEN 'ZES000016'
                WHEN 'PT1Q'          THEN 'ZPT000003'
                ELSE  ''
          END MATERIAL,     
          CASE e4edt.SOCIEDAD
                WHEN 'ES21'          THEN 'RETROACCIÓN COM. ENDESA ENERGÍA'
                WHEN 'ES29'          THEN 'RETROACCIÓN COM. EOSC'
                WHEN 'PT1Q'          THEN 'RETROACCIÓN COM. E. E. PORTUGAL'
                ELSE  ''
          END TEXTO_MATERIAL,
          1 CANTIDAD,
          ABS(VALUE) as PRECIO,
          CASE WHEN e4edt.TIPO_IMPOSITIVO ='IVA'          THEN '1'
                WHEN e4edt.TIPO_IMPOSITIVO ='IVA Portugal' THEN 'H'
                ELSE   ''
          END CLASIF_FISCAL_IVA,
          CASE e4edt.TIPO_IMPOSITIVO
                WHEN 'IGIC'          THEN '1'
                ELSE  ''
          END CLASIF_FISCAL_IGIC,    
          WBE_FINAL_IMPUTACION

        FROM ENEL_E4E_DEPOSIT_TEMP e4edt 
        WHERE 
            e4edt.VALUE < 0  and 
            e4edt.PERIODSEQ = iperiodseq;
               
     filas := sql%rowcount;
     COMMIT;

    
     w_debug('Fin Carga de la tabla ENEL_E4E_NEGATIVOS: '|| to_char(filas) || ' filas.', v_contador_debug);
     EXECUTE IMMEDIATE 'ANALYZE TABLE ENELEXT.ENEL_E4E_NEGATIVOS COMPUTE STATISTICS FOR ALL INDEXES';
     w_debug('Fin Actualizacion Indices ENELEXT.ENEL_E4E_NEGATIVOS.',v_contador_debug);
         
end;        
        

---------------- Se Actualiza la tabla temporal con los créditos del periodo indicado -------------
procedure p_Temporal_Creditos_Andromeda (  iprocessingUnitSeq IN VARCHAR2, iperiod IN VARCHAR2,iperiodseq IN VARCHAR2, itenantId IN VARCHAR2 )
AS
      
    
begin

    w_debug('Inicio Truncado de la tabla ENEL_ANDROMEDA_CREDIT_TEMP.', v_contador_debug);
    EXECUTE IMMEDIATE 'TRUNCATE TABLE ENELEXT.ENEL_ANDROMEDA_CREDIT_TEMP';
    w_debug('Fin Truncado de la tabla ENEL_ANDROMEDA_CREDIT_TEMP.', v_contador_debug);


    w_debug('Cargando tabla ENEL_ANDROMEDA_CREDIT_TEMP. Periodo:'|| iperiod ||' Periodseq: '||iperiodseq ||' TenantId: '||itenantId ,  v_contador_debug);
      
     INSERT INTO ENELEXT.ENEL_ANDROMEDA_CREDIT_TEMP (TENANTID, CREDITSEQ, SALESORDERSEQ, SALESTRANSACTIONSEQ, PERIODSEQ, PIPELINERUNSEQ, PIPELINERUNDATE, 
                                                        VALUE, PREADJUSTEDVALUE, GENERICATTRIBUTE1, GENERICATTRIBUTE2, GENERICATTRIBUTE4, 
                                                        GENERICATTRIBUTE9, COMMENTS, CREDITTYPEID, DESCRIPTION)   
        SELECT 
            credit.TENANTID,
            credit.CREDITSEQ,              --ID Callidus
            credit.SALESORDERSEQ,
            credit.SALESTRANSACTIONSEQ,
            credit.PERIODSEQ,                        
            credit.PIPELINERUNSEQ,
            credit.PIPELINERUNDATE,           
            credit.VALUE,                  --Importe Comision
            credit.PREADJUSTEDVALUE,       --Importe Precalculado
            credit.GENERICATTRIBUTE1,      --Concepto Liquidación
            credit.GENERICATTRIBUTE2,      --Proveedor
            credit.GENERICATTRIBUTE4,      --Prestador
            credit.GENERICATTRIBUTE9,      --Id de Tipo de Registro
            credit.COMMENTS,               --Observaciones
            ctype.CREDITTYPEID,            
            ctype.DESCRIPTION              --Subtipo de apunte
        FROM CS_CREDIT credit
        
            INNER JOIN CS_PLRUN p ON CREDIT.PIPELINERUNSEQ = P.PIPELINERUNSEQ 
                                     AND P.MODELSEQ = 0   -- Solo se tienen en cuenta las ejecuciones que no son de simulacion
                                             
            INNER JOIN CS_CREDITTYPE ctype ON credit.CREDITTYPESEQ = ctype.DATATYPESEQ 
                                                AND ctype.TENANTID = itenantId 
                                                AND ( ctype.CREDITTYPEID like ('Prestacion%') 
                                                      OR ctype.CREDITTYPEID like ('Instalacion%') ) 
                                                AND  ctype.REMOVEDATE  = v_eot
  
        WHERE
            credit.GENERICBOOLEAN1 = 1 AND  -- Indica los creditos que se incluyen en pagos
            credit.TENANTID = itenantId AND 
            credit.PROCESSINGUNITSEQ = iprocessingUnitSeq AND               
            credit.PERIODSEQ =  iperiodseq;
                
     filas := sql%rowcount;
    COMMIT;

    w_debug('Fin Carga de la tabla ENEL_ANDROMEDA_CREDIT_TEMP: '|| to_char(filas) || ' filas.', v_contador_debug);
    
    EXECUTE IMMEDIATE 'ANALYZE TABLE ENELEXT.ENEL_ANDROMEDA_CREDIT_TEMP COMPUTE STATISTICS FOR ALL INDEXES';
    w_debug('Fin Actualizacion Indices ENELEXT.ENEL_ANDROMEDA_CREDIT_TEMP.',v_contador_debug);
    
end;
   ---------------- Se Actualiza la tabla temporal con las transacciones del periodo indicado -------------
procedure p_Temporal_TXN_Andromeda (  iprocessingUnitSeq IN VARCHAR2, iperiod IN VARCHAR2,iperiodseq IN VARCHAR2, itenantId IN VARCHAR2 )
AS
      
    
begin

    w_debug('Inicio Truncado de la tabla ENEL_ANDROMEDA_TXN_TEMP.', v_contador_debug);
    EXECUTE IMMEDIATE 'TRUNCATE TABLE ENELEXT.ENEL_ANDROMEDA_TXN_TEMP';
    w_debug('Fin Truncado de la tabla ENEL_ANDROMEDA_TXN_TEMP.', v_contador_debug);


    w_debug('Cargando tabla ENEL_ANDROMEDA_TXN_TEMP. Periodo:'|| iperiod ||' Periodseq: '||iperiodseq ||' TenantId: '||itenantId ,  v_contador_debug);
    
     INSERT INTO ENELEXT.ENEL_ANDROMEDA_TXN_TEMP ( SALESTRANSACTIONSEQ, SALESORDERSEQ, ORDERID, LINENUMBER, SUBLINENUMBER,EVENTTYPEID, COMPENSATIONDATE, 
                                                    SOLICITUD_GARANTIA, DATASOURCE, ESTADO_LIQUIDACION, ESTADO_GA3 )   
        SELECT
            txn.SALESTRANSACTIONSEQ,
            txn.SALESORDERSEQ,
            ord.ORDERID,                   --Order
            txn.LINENUMBER,                -- Line
            txn.SUBLINENUMBER,             -- SubLine 
            etype.EVENTTYPEID,             -- Tipo Evento 
            txn.COMPENSATIONDATE,           
            TXN.GENERICBOOLEAN2,            -- Solicitud en Garantía (GB2)
            TXN.DATASOURCE,
            TXN.GENERICATTRIBUTE4,            -- Estado Liquidacion (para identificar Pte eliinar)
            TXN.GENERICATTRIBUTE3            -- Estado TXN GA3 (para identificar Pte Facturar)
        FROM CS_PERIOD per
            INNER JOIN CS_SALESTRANSACTION txn
                ON TXN.COMPENSATIONDATE between PER.STARTDATE and PER.ENDDATE - 1
                AND TXN.TENANTID = itenantId
                AND TXN.MODELSEQ = 0
                AND TXN.PROCESSINGUNITSEQ =iprocessingUnitSeq
            INNER JOIN CS_EVENTTYPE etype
                ON TXN.EVENTTYPESEQ = etype.DATATYPESEQ
                AND TXN.TENANTID = itenantId
                AND ETYPE.REMOVEDATE  = v_eot
            INNER JOIN CS_SALESORDER ord 
                ON TXN.SALESORDERSEQ = ORD.SALESORDERSEQ
                AND ORD.TENANTID = itenantId
                AND ORD.MODELSEQ = 0
                AND ORD.REMOVEDATE = v_eot
        WHERE PER.TENANTID =  itenantId
              AND PER.REMOVEDATE = v_eot        
              AND PER.PERIODSEQ = iperiodseq;
              
     filas := sql%rowcount;
    COMMIT;

    w_debug('Fin Carga de la tabla ENEL_ANDROMEDA_TXN_TEMP: '|| to_char(filas) || ' filas.', v_contador_debug);

    EXECUTE IMMEDIATE 'ANALYZE TABLE ENELEXT.ENEL_ANDROMEDA_TXN_TEMP COMPUTE STATISTICS FOR ALL INDEXES';
    w_debug('Fin Actualizacion Indices ENELEXT.ENEL_ANDROMEDA_TXN_TEMP.',v_contador_debug);
        
end;


procedure p_Final_Andromeda ( iperiod IN VARCHAR2,iperiodseq IN VARCHAR2, itenantId IN VARCHAR2, iInterfaz IN VARCHAR2 )
AS
    v_fechaInicioPeriodo date;
    v_txtFechaInicioPeriodo VARCHAR2(10);
    v_txtFechaLiquidacion VARCHAR2(10);
    v_Estado VARCHAR2(50);
    v_EstadoPteRevisar VARCHAR2(50);
    v_EstadoPteEliminar VARCHAR2(50);
    v_EstadoPteCarga VARCHAR2(50);
    v_EstadoPteFacturar VARCHAR2(50);
begin

    w_debug('Inicio Borrado de la tabla ENEL_ANDROMEDA_FINAL.', v_contador_debug);
   BEGIN
     LOOP
        DELETE FROM ENELEXT.ENEL_ANDROMEDA_FINAL WHERE PERIODO = iperiod AND ROWNUM <= 10000;
        EXIT WHEN SQL%ROWCOUNT = 0;
        COMMIT;
     END LOOP;
   END;
    w_debug('Fin Borrado de la tabla ENEL_ANDROMEDA_FINAL.', v_contador_debug);

    -- Se extrae la fecha inicial del periodSeq del proceso
    v_fechaInicioPeriodo :=  f_Primer_Dia_Periodo(iperiodseq);
    -- Se convierte a texto en formato DD/MM/YYYY para los registros de salida
    v_txtFechaInicioPeriodo := to_char(v_fechaInicioPeriodo, 'DD/MM/YYYY');
    -- La fecha en la que se genera el fichero de Liquidación (Mensual final) 
    v_txtFechaLiquidacion := '';
    v_Estado := 'Pte. Liquidar';
-- SI iInterfaz es 'ACTUALIZA_INFORMES_POST' se está generando el fichero definitivo de LIQUIDACION '
    --iInterfaz
    IF iInterfaz =  'ACTUALIZA_INFORMES_POST'  THEN
        v_txtFechaLiquidacion := to_char(SYSDATE, 'DD/MM/YYYY');
        v_Estado := 'Liquidado';
    ELSE
        v_txtFechaLiquidacion := '';
        v_Estado := 'Pte. Liquidar';
    END IF;
    -- Constantes de Estado
    v_EstadoPteRevisar := 'Pte. Revisar';
    v_EstadoPteEliminar := 'Pte. Eliminar';
    v_EstadoPteCarga := 'Pte. Carga';
    v_EstadoPteFacturar :='Pte. Facturar';
    

    w_debug('Carga 1: todas TXN y Creditos relacionadas de %Importebase y %Ajuste Manual de datos en tabla ENEL_ANDROMEDA_FINAL.' ,  v_contador_debug);
    
     INSERT INTO ENELEXT.ENEL_ANDROMEDA_FINAL ( Periodo, ORDERID, LINENUMBER, SUBLINENUMBER, EVENTTYPEID, TIPO_REGISTRO, TIPO_CREDITO, PERIODO_LIQUIDACION, 
    IMPORTE_COMISION, IMPORTE_PRECALCULADO, CONCEPTO_LIQUIDACION, PROVEEDOR, CREDITSEQ, FECHA_CALCULO, 
    FECHA_LIQUIDACION, ESTADO, CODIGO_COMERCIAL, OBSERVACIONES, DATASOURCE )   
        SELECT
            iperiod PERIODO,
            txntmp.ORDERID ,
            substr(to_char(txntmp.LINENUMBER, '000000000'),-9) ,   -- se pone el substr -9 para coger 9 ultimos caracteres. el to_char añade espacio en blanco
            txntmp.SUBLINENUMBER,
            txntmp.EVENTTYPEID,
            --credtmp.GENERICATTRIBUTE9 TIPO_REGISTRO,
            CASE WHEN CREDTMP.CREDITTYPEID is null THEN '' 
                 WHEN SUBSTR(CREDTMP.CREDITTYPEID,-13) = 'Ajuste Manual' THEN 'Solicitud de Servicio Manual'
                 ELSE 'Solicitud de Servicio Automática' END TIPO_REGISTRO,
            credtmp.DESCRIPTION TIPO_CREDITO,
            -- case WHEN credtmp.CREDITSEQ is null THEN  '' else iperiod end as PERIODO_LIQUIDACION, -- Se informa si existe crédito -- SOLICITAN LA FECHA DE COMPENSACION    
            to_char(txntmp.COMPENSATIONDATE, 'YYYYMMDD') as PERIODO_LIQUIDACION,     --  Periodo de liquidación : fecha de compensación de la txn en yyyymmdd (cambiado 06/09/2017)             
            --credtmp.VALUE IMPORTE_COMISION,
            TRIM(replace(to_char(credtmp.VALUE , '9999999999990D99'), ',', '.')) IMPORTE_COMISION,
            --credtmp.PREADJUSTEDVALUE IMPORTE_PRECALCULADO,
            TRIM(replace(to_char(credtmp.PREADJUSTEDVALUE, '9999999999990D99'), ',', '.')) IMPORTE_PRECALCULADO,
            credtmp.GENERICATTRIBUTE1 CONCEPTO_LIQUIDACION,
            credtmp.GENERICATTRIBUTE2 PROVEEDOR,
            credtmp.CREDITSEQ,
            --to_char(credtmp.PIPELINERUNDATE, 'DD/MM/YYYY HH24:MI:SS') FECHA_CALCULO, se cambia formato a MES/DIA/AÑO ...
            to_char(credtmp.PIPELINERUNDATE, 'MM/DD/YYYY HH24:MI:SS') FECHA_CALCULO,
            case WHEN credtmp.CREDITSEQ is null THEN  '' else v_txtFechaLiquidacion end as FECHA_LIQUIDACION, -- Se informa si existe crédito
            
            case  
                 -- Credito NO generado y  txn.GA4=Pte Elminar  -->  Pte Elminar
                 WHEN credtmp.CREDITSEQ is null and txntmp.ESTADO_LIQUIDACION = v_EstadoPteEliminar THEN   v_EstadoPteEliminar  
                 -- Credito NO generado y  txn.GA4 <> Pte Elminar  y Ajuste -->  Pte Revisar            
                 WHEN credtmp.CREDITSEQ is null and txntmp.ESTADO_LIQUIDACION <> v_EstadoPteEliminar
                                                and TXNTMP.EVENTTYPEID = 'Ajuste Manual STP'        THEN   v_EstadoPteRevisar
                 -- Credito NO generado y  txn.GA4 <> Pte Elminar  y Prestación/Instalacion y txn.GA3=Pte facturar -->  Pte Revisar                                                
                 WHEN credtmp.CREDITSEQ is null and txntmp.ESTADO_LIQUIDACION <> v_EstadoPteEliminar
                                                and txntmp.EVENTTYPEID <> 'Ajuste Manual STP'                                                
                                                and txntmp.ESTADO_GA3 = v_EstadoPteFacturar         THEN   v_EstadoPteRevisar
                 -- Credito NO generado y  txn.GA4 <> Pte Elminar  y Prestación/Instalacion y txn.GA3<>Pte facturar -->  txn.GA4
                 WHEN credtmp.CREDITSEQ is null and txntmp.ESTADO_LIQUIDACION <> v_EstadoPteEliminar
                                                and txntmp.EVENTTYPEID <> 'Ajuste Manual STP'                                                
                                                and txntmp.ESTADO_GA3 <> v_EstadoPteFacturar         THEN   txntmp.ESTADO_LIQUIDACION
                 -- Credito SI generado  Y VALOR =0 Y No es solicitud de Garantía  -->  Pte Revisar                                                
                -- WHEN credtmp.CREDITSEQ is not null and CREDTMP.VALUE=0 and TXNTMP.SOLICITUD_GARANTIA <> 1 THEN  v_EstadoPteRevisar  --v2.1 Se elimina la condicion de crédito con valor 0  genera estado Pte Revisar. 
                 -- Credito SI generado  Y Concepto Liquidación vacio  -->  Pte Revisar  
                 WHEN credtmp.CREDITSEQ is not null and CREDTMP.GENERICATTRIBUTE1 is null  THEN  v_EstadoPteRevisar  -- Concepto de Liquidación vacio
                 -- Credito SI generado  Y Proveedor nulo, vacio o con valor '000'  -->  Pte Revisar                 
                 WHEN credtmp.CREDITSEQ is not null and ( CREDTMP.GENERICATTRIBUTE2 is null OR CREDTMP.GENERICATTRIBUTE2 ='' OR CREDTMP.GENERICATTRIBUTE2 ='000' )    
                                                             THEN  v_EstadoPteRevisar
                 -- Credito SI generado OK -->  Pte Liquidar o Liquidado
                 ELSE v_Estado end as ESTADO, -- Se informa si existe crédito
            credtmp.GENERICATTRIBUTE4 CODIGO_COMERCIAL,
            credtmp.COMMENTS OBSERVACIONES,
            txntmp.DATASOURCE
        FROM ENELEXT.ENEL_ANDROMEDA_TXN_TEMP txntmp
            LEFT JOIN ENELEXT.ENEL_ANDROMEDA_CREDIT_TEMP credtmp
                ON txntmp.SALESTRANSACTIONSEQ = CREDTMP.SALESTRANSACTIONSEQ
        -- Se hace Left Join con los creditos de %Importe Base para tipos de eventos Prestacion e Instalacion 
        -- y los de %Ajuste Manual para eventos de Ajustes Manuales 
                and CREDTMP.CREDITTYPEID like CASE when TXNTMP.EVENTTYPEID ='Instalacion' THEN '%Importe Base' 
                                                when TXNTMP.EVENTTYPEID ='Prestacion'  THEN '%Importe Base'  
                                                when TXNTMP.EVENTTYPEID ='Ajuste Manual STP' THEN '%Ajuste Manual'
                                                END;                

                
     filas := sql%rowcount;
    COMMIT;
    
    w_debug('Fin Carga 1 en tabla ENEL_ANDROMEDA_FINAL: '|| to_char(filas) || ' filas.', v_contador_debug);
    
    w_debug('Carga 2: TXN de prestación e instalación que hayan generado otros Creditos que no sean %Importebase en tabla ENEL_ANDROMEDA_FINAL.' ,  v_contador_debug);
    
     INSERT INTO ENELEXT.ENEL_ANDROMEDA_FINAL ( Periodo, ORDERID, LINENUMBER, SUBLINENUMBER, EVENTTYPEID, TIPO_REGISTRO, TIPO_CREDITO, PERIODO_LIQUIDACION, 
    IMPORTE_COMISION, IMPORTE_PRECALCULADO, CONCEPTO_LIQUIDACION, PROVEEDOR, CREDITSEQ, FECHA_CALCULO, 
    FECHA_LIQUIDACION, ESTADO, CODIGO_COMERCIAL, OBSERVACIONES, DATASOURCE )   
        SELECT
            iperiod PERIODO,
            txntmp.ORDERID ,
            substr(to_char(txntmp.LINENUMBER, '000000000'),-9) ,   -- se pone el substr -9 para coger 9 ultimos caracteres. el to_char añade espacio en blanco
            txntmp.SUBLINENUMBER,
            txntmp.EVENTTYPEID,
            --credtmp.GENERICATTRIBUTE9 TIPO_REGISTRO,
            CASE WHEN CREDTMP.CREDITTYPEID is null THEN '' 
                 WHEN SUBSTR(CREDTMP.CREDITTYPEID,-13) = 'Ajuste Manual' THEN 'Solicitud de Servicio Manual'
                 ELSE 'Solicitud de Servicio Automática' END TIPO_REGISTRO,
            credtmp.DESCRIPTION TIPO_CREDITO,
            -- case WHEN credtmp.CREDITSEQ is null THEN  '' else iperiod end as PERIODO_LIQUIDACION, -- Se informa si existe crédito -- SOLICITAN LA FECHA DE COMPENSACION    
            to_char(txntmp.COMPENSATIONDATE, 'YYYYMMDD') as PERIODO_LIQUIDACION,     --  Periodo de liquidación : fecha de compensación de la txn en yyyymmdd (cambiado 06/09/2017)             
            --credtmp.VALUE IMPORTE_COMISION,
            TRIM(replace(to_char(credtmp.VALUE , '9999999999990D99'), ',', '.')) IMPORTE_COMISION,
            --credtmp.PREADJUSTEDVALUE IMPORTE_PRECALCULADO,
            TRIM(replace(to_char(credtmp.PREADJUSTEDVALUE, '9999999999990D99'), ',', '.')) IMPORTE_PRECALCULADO,
            credtmp.GENERICATTRIBUTE1 CONCEPTO_LIQUIDACION,
            credtmp.GENERICATTRIBUTE2 PROVEEDOR,
            credtmp.CREDITSEQ,
            --to_char(credtmp.PIPELINERUNDATE, 'DD/MM/YYYY HH24:MI:SS') FECHA_CALCULO, se cambia formato a MES/DIA/AÑO ...
            to_char(credtmp.PIPELINERUNDATE, 'MM/DD/YYYY HH24:MI:SS') FECHA_CALCULO,
            case WHEN credtmp.CREDITSEQ is null THEN  '' else v_txtFechaLiquidacion end as FECHA_LIQUIDACION, -- Se informa si existe crédito
            
            case  
                 -- Credito NO generado y  txn.GA4=Pte Elminar  -->  Pte Elminar
                 WHEN credtmp.CREDITSEQ is null and txntmp.ESTADO_LIQUIDACION = v_EstadoPteEliminar THEN   v_EstadoPteEliminar  
                 -- Credito NO generado y  txn.GA4 <> Pte Elminar  y Ajuste -->  Pte Revisar            
                 WHEN credtmp.CREDITSEQ is null and txntmp.ESTADO_LIQUIDACION <> v_EstadoPteEliminar
                                                and TXNTMP.EVENTTYPEID = 'Ajuste Manual STP'        THEN   v_EstadoPteRevisar
                 -- Credito NO generado y  txn.GA4 <> Pte Elminar  y Prestación/Instalacion y txn.GA3=Pte facturar -->  Pte Revisar                                                
                 WHEN credtmp.CREDITSEQ is null and txntmp.ESTADO_LIQUIDACION <> v_EstadoPteEliminar
                                                and txntmp.EVENTTYPEID <> 'Ajuste Manual STP'                                                
                                                and txntmp.ESTADO_GA3 = v_EstadoPteFacturar         THEN   v_EstadoPteRevisar
                 -- Credito NO generado y  txn.GA4 <> Pte Elminar  y Prestación/Instalacion y txn.GA3<>Pte facturar -->  txn.GA4
                 WHEN credtmp.CREDITSEQ is null and txntmp.ESTADO_LIQUIDACION <> v_EstadoPteEliminar
                                                and txntmp.EVENTTYPEID <> 'Ajuste Manual STP'                                                
                                                and txntmp.ESTADO_GA3 <> v_EstadoPteFacturar         THEN   txntmp.ESTADO_LIQUIDACION
                 -- Credito SI generado  Y VALOR =0 Y No es solicitud de Garantía  -->  Pte Revisar                                                
                 WHEN credtmp.CREDITSEQ is not null and CREDTMP.VALUE=0 and TXNTMP.SOLICITUD_GARANTIA <> 1 THEN  v_EstadoPteRevisar
                 -- Credito SI generado  Y Concepto Liquidación vacio  -->  Pte Revisar  
                 WHEN credtmp.CREDITSEQ is not null and CREDTMP.GENERICATTRIBUTE1 is null  THEN  v_EstadoPteRevisar  -- Concepto de Liquidación vacio
                 -- Credito SI generado  Y Proveedor nulo, vacio o con valor '000'  -->  Pte Revisar                 
                 WHEN credtmp.CREDITSEQ is not null and ( CREDTMP.GENERICATTRIBUTE2 is null OR CREDTMP.GENERICATTRIBUTE2 ='' OR CREDTMP.GENERICATTRIBUTE2 ='000' )    
                                                             THEN  v_EstadoPteRevisar
                 -- Credito SI generado OK -->  Pte Liquidar o Liquidado
                 ELSE v_Estado end as ESTADO, -- Se informa si existe crédito
            credtmp.GENERICATTRIBUTE4 CODIGO_COMERCIAL,
            credtmp.COMMENTS OBSERVACIONES,
            txntmp.DATASOURCE
        FROM ENELEXT.ENEL_ANDROMEDA_TXN_TEMP txntmp
            INNER JOIN ENELEXT.ENEL_ANDROMEDA_CREDIT_TEMP credtmp
                ON txntmp.SALESTRANSACTIONSEQ = CREDTMP.SALESTRANSACTIONSEQ
                and TXNTMP.EVENTTYPEID in ( 'Prestacion', 'Instalacion')
                and CREDTMP.CREDITTYPEID not like '%Importe Base';     
                
     filas := sql%rowcount;
    COMMIT;
    
    w_debug('Fin Carga 2 en tabla ENEL_ANDROMEDA_FINAL: '|| to_char(filas) || ' filas.', v_contador_debug);    

 
    w_debug('Actualizacion ENEL_ANDROMEDA_FINAL: Se actualizan como Pte Revisar aquellas TXNs que no sean de Importe Base cuyas relacionadas de Importe Base están en Pte Revisar' ,  v_contador_debug);

     UPDATE ENEL_ANDROMEDA_FINAL EAF1 
     SET EAF1.ESTADO = v_EstadoPteRevisar
     WHERE EAF1.EVENTTYPEID in ( 'Prestacion', 'Instalacion')
     AND EAF1.ESTADO <> v_EstadoPteRevisar
     AND EAF1.PERIODO = iperiod
     AND EAF1.TIPO_CREDITO <> 'Importe Base'
     AND EXISTS (select 1 FROM ENEL_ANDROMEDA_FINAL EAF2
                 WHERE EAF2.EVENTTYPEID in ( 'Prestacion', 'Instalacion') 
                     AND EAF2.ESTADO = v_EstadoPteRevisar
                     AND EAF2.PERIODO = iperiod 
                     AND EAF2.ORDERID = EAF1.ORDERID
                     AND EAF2.LINENUMBER = EAF1.LINENUMBER
                     AND EAF2.SUBLINENUMBER = EAF1.SUBLINENUMBER
                );

     filas := sql%rowcount;
    COMMIT;
       
    w_debug('Fin Actualizacion ENEL_ANDROMEDA_FINAL: '|| to_char(filas) || ' filas.', v_contador_debug);

    EXECUTE IMMEDIATE 'ANALYZE TABLE ENELEXT.ENEL_ANDROMEDA_FINAL COMPUTE STATISTICS FOR ALL INDEXES';
    w_debug('Fin Actualizacion Indices ENELEXT.ENEL_ANDROMEDA_FINAL.',v_contador_debug);
    
end;

   ---------------- Se Actualiza la tabla para el informe de SCAWEB para el periodo indicado -------------
procedure p_Temporal_Creditos_Scaweb (  iprocessingUnitSeq IN VARCHAR2,  iperiod IN VARCHAR2,iperiodseq IN VARCHAR2, itenantId IN VARCHAR2 )
AS
    vFechaAlta Date;
    v_fecInicioPeriodoSig date;

begin
    w_debug('Inicio Borrado de la tabla ENEL_SCAWEB_LIQUIDACION.', v_contador_debug);
   BEGIN
     LOOP
        DELETE FROM ENELEXT.ENEL_SCAWEB_LIQUIDACION WHERE PERIODO = iperiod AND ROWNUM <= 10000;
        EXIT WHEN SQL%ROWCOUNT = 0;
        COMMIT;
     END LOOP;
   END;
    w_debug('Fin Borrado de la tabla ENEL_SCAWEB_LIQUIDACION.', v_contador_debug);
    
    -- Fecha de Alta se corresponde con la fecha de sistema
    vFechaAlta := SYSDATE;
    
    -- Se extrae la fecha inicial del siguiente mes al periodSeq del proceso
    v_fecInicioPeriodoSig :=  f_Primer_Dia_Periodo_Siguiente(iperiodseq);
    
        
    w_debug('Insertando CREDITOS de datos en tabla ENEL_SCAWEB_LIQUIDACION.' ,  v_contador_debug);
    -- v2.0 Se cambia la tabla de origen CS_CREDIT  a la temporal ENEL_CREDIT_TEMP
     INSERT INTO ENELEXT.ENEL_SCAWEB_LIQUIDACION ( PERIODO, PROVEEDOR, ANO_LIQUIDACION, MES_LIQUIDACION, CODIGO_AGENTE_INTERNO, CONCEPTO, CANTIDAD, 
                                                    IMPORTE, FECHA_ALTA, FECHA_BAJA, TELEFONO, OBSERVACIONES, CODIGO_POSTAL, PROVINCIA, REALVALUE )   
        SELECT 
            iperiod PERIODO,        
            --credit.GENERICATTRIBUTE2,      -- Proveedor,
            --to_number(credtmp.GENERICATTRIBUTE2),   -- Proveedor en formato numerico, sin ceros a la izquierda
            to_number(REPLACE(credtmp.GENERICATTRIBUTE2, ' integer','')) PROVEEDOR,             
            --to_char(credit.COMPENSATIONDATE, 'YYYY'),
            to_char(v_fecInicioPeriodoSig, 'YYYY'),  -- Año del periodo sigiente
            --to_char(credit.COMPENSATIONDATE, 'MM'),
            to_char(v_fecInicioPeriodoSig, 'MM'),  -- Mes del periodo sigiente
            credtmp.GENERICATTRIBUTE4,      -- Prestador - PDS
            credtmp.GENERICATTRIBUTE1,      -- Concepto Liquidación
            1 as CANTIDAD,
            --credit.VALUE,                  --Importe Comision
            ABS(credtmp.VALUE),                  --Importe Comision 2017-09-28 - se pasa el valor absoluto del credito
            to_char(vFechaAlta, 'YYYYMMDD') as FechaAlta,
            '' as FechaBaja,
            '' as Telefono,
            --credtmp.GENERICATTRIBUTE9 as Observaciones,      -- Solicitud de servicio
            -- En ajustes Manuales se pone el campo Observaciones credit.GA15
            case when credtmp.CREDITTYPEID like '%Ajuste%' then credtmp.GENERICATTRIBUTE15 else credtmp.GENERICATTRIBUTE9 end as Observaciones,
            credtmp.GENERICATTRIBUTE11,       --Codigo Postal
            credtmp.GENERICATTRIBUTE6,       --Provincia
            credtmp.VALUE  as REALVALUE      -- Valor real sin tomar el valor absoluto para informe de revisión  
        FROM ENEL_CREDIT_TEMP credtmp

           INNER JOIN ENEL_PDS_TEMP TMP_PDS     -- Se hace JOIN CON PDS para poder filtar los de TIPO OCAP y Proveedor 050 que no se deben incluir
              ON credtmp.POSITIONSEQ=TMP_PDS.RULEELEMENTOWNERSEQ
                      
        WHERE 
            credtmp.GENERICBOOLEAN1 = 1 AND  -- Indica los creditos que se incluyen en pagos
            credtmp.GENERICATTRIBUTE1 is not null AND -- Solo se  incluyen los créditos con Concepto de Liquidación que no son vacios (nulos)
            NOT ( credtmp.GENERICATTRIBUTE2 ='050' AND TMP_PDS.TIPO_POSICION ='OCAP') AND  -- No se incluyen Creditos de OCAPS y proveedor 050
            ( credtmp.CREDITTYPEID like 'Prestacion%' 
              OR credtmp.CREDITTYPEID like 'Instalacion%'
              OR credtmp.CREDITTYPEID like 'Captacion%'
              OR credtmp.CREDITTYPEID like 'ATC - Ajuste Manual' );  -- De atención solo los ajustes Manuales (para que no salgan todo el detalle de operaciones)
     filas := sql%rowcount;
    COMMIT;

    
    w_debug('Fin Carga CREDITOS de la tabla ENEL_SCAWEB_LIQUIDACION: '|| to_char(filas) || ' filas.', v_contador_debug);

    w_debug('Insertando INCENTIVOS de datos en tabla ENEL_SCAWEB_LIQUIDACION.' ,  v_contador_debug);

     INSERT INTO ENELEXT.ENEL_SCAWEB_LIQUIDACION ( PERIODO, PROVEEDOR, ANO_LIQUIDACION, MES_LIQUIDACION, CODIGO_AGENTE_INTERNO, CONCEPTO, CANTIDAD, 
                                                    IMPORTE, FECHA_ALTA, FECHA_BAJA, TELEFONO, OBSERVACIONES, CODIGO_POSTAL, PROVINCIA, REALVALUE )   
        SELECT 
            iperiod PERIODO,        
            to_number(incentmp.GENERICATTRIBUTE2),   -- Proveedor en formato numerico, sin ceros a la izquierda             
            to_char(v_fecInicioPeriodoSig, 'YYYY'),  -- Año del periodo sigiente
            to_char(v_fecInicioPeriodoSig, 'MM'),  -- Mes del periodo sigiente
            TMP_PDS.PDS ,      -- Prestador - PDS
            incentmp.GENERICATTRIBUTE1,      -- Concepto Liquidación
            1 as CANTIDAD,
            ABS(incentmp.VALUE),
            to_char(vFechaAlta, 'YYYYMMDD') as FechaAlta,
            '' as FechaBaja,
            '' as Telefono,
             Replace(incentmp.GENERICATTRIBUTE4, 'integer', '') as Observaciones, 
            ''  as Codigo_Postal,       --Codigo Postal
            ''  as Provincia,     --Provincia
            incentmp.VALUE  as REALVALUE      -- Valor real sin tomar el valor absoluto para informe de revisión
            
        FROM ENEL_INCEN_TEMP incentmp
        
        INNER JOIN ENEL_PDS_TEMP TMP_PDS
              ON incentmp.POSITIONSEQ=TMP_PDS.RULEELEMENTOWNERSEQ
             
        WHERE
            incentmp.GENERICBOOLEAN1 = 1 AND  -- Indica los Incentivos que se incluyen en pagos
            incentmp.GENERICATTRIBUTE1 is not null AND -- Solo se  incluyen los créditos con Concepto de Liquidación que no son vacios (nulos)  
            incentmp.VALUE <> 0 AND -- Se filtran los incentivos que sean distintos de 0      
            NOT ( incentmp.GENERICATTRIBUTE2 ='050' AND TMP_PDS.TIPO_POSICION ='OCAP') AND  -- No se incluyen Creditos de OCAPS y proveedor 050            
            ( incentmp.NAME like 'I - Captacion - %'  OR 
              incentmp.NAME = 'I - ATC - Remun Comercial PDS' );

     filas := sql%rowcount;
    COMMIT;

    
    w_debug('Fin Carga INCENTIVOS de la tabla ENEL_SCAWEB_LIQUIDACION: '|| to_char(filas) || ' filas.', v_contador_debug);
    
    EXECUTE IMMEDIATE 'ANALYZE TABLE ENELEXT.ENEL_SCAWEB_LIQUIDACION COMPUTE STATISTICS FOR ALL INDEXES';
    w_debug('Fin Actualizacion Indices ENELEXT.ENEL_SCAWEB_LIQUIDACION.',v_contador_debug);
    
end;

procedure p_Temporal_TXN_INFPDS ( iprocessingUnitSeq IN VARCHAR2, iperiod IN VARCHAR2,iperiodseq IN VARCHAR2, itenantId IN VARCHAR2 )
AS

begin

    w_debug('Inicio Borrado de la tabla ENEL_INFPDS_TXN_TEMP.', v_contador_debug);
    EXECUTE IMMEDIATE 'TRUNCATE TABLE ENELEXT.ENEL_INFPDS_TXN_TEMP';
    w_debug('Fin Borrado de la tabla ENEL_INFPDS_TXN_TEMP.', v_contador_debug);
    
    w_debug('Insertando Registros de datos en tabla ENEL_INFPDS_TXN_TEMP.' ,  v_contador_debug);
    
    w_debug('Parámetros iprocessingUnitSeq:' || iprocessingUnitSeq || ' iperiodseq: ' || iperiodseq  ,  v_contador_debug);
    
    
     INSERT INTO ENELEXT.ENEL_INFPDS_TXN_TEMP ( TENANTID, PERIODSEQ, PERIODO, SALESORDERSEQ, SALESTRANSACTIONSEQ, LINENUMBER, SUBLINENUMBER, EVENTYPEID, COMPENSATIONDATE, 
                                                    PDS, Solicitud_Servicio, Contrato, Calle, Municipio, Provincia, CODIGO_POSTAL, Producto, Tipo_Servicio, 
                                                    Nombre_Servicio, ESTADO_GA3, Estado_Liquidacion, SS_Garantia, Motivo_Resultado, IDMARCA, IDMODELO, Modalidad_Pago, Calidad_Tecnica_Gas, 
                                                    Calidad_Tecnica_Luz, FechaHoraApertura, FechaMaximaInicial, FechaMaxima, FechaPrevista, FechaInicioTrabajos, 
                                                    FechaFinTrabajos, FechaSolicitadaCliente, FechaValidacion, DATASOURCE )   
/* 
   SELECT
        itenantId TENANTID,
        iperiodseq PERIODSEQ,
        iperiod PERIODO,
        TXN.SALESORDERSEQ,
        TXN.SALESTRANSACTIONSEQ,
        TXN.LINENUMBER,
        TXN.SUBLINENUMBER,
        ETYPE.EVENTTYPEID,
        TXN.COMPENSATIONDATE,
        TXNASS.POSITIONNAME,
        ordtxn.orderid as S_S, 
        TXN.PONUMBER AS Contrato,
        TXNADD.ADDRESS1 AS Calle ,   
        TXNADD.CITY  AS Municipio ,
        TXNADD.STATE AS Provincia ,
        TXNADD.POSTALCODE as Código_Postal,
        TXN.PRODUCTID as Producto,
        TXN.GENERICATTRIBUTE1 as Tipo_Servicio,
        TXN.GENERICATTRIBUTE2 as Nombre_Servicio,
        TXN.GENERICATTRIBUTE3 as Estado_GA3,        
        TXN.GENERICATTRIBUTE4 as Estado_Liquidacion,
        TXN.GENERICBOOLEAN2 as SS_Garantia,
        TXN.GENERICATTRIBUTE5 As Motivo_Resultado,
        TXN.GENERICATTRIBUTE8 As IDMARCA,
        TXN.GENERICATTRIBUTE9 As IDMODELO,
        TXN.GENERICATTRIBUTE7 || ' ' || TXN.GENERICATTRIBUTE12 as Modalidad_Pago,
        TXNASS.GENERICNUMBER1 as Calidad_Tecnica_Gas,
        TXNASS.GENERICNUMBER2 as Calidad_Tecnica_Luz,
        etxn0.GENERICATTRIBUTE10 as FechaHora_Apertura,
 --       etxn0.GENERICATTRIBUTE4  as FechaMaximaInicial,
        CASE WHEN INSTR (etxn0.GENERICATTRIBUTE4,'/') = 3 THEN etxn0.GENERICATTRIBUTE4 
                        ELSE to_char(to_date( etxn0.GENERICATTRIBUTE4,'YYYYMMDDHH24MISS'), 'DD/MM/YYYY HH24:MI:SS') END FechaMaximaInicial,        
        etxn0.GENERICATTRIBUTE6 as FechaMaxima,
        etxn0.GENERICATTRIBUTE11 as FechaPrevista,
        etxn0.GENERICATTRIBUTE7 as InicioTrabajos,
        etxn0.GENERICATTRIBUTE8 as FinTrabajos,
        etxn0.GENERICATTRIBUTE9 as FechaSolicitdaCliente,
 --       etxn0.GENERICATTRIBUTE5 as Fecha_Validacion
        CASE WHEN INSTR (etxn0.GENERICATTRIBUTE5,'/') = 3 THEN etxn0.GENERICATTRIBUTE5 
                        ELSE to_char(to_date( etxn0.GENERICATTRIBUTE5,'YYYYMMDDHH24MISS'), 'DD/MM/YYYY HH24:MI:SS') END Fecha_Validacion,
        TXN.DATASOURCE 
    FROM CS_PERIOD per    
    INNER JOIN CS_SALESTRANSACTION txn
        ON TXN.COMPENSATIONDATE between PER.STARTDATE and PER.ENDDATE - 1
        AND TXN.TENANTID = itenantId
        AND TXN.MODELSEQ = 0
        AND TXN.PROCESSINGUNITSEQ = iprocessingUnitSeq
        AND PER.REMOVEDATE = v_eot
    INNER JOIN CS_SALESORDER ordtxn
        on TXN.SALESORDERSEQ = ORDTXN.SALESORDERSEQ
        and ORDTXN.REMOVEDATE = v_eot
        AND ORDTXN.PROCESSINGUNITSEQ = iprocessingUnitSeq
    INNER JOIN CS_EVENTTYPE etype
                ON TXN.EVENTTYPESEQ = etype.DATATYPESEQ
                AND ETYPE.REMOVEDATE  = v_eot
   -- INNER JOIN CS_GASALESTRANSACTION etxn0
    LEFT JOIN CS_GASALESTRANSACTION etxn0   
                ON txn.SALESTRANSACTIONSEQ = etxn0.SALESTRANSACTIONSEQ
                AND etxn0.PAGENUMBER = 0
    --INNER JOIN CS_TRANSACTIONADDRESS txnadd
    LEFT JOIN CS_TRANSACTIONADDRESS txnadd 
                ON txn.SALESTRANSACTIONSEQ  = TXNADD.SALESTRANSACTIONSEQ
    INNER JOIN  CS_ADDRESSTYPE addtype
                ON TXNADD.ADDRESSTYPESEQ = ADDTYPE.ADDRESSTYPESEQ
                AND ADDTYPE.ADDRESSTYPEID ='BILLTO'                
    --INNER JOIN CS_TRANSACTIONASSIGNMENT txnass 
    LEFT JOIN CS_TRANSACTIONASSIGNMENT txnass
                ON txn.SALESTRANSACTIONSEQ  = txnass.SALESTRANSACTIONSEQ   
    WHERE  PER.TENANTID =  itenantId
          AND TXN.GENERICATTRIBUTE3 <> 'Anulada'
          AND PER.PERIODSEQ = iperiodseq;
*/


SELECT 
       TXN.TENANTID,
       TXN.PERIODSEQ,
       TXN.PERIODO,
        TXN.SALESORDERSEQ,
        TXN.SALESTRANSACTIONSEQ,
        TXN.LINENUMBER,
        TXN.SUBLINENUMBER,
        TXN.EVENTYPEID,
        TXN.COMPENSATIONDATE,
        TXN.TAS_POSITIONNAME,
        TXN.ORDERID as S_S,
        TXN.PONUMBER AS Contrato,
        TXN.TAD_ADDRESS1 AS Calle ,
        TXN.TAD_CITY AS Municipio ,
        TXN.TAD_STATE AS Provincia ,
        TXN.TAD_POSTALCODE as Código_Postal,
        TXN.PRODUCTID as Producto,
        TXN.GENERICATTRIBUTE1 as Tipo_Servicio,
        TXN.GENERICATTRIBUTE2 as Nombre_Servicio,
        TXN.GENERICATTRIBUTE3 as Estado_GA3,        
        TXN.GENERICATTRIBUTE4 as Estado_Liquidacion,
        TXN.GENERICBOOLEAN2 as SS_Garantia,
        TXN.GENERICATTRIBUTE5 As Motivo_Resultado,
        TXN.GENERICATTRIBUTE8 As IDMARCA,
        TXN.GENERICATTRIBUTE9 As IDMODELO,
        TXN.GENERICATTRIBUTE7 || ' ' || TXN.GENERICATTRIBUTE12 as Modalidad_Pago,
        TXN.TAS_GENERICNUMBER1 as Calidad_Tecnica_Gas,
        TXN.TAS_GENERICNUMBER2 as Calidad_Tecnica_Luz,
        TXN.TEX0_GENERICATTRIBUTE10 as FechaHora_Apertura,
        
 --       etxn0.GENERICATTRIBUTE4  as FechaMaximaInicial,
        CASE WHEN INSTR (TXN.TEX0_GENERICATTRIBUTE4,'/') = 3 THEN TXN.TEX0_GENERICATTRIBUTE4 
                        ELSE to_char(to_date( TXN.TEX0_GENERICATTRIBUTE4,'YYYYMMDDHH24MISS'), 'DD/MM/YYYY HH24:MI:SS') END FechaMaximaInicial,        
        TXN.TEX0_GENERICATTRIBUTE6 as FechaMaxima,
        TXN.TEX0_GENERICATTRIBUTE11 as FechaPrevista,
        TXN.TEX0_GENERICATTRIBUTE7 as InicioTrabajos,
        TXN.TEX0_GENERICATTRIBUTE8 as FinTrabajos,
        TXN.TEX0_GENERICATTRIBUTE9 as FechaSolicitdaCliente,
 --       etxn0.GENERICATTRIBUTE5 as Fecha_Validacion
        CASE WHEN INSTR (TXN.TEX0_GENERICATTRIBUTE5,'/') = 3 THEN TXN.TEX0_GENERICATTRIBUTE5
                        ELSE to_char(to_date( TXN.TEX0_GENERICATTRIBUTE5,'YYYYMMDDHH24MISS'), 'DD/MM/YYYY HH24:MI:SS') END Fecha_Validacion,
        TXN.DATASOURCE 
    FROM ENEL_TXN_TEMP   TXN       
    WHERE  TXN.TENANTID =  itenantId
          AND TXN.GENERICATTRIBUTE3 <> 'Anulada'
          AND TXN.PERIODSEQ = iperiodseq;


    filas := sql%rowcount;
    COMMIT;

    
    w_debug('Fin Carga de la tabla ENEL_INFPDS_TXN_TEMP: '|| to_char(filas) || ' filas.', v_contador_debug);

    EXECUTE IMMEDIATE 'ANALYZE TABLE ENELEXT.ENEL_INFPDS_TXN_TEMP COMPUTE STATISTICS FOR ALL INDEXES';
    w_debug('Fin Actualizacion Indices ENELEXT.ENEL_INFPDS_TXN_TEMP.',v_contador_debug);
        
end;


procedure p_Temporal_Creditos_INFPDS ( iprocessingUnitSeq IN VARCHAR2, iperiod IN VARCHAR2,iperiodseq IN VARCHAR2, itenantId IN VARCHAR2 )
AS

begin

    w_debug('Inicio Borrado de la tabla ENEL_INFPDS_CREDIT_TEMP.', v_contador_debug);
    EXECUTE IMMEDIATE 'TRUNCATE TABLE ENELEXT.ENEL_INFPDS_CREDIT_TEMP';
    w_debug('Fin Borrado de la tabla ENEL_INFPDS_CREDIT_TEMP.', v_contador_debug);
    
    w_debug('Insertando Registros de datos en tabla ENEL_INFPDS_CREDIT_TEMP.' ,  v_contador_debug);
    
    w_debug('Parámetros iprocessingUnitSeq:' || iprocessingUnitSeq || ' iperiodseq: ' || iperiodseq  ,  v_contador_debug);
    
     INSERT INTO ENELEXT.ENEL_INFPDS_CREDIT_TEMP ( TENANTID, PERIODSEQ, PERIODO, PIPELINERUNSEQ, PIPELINERUNDATE, NAME, CREDITSEQ, SALESORDERSEQ,
                                                    SALESTRANSACTIONSEQ, CREDITTYPEID, PLAZO, IMPORTE_COMISION, PREADJUSTEDVALUE, SOLICITUD_SERVICIO, 
                                                    EQUIPAMIENTO, MODALIDAD_PAGO, SS_GARANTIA, TIPO_COMISION, CONCEPTO_LIQUIDACION, PDS, 
                                                    PROVEEDOR, SERVICIO, PROVINCIA, ZONA, PRODUCTO, CODIGO_POSTAL, MOTIVO_RESULTADO, 
                                                    FECHA_CALCULO, INCLUIR_EN_PAGOS )   
/*    SELECT
            credit.TENANTID,
            credit.PERIODSEQ,
            iperiod PERIODO,
            credit.PIPELINERUNSEQ,
            credit.PIPELINERUNDATE,
            credit.NAME,
            CREDIT.CREDITSEQ,
            CREDIT.SALESORDERSEQ,        
            CREDIT.SALESTRANSACTIONSEQ,
            CTYPE.CREDITTYPEID,           
            credit.GENERICATTRIBUTE5,      -- Plazo  
            credit.VALUE,                  --Importe Comision
            credit.PREADJUSTEDVALUE,
            credit.GENERICATTRIBUTE9,      -- Solicitud de servicio
            credit.GENERICATTRIBUTE10,     -- Equipamiento            
            credit.GENERICATTRIBUTE12,     -- Modalidad de Pago            
            credit.GENERICBOOLEAN2,        -- S/S Garantía
            CTYPE.DESCRIPTION,             -- Tipo de Comisión
            credit.GENERICATTRIBUTE1,      -- Concepto Liquidación            
            credit.GENERICATTRIBUTE4,      -- Prestador - PDS
            credit.GENERICATTRIBUTE2,      -- Proveedor
            credit.GENERICATTRIBUTE3,      -- Servicio
            credit.GENERICATTRIBUTE6,      -- Provincia
            credit.GENERICATTRIBUTE7,      -- Zona
            credit.GENERICATTRIBUTE8,      -- Producto
            credit.GENERICATTRIBUTE11,     -- CodigoPostal
            credit.GENERICATTRIBUTE13,     --MotivoResultado
            credit.GENERICDATE1,           --FechaCalculo
            credit.GENERICBOOLEAN1         --Incluir_En_Pagos     
        
        FROM CS_CREDIT credit
        
            INNER JOIN CS_PLRUN p ON CREDIT.PIPELINERUNSEQ = P.PIPELINERUNSEQ 
                                     AND P.MODELSEQ = 0   -- Solo se tienen en cuenta las ejecuciones que no son de simulacion
                                             
            INNER JOIN CS_CREDITTYPE ctype ON credit.CREDITTYPESEQ = ctype.DATATYPESEQ 
                                                AND ctype.TENANTID = itenantId
                                                AND ( ctype.CREDITTYPEID like ('Prestacion%') 
                                                      OR ctype.CREDITTYPEID like ('Instalacion%') ) 
                                                AND  ctype.REMOVEDATE  = v_eot
        WHERE
            credit.TENANTID = itenantId 
            AND credit.PROCESSINGUNITSEQ = iprocessingUnitSeq 
            AND credit.GENERICBOOLEAN1 = 1   -- Indica los creditos que se incluyen en pagos
            --credit.GENERICATTRIBUTE1 is not null AND -- Solo se  incluyen los créditos con Concepto de Liquidación que no son vacios (nulos)            
            AND credit.PERIODSEQ =  iperiodseq; 
*/

            SELECT
            credittemp.TENANTID,
            credittemp.PERIODSEQ,
            credittemp.PERIODO,
            credittemp.PIPELINERUNSEQ,
            credittemp.PIPELINERUNDATE,
            credittemp.NAME,
            credittemp.CREDITSEQ,
            credittemp.SALESORDERSEQ,        
            credittemp.SALESTRANSACTIONSEQ,
            credittemp.CREDITTYPEID,           
            credittemp.GENERICATTRIBUTE5,      -- Plazo  
            credittemp.VALUE,                  --Importe Comision
            credittemp.PREADJUSTEDVALUE,
            credittemp.GENERICATTRIBUTE9,      -- Solicitud de servicio
            credittemp.GENERICATTRIBUTE10,     -- Equipamiento            
            credittemp.GENERICATTRIBUTE12,     -- Modalidad de Pago            
            credittemp.GENERICBOOLEAN2,        -- S/S Garantía
            CREDITTEMP.CREDITTYPEDESCRIPT,             -- Tipo de Comisión
            credittemp.GENERICATTRIBUTE1,      -- Concepto Liquidación            
            credittemp.GENERICATTRIBUTE4,      -- Prestador - PDS
            credittemp.GENERICATTRIBUTE2,      -- Proveedor
            credittemp.GENERICATTRIBUTE3,      -- Servicio
            credittemp.GENERICATTRIBUTE6,      -- Provincia
            credittemp.GENERICATTRIBUTE7,      -- Zona
            credittemp.GENERICATTRIBUTE8,      -- Producto
            credittemp.GENERICATTRIBUTE11,     -- CodigoPostal
            credittemp.GENERICATTRIBUTE13,     --MotivoResultado
            credittemp.GENERICDATE1,           --FechaCalculo
            credittemp.GENERICBOOLEAN1         --Incluir_En_Pagos    
            
            from ENEL_CREDIT_TEMP credittemp
            WHERE credittemp.GENERICBOOLEAN1 = 1   -- Indica los creditos que se incluyen en pagos
            --credit.GENERICATTRIBUTE1 is not null AND -- Solo se  incluyen los créditos con Concepto de Liquidación que no son vacios (nulos)            
            AND credittemp.PERIODSEQ =  iperiodseq
            AND ( CREDITTEMP.CREDITTYPEID like ('Prestacion%') 
                   OR CREDITTEMP.CREDITTYPEID like ('Instalacion%') ) ;

    filas := sql%rowcount;
    COMMIT;

    
    w_debug('Fin Carga de la tabla ENEL_INFPDS_CREDIT_TEMP: '|| to_char(filas) || ' filas.', v_contador_debug);

    EXECUTE IMMEDIATE 'ANALYZE TABLE ENELEXT.ENEL_INFPDS_CREDIT_TEMP COMPUTE STATISTICS FOR ALL INDEXES';
    w_debug('Fin Actualizacion Indices ENELEXT.ENEL_INFPDS_CREDIT_TEMP.',v_contador_debug);
        
end;    


-- INFORME Factura OCAP : ENEL_FACTOPE_DETALLE
procedure p_Inf_Factura_Ocap_Detalle ( iprocessingUnitSeq IN VARCHAR2, iperiod IN VARCHAR2,iperiodseq IN VARCHAR2, itenantId IN VARCHAR2 )
AS

begin

    w_debug('Inicio Borrado de la tabla ENEL_FACTOPE_DETALLE.', v_contador_debug);
    EXECUTE IMMEDIATE 'TRUNCATE TABLE ENELEXT.ENEL_FACTOPE_DETALLE';
    w_debug('Fin Borrado de la tabla ENEL_FACTOPE_DETALLE.', v_contador_debug);
   
    w_debug('Insertando Registros de datos en tabla ENEL_FACTOPE_DETALLE.' ,  v_contador_debug);
    
    w_debug('Parámetros iprocessingUnitSeq:' || iprocessingUnitSeq || ' iperiodseq: ' || iperiodseq  ,  v_contador_debug);
    
    INSERT INTO ENELEXT.ENEL_FACTOPE_DETALLE (PERIODO, PERIODSEQ, MES_PERIODO, CREDITSEQ, CREDITTYPEID,PAYEESEQ, POSITIONSEQ, OCAP_PDS, NOMBRE_FISCAL, PROVINCIA,
                                                POBLACION, TIPO_IMPOSITIVO, IDPROVEEDOR, DESCRIPCION, NAME, IMPORTE, CONCEPTO_LIQUIDACION, NUM_OPERACIONES, 
                                                UNIDAD_BAREMACION, K, FECHA_OPERACION, MES_OPERACION, TIPO_OPERACION, SUBTIPO_OPERACION, TIPO_ENTRADA, 
                                                AGRUPA_EN_FACTURA )
                                                
    SELECT
            credtmp.PERIODO, 
            credtmp.PERIODSEQ,
            to_char(CREDTMP.COMPENSATIONDATE, 'MM/YYYY') MES_PERIODO,
            credtmp.CREDITSEQ, 
            credtmp.CREDITTYPEID ,
            TMP_PDS.PAYEESEQ,
            TMP_PDS.RULEELEMENTOWNERSEQ ,  -- POSITIONSEQ
            TMP_PDS.PDS, 
            TMP_PDS.NOMBRE_FISCAL,
            TMP_PDS.PROVINCIA,
            TMP_PDS.POBLACION,
            TMP_PDS.TIPO_IMPOSITIVO, 
            TMP_PROV.IDPROVEEDOR, 
            TMP_PROV.DESCRIPCION,
            credtmp.name, 
            credtmp.VALUE,
            credtmp.GenericAttribute1,    --Concepto liquidación
            credtmp.GenericNumber1,       -- Numero operaciones
            credtmp.GenericNumber3,     --  Unidad Baremacion
            credtmp.GenericNumber2,       --  K (Famosa)
            CREDTMP.GENERICDATE1,       -- Fecha Operacion
            to_char(CREDTMP.GENERICDATE1, 'MM/YYYY') MES_OPERACION,
            eot.TIPO_OPERACION,   --TIpo Operacion 
            eot.SUBTIPO_OPERACION, -- Subtipo Operacion
            eot.TIPO_ENTRADA, -- Tipo Registro
            eot.AGRUPA_EN_FACTURA
            
        FROM  ENEL_CREDIT_TEMP credtmp
        
        LEFT JOIN ENEL_OPERACIONES_TEMP eot 
            ON CREDTMP.GENERICATTRIBUTE3 = eot.OPERACIONID

            INNER JOIN ENEL_PDS_TEMP TMP_PDS
                      ON CREDTMP.POSITIONSEQ=TMP_PDS.RULEELEMENTOWNERSEQ

            INNER JOIN ENEL_PROVEEDORES_TEMP TMP_PROV 
                ON TMP_PROV.IDPROVEEDOR=CREDTMP.GENERICATTRIBUTE2

        WHERE credtmp.CREDITTYPEID in ( 'ATC - Operaciones' , 'ATC - Ajuste Operaciones', 'ATC - Ajuste Recepcion', 'ATC - Recepcion');                                                

    filas := sql%rowcount;
    COMMIT;

    
    w_debug('Fin Carga de la tabla ENEL_FACTOPE_DETALLE: '|| to_char(filas) || ' filas.', v_contador_debug);

    EXECUTE IMMEDIATE 'ANALYZE TABLE ENELEXT.ENEL_FACTOPE_DETALLE COMPUTE STATISTICS FOR ALL INDEXES';
    w_debug('Fin Actualizacion Indices ENELEXT.ENEL_FACTOPE_DETALLE.',v_contador_debug);
        
end; 


-- INFORME Factura OCAP : ENEL_FACTOPE_TOTAL
-- Agrupa las operaciones de DETALLE en la tabla para informe con los TOTALES
procedure p_Inf_Factura_Ocap_TOTAL ( iprocessingUnitSeq IN VARCHAR2, iperiod IN VARCHAR2,iperiodseq IN VARCHAR2, itenantId IN VARCHAR2 )
AS

begin

    w_debug('Inicio Borrado de la tabla ENEL_FACTOPE_TOTAL periodo: ' || iperiod , v_contador_debug);
   BEGIN
     LOOP
        DELETE FROM ENELEXT.ENEL_FACTOPE_TOTAL WHERE PERIODO = iperiod AND ROWNUM <= 10000;
        EXIT WHEN SQL%ROWCOUNT = 0;
        COMMIT;
     END LOOP;
   END;
    w_debug('Fin Borrado de la tabla ENEL_FACTOPE_TOTAL.', v_contador_debug);
    
   
    w_debug('Insertando Registros de datos en tabla ENEL_FACTOPE_TOTAL.' ,  v_contador_debug);
    
    INSERT INTO ENELEXT.ENEL_FACTOPE_TOTAL (PERIODO,PERIODSEQ, MES_PERIODO, PAYEESEQ, POSITIONSEQ, OCAP_PDS, NOMBRE_FISCAL, PROVINCIA, POBLACION, 
                                            TIPO_IMPOSITIVO, K, MES_OPERACION, TIPO_ENTRADA, TIPO_OPERACION, SUBTIPO_OPERACION, UNIDAD_BAREMACION,
                                            AGRUPA_EN_FACTURA, ORDEN, NUM_OPERACIONES, TOTAL_OPERACIONES)
                                                
    SELECT
            EFD.PERIODO,
            EFD.PERIODSEQ,
            EFD.MES_PERIODO,
            EFD.PAYEESEQ,
            EFD.POSITIONSEQ,
            EFD.OCAP_PDS,
            EFD.NOMBRE_FISCAL,
            EFD.PROVINCIA,
            EFD.POBLACION,
            EFD.TIPO_IMPOSITIVO,
            EFD.K,
            EFD.MES_OPERACION,
            EFD.TIPO_ENTRADA,
            EFD.TIPO_OPERACION,
            EFD.SUBTIPO_OPERACION,
            EFD.UNIDAD_BAREMACION,
            EFD.AGRUPA_EN_FACTURA,
            0 as ORDEN,
            SUM(EFD.NUM_OPERACIONES),
            SUM(EFD.NUM_OPERACIONES * EFD.UNIDAD_BAREMACION)  as TOTAL

    FROM ENEL_FACTOPE_DETALLE efd

    WHERE 
        TIPO_ENTRADA is not null

    GROUP BY 
            EFD.PERIODO,
            EFD.PERIODSEQ,
            EFD.MES_PERIODO,
            EFD.PAYEESEQ,
            EFD.POSITIONSEQ,
            EFD.OCAP_PDS,
            EFD.NOMBRE_FISCAL,
            EFD.PROVINCIA,
            EFD.POBLACION,
            EFD.TIPO_IMPOSITIVO,
            EFD.K,
            EFD.MES_OPERACION,
            EFD.TIPO_ENTRADA,
            EFD.TIPO_OPERACION,
            EFD.SUBTIPO_OPERACION,
            EFD.UNIDAD_BAREMACION,
            EFD.AGRUPA_EN_FACTURA,
            0
    ORDER BY EFD.TIPO_ENTRADA, EFD.TIPO_OPERACION, EFD.SUBTIPO_OPERACION;    
    
    filas := sql%rowcount;
    COMMIT;

    
    w_debug('Fin Carga de la tabla ENEL_FACTOPE_TOTAL: '|| to_char(filas) || ' filas.', v_contador_debug);
    
    EXECUTE IMMEDIATE 'ANALYZE TABLE ENELEXT.ENEL_FACTOPE_TOTAL COMPUTE STATISTICS FOR ALL INDEXES';
    w_debug('Fin Actualizacion Indices ENELEXT.ENEL_FACTOPE_TOTAL.',v_contador_debug);
        
end;  


     
-- INFORME Factura OCAP : ENEL_FACTOPE_RESUMEN
-- RESUMEN DE FACTURA con los TOTALES de las operaciones y los incentivos adicionales
procedure p_Inf_Factura_Ocap_Resumen ( iprocessingUnitSeq IN VARCHAR2, iperiod IN VARCHAR2,iperiodseq IN VARCHAR2, itenantId IN VARCHAR2 )
AS

begin

    w_debug('Inicio Borrado de la tabla ENEL_FACTOPE_RESUMEN periodo: ' || iperiod , v_contador_debug);
   BEGIN
     LOOP
        DELETE FROM ENELEXT.ENEL_FACTOPE_RESUMEN WHERE PERIODO = iperiod AND ROWNUM <= 10000;
        EXIT WHEN SQL%ROWCOUNT = 0;
        COMMIT;
     END LOOP;
   END;
    w_debug('Fin Borrado de la tabla ENEL_FACTOPE_RESUMEN.', v_contador_debug);
    
   
    w_debug('Insertando Registros de datos en tabla ENEL_FACTOPE_RESUMEN.' ,  v_contador_debug);
    
    w_debug('Parámetros iprocessingUnitSeq:' || iprocessingUnitSeq || ' iperiodseq: ' || iperiodseq  ,  v_contador_debug);
    
    INSERT INTO ENELEXT.ENEL_FACTOPE_RESUMEN (PERIODO, PERIODSEQ, PAYEESEQ, POSITIONSEQ, OCAP_PDS, NOMBRE_FISCAL, PROVINCIA, POBLACION, TIPO_IMPOSITIVO,
                                              K, PERIODO_OPERACION, CANTIDAD, TOTAL, IMPORTE, YYYYMM_OPERACION, CONCEPTO, ORDEN )
                                                
    SELECT
            EFD.PERIODO,
            EFD.PERIODSEQ,
            EFD.PAYEESEQ,
            EFD.POSITIONSEQ,
            EFD.OCAP_PDS,
            EFD.NOMBRE_FISCAL,
            EFD.PROVINCIA,
            EFD.POBLACION,
            EFD.TIPO_IMPOSITIVO,
            EFD.K,
            per.NAME,
            sum(EFD.NUM_OPERACIONES) as CANTIDAD,
            SUM(EFD.NUM_OPERACIONES * EFD.UNIDAD_BAREMACION)  as TOTAL,
            sum(EFD.IMPORTE),
            to_char(EFD.FECHA_OPERACION, 'MM/YYYY') as YYYYMM_OPERACION,
            'TOTAL OPERACIONES'as CONCEPTO,
            0 as ORDEN
 
    FROM ENEL_FACTOPE_DETALLE efd

        INNER JOIN CS_PERIOD per
                    ON PER.STARTDATE <= EFD.FECHA_OPERACION 
                    AND PER.ENDDATE > EFD.FECHA_OPERACION
                    AND PER.REMOVEDATE=v_eot
        INNER JOIN CS_PERIODTYPE PERT
                    ON PER.PERIODTYPESEQ=PERT.PERIODTYPESEQ
                    AND PERT.removedate=v_eot
                    AND pert.name='month'
    GROUP BY 
        EFD.PERIODO,
        EFD.PERIODSEQ,
        EFD.PAYEESEQ,
        EFD.POSITIONSEQ,
        EFD.OCAP_PDS,
        EFD.NOMBRE_FISCAL,
        EFD.PROVINCIA,
        EFD.POBLACION,
        EFD.TIPO_IMPOSITIVO,
        EFD.K,
        per.NAME,     
        to_char(EFD.FECHA_OPERACION, 'MM/YYYY'),
        'TOTAL OPERACIONES' ,
        0    ;  -- ORDEN           
            
    filas := sql%rowcount;
    COMMIT;

    
    w_debug('Fin Carga de la tabla ENEL_FACTOPE_RESUMEN: '|| to_char(filas) || ' filas.', v_contador_debug);
    
    w_debug('Insertando INCENTIVOS en tabla ENEL_FACTOPE_RESUMEN.' ,  v_contador_debug);  
      
    INSERT INTO ENELEXT.ENEL_FACTOPE_RESUMEN (PERIODO, PERIODSEQ, PAYEESEQ, POSITIONSEQ, OCAP_PDS, NOMBRE_FISCAL, PROVINCIA, POBLACION, TIPO_IMPOSITIVO,
                                              CANTIDAD, IMPORTE,  PERIODO_OPERACION, YYYYMM_OPERACION, CONCEPTO, ORDEN )
                                                    
    SELECT
            INCENTMP.PERIODO,
            INCENTMP.PERIODSEQ, 
            INCENTMP.PAYEESEQ, 
            INCENTMP.POSITIONSEQ,
            TMP_PDS.PDS,
            TMP_PDS.NOMBRE_FISCAL,
            TMP_PDS.PROVINCIA,
            TMP_PDS.POBLACION,
            TMP_PDS.TIPO_IMPOSITIVO,            
            1 as CANTIDAD,
            INCENTMP.VALUE,
            '' PERIODO_OPERACION,
            '' YYYYMM_OPERACION,
            INCENTMP.GENERICATTRIBUTE3 as CONCEPTO,
            0 as ORDEN
    FROM ENEL_INCEN_TEMP INCENTMP

    INNER JOIN ENEL_PDS_TEMP TMP_PDS
         ON incentmp.POSITIONSEQ=TMP_PDS.RULEELEMENTOWNERSEQ 

    WHERE INCENTMP.NAME in ('I - ATC - Alquiler','I - ATC - Mantenimiento PC','I - ATC - Variable Calidad - Importe Pago');

    filas := sql%rowcount;
    COMMIT;

    
    w_debug('Fin Carga de INCENTIVOS en la tabla ENEL_FACTOPE_RESUMEN: '|| to_char(filas) || ' filas.', v_contador_debug);


    EXECUTE IMMEDIATE 'ANALYZE TABLE ENELEXT.ENEL_FACTOPE_RESUMEN COMPUTE STATISTICS FOR ALL INDEXES';
    w_debug('Fin Actualizacion Indices ENELEXT.ENEL_FACTOPE_RESUMEN.',v_contador_debug);
        
end;            
                 
-- INFORME PDS - Tabla Final para pestañas de STP Prestaciones e instalaciones
procedure p_Final_STP_INFPDS ( iprocessingUnitSeq IN VARCHAR2, iperiod IN VARCHAR2,iperiodseq IN VARCHAR2, itenantId IN VARCHAR2 )
AS

begin

    w_debug('Inicio Borrado de la tabla ENEL_INFPDS_STP periodo: ' || iperiod , v_contador_debug);
   BEGIN
     LOOP
        DELETE FROM ENELEXT.ENEL_INFPDS_STP WHERE PERIODO = iperiod AND ROWNUM <= 10000;
        EXIT WHEN SQL%ROWCOUNT = 0;
        COMMIT;
     END LOOP;
   END;
    w_debug('Fin Borrado de la tabla ENEL_INFPDS_STP.', v_contador_debug);
    
   
    w_debug('Insertando Registros de datos en tabla ENEL_INFPDS_STP.' ,  v_contador_debug);
    
    w_debug('Parámetros iprocessingUnitSeq:' || iprocessingUnitSeq || ' iperiodseq: ' || iperiodseq  ,  v_contador_debug);
    
     INSERT INTO ENELEXT.ENEL_INFPDS_STP ( TENANTID, PERIODSEQ, PAYEESEQ, POSITIONSEQ, PERIODO, LINENUMBER, SUBLINENUMBER, EVENTYPEID, PDS, Nombre_fiscal,Solicitud_Servicio, Contrato, Calle, Municipio,  
                                           Provincia, CODIGO_POSTAL, Producto, Tipo_Servicio, Nombre_Servicio, SS_Garantia, Motivo_Resultado, Equipamiento, Modalidad_Pago, 
                                           Calidad_Tecnica_Gas, Calidad_Tecnica_Luz, FechaHoraApertura, FechaMaximaInicial, FechaMaxima, FechaPrevista, 
                                           FechaInicioTrabajos, FechaFinTrabajos, FechaSolicitadaCliente, FechaValidacion, PLAZO, IMPORTE_COMISION, Estado )   
  SELECT
       PTXN.TENANTID,
       PTXN.PERIODSEQ,
       TPDS.PAYEESEQ,
       TPDS.RULEELEMENTOWNERSEQ,
       PTXN.PERIODO,
       PTXN.LINENUMBER,
       PTXN.SUBLINENUMBER,
       PTXN.EVENTYPEID,
       PTXN.PDS,
       tpds.Nombre_fiscal,
       PTXN.SOLICITUD_SERVICIO,
       PTXN.CONTRATO,
       PTXN.CALLE,
       PTXN.MUNICIPIO,
       PTXN.PROVINCIA,
       PTXN.CODIGO_POSTAL,
       PTXN.PRODUCTO,
       PTXN.TIPO_SERVICIO,
       PTXN.NOMBRE_SERVICIO,
       CASE WHEN PTXN.SS_GARANTIA=1 THEN 'SI' else 'NO' END SS_GARANTIA,
       PTXN.MOTIVO_RESULTADO,
       EET.EQUIPAMIENTO,
       PTXN.MODALIDAD_PAGO,
       PTXN.CALIDAD_TECNICA_GAS,
       PTXN.CALIDAD_TECNICA_LUZ,
       PTXN.FECHAHORAAPERTURA,
       PTXN.FECHAMAXIMAINICIAL,
       PTXN.FECHAMAXIMA,
       PTXN.FECHAPREVISTA,
       PTXN.FECHAINICIOTRABAJOS,
       PTXN.FECHAFINTRABAJOS,
       PTXN.FECHASOLICITADACLIENTE,
       PTXN.FECHAVALIDACION,
       max(pcredit.PLAZO) Plazo,
       sum(pcredit.IMPORTE_COMISION) as IMPCOMISION,
       CASE
         -- Credito NO generado y  txn.GA4=Pte Elminar  -->  Pte Elminar [No aplica porque están filtradas]
         WHEN PCREDIT.CREDITSEQ is null and PTXN.ESTADO_LIQUIDACION = 'Pte. Eliminar' THEN   'Pte. Eliminar'  
         -- Credito NO generado y  txn.GA4 <> Pte Elminar  y Ajuste -->  Pte Revisar            
         WHEN PCREDIT.CREDITSEQ is null and PTXN.ESTADO_LIQUIDACION <> 'Pte. Eliminar'
                                        and PTXN.EVENTYPEID = 'Ajuste Manual STP'      THEN   'Pte. Revisar'       
         -- Credito NO generado y  txn.GA4 <> Pte Elminar  y Prestación/Instalacion y txn.GA3=Pte facturar -->  Pte Revisar                                                
         WHEN PCREDIT.CREDITSEQ is null and PTXN.ESTADO_LIQUIDACION <> 'Pte. Eliminar'
                                        and PTXN.EVENTYPEID <> 'Ajuste Manual STP'                                                
                                        and PTXN.ESTADO_GA3 = 'Pte. Facturar'         THEN   'Pte. Revisar'
         -- Credito NO generado y  txn.GA4 <> Pte Elminar  y Prestación/Instalacion y txn.GA3<>Pte facturar -->  txn.GA4
         WHEN PCREDIT.CREDITSEQ is null and PTXN.ESTADO_LIQUIDACION <> 'Pte. Eliminar'
                                        and PTXN.EVENTYPEID <> 'Ajuste Manual STP'                                                
                                        and PTXN.ESTADO_GA3 <> 'Pte. Facturar'         THEN   PTXN.ESTADO_LIQUIDACION
--            WHEN PCREDIT.CREDITSEQ is not null and PCREDIT.IMPORTE_COMISION = 0 and PCREDIT.SS_GARANTIA <> 1 THEN  'Pte. Revisar Credito' -- credito valor 0 y no es SS de garantia
--            WHEN PCREDIT.CREDITSEQ is not null and PCREDIT.CONCEPTO_LIQUIDACION is null  THEN  'Pte. Revisar Credito'  -- Concepto de liquidación vacio
--            WHEN PCREDIT.CREDITSEQ is not null and ( PCREDIT.PROVEEDOR is null OR PCREDIT.PROVEEDOR ='' OR PCREDIT.PROVEEDOR ='000' )    
--                                                                                      THEN  'Pte. Revisar Credito'  -- Proveedor nulo, vacio o con valor '000' 
            ELSE 'OK' END ESTADO -- Se informa si existe crédito       

  FROM ENEL_INFPDS_TXN_TEMP ptxn
       LEFT JOIN ENEL_INFPDS_CREDIT_TEMP pcredit
            ON PTXN.SALESTRANSACTIONSEQ = pcredit.SALESTRANSACTIONSEQ
            -- Se cruzan los creditos de %Importe Base para tipos de eventos Prestacion e Instalacion y los de %Ajuste Manual para eventos de Ajustes Manuales 
--            AND pcredit.CREDITTYPEID like CASE when PTXN.EVENTYPEID ='Instalacion' THEN '%Importe Base' 
--                                                when PTXN.EVENTYPEID ='Prestacion' THEN '%Importe Base'  
--                                                when PTXN.EVENTYPEID ='Ajuste Manual STP' THEN '%Ajuste Manual'
--                                                END  
       LEFT JOIN ENEL_PDS_TEMP tpds 
            ON PTXN.PDS = tpds.PDS
       LEFT JOIN ENEL_EQUIPAMIENTO_TEMP eet
            ON  PTXN.IDMARCA = EET.IDMARCA
            AND PTXN.IDMODELO = EET.IDMODELO
  WHERE   PTXN.ESTADO_LIQUIDACION <> 'Pte. Eliminar'   -- No se incluyen las transacciones marcadas como Pte de Eliminar   
          AND PTXN.ESTADO_GA3 like CASE when PTXN.EVENTYPEID ='Ajuste Manual STP' then '%' ELSE 'Pte. Facturar' END -- y todas las de ajustes y solo las "Pte. Facturar" para Instalación / prestacio 
    GROUP BY  
       PTXN.TENANTID,
       PTXN.PERIODSEQ,
       TPDS.PAYEESEQ,
       TPDS.RULEELEMENTOWNERSEQ,       
       PTXN.PERIODO,
       PTXN.LINENUMBER,
       PTXN.SUBLINENUMBER,
       PTXN.EVENTYPEID,
       PTXN.PDS,
       tpds.Nombre_fiscal,
       PTXN.PERIODO,
       PTXN.SOLICITUD_SERVICIO,
       PTXN.CONTRATO,
       PTXN.CALLE,
       PTXN.MUNICIPIO,
       PTXN.PROVINCIA,
       PTXN.CODIGO_POSTAL,
       PTXN.PRODUCTO,
       PTXN.TIPO_SERVICIO,
       PTXN.NOMBRE_SERVICIO,
       CASE WHEN PTXN.SS_GARANTIA=1 THEN 'SI' else 'NO' END,
       PTXN.MOTIVO_RESULTADO,
       EET.EQUIPAMIENTO,
       PTXN.MODALIDAD_PAGO,
       PTXN.CALIDAD_TECNICA_GAS,
       PTXN.CALIDAD_TECNICA_LUZ,
       PTXN.FECHAHORAAPERTURA,
       PTXN.FECHAMAXIMAINICIAL,
       PTXN.FECHAMAXIMA,
       PTXN.FECHAPREVISTA,
       PTXN.FECHAINICIOTRABAJOS,
       PTXN.FECHAFINTRABAJOS,
       PTXN.FECHASOLICITADACLIENTE,
       PTXN.FECHAVALIDACION,
       CASE
         -- Credito NO generado y  txn.GA4=Pte Elminar  -->  Pte Elminar [No aplica porque están filtradas]
         WHEN PCREDIT.CREDITSEQ is null and PTXN.ESTADO_LIQUIDACION = 'Pte. Eliminar' THEN   'Pte. Eliminar'  
         -- Credito NO generado y  txn.GA4 <> Pte Elminar  y Ajuste -->  Pte Revisar            
         WHEN PCREDIT.CREDITSEQ is null and PTXN.ESTADO_LIQUIDACION <> 'Pte. Eliminar'
                                        and PTXN.EVENTYPEID = 'Ajuste Manual STP'      THEN   'Pte. Revisar'       
         -- Credito NO generado y  txn.GA4 <> Pte Elminar  y Prestación/Instalacion y txn.GA3=Pte facturar -->  Pte Revisar                                                
         WHEN PCREDIT.CREDITSEQ is null and PTXN.ESTADO_LIQUIDACION <> 'Pte. Eliminar'
                                        and PTXN.EVENTYPEID <> 'Ajuste Manual STP'                                                
                                        and PTXN.ESTADO_GA3 = 'Pte. Facturar'         THEN   'Pte. Revisar'
         -- Credito NO generado y  txn.GA4 <> Pte Elminar  y Prestación/Instalacion y txn.GA3<>Pte facturar -->  txn.GA4
         WHEN PCREDIT.CREDITSEQ is null and PTXN.ESTADO_LIQUIDACION <> 'Pte. Eliminar'
                                        and PTXN.EVENTYPEID <> 'Ajuste Manual STP'                                                
                                        and PTXN.ESTADO_GA3 <> 'Pte. Facturar'         THEN   PTXN.ESTADO_LIQUIDACION
--            WHEN PCREDIT.CREDITSEQ is not null and PCREDIT.IMPORTE_COMISION = 0 and PCREDIT.SS_GARANTIA <> 1 THEN  'Pte. Revisar Credito' -- credito valor 0 y no es SS de garantia
--            WHEN PCREDIT.CREDITSEQ is not null and PCREDIT.CONCEPTO_LIQUIDACION is null  THEN  'Pte. Revisar Credito'  -- Concepto de liquidación vacio
--            WHEN PCREDIT.CREDITSEQ is not null and ( PCREDIT.PROVEEDOR is null OR PCREDIT.PROVEEDOR ='' OR PCREDIT.PROVEEDOR ='000' )    
--                                                                                      THEN  'Pte. Revisar Credito'  -- Proveedor nulo, vacio o con valor '000' 
            ELSE 'OK' END ; -- Se informa si existe crédito;

    filas := sql%rowcount;
    COMMIT;

    
    w_debug('Fin Carga de la tabla ENEL_INFPDS_STP: '|| to_char(filas) || ' filas.', v_contador_debug);

    EXECUTE IMMEDIATE 'ANALYZE TABLE ENELEXT.ENEL_INFPDS_STP COMPUTE STATISTICS FOR ALL INDEXES';
    w_debug('Fin Actualizacion Indices ENELEXT.ENEL_INFPDS_STP.',v_contador_debug);
        
end; 


-- INFORME PDS - Tabla Final para pestañas de COMISIONES Prestaciones e instalaciones
procedure p_Final_Comisiones_INFPDS ( iprocessingUnitSeq IN VARCHAR2, iperiod IN VARCHAR2,iperiodseq IN VARCHAR2, itenantId IN VARCHAR2 )
AS

begin

    w_debug('Inicio Borrado de la tabla ENEL_INFPDS_COMISIONES periodo: ' || iperiod , v_contador_debug);
   BEGIN
     LOOP
        DELETE FROM ENELEXT.ENEL_INFPDS_COMISIONES WHERE PERIODO = iperiod AND ROWNUM <= 10000;
        EXIT WHEN SQL%ROWCOUNT = 0;
        COMMIT;
     END LOOP;
   END;
    w_debug('Fin Borrado de la tabla ENEL_INFPDS_COMISIONES.', v_contador_debug);


    
    w_debug('Insertando Registros de datos en tabla ENEL_INFPDS_COMISIONES.' ,  v_contador_debug);
    
    w_debug('Parámetros iprocessingUnitSeq:' || iprocessingUnitSeq || ' iperiodseq: ' || iperiodseq  ,  v_contador_debug);
    
     INSERT INTO ENELEXT.ENEL_INFPDS_COMISIONES ( CREDITSEQ, PERIODSEQ, PAYEESEQ, POSITIONSEQ, PERIODO, CREDITTYPEID, PDS, Nombre_fiscal, Solicitud_Servicio, Producto, Tipo_Servicio, 
                                                  Nombre_Servicio, PLAZO, Equipamiento, Modalidad_Pago, SS_Garantia, TIPO_COMISION, CONCEPTO_LIQUIDACION, IMPORTE_COMISION )   
    SELECT
       pcredit.CREDITSEQ,
       PCREDIT.PERIODSEQ,
       TPDS.PAYEESEQ,
       TPDS.RULEELEMENTOWNERSEQ,
       pcredit.PERIODO,
       pcredit.CREDITTYPEID,
       pcredit.PDS,
       tpds.Nombre_fiscal,
       pcredit.Solicitud_Servicio,
       PTXN.PRODUCTO,
       PTXN.TIPO_SERVICIO,
       PTXN.NOMBRE_SERVICIO,
       pcredit.PLAZO,
       pcredit.EQUIPAMIENTO,
       pcredit.MODALIDAD_PAGO,
       CASE WHEN pcredit.SS_GARANTIA = 1 THEN 'SI' 
            WHEN pcredit.SS_GARANTIA = 0 THEN 'NO'
            ELSE '' END SS_GARANTIA,
       pcredit.TIPO_COMISION,
       pcredit.CONCEPTO_LIQUIDACION,
       pcredit.IMPORTE_COMISION
    FROM ENEL_INFPDS_CREDIT_TEMP pcredit
        INNER JOIN ENEL_INFPDS_TXN_TEMP ptxn
            ON pcredit.SALESTRANSACTIONSEQ = PTXN.SALESTRANSACTIONSEQ
        LEFT JOIN ENEL_PDS_TEMP tpds 
            ON pcredit.PDS = tpds.PDS
    ORDER BY pcredit.PDS, pcredit.Solicitud_Servicio;

    filas := sql%rowcount;
    COMMIT;

    
    w_debug('Fin Carga de la tabla ENEL_INFPDS_COMISIONES: '|| to_char(filas) || ' filas.', v_contador_debug);

    EXECUTE IMMEDIATE 'ANALYZE TABLE ENELEXT.ENEL_INFPDS_COMISIONES COMPUTE STATISTICS FOR ALL INDEXES';
    w_debug('Fin Actualizacion Indices ENELEXT.ENEL_INFPDS_COMISIONES.',v_contador_debug);
        
end; 

-- INFORME PDS -- Datos de Revision de Créditos
procedure p_Rev_Creditos_INFPDS ( iprocessingUnitSeq IN VARCHAR2, iperiod IN VARCHAR2,iperiodseq IN VARCHAR2, itenantId IN VARCHAR2 )
AS

begin

    w_debug('Inicio Borrado de la tabla ENEL_INFPDS_CREDIT_REVISION periodo: ' || iperiod , v_contador_debug);
   BEGIN
     LOOP
        DELETE FROM ENELEXT.ENEL_INFPDS_CREDIT_REVISION WHERE PERIODO = iperiod AND ROWNUM <= 10000;
        EXIT WHEN SQL%ROWCOUNT = 0;
        COMMIT;
     END LOOP;
   END;
    w_debug('Fin Borrado de la tabla ENEL_INFPDS_CREDIT_REVISION.', v_contador_debug);


    
    w_debug('Insertando Registros de datos en tabla ENEL_INFPDS_CREDIT_REVISION.' ,  v_contador_debug);
    
    w_debug('Parámetros iprocessingUnitSeq:' || iprocessingUnitSeq || ' iperiodseq: ' || iperiodseq  ,  v_contador_debug);
    
     INSERT INTO ENELEXT.ENEL_INFPDS_CREDIT_REVISION ( TENANTID, PERIODSEQ, PERIODO, CREDITSEQ, SOLICITUD_SERVICIO, NOMBRE_FISCAL, PDS, CREDITTYPEID,
                                                       PRODUCTO, SERVICIO, PLAZO, EQUIPAMIENTO, MODALIDAD_PAGO, SS_GARANTIA, TIPO_COMISION, CONCEPTO_LIQUIDACION, 
                                                       CODIGO_POSTAL, PROVINCIA, ZONA, PROVEEDOR, FECHA_CALCULO, IMPORTE_COMISION, ESTADO )   
    SELECT
      pcredit.TENANTID,
      pcredit.PERIODSEQ,
      ptxn.PERIODO,
      pcredit.CREDITSEQ,
      pcredit.SOLICITUD_SERVICIO,
      TPDS.NOMBRE_FISCAL, 
      ptxn.PDS,
      pcredit.CREDITTYPEID,
      PCREDIT.PRODUCTO,
      pcredit.SERVICIO,
      pcredit.PLAZO,
      pcredit.EQUIPAMIENTO,
      pcredit.MODALIDAD_PAGO,
      pcredit.SS_GARANTIA,
      pcredit.TIPO_COMISION, 
      pcredit.CONCEPTO_LIQUIDACION,
      pcredit.CODIGO_POSTAL,
      pcredit.PROVINCIA, 
      pcredit.ZONA,
      pcredit.PROVEEDOR,  
      to_char(PCREDIT.PIPELINERUNDATE, 'DD/MM/YYYY HH24:MI:SS') FEC_CALCULO,
      pcredit.IMPORTE_COMISION,
      CASE WHEN PCREDIT.IMPORTE_COMISION = 0 and PCREDIT.SS_GARANTIA <> 1 THEN  'Importe 0 y No garantía' -- credito valor 0 y no es SS de garantia
           WHEN ( PCREDIT.PROVEEDOR is null OR PCREDIT.PROVEEDOR ='' OR PCREDIT.PROVEEDOR ='000' ) THEN  'Proveedor erróneo'  -- Proveedor nulo, vacio o con valor '000'
           WHEN PCREDIT.CONCEPTO_LIQUIDACION is null  THEN  'Falta Concepto Liquidación'  -- Concepto de liquidación vacio
           ELSE '' END
  
   FROM ENEL_INFPDS_TXN_TEMP ptxn
       LEFT JOIN ENEL_INFPDS_CREDIT_TEMP pcredit
            ON PTXN.SALESTRANSACTIONSEQ = pcredit.SALESTRANSACTIONSEQ
            -- Se cruzan los creditos de %Importe Base para tipos de eventos Prestacion e Instalacion y los de %Ajuste Manual para eventos de Ajustes Manuales 
            AND pcredit.CREDITTYPEID like CASE when PTXN.EVENTYPEID ='Instalacion' THEN '%Importe Base' 
                                                when PTXN.EVENTYPEID ='Prestacion' THEN '%Importe Base'  
                                                when PTXN.EVENTYPEID ='Ajuste Manual STP' THEN '%Ajuste Manual'
                                                END  
       LEFT JOIN ENEL_PDS_TEMP tpds 
            ON PTXN.PDS = tpds.PDS
       LEFT JOIN ENEL_EQUIPAMIENTO_TEMP eet
            ON  PTXN.IDMARCA = EET.IDMARCA
            AND PTXN.IDMODELO = EET.IDMODELO
  WHERE   PTXN.ESTADO_LIQUIDACION <> 'Pte. Eliminar'   -- No se incluyen las transacciones marcadas como Pte de Eliminar
  and  PCREDIT.CREDITSEQ is not null and 
        ( ( PCREDIT.IMPORTE_COMISION = 0 and PCREDIT.SS_GARANTIA <> 1) 
            OR PCREDIT.CONCEPTO_LIQUIDACION is null 
            OR ( PCREDIT.PROVEEDOR is null OR PCREDIT.PROVEEDOR ='' OR PCREDIT.PROVEEDOR ='000' ) );
      
    filas := sql%rowcount;
    COMMIT;
    
    w_debug('Fin Carga de la tabla ENEL_INFPDS_CREDIT_REVISION: '|| to_char(filas) || ' filas.', v_contador_debug);

    EXECUTE IMMEDIATE 'ANALYZE TABLE ENELEXT.ENEL_INFPDS_CREDIT_REVISION COMPUTE STATISTICS FOR ALL INDEXES';
    w_debug('Fin Actualizacion Indices ENELEXT.ENEL_INFPDS_CREDIT_REVISION.',v_contador_debug);
        
end; 


procedure p_Informe_LIQSCAWEB ( iprocessingUnitSeq IN VARCHAR2, iperiod IN VARCHAR2,iperiodseq IN VARCHAR2, itenantId IN VARCHAR2 )
AS
    v_fechaInicioPeriodo date;
    v_txtFechaInicioPeriodo VARCHAR2(10);
    v_txtFechaLiquidacion VARCHAR2(10);
    v_Estado VARCHAR2(50);
begin

    w_debug('Inicio Borrado de la tabla ENEL_LIQSCAWEB_FINAL.', v_contador_debug);
   BEGIN
     LOOP
        DELETE FROM ENELEXT.ENEL_LIQSCAWEB_FINAL WHERE PERIODO = iperiod AND ROWNUM <= 10000;
        EXIT WHEN SQL%ROWCOUNT = 0;
        COMMIT;
     END LOOP;
   END;
    w_debug('Fin Borrado de la tabla ENEL_LIQSCAWEB_FINAL.', v_contador_debug);

    w_debug('Insertando Registros de datos en tabla ENEL_LIQSCAWEB_FINAL.' ,  v_contador_debug);
    
     INSERT INTO ENELEXT.ENEL_LIQSCAWEB_FINAL ( PERIODO, ORDERID, LINENUMBER, SUBLINENUMBER, EVENTTYPEID, IMPORTE, UNIDAD, VALOR_1, UNIDAD_1, PRODUCTO_SCAWEB , CODIGO_PDS_OCAP, CICLO_FACTURACION )   
        SELECT 
            ECT.PERIODO,
            ETT.ORDERID,
            ETT.LINENUMBER,
            ETT.SUBLINENUMBER,
            ETT.EVENTYPEID,
            TRIM(replace(to_char(ECT.VALUE , '9999999999990D99'), ',', '.')) IMPORTE_COMISION,
            'EURO',
            TRIM(replace(to_char(ECT.GENERICNUMBER2 , '9999999999990D99'), ',', '.')) VALOR_1,
            'EURO',
            ECT.GENERICATTRIBUTE1,    --    ID Producto SCA Web
            ECT.GENERICATTRIBUTE4,    --    Código de PDS/OCAP
            case when ETT.ACCOUNTINGDATE is null then ''
            ELSE to_char(ETT.ACCOUNTINGDATE,'YYYY-MM-DD') END CICLO_FACT--       CICLO facturacion - Pte confirmar formato
        FROM ENEL_CREDIT_TEMP ect
        INNER JOIN ENEL_TXN_TEMP ett
            ON ECT.SALESTRANSACTIONSEQ = ETT.SALESTRANSACTIONSEQ
        WHERE ECT.CREDITTYPEID = 'Captacion - Importe Base';
               
     filas := sql%rowcount;
    COMMIT;

    
    w_debug('Fin Carga de la tabla ENEL_LIQSCAWEB_FINAL: '|| to_char(filas) || ' filas.', v_contador_debug);

    EXECUTE IMMEDIATE 'ANALYZE TABLE ENELEXT.ENEL_LIQSCAWEB_FINAL COMPUTE STATISTICS FOR ALL INDEXES';
    w_debug('Fin Actualizacion Indices ENELEXT.ENEL_LIQSCAWEB_FINAL.',v_contador_debug);
         
end;
        
        
procedure p_Informe_ICISA ( iprocessingUnitSeq IN VARCHAR2, iperiod IN VARCHAR2,iperiodseq IN VARCHAR2, itenantId IN VARCHAR2 )
AS
    v_fechaInicioPeriodo date;
    v_txtFechaInicioPeriodo VARCHAR2(10);
    v_txtFechaLiquidacion VARCHAR2(10);
    v_Estado VARCHAR2(50);
begin

    w_debug('Inicio Borrado de la tabla ENEL_INFORME_ICISA.', v_contador_debug);
   BEGIN
     LOOP
        DELETE FROM ENELEXT.ENEL_INFORME_ICISA WHERE PERIODO = iperiod AND ROWNUM <= 10000;
        EXIT WHEN SQL%ROWCOUNT = 0;
        COMMIT;
     END LOOP;
   END;
    w_debug('Fin Borrado de la tabla ENEL_INFORME_ICISA.', v_contador_debug);

    w_debug('Insertando Registros de datos en tabla ENEL_INFORME_ICISA.' ,  v_contador_debug);
    
     INSERT INTO ENELEXT.ENEL_INFORME_ICISA ( Periodo, TENANTID, PERIODSEQ, YEAR, MONTH, PDS, CONCEPTO_LIQUIDACION, COD_PROVEEDOR, 
                                                DES_PROVEEDOR, DES_CORTA_PROVEEDOR, IMPORTE, SOLICITUD_SERVICIO, PROVINCIA )   
/*  
        SELECT 
            iperiod PERIODO,        
            credit.TENANTID,
            credit.PERIODSEQ,            
            to_char(credit.COMPENSATIONDATE, 'YYYY'),
            to_char(credit.COMPENSATIONDATE, 'MM'),
            credit.GENERICATTRIBUTE4,      -- Prestador - PDS
            credit.GENERICATTRIBUTE1,      -- Concepto Liquidación
            credit.GENERICATTRIBUTE2,      -- Proveedor  
            tmp_prov.DESCRIPCION ,         -- Descripcion proveedor
            tmp_prov.DESCRIPCION_CORTA,    -- Descripcion CORTA proveedor
            credit.VALUE,                  --Importe Comision
            credit.GENERICATTRIBUTE9,      -- Solicitud de servicio
            credit.GENERICATTRIBUTE6       --Provincia          
        FROM CS_CREDIT credit
        
            INNER JOIN CS_PLRUN p ON CREDIT.PIPELINERUNSEQ = P.PIPELINERUNSEQ 
                                     AND P.MODELSEQ = 0   -- Solo se tienen en cuenta las ejecuciones que no son de simulacion
                                     
            INNER JOIN CS_CREDITTYPE ctype ON credit.CREDITTYPESEQ = ctype.DATATYPESEQ 
                                                AND ctype.TENANTID = itenantId 
                                                AND ( ctype.CREDITTYPEID like ('Prestacion%') 
                                                      OR ctype.CREDITTYPEID like ('Instalacion%') ) 
                                                AND  ctype.REMOVEDATE  = v_eot
  
            LEFT JOIN ENEL_PROVEEDORES_TEMP tmp_prov ON credit.GENERICATTRIBUTE2 = tmp_prov.IDPROVEEDOR
        WHERE
            credit.GENERICBOOLEAN1 = 1 AND  -- Indica los creditos que se incluyen en pagos
            credit.GENERICATTRIBUTE1 is not null AND -- Solo se  incluyen los créditos con Concepto de Liquidación que no son vacios (nulos)            
            credit.GENERICATTRIBUTE4 = 'TF9035'  AND -- Solo se ejecutará para el PDS TF9035, para pruebas sacamos todo lo que haya
            credit.PROCESSINGUNITSEQ = iprocessingUnitSeq AND  
            credit.TENANTID = itenantId AND 
            credit.PERIODSEQ =  iperiodseq;


*/

-- SE MODIFICA LA EXTRACCIÓN DE DATOS DE LA TABLA TEMPORAL DE CREDITOS PARA EVITAR VARIAS CONSULTAS DIRECTAS SOBRE CS_CREDIT QUE PUEDEN PENALIZAR RENDIMIENTO
        SELECT 
            creditemp.PERIODO,        
            creditemp.TENANTID,
            creditemp.PERIODSEQ,            
            to_char(creditemp.COMPENSATIONDATE, 'YYYY'),
            to_char(creditemp.COMPENSATIONDATE, 'MM'),
            creditemp.GENERICATTRIBUTE4,      -- Prestador - PDS
            creditemp.GENERICATTRIBUTE1,      -- Concepto Liquidación
            creditemp.GENERICATTRIBUTE2,      -- Proveedor  
            tmp_prov.DESCRIPCION ,         -- Descripcion proveedor
            tmp_prov.DESCRIPCION_CORTA,    -- Descripcion CORTA proveedor
            creditemp.VALUE,                  --Importe Comision
            creditemp.GENERICATTRIBUTE9,      -- Solicitud de servicio
            creditemp.GENERICATTRIBUTE6       --Provincia        

        FROM ENEL_CREDIT_TEMP creditemp
            
            LEFT JOIN ENEL_PROVEEDORES_TEMP tmp_prov ON creditemp.GENERICATTRIBUTE2 = tmp_prov.IDPROVEEDOR
        WHERE
            creditemp.GENERICBOOLEAN1 = 1 AND  -- Indica los creditos que se incluyen en pagos
            creditemp.GENERICATTRIBUTE1 is not null AND -- Solo se  incluyen los créditos con Concepto de Liquidación que no son vacios (nulos)            
            ( creditemp.CREDITTYPEID like ('Prestacion%')  OR creditemp.CREDITTYPEID like ('Instalacion%') ) AND
            creditemp.GENERICATTRIBUTE4 = 'TF9035';  -- Solo se ejecutará para el PDS TF9035, para pruebas sacamos todo lo que haya

     filas := sql%rowcount;
    COMMIT;

    
    w_debug('Fin Carga de la tabla ENEL_INFORME_ICISA: '|| to_char(filas) || ' filas.', v_contador_debug);

    EXECUTE IMMEDIATE 'ANALYZE TABLE ENELEXT.ENEL_INFORME_ICISA COMPUTE STATISTICS FOR ALL INDEXES';
    w_debug('Fin Actualizacion Indices ENELEXT.ENEL_INFORME_ICISA.',v_contador_debug);
            
end;

procedure p_Informe_STP ( iprocessingUnitSeq IN VARCHAR2, iperiod IN VARCHAR2,iperiodseq IN VARCHAR2, itenantId IN VARCHAR2 )
AS
    v_fechaInicioPeriodo date;
    v_txtFechaInicioPeriodo VARCHAR2(10);
    v_txtFechaLiquidacion VARCHAR2(10);
    v_Estado VARCHAR2(50);
begin

    w_debug('Inicio Borrado de la tabla ENEL_INFORME_STP.', v_contador_debug);
   BEGIN
     LOOP
        DELETE FROM ENELEXT.ENEL_INFORME_STP WHERE PERIODNAME = iperiod AND ROWNUM <= 10000;
        EXIT WHEN SQL%ROWCOUNT = 0;
        COMMIT;
     END LOOP;
   END;
    w_debug('Fin Borrado de la tabla ENEL_INFORME_STP.', v_contador_debug);

    w_debug('Insertando Registros de datos en tabla ENEL_INFORME_STP.' ,  v_contador_debug);
    
     INSERT INTO ENELEXT.ENEL_INFORME_STP ( TENANTID, PERIODSEQ, PERIODNAME, PDS, CONCEPTO_LIQUIDACION, COD_PROVEEDOR, DES_PROVEEDOR, 
                                                PROVINCIA, ZONA, IMPORTE, SOLICITUD_SERVICIO, UNIDADES )   

      SELECT 
            credit.TENANTID,
            credit.PERIODSEQ,
            iperiod PERIODO,
            credit.GENERICATTRIBUTE4,      --Prestador            
            credit.GENERICATTRIBUTE1,      --Concepto Liquidación
            credit.GENERICATTRIBUTE2,      --Proveedor       
            tmp_prov.DESCRIPCION,         -- Desc. Proveedor
            credit.GENERICATTRIBUTE6,     -- Provincia
            credit.GENERICATTRIBUTE7,     -- Zona                 
            SUM(credit.VALUE),                  --Importe Comision
            credit.GENERICATTRIBUTE9,      --Solicitud Servicio
            1 as unidades

        FROM CS_CREDIT credit
        
            INNER JOIN CS_PLRUN p ON CREDIT.PIPELINERUNSEQ = P.PIPELINERUNSEQ 
                                     AND P.MODELSEQ = 0   -- Solo se tienen en cuenta las ejecuciones que no son de simulacion
                                     
            INNER JOIN CS_CREDITTYPE ctype ON credit.CREDITTYPESEQ = ctype.DATATYPESEQ 
                                                AND ctype.TENANTID = itenantId 
                                                AND ( ctype.CREDITTYPEID like ('Prestacion%') 
                                                      OR ctype.CREDITTYPEID like ('Instalacion%') ) 
                                                AND  ctype.REMOVEDATE  =  v_eot
  
            LEFT JOIN ENEL_PROVEEDORES_TEMP tmp_prov ON credit.GENERICATTRIBUTE2 = tmp_prov.IDPROVEEDOR
        WHERE
            credit.GENERICBOOLEAN1 = 1 AND  -- Indica los creditos que se incluyen en pagos
            credit.GENERICATTRIBUTE1 is not null AND -- Solo se  incluyen los créditos con Concepto de Liquidación que no son vacios (nulos)
            credit.PROCESSINGUNITSEQ = iprocessingUnitSeq AND            
            credit.TENANTID = itenantId AND 
            credit.PERIODSEQ =  iperiodseq
GROUP BY
            credit.TENANTID,
            credit.PERIODSEQ,
            iperiod  ,
            credit.GENERICATTRIBUTE4,                  
            credit.GENERICATTRIBUTE1,      
            credit.GENERICATTRIBUTE2,             
            tmp_prov.DESCRIPCION  ,      
            credit.GENERICATTRIBUTE6,
            credit.GENERICATTRIBUTE7,                
            credit.GENERICATTRIBUTE9,    
            1;


     filas := sql%rowcount;
    COMMIT;

    
    w_debug('Fin Carga de la tabla ENEL_INFORME_STP: '|| to_char(filas) || ' filas.', v_contador_debug);

    EXECUTE IMMEDIATE 'ANALYZE TABLE ENELEXT.ENEL_INFORME_STP COMPUTE STATISTICS FOR ALL INDEXES';
    w_debug('Fin Actualizacion Indices ENELEXT.ENEL_INFORME_STP.',v_contador_debug);
    
end;

-- FATURA PDS - DETALLE
procedure p_Inf_Factura_PDS_Detalle ( iprocessingUnitSeq IN VARCHAR2, iperiod IN VARCHAR2,iperiodseq IN VARCHAR2, itenantId IN VARCHAR2 )
AS
    v_fechaPeriodoSiguiente date;
    v_txtMes_Liquidacion VARCHAR2(10);
begin

    w_debug('Inicio Borrado de la tabla ENEL_FACTPDS_DETALLE.', v_contador_debug);
   BEGIN
     LOOP
        DELETE FROM ENELEXT.ENEL_FACTPDS_DETALLE WHERE PERIODO = iperiod AND ROWNUM <= 10000;
        EXIT WHEN SQL%ROWCOUNT = 0;
        COMMIT;
     END LOOP;
   END;
    w_debug('Fin Borrado de la tabla ENEL_FACTPDS_DETALLE.', v_contador_debug);

    -- Se extrae la fecha inicial del siguiente mes al periodSeq del proceso
    v_fechaPeriodoSiguiente :=  f_Primer_Dia_Periodo_Siguiente(iperiodseq);
    
    -- Se convierte a texto en formato DD/MM/YYYY para los registros de salida
    v_txtMes_Liquidacion := to_char(v_fechaPeriodoSiguiente, 'YYYYMM');

    w_debug('Insertando Registros de CREDITOS en tabla ENEL_FACTPDS_DETALLE.' ,  v_contador_debug);
   
    
     INSERT INTO ENELEXT.ENEL_FACTPDS_DETALLE ( PERIODO, PERIODSEQ, MES_LIQUIDACION, CREDITSEQ, CREDITTYPEID, PAYEESEQ, POSITIONSEQ, 
                                                PDS, NOMBRE_FISCAL, CIF, IDPROVEEDOR, DESCRIPCION, FICHERO, ACTIVIDAD, DETALLE_ACTIVIDAD, CODIGOE4E,DELEGACION,
                                                ZONA, TERRITORIO, CALLE, COD_POSTAL, PROVINCIA, POBLACION, CANTIDAD, VALUE, SOLICITUD_SERVICIO, CONCEPTO_LIQ, DESC_CONCEPTO_LIQ, 
                                                COD_CONTRATO, EVENTYPEID, CONTRATO, PRODUCTID, COD_POSTAL_DETALLE, COD_COMERCIAL, MARCA, MODELO )   

      SELECT 
            credtmp.PERIODO, 
            credtmp.PERIODSEQ,
            v_txtMes_Liquidacion as Mes_Liquidacion,
            credtmp.CREDITSEQ, 
            credtmp.CREDITTYPEID ,
            TMP_PDS.PAYEESEQ,
            TMP_PDS.RULEELEMENTOWNERSEQ ,  -- POSITIONSEQ
            TMP_PDS.PDS, 
            TMP_PDS.NOMBRE_FISCAL,
            TMP_PDS.CIF,
            TMP_PROV.IDPROVEEDOR, 
            TMP_PROV.DESCRIPCION,
            TMP_PROV.FICHERO,
            TMP_PROV.ACTIVIDAD,
            TMP_PROV.DETALLE_ACTIVIDAD,
            TMP_PDS.PAR_PROVEEDOR as CODIGOE4E,
            TMP_PDS.DELEGACION,
            TMP_PDS.ZONA,
            TMP_PDS.TERRITORIO,
            TMP_PDS.CALLE,
            TMP_PDS.COD_POSTAL,
            TMP_PDS.PROVINCIA,
            TMP_PDS.POBLACION, 
            1 AS CANTIDAD,           
            credtmp.VALUE,
            case when CREDTMP.CREDITTYPEID like 'Instalacion%' or CREDTMP.CREDITTYPEID like 'Prestacion%'
                    THEN credtmp.GENERICATTRIBUTE9 ELSE '' END AS solicitud_servicio,      -- Solicitud de servicio (solo prestacion e Instalacion)
            credtmp.GenericAttribute1 as CONCEPTO_LIQ,    --Concepto liquidación
            CASE WHEN credtmp.GenericAttribute14 is not null THEN credtmp.GenericAttribute14                              -- Si existe GA14 --> GA14,
                 WHEN credtmp.GenericAttribute14 is null  AND TMP_PROD.DESCRIPTION is not null THEN TMP_PROD.DESCRIPTION  -- Si no existe GA14 pero si hay Descrip Producto-->  Descrip Producto
                      else credtmp.GenericAttribute1 END AS DESC_CONCEPTO_LIQ,                                             -- Si no Se pone el GA1 --> Concepto de Liquidacion
            TMP_CONTRA.COD_CONTRATO,  -- PAra saber si tiene pedido o no
            TXNTMP.EVENTYPEID,
            TXNTMP.PONUMBER as CONTRATO,
            TXNTMP.PRODUCTID, 
            TXNTMP.TAD_POSTALCODE AS COD_POSTAL_DETALLE,
            TXNTMP.TAS_GENERICATTRIBUTE1 AS COD_COMERCIAL,
            EET.MARCA,
            EET.MODELO

       FROM ENEL_CREDIT_TEMP CREDTMP
        INNER JOIN ENEL_TXN_TEMP TXNTMP
            ON CREDTMP.SALESTRANSACTIONSEQ = TXNTMP.SALESTRANSACTIONSEQ
            
            INNER JOIN ENEL_PDS_TEMP TMP_PDS
                      ON CREDTMP.POSITIONSEQ=TMP_PDS.RULEELEMENTOWNERSEQ

            INNER JOIN ENEL_PROVEEDORES_TEMP TMP_PROV 
                ON TMP_PROV.IDPROVEEDOR=CREDTMP.GENERICATTRIBUTE2
                
            LEFT JOIN ENEL_PRODUCTOS_TEMP TMP_PROD
                 ON TMP_PROD.PRODUCTID=CREDTMP.GENERICATTRIBUTE1

           LEFT JOIN ENEL_E4E_CONTRATOS_TEMP TMP_CONTRA
                ON  TMP_CONTRA.PDS = TMP_PDS.PDS
                    AND TMP_CONTRA.ACTIVIDAD = TMP_PROV.ACTIVIDAD
                    AND TMP_CONTRA.ACTIVIDAD_DETALLADA=TMP_PROV.DETALLE_ACTIVIDAD
                    AND TMP_CONTRA.periodseq=TMP_PROV.periodseq

           LEFT JOIN ENEL_EQUIPAMIENTO_TEMP EET
            ON  TXNTMP.GENERICATTRIBUTE8 = EET.IDMARCA
            AND TXNTMP.GENERICATTRIBUTE9 = EET.IDMODELO                    
            
        WHERE ( CREDTMP.CREDITTYPEID like 'Captacion%' OR
                CREDTMP.CREDITTYPEID like 'Prestacion%' OR
                CREDTMP.CREDITTYPEID like 'Instalacion%' ) AND
                CREDTMP.GENERICATTRIBUTE1 is not null  AND
                CREDTMP.GENERICATTRIBUTE2 is not null   AND CREDTMP.GENERICATTRIBUTE2 <> '000' AND
                CREDTMP.GENERICBOOLEAN1 = 1;    

     filas := sql%rowcount;
    COMMIT;

    
    w_debug('Fin Carga CREDITOS de la tabla ENEL_FACTPDS_DETALLE: '|| to_char(filas) || ' filas.', v_contador_debug);

    w_debug('Insertando Registros de INCENTIVOS en tabla ENEL_FACTPDS_DETALLE.' ,  v_contador_debug);
   
    
     INSERT INTO ENELEXT.ENEL_FACTPDS_DETALLE ( PERIODO, PERIODSEQ, MES_LIQUIDACION, CREDITSEQ, CREDITTYPEID, PAYEESEQ, POSITIONSEQ, 
                                                PDS, NOMBRE_FISCAL, CIF, IDPROVEEDOR, DESCRIPCION, FICHERO, ACTIVIDAD, DETALLE_ACTIVIDAD, CODIGOE4E, DELEGACION, 
                                                ZONA, TERRITORIO, CALLE, COD_POSTAL, PROVINCIA, POBLACION, CANTIDAD, VALUE, SOLICITUD_SERVICIO, CONCEPTO_LIQ, 
                                                DESC_CONCEPTO_LIQ, COD_CONTRATO, EVENTYPEID, CONTRATO, PRODUCTID, COD_POSTAL_DETALLE, COD_COMERCIAL, 
                                                MARCA, MODELO )   


      SELECT 
            INCETMP.PERIODO, 
            INCETMP.PERIODSEQ,
            v_txtMes_Liquidacion as Mes_Liquidacion,
            INCETMP.INCENTIVESEQ,
            INCETMP.NAME ,
            TMP_PDS.PAYEESEQ,
            TMP_PDS.RULEELEMENTOWNERSEQ ,  -- POSITIONSEQ
            TMP_PDS.PDS, 
            TMP_PDS.NOMBRE_FISCAL,
            TMP_PDS.CIF,
            TMP_PROV.IDPROVEEDOR, 
            TMP_PROV.DESCRIPCION,
            TMP_PROV.FICHERO,
            TMP_PROV.ACTIVIDAD,
            TMP_PROV.DETALLE_ACTIVIDAD,
            TMP_PDS.PAR_PROVEEDOR as CODIGOE4E,
            TMP_PDS.DELEGACION,
            TMP_PDS.ZONA,
            TMP_PDS.TERRITORIO,
            TMP_PDS.CALLE,
            TMP_PDS.COD_POSTAL,
            TMP_PDS.PROVINCIA,
            TMP_PDS.POBLACION, 
            1 AS CANTIDAD,           
            INCETMP.VALUE,
            '' solicitud_servicio,      -- Solicitud de servicio
            INCETMP.GenericAttribute1 as CONCEPTO_LIQ,    --Concepto liquidación
            INCETMP.GenericAttribute3 AS DESC_CONCEPTO_LIQ,  -- Siempre debe venir informado
            TMP_CONTRA.COD_CONTRATO,
            '' EVENTYPEID,
            ''  CONTRATO,
            '' PRODUCTID, 
            '' COD_POSTAL_DETALLE,
            '' COD_COMERCIAL,
            '' MARCA,
            '' MODELO
       FROM ENEL_INCEN_TEMP INCETMP

            INNER JOIN ENEL_PDS_TEMP TMP_PDS
                      ON INCETMP.POSITIONSEQ=TMP_PDS.RULEELEMENTOWNERSEQ

            INNER JOIN ENEL_PROVEEDORES_TEMP TMP_PROV 
                ON TMP_PROV.IDPROVEEDOR=INCETMP.GENERICATTRIBUTE2

            LEFT JOIN ENEL_E4E_CONTRATOS_TEMP TMP_CONTRA
                ON  TMP_CONTRA.PDS = TMP_PDS.PDS
                    AND TMP_CONTRA.ACTIVIDAD = TMP_PROV.ACTIVIDAD
                    AND TMP_CONTRA.ACTIVIDAD_DETALLADA=TMP_PROV.DETALLE_ACTIVIDAD
                    AND TMP_CONTRA.periodseq=TMP_PROV.periodseq      

        WHERE INCETMP.NAME like 'I - Captacion - %' AND
              INCETMP.GENERICATTRIBUTE1 is not null AND
              INCETMP.GENERICATTRIBUTE2 is not null AND INCETMP.GENERICATTRIBUTE2 <> '000' AND
              INCETMP.GENERICBOOLEAN1 = 1
              and INCETMP.value > 0;

     filas := sql%rowcount;
    COMMIT;

    w_debug('Fin Carga INCENTIVOS de la tabla ENEL_FACTPDS_DETALLE: '|| to_char(filas) || ' filas.', v_contador_debug);
    
    EXECUTE IMMEDIATE 'ANALYZE TABLE ENELEXT.ENEL_FACTPDS_DETALLE COMPUTE STATISTICS FOR ALL INDEXES';
    w_debug('Fin Actualizacion Indices ENELEXT.ENEL_FACTPDS_DETALLE.',v_contador_debug);
    
end;


procedure p_Inf_Factura_PDS_Portada ( iprocessingUnitSeq IN VARCHAR2, iperiod IN VARCHAR2,iperiodseq IN VARCHAR2, itenantId IN VARCHAR2 )
AS
    v_fechaActual date;
begin

    w_debug('Inicio Borrado de la tabla ENEL_FACTPDS_PORTADA.', v_contador_debug);
   BEGIN
     LOOP
        DELETE FROM ENELEXT.ENEL_FACTPDS_PORTADA WHERE PERIODO = iperiod AND ROWNUM <= 10000;
        EXIT WHEN SQL%ROWCOUNT = 0;
        COMMIT;
     END LOOP;
   END;
    w_debug('Fin Borrado de la tabla ENEL_FACTPDS_PORTADA.', v_contador_debug);

    v_fechaActual := sysdate;
    
    w_debug('Insertando Registros de CREDITOS en tabla ENEL_FACTPDS_PORTADA.' ,  v_contador_debug);
   
    
     INSERT INTO ENELEXT.ENEL_FACTPDS_PORTADA ( PERIODO, PERIODSEQ, NUMERO_RESUMEN, MES_LIQUIDACION, FECHA_LIQUIDACION, PAYEESEQ, POSITIONSEQ, CIF, CODIGOE4E,  
                                                ZONA, PDS, NOMBRE_FISCAL, CALLE, COD_POSTAL, POBLACION, PROVINCIA, IDPROVEEDOR, FICHERO, DESCRIPCION, 
                                                CONCEPTO_LIQ, DESC_CONCEPTO_LIQ, COD_CONTRATO, ACTIVIDAD, DETALLE_ACTIVIDAD, PRECIO_UNITARIO, 
                                                CANTIDAD, IMPORTE_TOTAL )   

      SELECT 
            FAPDET.PERIODO,
            FAPDET.PERIODSEQ,
            substr(FAPDET.MES_LIQUIDACION,1,4) || '/'||  FAPDET.PDS as NUMERO_RESUMEN ,  -- YYYY/PDS
            FAPDET.MES_LIQUIDACION,
            v_fechaActual as FECHA_LIQUIDACION,
            FAPDET.PAYEESEQ,
            FAPDET.POSITIONSEQ,
            FAPDET.CIF,
            FAPDET.CODIGOE4E,
            FAPDET.DELEGACION AS ZONA,
            FAPDET.PDS,
            FAPDET.NOMBRE_FISCAL,
            FAPDET.CALLE,
            FAPDET.COD_POSTAL,
            FAPDET.POBLACION,
            FAPDET.PROVINCIA,
            FAPDET.IDPROVEEDOR,
            FAPDET.FICHERO,
            FAPDET.DESCRIPCION,
            FAPDET.CONCEPTO_LIQ,
            FAPDET.DESC_CONCEPTO_LIQ,
            FAPDET.COD_CONTRATO,
            FAPDET.ACTIVIDAD,
            FAPDET.DETALLE_ACTIVIDAD,
            FAPDET.VALUE as PRECIO_UNITARIO,
            sum(FAPDET.CANTIDAD),
            sum(FAPDET.CANTIDAD * FAPDET.VALUE) AS IMPORTE_TOTAL

      FROM ENEL_FACTPDS_DETALLE fapDet
      WHERE FAPDET.PERIODSEQ = iperiodseq

      GROUP BY
            FAPDET.PERIODO,
            FAPDET.PERIODSEQ,
            substr(FAPDET.MES_LIQUIDACION,1,4) || '/'||  FAPDET.PDS,
            FAPDET.MES_LIQUIDACION,
            v_fechaActual,
            FAPDET.PAYEESEQ,
            FAPDET.POSITIONSEQ,
            FAPDET.CIF,
            FAPDET.CODIGOE4E,
            FAPDET.DELEGACION,
            FAPDET.PDS,
            FAPDET.NOMBRE_FISCAL,
            FAPDET.CALLE,
            FAPDET.COD_POSTAL,
            FAPDET.POBLACION,
            FAPDET.PROVINCIA,
            FAPDET.IDPROVEEDOR,
            FAPDET.FICHERO,
            FAPDET.DESCRIPCION,
            FAPDET.CONCEPTO_LIQ,
            FAPDET.DESC_CONCEPTO_LIQ,
            FAPDET.COD_CONTRATO,
            FAPDET.ACTIVIDAD,
            FAPDET.DETALLE_ACTIVIDAD,
            FAPDET.VALUE

      ORDER BY PDS;   
      
     filas := sql%rowcount;
    COMMIT;

    
    w_debug('Fin Carga de la tabla ENEL_FACTPDS_PORTADA: '|| to_char(filas) || ' filas.', v_contador_debug);
    
    EXECUTE IMMEDIATE 'ANALYZE TABLE ENELEXT.ENEL_FACTPDS_PORTADA COMPUTE STATISTICS FOR ALL INDEXES';
    w_debug('Fin Actualizacion Indices ENELEXT.ENEL_FACTPDS_PORTADA.',v_contador_debug);
    
end;

procedure p_Comparativa_Pagos_SCAWEB_E4E ( iprocessingUnitSeq IN VARCHAR2, iperiod IN VARCHAR2,iperiodseq IN VARCHAR2, itenantId IN VARCHAR2 )
AS

begin

    w_debug('Inicio Borrado de la tabla ENEL_COMP_SCAWEB_E4E.', v_contador_debug);
   BEGIN
     LOOP
        DELETE FROM ENELEXT.ENEL_COMP_SCAWEB_E4E WHERE PERIODO = iperiod AND ROWNUM <= 10000;
        EXIT WHEN SQL%ROWCOUNT = 0;
        COMMIT;
     END LOOP;
   END;
    w_debug('Fin Borrado de la tabla ENEL_COMP_SCAWEB_E4E.', v_contador_debug);

    w_debug('Insertando Registros SCAWEB-E4E de datos en tabla ENEL_COMP_SCAWEB_E4E.' ,  v_contador_debug);
    
     INSERT INTO ENELEXT.ENEL_COMP_SCAWEB_E4E ( PERIODO, IDPROVEEDOR, DESCRIPCION, ACTIVIDAD, PDS, NOMBRE_FISCAL, IMPORTE_SCAWEB, E4E_POS_CON_CONTRATO, 
                                                E4E_POS_SIN_CONTRATO, E4E_NEGATIVO,E4E_OPERACIONES )   

      SELECT 
        T_SCAWEB.PERIODO,
        T_SCAWEB.IDPROVEEDOR,
        TMP_PROV.DESCRIPCION,
        TMP_PROV.ACTIVIDAD,
        T_SCAWEB.PDS,
        TMP_PDS.NOMBRE_FISCAL,
        IMPORTE_SCAWEB,
        T_E4E.POSITIVO_CON_CONTRATO,
        T_E4E.POSITIVO_SIN_CONTRATO,
        T_E4E.NEGATIVO,
        T_E4E.OPERACIONES
      FROM
        ( select PERIODO, TRIM(to_char(PROVEEDOR,'000')) IDPROVEEDOR, SCA.CODIGO_AGENTE_INTERNO as PDS, sum(REALVALUE) as IMPORTE_SCAWEB, count(*) registros
            from ENEL_SCAWEB_LIQUIDACION sca where PERIODO = iperiod
            group by PERIODO, TRIM(to_char(PROVEEDOR,'000')) , SCA.CODIGO_AGENTE_INTERNO ) T_SCAWEB
      LEFT JOIN 
        (select TRIM(IDPROVEEDOR) as IDPROVEEDOR, PDS, 
                sum(CASE when VALUE > 0 AND COD_CONTRATO is not null THEN VALUE ELSE 0 END) AS POSITIVO_CON_CONTRATO,
                sum(CASE when VALUE > 0 AND COD_CONTRATO is null THEN VALUE ELSE 0 END) AS POSITIVO_SIN_CONTRATO,
                SUM(CASE when VALUE < 0 THEN VALUE ELSE 0 END) AS NEGATIVO,
                SUM(VALOR_OPERACIONES) AS OPERACIONES
            from ENEL_E4E_DEPOSIT_TEMP where periodseq=iperiodseq
            group by TRIM(IDPROVEEDOR), PDS ) T_E4E
            
       ON TRIM(T_SCAWEB.IDPROVEEDOR) = TRIM(T_E4E.IDPROVEEDOR) AND 
          TRIM(T_SCAWEB.PDS) = TRIM(T_E4E.PDS)
          
       INNER JOIN ENEL_PDS_TEMP TMP_PDS
                      ON T_SCAWEB.PDS=TMP_PDS.PDS

       INNER JOIN ENEL_PROVEEDORES_TEMP TMP_PROV 
                      ON  TRIM(TMP_PROV.IDPROVEEDOR)=TRIM(T_SCAWEB.IDPROVEEDOR);      
      
     filas := sql%rowcount;
    COMMIT;

    
    w_debug('Fin Carga Registros SCAWEB-E4E de la tabla ENEL_COMP_SCAWEB_E4E: '|| to_char(filas) || ' filas.', v_contador_debug);

    w_debug('Insertando Registros E4E-SCAWEB (scaweb nulos) de datos en tabla ENEL_COMP_SCAWEB_E4E.' ,  v_contador_debug);
    
     INSERT INTO ENELEXT.ENEL_COMP_SCAWEB_E4E ( PERIODO, IDPROVEEDOR, DESCRIPCION, ACTIVIDAD, PDS, NOMBRE_FISCAL, IMPORTE_SCAWEB, E4E_POS_CON_CONTRATO,
                                                E4E_POS_SIN_CONTRATO, E4E_NEGATIVO,E4E_OPERACIONES )
      SELECT 
        T_E4E.PERIODO,
        T_E4E.IDPROVEEDOR,
        TMP_PROV.DESCRIPCION,
        TMP_PROV.ACTIVIDAD,
        T_E4E.PDS,
        TMP_PDS.NOMBRE_FISCAL,
        IMPORTE_SCAWEB,
        T_E4E.POSITIVO_CON_CONTRATO,
        T_E4E.POSITIVO_SIN_CONTRATO,
        T_E4E.NEGATIVO,
        T_E4E.OPERACIONES
      FROM
        (select iperiod PERIODO, TRIM(IDPROVEEDOR)  as IDPROVEEDOR, PDS, 
                sum(CASE when VALUE > 0 AND COD_CONTRATO is not null THEN VALUE ELSE 0 END) AS POSITIVO_CON_CONTRATO,
                sum(CASE when VALUE > 0 AND COD_CONTRATO is null THEN VALUE ELSE 0 END) AS POSITIVO_SIN_CONTRATO,
                SUM(CASE when VALUE < 0 THEN VALUE ELSE 0 END) AS NEGATIVO,
                SUM(VALOR_OPERACIONES) AS OPERACIONES
            from ENEL_E4E_DEPOSIT_TEMP where periodseq=iperiodseq
            group by iperiod, TRIM(IDPROVEEDOR), PDS ) T_E4E
            
      LEFT JOIN
       
        ( select PERIODO, trim( to_char(PROVEEDOR,'000')) IDPROVEEDOR, SCA.CODIGO_AGENTE_INTERNO as PDS, sum(REALVALUE) as IMPORTE_SCAWEB, count(*) registros
            from ENEL_SCAWEB_LIQUIDACION sca where PERIODO = iperiod
            group by PERIODO, trim( to_char(PROVEEDOR,'000')) , SCA.CODIGO_AGENTE_INTERNO ) T_SCAWEB
           
       ON TRIM(T_SCAWEB.IDPROVEEDOR) = TRIM(T_E4E.IDPROVEEDOR) AND 
          TRIM(T_SCAWEB.PDS) = TRIM(T_E4E.PDS)
          
       INNER JOIN ENEL_PDS_TEMP TMP_PDS
                      ON T_E4E.PDS=TMP_PDS.PDS

       INNER JOIN ENEL_PROVEEDORES_TEMP TMP_PROV 
                      ON  TRIM(TMP_PROV.IDPROVEEDOR)=TRIM(T_E4E.IDPROVEEDOR)
      
       WHERE T_SCAWEB.IMPORTE_SCAWEB is null;
      
     filas := sql%rowcount;
    COMMIT;

    
    w_debug('Fin Carga Registros E4E-SCAWEB (scaweb nulos) de la tabla ENEL_COMP_SCAWEB_E4E: '|| to_char(filas) || ' filas.', v_contador_debug);
    
    
    EXECUTE IMMEDIATE 'ANALYZE TABLE ENELEXT.ENEL_COMP_SCAWEB_E4E COMPUTE STATISTICS FOR ALL INDEXES';
    w_debug('Fin Actualizacion Indices ENELEXT.ENEL_COMP_SCAWEB_E4E.',v_contador_debug);
    
end;      
      
procedure p_Informe_Resumen_Pagos ( iprocessingUnitSeq IN VARCHAR2, iperiod IN VARCHAR2,iperiodseq IN VARCHAR2, itenantId IN VARCHAR2 )
AS

begin

    w_debug('Inicio Borrado de la tabla ENEL_PAGOS_RESUMEN.', v_contador_debug);
   BEGIN
     LOOP
        DELETE FROM ENELEXT.ENEL_PAGOS_RESUMEN WHERE PERIODO = iperiod AND ROWNUM <= 10000;
        EXIT WHEN SQL%ROWCOUNT = 0;
        COMMIT;
     END LOOP;
   END;
    w_debug('Fin Borrado de la tabla ENEL_PAGOS_RESUMEN.', v_contador_debug);

    w_debug('Insertando Registros de datos en tabla ENEL_PAGOS_RESUMEN.' ,  v_contador_debug);
    
     INSERT INTO ENELEXT.ENEL_PAGOS_RESUMEN ( TENANTID, PERIODSEQ, PERIODO, IDPROVEEDOR, DESCRIPCION, 
                                              TOTAL, VALOR_POS_CON, VALOR_POS_SIN, VALOR_NEG_CON, VALOR_NEG_SIN )   

      SELECT 
            itenantId,
            iperiodseq,
            iperiod,
            TMP_PROV.IDPROVEEDOR,
            TMP_PROV.DESCRIPCION,
            sum(DEPO.VALUE) TOTAL,
            SUM( CASE WHEN DEPO.VALUE>=0 and TMP_CONTRA.COD_CONTRATO is not null then DEPO.VALUE else 0 END ) VALOR_POS_CON,
            SUM( CASE WHEN DEPO.VALUE>=0 and TMP_CONTRA.COD_CONTRATO is null then DEPO.VALUE else 0 END ) VALOR_POS_SIN,
            SUM( CASE WHEN DEPO.VALUE<0 and TMP_CONTRA.COD_CONTRATO is not null then DEPO.VALUE else 0 END ) VALOR_NEG_CON,
            SUM( CASE WHEN DEPO.VALUE<0 and TMP_CONTRA.COD_CONTRATO is null then DEPO.VALUE else 0 END ) VALOR_NEG_SIN

      FROM CS_DEPOSIT DEPO
    
            INNER JOIN CS_PLRUN p ON DEPO.PIPELINERUNSEQ = P.PIPELINERUNSEQ 
                  AND P.MODELSEQ = 0   -- Solo se tienen en cuenta las ejecuciones que no son de simulacion
                                             
            INNER JOIN ENEL_PDS_TEMP TMP_PDS ON 
                DEPO.payeeseq=TMP_PDS.payeeseq 
                and DEPO.POSITIONSEQ=TMP_PDS.RULEELEMENTOWNERSEQ
                and DEPO.periodseq=TMP_PDS.periodseq

            INNER JOIN ENEL_PROVEEDORES_TEMP TMP_PROV 
                ON TMP_PROV.IDPROVEEDOR=DEPO.earninggroupid  
                AND DEPO.periodseq=TMP_PROV.periodseq

              LEFT JOIN ENEL_E4E_CONTRATOS_TEMP TMP_CONTRA
                ON TMP_CONTRA.periodseq=DEPO.periodseq  
                AND TMP_CONTRA.PDS = TMP_PDS.PDS                 
                AND TMP_CONTRA.ACTIVIDAD_DETALLADA=TMP_PROV.DETALLE_ACTIVIDAD
                AND TMP_CONTRA.periodseq=TMP_PROV.periodseq                

        WHERE DEPO.TENANTID = itenantId
              AND DEPO.periodseq=iperiodseq        
              AND DEPO.PROCESSINGUNITSEQ =  iprocessingUnitSeq
        GROUP BY TMP_PROV.IDPROVEEDOR, TMP_PROV.DESCRIPCION;

     filas := sql%rowcount;
    COMMIT;

    
    w_debug('Fin Carga de la tabla ENEL_PAGOS_RESUMEN: '|| to_char(filas) || ' filas.', v_contador_debug);

    EXECUTE IMMEDIATE 'ANALYZE TABLE ENELEXT.ENEL_PAGOS_RESUMEN COMPUTE STATISTICS FOR ALL INDEXES';
    w_debug('Fin Actualizacion Indices ENELEXT.ENEL_PAGOS_RESUMEN.',v_contador_debug);
    
end;


--ENEL_GRALPROV_DETALLE
procedure p_Inf_GeneralProv_Det ( iprocessingUnitSeq IN VARCHAR2, iperiod IN VARCHAR2,iperiodseq IN VARCHAR2, itenantId IN VARCHAR2 )
AS

begin

    w_debug('Inicio Borrado de la tabla ENEL_GRALPROV_DETALLE.', v_contador_debug);
   BEGIN
     LOOP
        DELETE FROM ENELEXT.ENEL_GRALPROV_DETALLE WHERE PERIODO = iperiod AND ROWNUM <= 10000;
        EXIT WHEN SQL%ROWCOUNT = 0;
        COMMIT;
     END LOOP;
   END;
    w_debug('Fin Borrado de la tabla ENEL_GRALPROV_DETALLE.', v_contador_debug);

    w_debug('Insertando Registros de datos en tabla ENEL_GRALPROV_DETALLE.' ,  v_contador_debug);
    
     INSERT INTO ENELEXT.ENEL_GRALPROV_DETALLE ( PERIODO, IDPROVEEDOR, DESCRIPCION, ACTIVIDAD, PDS, NOMBRE_FISCAL, TIPO_IMPOSITIVO, 
                                                 DELEGACION, ZONA, TERRITORIO, IMPORTEBASE )   

      SELECT 
        iperiod,
        ept.IDPROVEEDOR,
        ept.DESCRIPCION,
        ept.ACTIVIDAD,
        EPDS.PDS,
        EPDS.NOMBRE_FISCAL,            
        EPDS.TIPO_IMPOSITIVO,
        EPDS.DELEGACION,
        EPDS.ZONA,
        EPDS.TERRITORIO,
        sum(edt.VALUE) IMPORTEBASE
            
      FROM ENEL_PROVEEDORES_TEMP ept
    
        LEFT JOIN ENEL_DEPOSIT_TEMP edt 
             ON EPT.IDPROVEEDOR = edt.EARNINGGROUPID

        LEFT JOIN ENEL_PDS_TEMP epds
             ON  EPDS.RULEELEMENTOWNERSEQ = edt.positionseq
             AND EPDS.PAYEESEQ = edt.payeeseq
             
        GROUP BY iperiod, 
                 ept.IDPROVEEDOR,
                 EPT.DESCRIPCION,
                 ept.actividad,
                 EPDS.PDS,
                 EPDS.NOMBRE_FISCAL,
                 EPDS.TIPO_IMPOSITIVO,
                 EPDS.DELEGACION,
                 EPDS.ZONA,
                 EPDS.TERRITORIO;            

     filas := sql%rowcount;
    COMMIT;

    
    w_debug('Fin Carga de la tabla ENEL_GRALPROV_DETALLE: '|| to_char(filas) || ' filas.', v_contador_debug);

    EXECUTE IMMEDIATE 'ANALYZE TABLE ENELEXT.ENEL_GRALPROV_DETALLE COMPUTE STATISTICS FOR ALL INDEXES';
    w_debug('Fin Actualizacion Indices ENELEXT.ENEL_GRALPROV_DETALLE.',v_contador_debug);
    
end;



-- Comrpueba si el periodo está Liquidado ya o no. Si está Liquidado, los datos de andrómeda no deben actualizarse
function f_ComprobarPeriodoLiquidado ( iprocessingUnitSeq IN VARCHAR2, iperiod IN VARCHAR2,iperiodseq IN VARCHAR2, itenantId IN VARCHAR2 ) return boolean as   
    v_liquidado BOOLEAN;
    v_checkCountEstado integer;
begin

  
   -- Se comprueba si existe la marca de PERIODO LIQUIDADO para el Periodo y la Unidad de proceso
   SELECT count(ESTADO)
     into v_checkCountEstado
   FROM ENELEXT.ENEL_PERIODOS_LIQUIDADOS epl 
   WHERE epl.PERIODO = iperiod 
     AND epl.PROCESSINGUNITSEQ=iprocessingUnitSeq;
 
    IF v_checkCountEstado > 0 THEN
        v_liquidado := true;
        w_debug(' Comprobar Estado del Periodo : LIQUIDADO - '||  iperiod ||' Unidad Proceso: '|| to_char(iprocessingUnitSeq) ,  v_contador_debug);
    ELSE
        v_liquidado := false;    
        w_debug(' Comprobar Estado del Periodo : NO Liquidado - '||  iperiod ||' Unidad Proceso: '|| to_char(iprocessingUnitSeq) ,  v_contador_debug);
    END IF;
    
    return v_liquidado;  
    
end;           
            
   ---------------- Actualizamos la tabla que indica la fecha y hora de actualizaci¿n del informes-------------
procedure p_Actualiza_Informe_Fecha ( iPeriod IN VARCHAR2, iInforme IN varchar2)
AS
    
begin

    MERGE INTO ENELEXT.ENEL_FECHAS_WEBI tabla
    USING (SELECT iPeriod as mes, iInforme as tabla from dual) condicion
    ON (tabla.periodo = condicion.mes and tabla.tabla=condicion.tabla)
    WHEN MATCHED THEN UPDATE SET
    tabla.ultima_actualizacion = FROM_TZ(CAST(sysdate AS TIMESTAMP), to_char(cast(systimestamp as TIMESTAMP WITH TIME ZONE),'TZH:TZM')) AT TIME ZONE 'Europe/Madrid'
    WHEN NOT MATCHED THEN
    INSERT  (periodo, tabla, ultima_actualizacion, descripcion)
    VALUES  (
    condicion.mes,
    condicion.tabla,
    FROM_TZ(CAST(sysdate AS TIMESTAMP), to_char(cast(systimestamp as TIMESTAMP WITH TIME ZONE),'TZH:TZM')) AT TIME ZONE 'Europe/Madrid',
    'Ultima carga de la tabla '|| iInforme
    );

    COMMIT;

    w_debug('Fin carga ENELEXT.ENEL_FECHAS_WEBI para Informe: ' ||iInforme,v_contador_debug );
    
    
end;








/******************************
    RUN
******************************/

  PROCEDURE RUN(calendar IN VARCHAR2,calendarSeq IN VARCHAR2,groupid IN VARCHAR2,period IN VARCHAR2,
                  periodSeq IN VARCHAR2,processingUnit IN VARCHAR2,processingUnitSeq IN VARCHAR2,
                stage IN VARCHAR2,userName IN VARCHAR2,triggerFilename IN VARCHAR2,tenantId IN VARCHAR2,
                salidacontrol out varchar2,informe varchar2 ) IS
    
  v_Interfaz_Proceso  nvarchar2(50);  
  v_Listado_Informes  nvarchar2(500);
  v_PeriodoLiquidado boolean;
      
 BEGIN
    
    --Iniciamos el contador del Debug
    v_contador_debug := 0;
     
    
    w_debug('Procedure starting...', v_contador_debug);
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
    w_debug('Argumento: informe              : ['||informe            ||']',V_CONTADOR_DEBUG);  


    
    
    --------------- Comprobar si es una ejecuci?n por StageHook o manual --------------
    
    if  triggerFilename = 'EJECUCION_MANUAL' then
    
        w_debug('Peticion de ejecucion manual con periodo '||period, v_contador_debug);
        w_debug('Informes a actualizar  '||informe, v_contador_debug);
        v_Interfaz_Proceso := 'ACTUALIZA_INFORMES_MANUAL';
        if informe = '' or informe is null then  -- MRA 
            v_Listado_Informes := 'ALL';
            w_debug('Argumento Actualizado : informe : ['||v_Listado_Informes            ||'] (EJECUCION_MANUAL)',V_CONTADOR_DEBUG);
        else
            v_Listado_Informes := informe;
        end if;

        
    else
        w_debug('Peticion de ejecucion StageHook con periodo '|| period, v_contador_debug);
        
        
           CASE stage 
            WHEN 'Reward__'  then v_Interfaz_Proceso := 'ACTUALIZA_INFORMES_REWARD';  
            WHEN 'Post__'    then v_Interfaz_Proceso := 'ACTUALIZA_INFORMES_POST';
            WHEN 'Pay__'     then v_Interfaz_Proceso := 'ACTUALIZA_INFORMES_PAY';
            ELSE BEGIN
                    w_debug('stage '||stage||' No contemplado. Salimos...', v_contador_debug);
                    RETURN;
                END;
        end CASE;
    
        p_Datos_Interfaz(v_Interfaz_Proceso);    
        w_debug('Informes a actualizar  '||v_ARGUMENTOS, v_contador_debug);
        v_Listado_Informes := v_ARGUMENTOS;
    
              
        if v_ACTIVO <> 1 then
            w_debug('Interfaz '||v_Interfaz_Proceso||' NO ACTIVO. Salimos...', v_contador_debug);
            salidacontrol :='Salida '||v_Interfaz_Proceso||' no activa.';
            RETURN;
        else 
            w_debug('Interfaz '||v_Interfaz_Proceso||' ACTIVO.', v_contador_debug);
        end if;    
        
    end if; 
    
    
    salidacontrol :='Procedure '||v_Interfaz_Proceso||' comenzando';
    
        
-- Se comprueba si el periodo Ya ha sido liquidado. 
    v_PeriodoLiquidado := f_ComprobarPeriodoLiquidado( processingUnitSeq, period ,periodSeq , tenantId  );
    
-- SI EL PERIODO NO SE HA LIQUIDADO, SE EXTRAEN DE NUEVO LOS DATOS PARA LOS INFORMES      
    IF  v_PeriodoLiquidado = false THEN
    ------------------------------------------------------------
    -- Datos Generales que se usan en varios informes
    ------------------------------------------------------------
  
        -- Volcar datos de las tablas de transacciones a una tabla temporal. Tabla ENEL_TXN_TEMP
        p_Temporal_Transacciones ( processingUnitSeq, period ,periodSeq , tenantId  );
        -- Volcar datos de la tabla de créditos a una tabla temporal. Tabla ENEL_CREDIT_TEMP
        p_Temporal_Creditos ( processingUnitSeq, period ,periodSeq , tenantId  );
        -- Volcar datos de la tabla de incentivos a una tabla temporal. Tabla ENEL_INCEN_TEMP
        p_Temporal_Incentivos ( processingUnitSeq, period ,periodSeq , tenantId  );
        -- Volcar datos de la tabla de Depósitos a una tabla temporal. Tabla ENEL_DEPOSIT_TEMP
        p_Temporal_Depositos ( processingUnitSeq, period ,periodSeq , tenantId  );
            
        -- Volcar datos de clasificacion a una Temporal de Proveedores. Tabla ENEL_PROVEEDORES_TEMP
        p_Temporal_Proveedores ( period ,periodSeq , tenantId  );
        -- Volcar datos de clasificacion a una Temporal de Equipamientos Tabla ENEL_EQUIPAMIENTO_TEMP        
        p_Temporal_Equipamientos ( period ,periodSeq , tenantId  );
        -- Volcar datos de Posiciones y participantes a una Temporal de PDS. Tabla: ENEL_PDS_TEMP
        p_Temporal_Pds ( processingUnitSeq, period ,periodSeq , tenantId  );
        -- Volcar datos de clasificacion a una Temporal de Operaciones Tabla ENEL_OPERACIONES_TEMP        
        p_Temporal_Operaciones ( period ,periodSeq , tenantId  );   
        -- Volcar datos de Productos a una Temporal Tabla ENEL_PRODUCTOS_TEMP   
        p_Temporal_Productos ( period ,periodSeq , tenantId  );
            
    ------------------------------------
    -- Datos para INTERFACE ANDROMEDA
    ------------------------------------


            p_Temporal_Creditos_Andromeda ( processingUnitSeq, period ,periodSeq , tenantId  );        
            -- Extraer datos de transacciones  -> Tabla : ENEL_ANDROMEDA_TXN_TEMP
            p_Temporal_TXN_Andromeda ( processingUnitSeq, period ,periodSeq , tenantId  );        
    
    
    --------------------------------
    -- Datos para INTERFACE E4E
    --------------------------------

        -- Volcar datos de clasificaci?n a una Temporal de Contratos.     Tabla ENEL_E4E_CONTRATOS_TEMP
           p_Temporal_Contratos_E4E ( period ,periodSeq , tenantId  );
   
        -- Extraer datos de Dep?sitos y JOIN con tablas temporales Tabla: ENEL_E4E_DEPOSIT_TEMP
           p_Temporal_Depositos_E4E ( processingUnitSeq, period ,periodSeq , tenantId, v_Interfaz_Proceso  );
    

    ------------------------------------
    -- Datos para INTERFACE SCAWEB
    ------------------------------------

    --------------------------------
    -- Datos para INFORME SMTP
    --------------------------------    

    --------------------------------
    -- Datos para INFORME ICISA
    --------------------------------    
        
    --------------------------------
    -- Datos para INFORMES PDS -INFPDS
    --------------------------------    


        -- Extraer datos de Transacciones para informes del PDS
         p_Temporal_TXN_INFPDS ( processingUnitSeq, period ,periodSeq , tenantId  );
        
        -- Extraer datos de Créditos para informes del PDS        
         p_Temporal_Creditos_INFPDS ( processingUnitSeq, period ,periodSeq , tenantId  );


    ---------------------------------------------------
    -- Datos para INFORMES GENERAL DE PROVEEDORES
    ---------------------------------------------------    
  
    ---------------------------------------------------
    -- Datos para FACTURA OCAPS
    ---------------------------------------------------

        
    --------------------------------
    -- Datos para Mensual de Liquidación SCAWEB
    --------------------------------    

 
    ---------------------------------------------------
    -- Datos para FACTURA PDS
    ---------------------------------------------------
  
 
  ELSE
        w_debug('Periodo YA Liquidado. NO se actualizan Datos de INFORMES', v_contador_debug);
  end if;
      
    w_debug('Procedure END', v_contador_debug);
    salidacontrol :='Procedure '||v_Interfaz_Proceso||' END';
    
    COMMIT;    
            
  END;

END;
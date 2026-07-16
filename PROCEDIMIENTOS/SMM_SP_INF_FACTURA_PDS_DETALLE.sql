CREATE OR REPLACE PROCEDURE EXT.SMM_SP_INF_FACTURA_PDS_DETALLE( IN i_processingUnitSeq BIGINT ,IN i_period VARCHAR(25), IN i_periodseq BIGINT)
LANGUAGE SQLSCRIPT
SQL SECURITY INVOKER 
DEFAULT SCHEMA EXT AS
/*---------------------------------------------------------------------
    | Author: Samuel Miralles Manresa
    | Company: Inycom
    | Initial Version Date: 
    |----------------------------------------------------------------------
    | Procedure Purpose: FATURA PDS - DETALLE - Prefactura Portada/Detalle
    |
	| Version:	0.1	SMM	   Initial Version.
	|
    -----------------------------------------------------------------------
*/
BEGIN
    DECLARE v_cont INT = 0;
	DECLARE v_proc_name NVARCHAR(50) := ::CURRENT_OBJECT_SCHEMA ||'.'|| ::CURRENT_OBJECT_NAME;
	DECLARE v_version NVARCHAR(4) := '0.1';
	DECLARE v_log_count INTEGER := 0;
	DECLARE v_idproceso BIGINT := 0;
	DECLARE v_tenantid NVARCHAR(4) := EXT.LIB_GLOBAL_ENDESA:getTenantID();
	DECLARE v_permisos_log NVARCHAR(50) := EXT.LIB_GLOBAL_ENDESA:GET_PERMISOS_LOG();
	DECLARE v_eot DATE := EXT.LIB_CONSTANTES_ENDESA:v_eot;
	DECLARE v_finicio TIMESTAMP = CURRENT_TIMESTAMP;
	DECLARE v_contador_ctrl_inf INT;
	DECLARE v_num_ejecucion INT;
	DECLARE v_fechaPeriodoSiguiente DATE;
	DECLARE v_txtMes_Liquidacion VARCHAR(20);
	
	
	

	DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name, 'Error en procedimiento principal ' || v_proc_name || ' - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'')
																											|| '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, v_log_count, v_idproceso, 'error');
		CALL EXT.SMM_SP_Z_CTRL_INF(v_contador_ctrl_inf, v_num_ejecucion, v_proc_name, v_finicio, current_timestamp, 'Error:'||::SQL_ERROR_CODE||::SQL_ERROR_MESSAGE);																									
																							
		RESIGNAL;
	END;
	
	-- v_ultimo_dia_periodo := EXT.SMM_F_ULTIMO_DIA_PERIODO(i_periodseq);
	
	CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name, 'Procedure starting for: ' || v_proc_name, v_log_count, v_idproceso,'info');
	CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name, 'Argumentos del proceso: ' 
		|| ' || i_processingUnitSeq: ' || i_processingUnitSeq
		|| ' || i_period: ' || i_period
		|| ' || i_periodseq: ' || i_periodseq
		, v_log_count, v_idproceso,'info');
	
	--SMM_FACTPDS_DETALLE
	CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Inicio borrado de la tabla SMM_FACTPDS_DETALLE.', v_log_count, v_idproceso,'info');
	DELETE FROM EXT.SMM_FACTPDS_DETALLE WHERE PERIODO = i_period;
	CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Fin borrado de la tabla SMM_FACTPDS_DETALLE.', v_log_count, v_idproceso,'info');
	
	-- Se extrae la fecha inicial del siguiente mes al periodSeq del proceso
    v_fechaPeriodoSiguiente :=  EXT.SMM_F_PRIMER_DIA_PERIODO_SIGUIENTE(i_periodseq);
    
    -- Se convierte a texto en formato DD/MM/YYYY para los registros de salida
    v_txtMes_Liquidacion := to_char(v_fechaPeriodoSiguiente, 'YYYYMM');
    
    CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, v_proc_name,'Insertando Registros de datos en tabla EXT.SMM_FACTPDS_DETALLE.' , v_log_count, v_idproceso,'info');
    
	INSERT INTO EXT.SMM_FACTPDS_DETALLE ( PERIODO, PERIODSEQ, MES_LIQUIDACION, CREDITSEQ, CREDITTYPEID, PAYEESEQ, POSITIONSEQ, 
                                                PDS, NOMBRE_FISCAL, CIF, IDPROVEEDOR, DESCRIPCION, FICHERO, ACTIVIDAD, DETALLE_ACTIVIDAD, CODIGOE4E,DELEGACION,
                                                ZONA, TERRITORIO, CALLE, COD_POSTAL, PROVINCIA, POBLACION, CANTIDAD, VALUE, SOLICITUD_SERVICIO, CONCEPTO_LIQ, DESC_CONCEPTO_LIQ, 
                                                COD_CONTRATO, EVENTYPEID, CONTRATO, PRODUCTID, COD_POSTAL_DETALLE, COD_COMERCIAL, MARCA, MODELO, OBSERVACIONES, WBE, CUPS )   
    SELECT
    CREDTMP.PERIODO,
    CREDTMP.PERIODSEQ,
    :v_txtMes_Liquidacion AS MES_LIQUIDACION,
    CREDTMP.CREDITSEQ,
    CREDTMP.CREDITTYPEID,
    TMP_PDS.PAYEESEQ,
    TMP_PDS.RULEELEMENTOWNERSEQ,
    TMP_PDS.PDS,
    TMP_PDS.NOMBRE_FISCAL,
    TMP_PDS.CIF,
    TMP_PROV.IDPROVEEDOR,
    TMP_PROV.DESCRIPCION,
    TMP_PROV.FICHERO,
    TMP_PROV.ACTIVIDAD,
    TMP_PROV.DETALLE_ACTIVIDAD,
    TMP_PDS.PAR_PROVEEDOR AS CODIGOE4E,
    TMP_PDS.DELEGACION,
    TMP_PDS.ZONA,
    TMP_PDS.TERRITORIO,
    TMP_PDS.CALLE,
    TMP_PDS.COD_POSTAL,
    TMP_PDS.PROVINCIA,
    TMP_PDS.POBLACION,
    1 AS CANTIDAD,
    CREDTMP.VALUE,

    CASE
        WHEN UPPER(CREDTMP.CREDITTYPEID) LIKE 'INSTALACION%'
          OR UPPER(CREDTMP.CREDITTYPEID) LIKE 'PRESTACION%'
        THEN CREDTMP.GENERICATTRIBUTE9
        ELSE ''
    END AS SOLICITUD_SERVICIO,

    CREDTMP.GENERICATTRIBUTE1 AS CONCEPTO_LIQ,

    COALESCE(
        CREDTMP.GENERICATTRIBUTE14,
        TMP_PROD.DESCRIPTION,
        CREDTMP.GENERICATTRIBUTE1
    ) AS DESC_CONCEPTO_LIQ,

    TMP_CONTRA.COD_CONTRATO,

    TXNTMP.EVENTYPEID,

    COALESCE(
        TXNTMP.PONUMBER,
        TXNTMP.ORDERID
    ) AS CONTRATO,

    TXNTMP.PRODUCTID,
    TXNTMP.TAD_POSTALCODE AS COD_POSTAL_DETALLE,
    TXNTMP.TAS_GENERICATTRIBUTE1 AS COD_COMERCIAL,

    EET.MARCA,
    EET.MODELO,

    CREDTMP.GENERICATTRIBUTE15,
    CREDTMP.GENERICATTRIBUTE11,
    TXNTMP.ALTERNATEORDERNUMBER

FROM EXT.SMM_CREDIT_TEMP CREDTMP

INNER JOIN EXT.SMM_TXN_TEMP TXNTMP
    ON TXNTMP.SALESTRANSACTIONSEQ = CREDTMP.SALESTRANSACTIONSEQ
   AND TXNTMP.PERIODSEQ = CREDTMP.PERIODSEQ
   AND TXNTMP.PERIODSEQ = :I_PERIODSEQ

INNER JOIN EXT.SMM_PDS_TEMP TMP_PDS
    ON TMP_PDS.RULEELEMENTOWNERSEQ = CREDTMP.POSITIONSEQ
   AND TMP_PDS.PERIODSEQ = :I_PERIODSEQ

INNER JOIN EXT.SMM_PROVEEDORES_TEMP TMP_PROV
    ON TMP_PROV.IDPROVEEDOR = CREDTMP.GENERICATTRIBUTE2
   AND TMP_PROV.PERIODSEQ = :I_PERIODSEQ

LEFT JOIN EXT.SMM_PRODUCTOS_TEMP TMP_PROD
    ON TMP_PROD.PRODUCTID = CREDTMP.GENERICATTRIBUTE1
   AND TMP_PROD.PERIODSEQ = :I_PERIODSEQ

LEFT JOIN EXT.SMM_EQUIPAMIENTO_TEMP EET
    ON EET.IDMARCA = TXNTMP.GENERICATTRIBUTE8
   AND EET.IDMODELO = TXNTMP.GENERICATTRIBUTE9
   AND EET.PERIODSEQ = :I_PERIODSEQ

LEFT JOIN EXT.SMM_E4E_CONTRATOS_TEMP TMP_CONTRA
    ON TMP_CONTRA.PDS = TMP_PDS.PDS
   AND TMP_CONTRA.ACTIVIDAD = TMP_PROV.ACTIVIDAD
   AND TMP_CONTRA.ACTIVIDAD_DETALLADA = TMP_PROV.DETALLE_ACTIVIDAD
   AND TMP_CONTRA.PERIODSEQ = :I_PERIODSEQ

WHERE
(
       UPPER(CREDTMP.CREDITTYPEID) LIKE 'CAPTACION%'
    OR UPPER(CREDTMP.CREDITTYPEID) LIKE 'PRESTACION%'
    OR UPPER(CREDTMP.CREDITTYPEID) LIKE 'INSTALACION%'
    OR UPPER(CREDTMP.CREDITTYPEID) LIKE 'ATC - AJUSTE MANUAL'
    OR UPPER(CREDTMP.CREDITTYPEID) LIKE 'ATC - EFACTURA PULL'
    OR UPPER(CREDTMP.CREDITTYPEID) LIKE 'CAPTACION SW - AJUSTE MANUAL'
    OR UPPER(CREDTMP.CREDITTYPEID) LIKE 'CAPTACION CNS - AJUSTE MANUAL'
    OR UPPER(CREDTMP.CREDITTYPEID) LIKE 'CAPTACION ASESOR - AJUSTE MANUAL'
    OR UPPER(CREDTMP.CREDITTYPEID) LIKE 'VENTA EXT.SMMX%'
    OR UPPER(CREDTMP.CREDITTYPEID) LIKE 'INSTALACI%N EXT.SMMX%'
    OR UPPER(CREDTMP.CREDITTYPEID) LIKE 'RETROCOMISION EXT.SMMX%'
    OR UPPER(CREDTMP.CREDITTYPEID) LIKE 'CAPTACION - PRESCRIPTOR'
    OR UPPER(CREDTMP.CREDITTYPEID) LIKE 'CCPP -%'
    OR UPPER(CREDTMP.CREDITTYPEID) LIKE 'AJUSTE VENTA EXT.SMMX - CANAL PRESENCIAL%'
    OR UPPER(CREDTMP.CREDITTYPEID) LIKE 'COMISIONADO ACT COMERCIAL - IMPORTE'
    OR UPPER(CREDTMP.CREDITTYPEID) LIKE 'CAPTACION - MAS ORANGE%'
    OR UPPER(CREDTMP.CREDITTYPEID) LIKE 'BAJAS - MAS ORANGE%'
    OR UPPER(CREDTMP.CREDITTYPEID) LIKE 'AJUSTE MANUAL - MAS ORANGE'
    OR UPPER(CREDTMP.CREDITTYPEID) LIKE 'ACTIVACION - IMPORTE BASE'
    OR UPPER(CREDTMP.CREDITTYPEID) LIKE 'ACTIVACION - IMPORTE TARIFAS'
    OR UPPER(CREDTMP.CREDITTYPEID) LIKE 'BAJA - IMPORTE BASE'
    OR UPPER(CREDTMP.CREDITTYPEID) LIKE 'BAJA - IMPORTE BASE - PRESCRIPTOR'
    OR UPPER(CREDTMP.CREDITTYPEID) LIKE 'ACTIVACION - PRESCRIPTOR'
    OR UPPER(CREDTMP.CREDITTYPEID) LIKE 'BAJA - RAPPEL - FRONT'
    OR UPPER(CREDTMP.CREDITTYPEID) LIKE 'BAJA - RAPPEL - PRESCRIPTOR'
)
AND CREDTMP.GENERICATTRIBUTE1 IS NOT NULL
AND CREDTMP.GENERICATTRIBUTE2 IS NOT NULL
AND CREDTMP.GENERICATTRIBUTE2 <> '000'
AND CREDTMP.GENERICATTRIBUTE15 NOT LIKE 'Prescriptor'
AND CREDTMP.GENERICBOOLEAN1 = 1
AND CREDTMP.PERIODSEQ = :I_PERIODSEQ

AND (
        UPPER(CREDTMP.CREDITTYPEID) NOT LIKE 'CAPTACION%'
        OR TMP_PROD.PROVEEDOR_CAPTACION IS NOT NULL
    );
 --   SELECT 
 --       credtmp.PERIODO, 
 --       credtmp.PERIODSEQ,
 --       v_txtMes_Liquidacion as Mes_Liquidacion,
 --       credtmp.CREDITSEQ, 
 --       credtmp.CREDITTYPEID ,
 --       TMP_PDS.PAYEESEQ,
 --       TMP_PDS.RULEELEMENTOWNERSEQ ,  -- POSITIONSEQ
 --       TMP_PDS.PDS, 
 --       TMP_PDS.NOMBRE_FISCAL,
 --       TMP_PDS.CIF,
 --       TMP_PROV.IDPROVEEDOR, 
 --       TMP_PROV.DESCRIPCION,
 --       TMP_PROV.FICHERO,
 --       TMP_PROV.ACTIVIDAD,
 --       TMP_PROV.DETALLE_ACTIVIDAD,
 --       TMP_PDS.PAR_PROVEEDOR as CODIGOE4E,
 --       TMP_PDS.DELEGACION,
 --       TMP_PDS.ZONA,
 --       TMP_PDS.TERRITORIO,
 --       TMP_PDS.CALLE,
 --       TMP_PDS.COD_POSTAL,
 --       TMP_PDS.PROVINCIA,
 --       TMP_PDS.POBLACION, 
 --       1 AS CANTIDAD,           
 --       credtmp.VALUE,
 --       case 
 --           when CREDTMP.CREDITTYPEID like 'Instalacion%' or CREDTMP.CREDITTYPEID like 'Prestacion%' THEN credtmp.GENERICATTRIBUTE9 
	-- 		ELSE '' 
 --       END AS solicitud_servicio,      -- Solicitud de servicio (solo prestacion e Instalacion)
 --       credtmp.GenericAttribute1 as CONCEPTO_LIQ,    --Concepto liquidacion
 --       CASE 
 --           WHEN credtmp.GenericAttribute14 is not null THEN credtmp.GenericAttribute14                             -- Si existe GA14 --> GA14,
 --           WHEN credtmp.GenericAttribute14 is null AND TMP_PROD.DESCRIPTION is not null THEN TMP_PROD.DESCRIPTION  -- Si no existe GA14 pero si hay Descrip Producto
 --           else credtmp.GenericAttribute1 
 --       END AS DESC_CONCEPTO_LIQ,                                             -- Si no Se pone el GA1 --> Concepto de Liquidacion
 --       TMP_CONTRA.COD_CONTRATO,  -- PAra saber si tiene pedido o no
 --       TXNTMP.EVENTYPEID,
 --       /*BOM APM 07.07.2026 Old Code*/
 --       --TXNTMP.PONUMBER as CONTRATO,
 --       --New Code
 --       CASE 
 --           WHEN TXNTMP.PONUMBER is not null THEN TXNTMP.PONUMBER                             
 --           WHEN TXNTMP.PONUMBER is null THEN TXNTMP.ORDERID  -- Si no está relleno el PONUMBER, poner el ORDERID
 --       END AS CONTRATO,        
 --       /*EOM APM 07.07.2026*/
 --       TXNTMP.PRODUCTID, 
 --       TXNTMP.TAD_POSTALCODE AS COD_POSTAL_DETALLE,
 --       TXNTMP.TAS_GENERICATTRIBUTE1 AS COD_COMERCIAL,
 --       --EET.MARCA,
 --       --EET.MODELO,
 --       (select MARCA from EXT.SMM_EQUIPAMIENTO_TEMP EET where eet.periodseq = i_periodseq and TXNTMP.GENERICATTRIBUTE8 = EET.IDMARCA AND TXNTMP.GENERICATTRIBUTE9 = EET.IDMODELO ) as MARCA,
 --       (select MODELO from EXT.SMM_EQUIPAMIENTO_TEMP EET where eet.periodseq = i_periodseq and TXNTMP.GENERICATTRIBUTE8 = EET.IDMARCA AND TXNTMP.GENERICATTRIBUTE9 = EET.IDMODELO ) as MODELO,
 --       credtmp.genericattribute15,
 --       credtmp.genericattribute11,
 --       TXNTMP.ALTERNATEORDERNUMBER
        

 --   FROM EXT.SMM_CREDIT_TEMP CREDTMP
 --       INNER JOIN EXT.SMM_TXN_TEMP TXNTMP 
 --           ON CREDTMP.SALESTRANSACTIONSEQ=TXNTMP.SALESTRANSACTIONSEQ
 --           and CREDTMP.PERIODSEQ=TXNTMP.PERIODSEQ
 --           AND TXNTMP.PERIODSEQ = i_periodseq
        
 --       INNER JOIN EXT.SMM_PDS_TEMP TMP_PDS 
 --           ON CREDTMP.POSITIONSEQ=TMP_PDS.RULEELEMENTOWNERSEQ 
 --           and tmp_pds.periodseq = i_periodseq
        
 --       INNER JOIN EXT.SMM_PROVEEDORES_TEMP TMP_PROV 
 --           ON TMP_PROV.IDPROVEEDOR=CREDTMP.GENERICATTRIBUTE2 
 --           and TMP_PROV.periodseq = i_periodseq
    
 --       LEFT JOIN EXT.SMM_PRODUCTOS_TEMP TMP_PROD 
 --           ON TMP_PROD.PRODUCTID=CREDTMP.GENERICATTRIBUTE1 
 --           and tmp_prod.periodseq = i_periodseq
            
 --       LEFT JOIN EXT.SMM_E4E_CONTRATOS_TEMP TMP_CONTRA 
 --           ON TMP_CONTRA.PDS = TMP_PDS.PDS 
 --           AND TMP_CONTRA.periodseq = i_periodseq
 --           AND TMP_CONTRA.ACTIVIDAD = TMP_PROV.ACTIVIDAD 
 --           AND TMP_CONTRA.ACTIVIDAD_DETALLADA=TMP_PROV.DETALLE_ACTIVIDAD
  
 --   /* comentamos la condicion antigua -- condicion de DEV          
 --       WHERE ( CREDTMP.CREDITTYPEID like 'Captacion%' OR
 --               CREDTMP.CREDITTYPEID like 'Prestacion%' OR
 --               CREDTMP.CREDITTYPEID like 'Instalacion%' OR
 --               credtmp.credittypeid like 'ATC - Ajuste Manual') AND
 --               CREDTMP.GENERICATTRIBUTE1 is not null  AND
 --               CREDTMP.GENERICATTRIBUTE2 is not null   AND CREDTMP.GENERICATTRIBUTE2 <> '000' AND
 --               CREDTMP.GENERICBOOLEAN1 = 1;    
 --   */
 --   WHERE ( UPPER(CREDTMP.CREDITTYPEID) LIKE 'CAPTACION%' 
 --           OR UPPER(CREDTMP.CREDITTYPEID) LIKE 'PRESTACION%' 
 --           OR UPPER(CREDTMP.CREDITTYPEID) LIKE 'INSTALACION%' 
 --           OR UPPER(CREDTMP.CREDITTYPEID) LIKE 'ATC - AJUSTE MANUAL'
	-- 		OR UPPER(CREDTMP.CREDITTYPEID) LIKE 'ATC - EFACTURA PULL'
	-- 		OR UPPER(CREDTMP.CREDITTYPEID) LIKE 'CAPTACION SW - AJUSTE MANUAL'
	-- 		OR UPPER(CREDTMP.CREDITTYPEID) LIKE 'CAPTACION CNS - AJUSTE MANUAL'
	-- 		-- MPR condicion para Asesor
	-- 		or UPPER(CREDTMP.CREDITTYPEID) LIKE 'CAPTACION ASESOR - AJUSTE MANUAL'
 --           /*BOM 12.12.2023 APM*/
 --           OR UPPER(CREDTMP.CREDITTYPEID) like 'VENTA EXT.SMMX%'
 --           OR UPPER(CREDTMP.CREDITTYPEID) like 'INSTALACI%N EXT.SMMX%'
 --           /*EOM 12.12.2023 APM*/
 --           OR UPPER(CREDTMP.CREDITTYPEID) like 'RETROCOMISION EXT.SMMX%' --APM 29.12.2023
 --           OR UPPER(CREDTMP.CREDITTYPEID) like 'CAPTACION - PRESCRIPTOR' --APM 16.02.2024
 --           OR UPPER(CREDTMP.CREDITTYPEID) LIKE 'CCPP -%'
 --           OR UPPER(CREDTMP.CREDITTYPEID) LIKE 'AJUSTE VENTA EXT.SMMX - CANAL PRESENCIAL%' --APM 05.11.2024
 --           OR UPPER(CREDTMP.CREDITTYPEID) LIKE 'COMISIONADO ACT COMERCIAL - IMPORTE' --APM 13.01.2026
 --           /*BOM APM 19.03.2026*/
 --           OR UPPER(CREDTMP.CREDITTYPEID) LIKE 'CAPTACION - MAS ORANGE%'
 --           OR UPPER(CREDTMP.CREDITTYPEID) LIKE 'BAJAS - MAS ORANGE%'
 --           OR UPPER(CREDTMP.CREDITTYPEID) LIKE 'AJUSTE MANUAL - MAS ORANGE'
 --           /*EOM APM 19.03.2026*/
 --           /*BOM APM 23.06.2026 New Code*/
 --           OR UPPER(CREDTMP.CREDITTYPEID) LIKE 'ACTIVACION - IMPORTE BASE'
 --           OR UPPER(CREDTMP.CREDITTYPEID) LIKE 'ACTIVACION - IMPORTE TARIFAS'
	-- 		OR UPPER(CREDTMP.CREDITTYPEID) LIKE 'BAJA - IMPORTE BASE'
	-- 		OR UPPER(CREDTMP.CREDITTYPEID) LIKE 'BAJA - IMPORTE BASE - PRESCRIPTOR'
 --           OR UPPER(CREDTMP.CREDITTYPEID) LIKE 'ACTIVACION - PRESCRIPTOR' 
 --           OR UPPER(CREDTMP.CREDITTYPEID) LIKE 'BAJA - RAPPEL - FRONT'
 --           OR UPPER(CREDTMP.CREDITTYPEID) LIKE 'BAJA - RAPPEL - PRESCRIPTOR'
 --           /*EOM APM 23.06.2026*/
 --       ) 
 --       and CREDTMP.GENERICATTRIBUTE1 is not null  
 --       and CREDTMP.GENERICATTRIBUTE2 is not null  
 --       AND CREDTMP.GENERICATTRIBUTE2 <> '000' 
 --       AND CREDTMP.GENERICATTRIBUTE15 NOT LIKE 'Prescriptor'
 --       and CREDTMP.GENERICBOOLEAN1 = 1
 --       and credtmp.periodseq = i_periodseq
 --       and 1=
 --           (select 
 --               case 
 --                   when CREDTMP.CREDITTYPEID like 'Captacion%' and tmp_prod.proveedor_captacion is not null then count(tmp_prod.proveedor_captacion)
 --                   when CREDTMP.CREDITTYPEID like 'Prestacion%'  then 1
 --                   when CREDTMP.CREDITTYPEID like 'Instalacion%' then 1
 --                   when credtmp.credittypeid like 'ATC - Ajuste Manual' then 1
	-- 				when credtmp.credittypeid like 'ATC - EFactura PULL' then 1
	-- 				when txntmp.eventypeid like 'Ajuste Manual Captacion' then 1
	-- 				when credtmp.credittypeid like 'Captacion SW - Ajuste Manual' then 1
	-- 				when credtmp.credittypeid like 'Captacion CNS - Ajuste Manual' then 1
	-- 				-- MPR condicion para Asesor
	-- 				when UPPER(CREDTMP.CREDITTYPEID) LIKE 'CAPTACION ASESOR - AJUSTE MANUAL' then 1
 --                   /*BOM 12.12.2023 APM*/
 --                   when UPPER(CREDTMP.CREDITTYPEID) like 'VENTA EXT.SMMX%' then 1
 --                   when UPPER(CREDTMP.CREDITTYPEID) like 'INSTALACI%N EXT.SMMX%' then 1
 --                   /*EOM 12.12.2023 APM*/
 --                   when credtmp.CREDITTYPEID like 'Retrocomision EXT.SMMX%' then 1 --APM 29.12.2023
 --                   when credtmp.CREDITTYPEID like 'Captacion - Prescriptor' then 1 --APM 16.02.2024
 --                   when CREDTMP.CREDITTYPEID like 'CCPP -%'  then 1
 --                   when UPPER(CREDTMP.CREDITTYPEID) LIKE 'AJUSTE VENTA EXT.SMMX - CANAL PRESENCIAL%' then 1 --APM 05.11.2024
 --                   when UPPER(CREDTMP.CREDITTYPEID) LIKE 'COMISIONADO ACT COMERCIAL - IMPORTE' then 1 --APM 13.01.2026
 --                   /*BOM APM 19.03.2026*/
 --                   when UPPER(CREDTMP.CREDITTYPEID) LIKE 'CAPTACION - MAS ORANGE%' then 1
 --                   when UPPER(CREDTMP.CREDITTYPEID) LIKE 'BAJAS - MAS ORANGE%' then 1
 --                   when UPPER(CREDTMP.CREDITTYPEID) LIKE 'AJUSTE MANUAL - MAS ORANGE' then 1
 --                   /*EOM APM 19.03.2026*/
 --                   /*BOM APM 23.06.2026 New Code*/
 --                   when UPPER(CREDTMP.CREDITTYPEID) LIKE 'ACTIVACION - IMPORTE BASE' then 1
 --                   when UPPER(CREDTMP.CREDITTYPEID) LIKE 'ACTIVACION - IMPORTE TARIFAS' then 1
 --                   when UPPER(CREDTMP.CREDITTYPEID) LIKE 'BAJA - IMPORTE BASE' then 1
 --                   when UPPER(CREDTMP.CREDITTYPEID) LIKE 'BAJA - IMPORTE BASE - PRESCRIPTOR' then 1
 --                   when UPPER(CREDTMP.CREDITTYPEID) LIKE 'ACTIVACION - PRESCRIPTOR'  then 1
 --                   when UPPER(CREDTMP.CREDITTYPEID) LIKE 'BAJA - RAPPEL - FRONT' then 1
 --                    when UPPER(CREDTMP.CREDITTYPEID) LIKE 'BAJA - RAPPEL - PRESCRIPTOR' then 1
 --                   /*EOM APM 23.06.2026*/
 --               end
 --               from DUMMY
 --           )
	-- ;
                
    
    COMMIT;
    
    CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Fin Carga CREDITOS de la tabla EXT.SMM_FACTPDS_DETALLE: '|| ::ROWCOUNT || ' filas.', v_log_count, v_idproceso,'info');

    CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Insertando Registros de INCENTIVOS en tabla EXT.SMM_FACTPDS_DETALLE.' , v_log_count, v_idproceso,'info');
    
    INSERT INTO EXT.SMM_FACTPDS_DETALLE ( PERIODO, PERIODSEQ, MES_LIQUIDACION, CREDITSEQ, CREDITTYPEID, PAYEESEQ, POSITIONSEQ, 
                                                PDS, NOMBRE_FISCAL, CIF, IDPROVEEDOR, DESCRIPCION, FICHERO, ACTIVIDAD, DETALLE_ACTIVIDAD, CODIGOE4E, DELEGACION, 
                                                ZONA, TERRITORIO, CALLE, COD_POSTAL, PROVINCIA, POBLACION, CANTIDAD, VALUE, SOLICITUD_SERVICIO, CONCEPTO_LIQ, 
                                                DESC_CONCEPTO_LIQ, COD_CONTRATO, EVENTYPEID, CONTRATO, PRODUCTID, COD_POSTAL_DETALLE, COD_COMERCIAL, 
                                                MARCA, MODELO, WBE )   
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
        INCETMP.GenericAttribute1 as CONCEPTO_LIQ,    --Concepto liquidacion
        INCETMP.GenericAttribute3 AS DESC_CONCEPTO_LIQ,  -- Siempre debe venir informado
        TMP_CONTRA.COD_CONTRATO,
        '' EVENTYPEID,
        ''  CONTRATO,
        '' PRODUCTID, 
        '' COD_POSTAL_DETALLE,
        '' COD_COMERCIAL,
        '' MARCA,
        '' MODELO,
        INCETMP.GENERICATTRIBUTE7
    
    FROM EXT.SMM_INCEN_TEMP INCETMP
        INNER JOIN EXT.SMM_PDS_TEMP TMP_PDS
            ON INCETMP.POSITIONSEQ=TMP_PDS.RULEELEMENTOWNERSEQ
            and tmp_pds.periodseq = i_periodseq
            
        INNER JOIN EXT.SMM_PROVEEDORES_TEMP TMP_PROV 
            ON TMP_PROV.IDPROVEEDOR=INCETMP.GENERICATTRIBUTE2
            and TMP_PROV.periodseq = i_periodseq
                
        LEFT JOIN EXT.SMM_E4E_CONTRATOS_TEMP TMP_CONTRA
            ON  TMP_CONTRA.PDS = TMP_PDS.PDS
            AND TMP_CONTRA.ACTIVIDAD = TMP_PROV.ACTIVIDAD
            AND TMP_CONTRA.ACTIVIDAD_DETALLADA=TMP_PROV.DETALLE_ACTIVIDAD
            AND TMP_CONTRA.periodseq=TMP_PROV.periodseq      

    WHERE --INCETMP.NAME like 'I - Captacion - %' AND    v2.2 se elmina esta condicion
        NOT( INCETMP.GENERICATTRIBUTE2 ='050' AND TMP_PDS.TIPO_POSICION ='OCAP')   -- v2.2 se filtra que no sea proveedor 050 y OCAP 
        -- MPR se excluyen los incentivos de los Dashboards
		and incetmp.Name not like 'I - Captacion - Rappel Cuantitativo Incremental - Objetivo % (Dashboards)'
        and incetmp.Name not like 'I - Captacion - Rappel Cuantitativo Incremental - Objetivo % (DB)'
        and INCETMP.NAME NOT LIKE 'C - Captacion%- Incentivo Transversal%'
        and INCETMP.NAME NOT LIKE 'C - Activacion%'
        and (INCETMP.NAME NOT like 'C - Activacion - Importe Base Prescriptor -%'
        and INCETMP.NAME NOT like 'C - Activacion - Retrocesion - Importe Base Prescriptor -%'
        and INCETMP.NAME NOT like 'C - Activacion - Rappel Cuantitativo Prescriptor -%'
        and INCETMP.NAME NOT like 'C - Activacion - Rappel Cuantitativo -%')
		AND INCETMP.GENERICATTRIBUTE1 is not null 
        AND INCETMP.GENERICATTRIBUTE2 is not null 
        AND INCETMP.GENERICATTRIBUTE2 <> '000' 
        AND INCETMP.GENERICBOOLEAN1 = 1
        and INCETMP.value <> 0
        and INCETMP.periodseq = i_periodseq;

    
    COMMIT;
    
    
    INSERT INTO EXT.SMM_FACTPDS_DETALLE ( PERIODO, PERIODSEQ, MES_LIQUIDACION, CREDITSEQ, CREDITTYPEID, PAYEESEQ, POSITIONSEQ, 
                                                PDS, NOMBRE_FISCAL, CIF, IDPROVEEDOR, DESCRIPCION, FICHERO, ACTIVIDAD, DETALLE_ACTIVIDAD, CODIGOE4E, DELEGACION, 
                                                ZONA, TERRITORIO, CALLE, COD_POSTAL, PROVINCIA, POBLACION, CANTIDAD, VALUE, SOLICITUD_SERVICIO, CONCEPTO_LIQ, 
                                                DESC_CONCEPTO_LIQ, COD_CONTRATO, EVENTYPEID, CONTRATO, PRODUCTID, COD_POSTAL_DETALLE, COD_COMERCIAL, 
                                                MARCA, MODELO, WBE,OBSERVACIONES, CUPS )   
    SELECT 
        i_period, 
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
        COMMI.VALUE,
        '' solicitud_servicio,      -- Solicitud de servicio
        INCETMP.GenericAttribute1 as CONCEPTO_LIQ,    --Concepto liquidacion
        INCETMP.GenericAttribute3 AS DESC_CONCEPTO_LIQ,  -- Siempre debe venir informado
        TMP_CONTRA.COD_CONTRATO,
        '' EVENTYPEID,
        TXNTMP.PONUMBER  CONTRATO,
        '' PRODUCTID, 
        '' COD_POSTAL_DETALLE,
        /*BOM APM 07.07.2026 Old Code*/
        --'' COD_COMERCIAL, 
        --New code
        TXNTMP.TAS_GENERICATTRIBUTE1 AS COD_COMERCIAL,
        /*EOM APM 07.07.2026*/
        '' MARCA,
        '' MODELO,
        INCETMP.GENERICATTRIBUTE7,
        INCETMP.GENERICATTRIBUTE4 AS OBSERVACIONES,
        TXNTMP.ALTERNATEORDERNUMBER AS CUPS --APM 07.07.2026
    
    FROM CS_INCENTIVE INCETMP
        INNER JOIN EXT.SMM_PDS_TEMP TMP_PDS
            ON INCETMP.POSITIONSEQ=TMP_PDS.RULEELEMENTOWNERSEQ
            and tmp_pds.periodseq = i_periodseq
            
        INNER JOIN EXT.SMM_PROVEEDORES_TEMP TMP_PROV 
            ON TMP_PROV.IDPROVEEDOR=INCETMP.GENERICATTRIBUTE2
            and TMP_PROV.periodseq = i_periodseq
                
        LEFT JOIN EXT.SMM_E4E_CONTRATOS_TEMP TMP_CONTRA
            ON  TMP_CONTRA.PDS = TMP_PDS.PDS
            AND TMP_CONTRA.ACTIVIDAD = TMP_PROV.ACTIVIDAD
            AND TMP_CONTRA.ACTIVIDAD_DETALLADA=TMP_PROV.DETALLE_ACTIVIDAD
            AND TMP_CONTRA.periodseq=TMP_PROV.periodseq      
            
        LEFT JOIN CS_COMMISSION COMMI 
        ON INCETMP.INCENTIVESEQ = COMMI.INCENTIVESEQ
            AND INCETMP.payeeseq = commi.payeeseq
            AND INCETMP.positionseq = commi.positionseq
            AND INCETMP.periodseq = commi.periodseq
            AND INCETMP.pipelinerunseq = commi.pipelinerunseq
            
        left join EXT.SMM_CREDIT_TEMP CREDTMP
        on CREDTMP.creditseq=commi.creditseq
        and credtmp.periodseq=commi.periodseq
        INNER JOIN EXT.SMM_TXN_TEMP TXNTMP 
            ON CREDTMP.SALESTRANSACTIONSEQ=TXNTMP.SALESTRANSACTIONSEQ
            and CREDTMP.PERIODSEQ=TXNTMP.PERIODSEQ
            AND TXNTMP.PERIODSEQ = i_periodseq

    WHERE (INCETMP.NAME like 'C - Activacion - Importe Base Prescriptor -%'
        or INCETMP.NAME like 'C - Activacion - Retrocesion - Importe Base Prescriptor -%'
        or INCETMP.NAME like 'C - Activacion - Rappel Cuantitativo Prescriptor -%'
        or INCETMP.NAME like 'C - Activacion - Rappel Cuantitativo -%'
        or INCETMP.NAME like 'C - Captacion - Rappel Cuantitativo Incremental -%') --APM 09.07.2026
        and INCETMP.periodseq = i_periodseq;
    
    
	CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Fin Carga de la tabla SMM_FACTPDS_DETALLE: '|| ::ROWCOUNT || ' filas.', v_log_count, v_idproceso,'info');
	
    COMMIT;
   
    
   
    
   
      
    


    
  

	CALL EXT.SMM_SP_Z_CTRL_INF(v_contador_ctrl_inf, v_num_ejecucion, v_proc_name, v_finicio, current_timestamp, NULL);
	
	
	CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, v_proc_name, 'Fin procedimiento', v_log_count, v_idproceso, 'info');
end;
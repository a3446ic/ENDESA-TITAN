CREATE OR REPLACE PROCEDURE EXT.SMM_SP_FINAL_E4E_2_CAT_TVTA( IN i_period VARCHAR(25), IN i_periodseq BIGINT)
LANGUAGE SQLSCRIPT
SQL SECURITY INVOKER 
DEFAULT SCHEMA EXT AS
/*---------------------------------------------------------------------
    | Author: Samuel Miralles Manresa
    | Company: Inycom
    | Initial Version Date: 
    |----------------------------------------------------------------------
    | Procedure Purpose: 
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
	DECLARE v_fechaInicioPeriodo DATE;
	DECLARE v_fechaInicio DATE;
	DECLARE v_txtFechaInicioPeriodo VARCHAR(25);
	DECLARE v_txtFechaInicio VARCHAR(25);
	DECLARE v_txtYear VARCHAR(4);
	DECLARE v_codMes VARCHAR(2);
	DECLARE v_txtFechaActual VARCHAR(25);
	DECLARE contadorE4E INT;
	DECLARE contadorECS INT;
	DECLARE contadorPosicion  INT;
	DECLARE v_codFichero VARCHAR(50);
	DECLARE v_actividad VARCHAR(20);
	DECLARE v_impuesto VARCHAR(5);
	DECLARE v_referencia VARCHAR(50);
	DECLARE contadorTabla INT;
	DECLARE v_fila_C_TMPDEPOSITOS INT;
	DECLARE v_total_filas_C_TMPDEPOSITOS INT;
	DECLARE v_offset INT;
	DECLARE v_c_tmpdepositos_actividad VARCHAR(25);
	DECLARE v_c_tmpdepositos_id_centro_e4e VARCHAR(25);
	DECLARE v_c_tmpdepositos_tipo_impositivo VARCHAR(25);
	DECLARE v_c_tmpdepositos_pos_fecha_ini_vigencia DATE;
	DECLARE v_c_tmpdepositos_rn INT;
	DECLARE v_c_tmpdepositos_cod_contrato VARCHAR(25);
	DECLARE v_c_tmpdepositos_sociedad VARCHAR(25);
	DECLARE v_c_tmpdepositos_par_proveedor VARCHAR(25);
	DECLARE v_c_tmpdepositos_ceco VARCHAR(25);
	DECLARE v_c_tmpdepositos_org_compras VARCHAR(25);
	DECLARE v_c_tmpdepositos_gr_compras VARCHAR(25);
	DECLARE v_c_tmpdepositos_businessunit VARCHAR(25);
	DECLARE v_c_tmpdepositos_orden_entrega INT;
	DECLARE v_c_tmpdepositos_pos_doc VARCHAR(255);
	DECLARE v_c_tmpdepositos_texto_breve VARCHAR(255);
	DECLARE v_c_tmpdepositos_descripcion VARCHAR(255);
	DECLARE v_c_tmpdepositos_tipo_pago VARCHAR(255);
	DECLARE v_c_tmpdepositos_value DECIMAL(25,10);
	DECLARE v_c_tmpdepositos_centro_logistico VARCHAR(255);
	DECLARE v_c_tmpdepositos_wbe_final_imputacion VARCHAR(255);
	DECLARE v_c_tmpdepositos_subposicion VARCHAR(255);
	DECLARE v_c_tmpdepositos_codigo_servicio VARCHAR(255);
	

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
		|| ' || i_period: ' || i_period
		|| ' || i_periodseq: ' || i_periodseq
		, v_log_count, v_idproceso,'info');
	
	--SMM_E4E_FINAL_CAT_TVTA
	CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Inicio borrado de la tabla SMM_E4E_FINAL_CAT_TVTA.', v_log_count, v_idproceso,'info');
	DELETE FROM EXT.SMM_E4E_FINAL_CAT_TVTA WHERE PERIODO = i_period AND FICHERO LIKE 'CAT_TVTA2';
	CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Fin borrado de la tabla SMM_E4E_FINAL_CAT_TVTA.', v_log_count, v_idproceso,'info');
	
	-- Se extrae la fecha inicial del siguiente mes al periodSeq del proceso
    v_fechaInicioPeriodo :=  EXT.SMM_F_PRIMER_DIA_PERIODO_SIGUIENTE(i_periodseq);
    v_fechaInicio := EXT.SMM_F_FECHA_INICIO(i_periodseq);
    -- Se convierte a texto en formato DD/MM/YYYY para los registros de salida
    v_txtFechaInicioPeriodo := to_char(v_fechaInicioPeriodo, 'DD/MM/YYYY');
    -- Se convierte a texto el año YY para el codigo de referencia
    v_txtYear := to_char(v_fechaInicioPeriodo, 'YY');
    -- Se extrae el codigo asociado al mes, donde Enero = A, Febrero = B, ... Diciembre = L
    v_codMes := EXT.SMM_F_CODIGO_MES(v_fechaInicioPeriodo);
    -- Se convierte a texto la fecha actual en formato DD/MM/YYYY para los registros de salida
    v_txtFechaActual := to_char(CURRENT_DATE, 'DD/MM/YYYY');
    
    CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, v_proc_name,'Referencia fechas. Periodo:'|| i_period ||' FechaInicioPeriodo Siguiente: '||v_txtFechaInicioPeriodo ||' YY: '||v_txtYear ||' codMes: '||v_codMes || ' FechaActual ' || v_txtFechaActual , v_log_count, v_idproceso,'info');
    
    CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, v_proc_name,'Cargando tabla EXT.SMM_E4E_FINAL_CAT_TVTA. Periodo:'|| i_period ||' Periodseq: '||i_periodseq ||' TenantId: '||v_tenantid , v_log_count, v_idproceso,'info');

    CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, v_proc_name,'Insertando Registros de datos en tabla EXT.SMM_E4E_FINAL_CAT_TVTA. Fichero ' || v_codFichero , v_log_count, v_idproceso,'info');
    
    C_TMPDEPOSITOS =

		SELECT
		    T.*,
		    ROW_NUMBER() OVER (
		        PARTITION BY POS_NAME, ACTIVIDAD
		        ORDER BY WBE_FINAL_IMPUTACION
		    ) AS RN,
		
		    ROW_NUMBER() OVER (
		        PARTITION BY POS_NAME, ACTIVIDAD
		        ORDER BY WBE_FINAL_IMPUTACION
		    ) * 10 AS ORDEN_ENTREGA
		
		FROM EXT.SMM_E4E_DEPOSIT_CAT_TVTA_TEMP T
		WHERE PERIODSEQ = :i_periodseq
		  AND COD_CONTRATO IS NOT NULL
		  AND VALUE > 0
		
		ORDER BY
		    POS_NAME,
		    ACTIVIDAD,
		    WBE_FINAL_IMPUTACION;
		
		v_fila_C_TMPDEPOSITOS:= 0;
		v_total_filas_C_TMPDEPOSITOS := RECORD_COUNT(:C_TMPDEPOSITOS);
		
		FOR v_fila_C_TMPDEPOSITOS IN 1 .. v_total_filas_C_TMPDEPOSITOS DO
		BEGIN
			v_offset := v_fila_C_TMPDEPOSITOS - 1;
			SELECT ACTIVIDAD
				, ID_CENTRO_E4E
				, TIPO_IMPOSITIVO
				, POS_FECHA_INI_VIGENCIA
				, RN
				, COD_CONTRATO
				, SOCIEDAD
				, PAR_PROVEEDOR
				, CECO
				, ORG_COMPRAS
		        , GR_COMPRAS
		        , BUSINESSUNIT
		        , ORDEN_ENTREGA
		        , POS_DOC
		        , TEXTO_BREVE
		        , DESCRIPCION
		        , TIPO_PAGO
		        , VALUE
		        , CENTRO_LOGISTICO
		        , WBE_FINAL_IMPUTACION
		        , SUBPOSICION
				, CODIGO_SERVICIO
				INTO v_c_tmpdepositos_actividad
				, v_c_tmpdepositos_id_centro_e4e
				, v_c_tmpdepositos_tipo_impositivo
				, v_c_tmpdepositos_pos_fecha_ini_vigencia
				, v_c_tmpdepositos_rn
				, v_c_tmpdepositos_cod_contrato
				, v_c_tmpdepositos_sociedad
				, v_c_tmpdepositos_par_proveedor
				, v_c_tmpdepositos_ceco
				, v_c_tmpdepositos_org_compras
				, v_c_tmpdepositos_gr_compras
				, v_c_tmpdepositos_businessunit
				, v_c_tmpdepositos_orden_entrega
				, v_c_tmpdepositos_pos_doc
				, v_c_tmpdepositos_texto_breve
				, v_c_tmpdepositos_descripcion
				, v_c_tmpdepositos_tipo_pago
				, v_c_tmpdepositos_value
				, v_c_tmpdepositos_centro_logistico
				, v_c_tmpdepositos_wbe_final_imputacion
				, v_c_tmpdepositos_subposicion
				, v_c_tmpdepositos_codigo_servicio
	    			    FROM :C_TMPDEPOSITOS 
						-- ORDER BY EARNINGCODEID,EARNINGGROUPID, PROGRAMA, DEPOSITSEQ 
						LIMIT 1 OFFSET :v_offset
						;
		    v_codFichero := 'CAT_TVTA2';
		
		    ------------------------------------------------
		    -- REFERENCIA
		    ------------------------------------------------
		
		    v_actividad :=
		        CASE v_c_tmpdepositos_actividad
			        WHEN 'CAPTACIÓN' THEN 'CAT'
			        WHEN 'CAPTACION' THEN 'CAT'
			        WHEN 'RECUPERACIÓN' THEN  'REC'
			        WHEN 'MKT DIRECTO COTEL' THEN  'MKT'
			        ELSE 'ERR'
		    	END;
		
		    v_referencia :=
		        v_txtYear ||
		        v_c_tmpdepositos_id_centro_e4e ||
		        v_actividad ||
		        v_codMes;
		
		    ------------------------------------------------
		    -- IMPUESTO
		    ------------------------------------------------
		
		    v_impuesto :=
		    	CASE v_c_tmpdepositos_tipo_impositivo
		        	WHEN 'IVA' THEN 'SD'
		        	WHEN 'IGIC' THEN 'CG'
		        	WHEN 'IVA Portugal' THEN 'KK'
		        	WHEN 'IVA OFFSHORE' THEN 'BF'
		        	ELSE ''
		    	END;
		
		    ------------------------------------------------
		    -- FECHA INICIO
		    ------------------------------------------------
		
		    IF v_c_tmpdepositos_pos_fecha_ini_vigencia > v_fechaInicioPeriodo THEN
		       v_txtFechaInicio :=
		            TO_VARCHAR(
		                v_c_tmpdepositos_pos_fecha_ini_vigencia,
		                'DD/MM/YYYY'
		            );
		    ELSE
		       v_txtFechaInicio := v_txtFechaInicioPeriodo;
		    END IF;
		
		    ------------------------------------------------
		    -- CABECERA
		    ------------------------------------------------
		
		    IF v_c_tmpdepositos_rn = 1 THEN
		
		        contadorE4E := contadorE4E + 1;
		        contadorTabla := contadorE4E;
		
		        INSERT INTO EXT.SMM_E4E_FINAL_CAT_TVTA (PERIODO, ORDEN, CAMPO1, CAMPO2, CAMPO3, CAMPO4, CAMPO5, CAMPO6, CAMPO7, CAMPO8, CAMPO9, CAMPO10, 
                                               CAMPO11, CAMPO12, CAMPO13, CAMPO14, CAMPO15, CAMPO16, CAMPO17, CAMPO18, CAMPO19, CAMPO20, CAMPO21, CAMPO22, FICHERO, BUSINESSUNIT)
		        VALUES
		        (:i_period,contadorTabla, v_referencia, '', 'CABECERA',  v_c_tmpdepositos_cod_contrato, v_txtFechaInicio, '', v_c_tmpdepositos_sociedad, v_c_tmpdepositos_par_proveedor, v_c_tmpdepositos_ceco
		        	, v_c_tmpdepositos_org_compras, v_c_tmpdepositos_gr_compras, 'NO', '', 'RE', '','','','','','','','',v_codFichero, v_c_tmpdepositos_businessunit);
		
		    END IF;
		
		    ------------------------------------------------
		    -- POSICION
		    ------------------------------------------------
		
		    contadorE4E := contadorE4E + 1;
		    contadorTabla := contadorE4E;
		
		    INSERT INTO EXT.SMM_E4E_FINAL_CAT_TVTA (PERIODO, ORDEN, CAMPO1, CAMPO2, CAMPO3, CAMPO4, CAMPO5, CAMPO6, CAMPO7, CAMPO8, CAMPO9, CAMPO10, 
                                           CAMPO11, CAMPO12, CAMPO13, CAMPO14, CAMPO15, CAMPO16, CAMPO17, CAMPO18, CAMPO19, CAMPO20, CAMPO21, CAMPO22, FICHERO, BUSINESSUNIT)
				VALUES ( :i_period,
						contadorTabla,
						v_referencia,    --CAMPO1
						v_c_tmpdepositos_orden_entrega,
						'POSICION', 
						v_c_tmpdepositos_cod_contrato, --CAMPO4
						'',
						v_c_tmpdepositos_pos_doc,
						'P',                      --CAMPO7
						'',
						v_c_tmpdepositos_texto_breve,  --CAMPO9
						UPPER(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(v_c_tmpdepositos_descripcion,'ú','u'),'ó','o'),'í','i'),'é','e'),'á','a')),  --CAMPO10
						-- CAMPO 11 es 1 cuando hay linea de SERVICIO y si no contiene el importe
						CASE WHEN v_c_tmpdepositos_tipo_pago = 'SERVICIO' THEN '1' ELSE to_char(v_c_tmpdepositos_value) END,  --CAMPO11
						'UA',
						v_txtFechaActual,
						v_c_tmpdepositos_centro_logistico,
						v_c_tmpdepositos_wbe_final_imputacion,
						v_Impuesto,
						'','','','','','ES21-06',v_codFichero,
						v_c_tmpdepositos_businessunit);
		
		    ------------------------------------------------
		    -- SERVICIO
		    ------------------------------------------------
		
		    IF v_c_tmpdepositos_tipo_pago = 'SERVICIO' THEN
		
		        contadorE4E := contadorE4E + 1;
		        contadorTabla := contadorE4E;
		
		        INSERT INTO EXT.SMM_E4E_FINAL_CAT_TVTA (PERIODO, ORDEN, CAMPO1, CAMPO2, CAMPO3, CAMPO4, CAMPO5, CAMPO6, CAMPO7, CAMPO8, CAMPO9, CAMPO10, 
                                           CAMPO11, CAMPO12, CAMPO13, CAMPO14, CAMPO15, CAMPO16, CAMPO17, CAMPO18, CAMPO19, CAMPO20, CAMPO21, CAMPO22, FICHERO, BUSINESSUNIT)
					VALUES ( :i_period,
							contadorTabla,
							v_referencia,
							v_c_tmpdepositos_orden_entrega,
							'SERVICIO', 
							v_c_tmpdepositos_cod_contrato,
							'',
							v_c_tmpdepositos_pos_doc,  -- CAMPO6
							v_c_tmpdepositos_subposicion,      -- CAMPO7
							v_c_tmpdepositos_codigo_servicio,  --CAMPO8
							v_c_tmpdepositos_texto_breve,      --CAMPO9
							to_char(v_c_tmpdepositos_value),  --CAMPO10
							v_c_tmpdepositos_wbe_final_imputacion, -- CAMPO11
							'', '', '', '',                    -- CAMPO12 a 15
							'', '', '', '',                    -- CAMPO16 a 19
							'', '', '',                        -- CAMPO20 a 22
							v_codFichero,v_c_tmpdepositos_businessunit);
		
		    END IF;
		END;
		END FOR;
	/* CODIGO ORACLE
contadorE4E := 4;
	--contadorECS := 4;

    DECLARE
		CURSOR C_TMPPAYEE IS
            SELECT DISTINCT POS_NAME, ACTIVIDAD 
            FROM ENEL_E4E_DEPOSIT_CAT_TVTA_TEMP
            WHERE PERIODSEQ = iperiodseq
                AND COD_CONTRATO IS NULL        -- Fichero E4E2 contiene los registros sin contrato
            --    AND VALUE > 0                   -- Fichero E4E se incluyen solo los positivos --RMM 13/07/2022
            ;

            v_reg_pos_name          VARCHAR2(255);
            v_reg_pos_actividad     VARCHAR2(255);

        CURSOR C_TMPDEPOSITOS IS
            SELECT 
				PERIODSEQ,
				VALUE,
				POS_NAME,
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
				CODIGO_SERVICIO,
				SUBPOSICION,
				ID_CENTRO_E4E,
				BUSINESSUNIT
            FROM ENEL_E4E_DEPOSIT_CAT_TVTA_TEMP
            WHERE 
				PERIODSEQ = iperiodseq 
				AND COD_CONTRATO is null        -- Fichero E4E2 contiene los registros sin contrato
				AND VALUE > 0                   -- Fichero E4E se incluyen solo los positivos --RMM 12/07/2022 Solicitan que aparezcan negativos
				AND POS_NAME = v_reg_pos_name
				AND ACTIVIDAD = v_reg_pos_actividad
            ORDER BY WBE_FINAL_IMPUTACION; 

			REGDEPOSITO C_TMPDEPOSITOS%ROWTYPE;
    BEGIN
        OPEN C_TMPPAYEE;
        FETCH C_TMPPAYEE INTO v_reg_pos_name,v_reg_pos_actividad;

        WHILE C_TMPPAYEE%FOUND
        LOOP
			--Inicializamos contadores
            v_contador_cabecera := 0;
            v_contador_orden_entrega := 0;

            OPEN C_TMPDEPOSITOS;
            FETCH C_TMPDEPOSITOS INTO REGDEPOSITO;

            WHILE C_TMPDEPOSITOS%FOUND
            LOOP
				--Codigo Fichero
                v_codFichero := 'CAT_TVTA2';

                -- Se concatenan los valores que forman el código de referencia:
                --    YY + Codigo de PDS + Código de proveedor + Código de Mes (Enero = A, Febrero = B ...)
                --En función del tipo de actividad se genera un valor de referencia u otro
                --CAPTACTION -> CAT
                --RECUPERACION -> REC
                --MKT DIRECTO COTEL -> MKT

                v_actividad := 'ERR'; --valor por defecto

                CASE REGDEPOSITO.ACTIVIDAD
                    WHEN 'CAPTACIÓN'            THEN v_actividad := 'CAT';
                    WHEN 'CAPTACION'            THEN v_actividad := 'CAT';
                    WHEN 'RECUPERACIÓN'         THEN v_actividad := 'REC';
                    WHEN 'MKT DIRECTO COTEL'    THEN v_actividad := 'MKT';
                    ELSE                             v_actividad := 'ERR';
                END CASE;
                v_referencia := v_txtYear || REGDEPOSITO.ID_CENTRO_E4E || v_actividad || v_codMes;

                -- Se determina el código de equivalencia del tipo impositivo
                CASE REGDEPOSITO.TIPO_IMPOSITIVO
                    WHEN 'IVA'          THEN v_Impuesto := 'SD';
                    WHEN 'IGIC'         THEN v_Impuesto := 'CG';
                    WHEN 'IVA Portugal' THEN v_Impuesto := 'KK';
                    WHEN 'IVA OFFSHORE' THEN v_Impuesto := 'BF';
                    ELSE                     v_Impuesto := '';
                END CASE;

                -- Se determina la fecha de inicio
                IF REGDEPOSITO.POS_FECHA_INI_VIGENCIA > v_fechaInicioPeriodo THEN
                    v_txtFechaInicio := to_char(REGDEPOSITO.POS_FECHA_INI_VIGENCIA, 'DD/MM/YYYY');
                ELSE
                    v_txtFechaInicio := v_txtFechaInicioPeriodo;
                END IF;

                -- Registro de DATOS - CABECERA
                IF v_codFichero = 'CAT_TVTA2' then
                    contadorE4E := contadorE4E +1;
                    contadorTabla := contadorE4E;
                END IF;

                IF v_contador_cabecera = 0 THEN   
					INSERT INTO ENEL_E4E_FINAL_CAT_TVTA (PERIODO, ORDEN, CAMPO1, CAMPO2, CAMPO3, CAMPO4, CAMPO5, CAMPO6, CAMPO7, CAMPO8, CAMPO9, CAMPO10, 
														CAMPO11, CAMPO12, CAMPO13, CAMPO14, CAMPO15, CAMPO16, CAMPO17, CAMPO18, CAMPO19, CAMPO20, CAMPO21, CAMPO22, FICHERO, BUSINESSUNIT)
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
							'','','','','','','','',v_codFichero,
							REGDEPOSITO.BUSINESSUNIT);

                    -- Registro de DATOS - POSICION
                    IF v_codFichero = 'CAT_TVTA2' then
						contadorE4E := contadorE4E +1;
                        contadorTabla := contadorE4E;
                    END IF;

                    v_contador_cabecera := 1; --Cabecera insertada. A 1 para no volver a insertarla 
                END IF;

                IF v_codFichero = 'CAT_TVTA2' then
                    v_contador_orden_entrega := v_contador_orden_entrega + 10;
                END IF;

                INSERT INTO ENEL_E4E_FINAL_CAT_TVTA (PERIODO, ORDEN, CAMPO1, CAMPO2, CAMPO3, CAMPO4, CAMPO5, CAMPO6, CAMPO7, CAMPO8, CAMPO9, CAMPO10, 
													CAMPO11, CAMPO12, CAMPO13, CAMPO14, CAMPO15, CAMPO16, CAMPO17, CAMPO18, CAMPO19, CAMPO20, CAMPO21, CAMPO22, FICHERO, BUSINESSUNIT)
				VALUES ( iperiod,
						contadorTabla,
						v_referencia,    --CAMPO1
						v_contador_orden_entrega,
						'POSICION', 
						REGDEPOSITO.COD_CONTRATO, --CAMPO4
						'',
						REGDEPOSITO.POS_DOC,
						'P',                      --CAMPO7
						'',
						REGDEPOSITO.TEXTO_BREVE,  --CAMPO9
						UPPER(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REGDEPOSITO.DESCRIPCION,'ú','u'),'ó','o'),'í','i'),'é','e'),'á','a')),  --CAMPO10
						-- CAMPO 11 es 1 cuando hay linea de SERVICIO y si no contiene el importe
						CASE WHEN REGDEPOSITO.TIPO_PAGO = 'SERVICIO' THEN '1' ELSE to_char(REGDEPOSITO.VALUE) END,  --CAMPO11
						'UA',
						v_txtFechaActual,
						REGDEPOSITO.CENTRO_LOGISTICO,
						REGDEPOSITO.WBE_FINAL_IMPUTACION,
						v_Impuesto,
						'','','','','','ES21-06',v_codFichero,
						REGDEPOSITO.BUSINESSUNIT);            

                IF REGDEPOSITO.TIPO_PAGO = 'SERVICIO' THEN
                    -- Registro de DATOS - POSICION
                    IF v_codFichero = 'CAT_TVTA2' then
						contadorE4E := contadorE4E +1;
						contadorTabla := contadorE4E;
                    END IF; 

					INSERT INTO ENEL_E4E_FINAL_CAT_TVTA (PERIODO, ORDEN, CAMPO1, CAMPO2, CAMPO3, CAMPO4, CAMPO5, CAMPO6, CAMPO7, CAMPO8, CAMPO9, CAMPO10, 
													CAMPO11, CAMPO12, CAMPO13, CAMPO14, CAMPO15, CAMPO16, CAMPO17, CAMPO18, CAMPO19, CAMPO20, CAMPO21, CAMPO22, FICHERO, BUSINESSUNIT)
					VALUES ( iperiod,
							contadorTabla,
							v_referencia,
							v_contador_orden_entrega,
							'SERVICIO', 
							REGDEPOSITO.COD_CONTRATO,
							'',
							REGDEPOSITO.POS_DOC,  -- CAMPO6
							REGDEPOSITO.SUBPOSICION,      -- CAMPO7
							REGDEPOSITO.CODIGO_SERVICIO,  --CAMPO8
							REGDEPOSITO.TEXTO_BREVE,      --CAMPO9
							to_char(REGDEPOSITO.VALUE),  --CAMPO10
							REGDEPOSITO.WBE_FINAL_IMPUTACION, -- CAMPO11
							'', '', '', '',                    -- CAMPO12 a 15
							'', '', '', '',                    -- CAMPO16 a 19
							'', '', '',                        -- CAMPO20 a 22
							v_codFichero,REGDEPOSITO.BUSINESSUNIT);
                END IF;

				FETCH C_TMPDEPOSITOS INTO REGDEPOSITO;
			END LOOP;

			FETCH C_TMPPAYEE INTO v_reg_pos_name,v_reg_pos_actividad;

            CLOSE C_TMPDEPOSITOS;
		END LOOP;

		CLOSE C_TMPPAYEE;
    END;
	*/
    --Si se han insertado registros de datos de E4E, se insertan los registros de cabecera para el fichero E4E2
    if contadorE4E > 4 THEN
		CALL EXT.SMM_SP_CABECERA_FICHEROS_E4E(  i_period , 'CAT_TVTA2' );
	end if;
    
        
	CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, v_proc_name,'Fin Carga de la tabla EXT.SMM_E4E_FINAL_CAT_TVTA:  E4E2'|| to_char(contadorE4E) || ' filas.', v_log_count, v_idproceso, 'info');

    


    
  

	CALL EXT.SMM_SP_Z_CTRL_INF(v_contador_ctrl_inf, v_num_ejecucion, v_proc_name, v_finicio, current_timestamp, NULL);
	
	
	CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, v_proc_name, 'Fin procedimiento', v_log_count, v_idproceso, 'info');
end
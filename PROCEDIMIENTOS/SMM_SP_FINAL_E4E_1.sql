CREATE OR REPLACE PROCEDURE EXT.SMM_SP_FINAL_E4E_1( IN i_period VARCHAR(25), IN i_periodseq BIGINT)
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
	DECLARE v_txtYear VARCHAR(4);
	DECLARE v_codMes VARCHAR(2);
	DECLARE v_txtFechaActual VARCHAR(25);
	DECLARE contadorE4E INT;
	DECLARE contadorECS INT;
	DECLARE contadorPosicion  INT;
	DECLARE v_codFichero VARCHAR(50);
	

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
	
	--SMM_E4E_FINAL
	CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Inicio borrado de la tabla SMM_E4E_FINAL.', v_log_count, v_idproceso,'info');
	DELETE FROM EXT.SMM_E4E_FINAL WHERE PERIODO = i_period AND FICHERO LIKE 'E%1';
	CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Fin borrado de la tabla SMM_E4E_FINAL.', v_log_count, v_idproceso,'info');
	
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
    
    CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, v_proc_name,'Cargando tabla EXT.SMM_E4E_FINAL. Periodo:'|| i_period ||' Periodseq: '||i_periodseq ||' TenantId: '||v_tenantid , v_log_count, v_idproceso,'info');

    CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, v_proc_name,'Insertando Registros de datos en tabla EXT.SMM_E4E_FINAL. Fichero ' || v_codFichero , v_log_count, v_idproceso,'info');
    
	contadorE4E := 4;
	contadorECS := 4;
	contadorPosicion := 10;
	
	TEMP_DATOS =
			SELECT
			    PERIODSEQ,
			    ROUND(SUM(VALUE),2)             AS VALUE,
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
			    CODIGO_SERVICIO,
			    SUBPOSICION,
			    BUSINESSUNIT
			FROM EXT.SMM_E4E_DEPOSIT_TEMP_2
			WHERE PERIODSEQ = :i_periodseq
			  AND COD_CONTRATO IS NOT NULL
			  AND VALUE > 0
			  AND IDPROVEEDOR NOT IN
			      ('019','023','031','057','083','110','112','115')
			GROUP BY
			    PERIODSEQ,
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
			    CODIGO_SERVICIO,
			    SUBPOSICION,
			    BUSINESSUNIT;
		
		TEMP_FINAL =
			SELECT
			    t.*,
			    :v_txtYear || t.PDS || t.IDPROVEEDOR || :v_codMes
			        AS REFERENCIA,
			
			    CASE t.ACTIVIDAD
			        WHEN 'STP' THEN 'E4E1'
			        WHEN 'SSII' THEN 'E4E1'
			        WHEN 'CAPTACIÓN' THEN 'ECS1'
			        WHEN 'CAPTACION' THEN 'ECS1'
			        WHEN 'ATC' THEN 'ECS1'
			        ELSE 'NOT1'
			    END AS COD_FICHERO,
			
			    CASE
			
			        WHEN :v_fechaInicio
			             BETWEEN DATE'2017-01-01'
			                 AND DATE'2019-02-28'
			
			        THEN
			
			            CASE t.TIPO_IMPOSITIVO
			                WHEN 'IVA' THEN 'SD'
			                WHEN 'IGIC' THEN 'CB'
			                WHEN 'IVA Portugal' THEN 'KK'
			                ELSE ''
			            END
			
			        WHEN :v_fechaInicio
			             BETWEEN DATE'2019-03-01'
			                 AND DATE'2019-11-30'
			
			        THEN
			
			            CASE t.TIPO_IMPOSITIVO
			                WHEN 'IVA' THEN 'SD'
			                WHEN 'IGIC' THEN 'CG'
			                WHEN 'IVA PTG' THEN 'KK'
			                ELSE ''
			            END
			
			        ELSE
			
			            CASE t.TIPO_IMPOSITIVO
			                WHEN 'IVA' THEN 'SD'
			                WHEN 'IGIC' THEN 'CB'
			                WHEN 'IVA PTG' THEN 'KK'
			                ELSE ''
			            END
			
			    END AS IMPUESTO,
			
			    CASE
			        WHEN t.POS_FECHA_INI_VIGENCIA >
			             :v_fechaInicioPeriodo
			        THEN TO_VARCHAR(
			                t.POS_FECHA_INI_VIGENCIA,
			                'DD/MM/YYYY'
			             )
			        ELSE :v_txtFechaInicioPeriodo
			    END AS FECHA_INICIO,
			
			    ROW_NUMBER()
			    OVER(
			        PARTITION BY t.PDS,t.IDPROVEEDOR
			        ORDER BY t.POS_DOC
			    ) AS RN_GRUPO,
			
			    ROW_NUMBER()
			    OVER(
			        PARTITION BY t.PDS,t.IDPROVEEDOR
			        ORDER BY t.POS_DOC
			    ) * 10 AS CONTADOR_POSICION
			
			FROM :TEMP_DATOS t;
			
		--CABECERAS
		INSERT INTO EXT.SMM_E4E_FINAL
		(
		 PERIODO,
		 ORDEN,
		 CAMPO1,
		 CAMPO2,
		 CAMPO3,
		 CAMPO4,
		 CAMPO5,
		 CAMPO6,
		 CAMPO7,
		 CAMPO8,
		 CAMPO9,
		 CAMPO10,
		 CAMPO11,
		 CAMPO12,
		 CAMPO13,
		 CAMPO14,
		 CAMPO15,
		 CAMPO16,
		 CAMPO17,
		 CAMPO18,
		 CAMPO19,
		 CAMPO20,
		 CAMPO21,
		 CAMPO22,
		 FICHERO,
		 BUSINESSUNIT
		)
		SELECT
		    :i_period,
		
		    ROW_NUMBER()
		      OVER(
		         PARTITION BY COD_FICHERO
		         ORDER BY PDS,IDPROVEEDOR
		      ) + 4,
		
		    REFERENCIA,
		    '',
		    'CABECERA',
		    COD_CONTRATO,
		    FECHA_INICIO,
		    '',
		    SOCIEDAD,
		    PAR_PROVEEDOR,
		    CECO,
		    ORG_COMPRAS,
		    GR_COMPRAS,
		    'NO',
		    '',
		    'RE',
		    '',
		    '',
		    '',
		    '',
		    '',
		    '',
		    '',
		    '',
		    COD_FICHERO,
		    BUSINESSUNIT
		
		FROM :TEMP_FINAL
		
		WHERE RN_GRUPO = 1;
		
		--POSICIONES
		INSERT INTO EXT.SMM_E4E_FINAL
		(
		 PERIODO,
		 ORDEN,
		 CAMPO1,
		 CAMPO2,
		 CAMPO3,
		 CAMPO4,
		 CAMPO5,
		 CAMPO6,
		 CAMPO7,
		 CAMPO8,
		 CAMPO9,
		 CAMPO10,
		 CAMPO11,
		 CAMPO12,
		 CAMPO13,
		 CAMPO14,
		 CAMPO15,
		 CAMPO16,
		 CAMPO17,
		 CAMPO18,
		 CAMPO19,
		 CAMPO20,
		 CAMPO21,
		 CAMPO22,
		 FICHERO,
		 BUSINESSUNIT
		)
		
		SELECT
		    :i_period,
		
		    100000 +
		    ROW_NUMBER()
		    OVER(
		        PARTITION BY COD_FICHERO
		        ORDER BY PDS,IDPROVEEDOR,POS_DOC
		    ),
		
		    REFERENCIA,
		    TO_NVARCHAR(CONTADOR_POSICION),
		    'POSICION',
		    COD_CONTRATO,
		    '',
		    POS_DOC,
		    'P',
		    '',
		    TEXTO_BREVE,
		    DESCRIPCION,
		
		    CASE
		        WHEN TIPO_PAGO='SERVICIO'
		        THEN '1'
		        ELSE TO_NVARCHAR(VALUE)
		    END,
		
		    'EUR',
		    :v_txtFechaActual,
		    CENTRO_LOGISTICO,
		    WBE_FINAL_IMPUTACION,
		    IMPUESTO,
		    '',
		    '',
		    '',
		    '',
		    '',
		    'ES21-01',
		    COD_FICHERO,
		    BUSINESSUNIT
		
		FROM :TEMP_FINAL;
		
		--SERVICIOS
		INSERT INTO EXT.SMM_E4E_FINAL
			(
			 PERIODO,
			 ORDEN,
			 CAMPO1,
			 CAMPO2,
			 CAMPO3,
			 CAMPO4,
			 CAMPO5,
			 CAMPO6,
			 CAMPO7,
			 CAMPO8,
			 CAMPO9,
			 CAMPO10,
			 CAMPO11,
			 CAMPO12,
			 CAMPO13,
			 CAMPO14,
			 CAMPO15,
			 CAMPO16,
			 CAMPO17,
			 CAMPO18,
			 CAMPO19,
			 CAMPO20,
			 CAMPO21,
			 CAMPO22,
			 FICHERO,
			 BUSINESSUNIT
			)
			
			SELECT
			    :i_period,
			
			    200000 +
			    ROW_NUMBER()
			    OVER(
			        PARTITION BY COD_FICHERO
			        ORDER BY PDS,IDPROVEEDOR,POS_DOC
			    ),
			
			    REFERENCIA,
			    TO_NVARCHAR(CONTADOR_POSICION),
			    'SERVICIO',
			    COD_CONTRATO,
			    '',
			    POS_DOC,
			    COALESCE(SUBPOSICION,'10'),
			    CODIGO_SERVICIO,
			    TEXTO_BREVE,
			    TO_NVARCHAR(VALUE),
			    WBE_FINAL_IMPUTACION,
			    '',
			    '',
			    '',
			    '',
			    '',
			    '',
			    '',
			    '',
			    '',
			    '',
			    '',
			    COD_FICHERO,
			    BUSINESSUNIT
			
			FROM :TEMP_FINAL
			
			WHERE TIPO_PAGO='SERVICIO';
			
    /* 
    DECLARE
        CURSOR C_TMPDEPOSITOS IS
            SELECT 
				PERIODSEQ,
				trunc(sum(VALUE),2) as value,
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
				CODIGO_SERVICIO,
				SUBPOSICION,
				BUSINESSUNIT

            FROM EXT.SMM_E4E_DEPOSIT_TEMP_2
            WHERE PERIODSEQ = i_periodseq 
				AND COD_CONTRATO is not null      -- Fichero E4E1 contiene los registros con contrato
				AND VALUE > 0                     -- Fichero E4E se incluyen solo los positivos 
				AND IDPROVEEDOR not in ('019', '023', '031', '057', '083', '110','112', '115') -- MPR se excluye los proveedore para que no aparezcan en el fichero de captacion
            group by
				PERIODSEQ,
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
				CODIGO_SERVICIO,
				SUBPOSICION,
				BUSINESSUNIT
			order by pds, idproveedor;
        
            REGDEPOSITO C_TMPDEPOSITOS%ROWTYPE;
            
    BEGIN
        OPEN C_TMPDEPOSITOS;
        FETCH C_TMPDEPOSITOS INTO REGDEPOSITO;
        
        WHILE C_TMPDEPOSITOS%FOUND
        LOOP        
            -- Codigo de fichero
            CASE REGDEPOSITO.ACTIVIDAD 
                WHEN 'STP'          THEN v_codFichero :='E4E1';
                WHEN 'SSII'         THEN v_codFichero :='E4E1';
                WHEN 'CAPTACIÓN'    THEN v_codFichero :='ECS1';
                WHEN 'CAPTACION'    THEN v_codFichero :='ECS1';
                WHEN 'ATC'          THEN v_codFichero :='ECS1';
                ELSE                     v_codFichero :='NOT1';
            END CASE;
                
            -- Se concatenan los valores que forman el codigo de referencia:
            --    YY + Codigo de PDS + Codigo de proveedor + Codigo de Mes (Enero = A, Febrero = B ...)
            v_referencia := v_txtYear || REGDEPOSITO.PDS || REGDEPOSITO.IDPROVEEDOR || v_codMes;

            -- Se determina el codigo de equivalencia del tipo impositivo
            if (v_fechaInicio>= to_date('01/01/2017','dd/mm/yyyy') AND v_fechaInicio <=to_date('28/02/2019', 'dd/mm/yyyy')) THEN
                CASE REGDEPOSITO.TIPO_IMPOSITIVO
                    WHEN 'IVA'          THEN v_Impuesto := 'SD';
                    WHEN 'IGIC'         THEN v_Impuesto := 'CB';
                    WHEN 'IVA Portugal' THEN v_Impuesto := 'KK';
                    ELSE                     v_Impuesto := '';
                END CASE;
            END IF;
            
            if (v_fechaInicio>= to_date('01/03/2019','dd/mm/yyyy')  AND v_fechaInicio <=to_date('30/11/2019','dd/mm/yyyy')) THEN
                CASE REGDEPOSITO.TIPO_IMPOSITIVO 
                    WHEN 'IVA'          THEN v_Impuesto := 'SD';
                    WHEN 'IGIC'         THEN v_Impuesto := 'CG';
                    WHEN 'IVA PTG'      THEN v_Impuesto := 'KK';
                    ELSE                     v_Impuesto := '';
                END CASE;
            END IF;
            
			if (v_fechaInicio>= to_date('01/12/2019','dd/mm/yyyy') AND v_fechaInicio <=to_date('01/01/2200', 'dd/mm/yyyy')) THEN
                CASE REGDEPOSITO.TIPO_IMPOSITIVO
                    WHEN 'IVA'          THEN v_Impuesto := 'SD';
                    WHEN 'IGIC'         THEN v_Impuesto := 'CB';
                    WHEN 'IVA PTG'      THEN v_Impuesto := 'KK';
                    ELSE                     v_Impuesto := '';
                END CASE;
            END IF;
            
            -- Se determina la fecha de inicio
            IF REGDEPOSITO.POS_FECHA_INI_VIGENCIA > v_fechaInicioPeriodo THEN
                v_txtFechaInicio := to_char(REGDEPOSITO.POS_FECHA_INI_VIGENCIA, 'DD/MM/YYYY');
            ELSE
                v_txtFechaInicio := v_txtFechaInicioPeriodo;
            END IF;
             
            -- MPR - Se concatenan los valores que forman el codigo para que solo cargue una cabecera por pds + proveedor, independientemente de las wbe:
            -- Codigo de PDS + Codigo de proveedor
           
            IF v_cabecera is null then 
                -- Registro de DATOS - CABECERA
                IF v_codFichero = 'E4E1' then
                    contadorE4E := contadorE4E +1;
                    contadorTabla := contadorE4E;
                ELSIF v_codFichero = 'ECS1' then
                    contadorECS := contadorECS +1;
                    contadorTabla := contadorECS;
                END IF;    
                
                INSERT INTO EXT.SMM_E4E_FINAL (PERIODO, ORDEN, CAMPO1, CAMPO2, CAMPO3, CAMPO4, CAMPO5, CAMPO6, CAMPO7, CAMPO8, CAMPO9, CAMPO10, 
                                           CAMPO11, CAMPO12, CAMPO13, CAMPO14, CAMPO15, CAMPO16, CAMPO17, CAMPO18, CAMPO19, CAMPO20, CAMPO21, CAMPO22, FICHERO, BUSINESSUNIT)
				VALUES ( i_period,
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
	
			ELSIF v_cabecera <> REGDEPOSITO.PDS || REGDEPOSITO.IDPROVEEDOR then      
				-- Registro de DATOS - CABECERA
				IF v_codFichero = 'E4E1' then
					contadorE4E := contadorE4E +1;
					contadorTabla := contadorE4E;
				ELSIF v_codFichero = 'ECS1' then
					contadorECS := contadorECS +1;
					contadorTabla := contadorECS;
				END IF;    
            
				INSERT INTO EXT.SMM_E4E_FINAL (PERIODO, ORDEN, CAMPO1, CAMPO2, CAMPO3, CAMPO4, CAMPO5, CAMPO6, CAMPO7, CAMPO8, CAMPO9, CAMPO10, 
											CAMPO11, CAMPO12, CAMPO13, CAMPO14, CAMPO15, CAMPO16, CAMPO17, CAMPO18, CAMPO19, CAMPO20, CAMPO21, CAMPO22, FICHERO, BUSINESSUNIT)
				VALUES ( i_period,
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
				contadorPosicion := 10;
			ELSE
				contadorPosicion := contadorPosicion+10;
			END IF;

			-- Registro de DATOS - POSICION
			IF v_codFichero = 'E4E1' then
				contadorE4E := contadorE4E +1;
                contadorTabla := contadorE4E;
            ELSIF v_codFichero = 'ECS1' then
                contadorECS := contadorECS +1;
                contadorTabla := contadorECS;
            END IF; 
			
            INSERT INTO EXT.SMM_E4E_FINAL (PERIODO, ORDEN, CAMPO1, CAMPO2, CAMPO3, CAMPO4, CAMPO5, CAMPO6, CAMPO7, CAMPO8, CAMPO9, CAMPO10, 
                                       CAMPO11, CAMPO12, CAMPO13, CAMPO14, CAMPO15, CAMPO16, CAMPO17, CAMPO18, CAMPO19, CAMPO20, CAMPO21, CAMPO22, FICHERO, BUSINESSUNIT)
			VALUES ( i_period,
					contadorTabla,
					v_referencia,    --CAMPO1
					--'10',
					contadorPosicion,
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
					'EUR',
					v_txtFechaActual,
					REGDEPOSITO.CENTRO_LOGISTICO,
					REGDEPOSITO.WBE_FINAL_IMPUTACION,
					v_Impuesto,
					'','','','','','ES21-01',v_codFichero,
					REGDEPOSITO.BUSINESSUNIT);            

            IF REGDEPOSITO.TIPO_PAGO = 'SERVICIO' THEN
                -- Registro de DATOS - POSICION
                IF v_codFichero = 'E4E1' then
					contadorE4E := contadorE4E +1;
					contadorTabla := contadorE4E;
                ELSIF v_codFichero = 'ECS1' then
					contadorECS := contadorECS +1;
					contadorTabla := contadorECS;
                END IF; 
                
				INSERT INTO EXT.SMM_E4E_FINAL (PERIODO, ORDEN, CAMPO1, CAMPO2, CAMPO3, CAMPO4, CAMPO5, CAMPO6, CAMPO7, CAMPO8, CAMPO9, CAMPO10, 
											CAMPO11, CAMPO12, CAMPO13, CAMPO14, CAMPO15, CAMPO16, CAMPO17, CAMPO18, CAMPO19, CAMPO20, CAMPO21, CAMPO22, FICHERO, BUSINESSUNIT)
				VALUES ( i_period,
						contadorTabla,
						v_referencia,
						--'10',
						contadorPosicion,
						'SERVICIO', 
						REGDEPOSITO.COD_CONTRATO,
						'',
						REGDEPOSITO.POS_DOC,  -- CAMPO6
						CASE WHEN REGDEPOSITO.SUBPOSICION IS NULL THEN '10' ELSE REGDEPOSITO.SUBPOSICION END, -- CAMPO7
						REGDEPOSITO.CODIGO_SERVICIO,  --CAMPO8
						REGDEPOSITO.TEXTO_BREVE,
						to_char(REGDEPOSITO.VALUE),  --CAMPO10
						REGDEPOSITO.WBE_FINAL_IMPUTACION, -- CAMPO11
						'', '', '', '',                    -- CAMPO12 a 15
						'', '', '', '',                    -- CAMPO16 a 19
						'', '', '',                        -- CAMPO20 a 22
						v_codFichero,
						REGDEPOSITO.BUSINESSUNIT);
            END IF;
            
            v_cabecera := REGDEPOSITO.PDS || REGDEPOSITO.IDPROVEEDOR;
                       
            FETCH C_TMPDEPOSITOS INTO REGDEPOSITO;
            
        END LOOP;
                   
        CLOSE C_TMPDEPOSITOS;
    END;
    */
    --Si se han insertado registros de datos de E4E, se insertan los registros de cabecera para el fichero E4E2
    if contadorE4E > 4 THEN
		CALL EXT.SMM_SP_CABECERA_FICHEROS_E4E(  i_period , 'E4E1' );
	end if;
    --Si se han insertado registros de datos ECS, se insertan los registros de cabecera para el fichero ECS2
    if contadorECS > 4 THEN
		CALL EXT.SMM_SP_CABECERA_FICHEROS_E4E(  i_period , 'ECS1' );
	end if;   
        
	CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, v_proc_name,'Fin Carga de la tabla EXT.SMM_E4E_FINAL:  E4E1'|| to_char(contadorE4E) || ' -- ECS1'|| to_char(contadorECS) || ' filas.', v_log_count, v_idproceso, 'info');

    


    
  

	CALL EXT.SMM_SP_Z_CTRL_INF(v_contador_ctrl_inf, v_num_ejecucion, v_proc_name, v_finicio, current_timestamp, NULL);
	
	
	CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, v_proc_name, 'Fin procedimiento', v_log_count, v_idproceso, 'info');
end;
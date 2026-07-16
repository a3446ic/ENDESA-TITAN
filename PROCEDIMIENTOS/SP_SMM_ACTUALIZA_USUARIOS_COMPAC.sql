CREATE OR REPLACE PROCEDURE EXT.SP_SMM_ACTUALIZA_USUARIOS_COMPAC(OUT o_salidacontrol VARCHAR(50))
LANGUAGE SQLSCRIPT
SQL SECURITY INVOKER 
DEFAULT SCHEMA EXT AS
/* *****************************************************************************
   NAME: ENEL_ACTUALIZA_USUARIOS_COMPAC
   PURPOSE:

   REVISIONS:
   Ver        Date        	Author           	Description
   ---------  ----------  	---------------  	------------------------------------
   1.0        27/07/2021	Kassandra Ceña  	Creación procedimiento Usuarios CompAC
***************************************************************************** */
BEGIN

	DECLARE v_cont INT = 0;
	DECLARE v_proc_name NVARCHAR(50) := ::CURRENT_OBJECT_SCHEMA ||'.'|| ::CURRENT_OBJECT_NAME;
	DECLARE v_version NVARCHAR(4) := '0.1';
	DECLARE v_log_count INTEGER := 0;
	DECLARE v_idproceso BIGINT := 0;
	DECLARE v_tenantid NVARCHAR(4) := EXT.LIB_GLOBAL_ENDESA:getTenantID();
	DECLARE v_permisos_log NVARCHAR(50) := EXT.LIB_GLOBAL_ENDESA:GET_PERMISOS_LOG();
	DECLARE v_eot DATE := EXT.LIB_CONSTANTES_ENDESA:v_eot;
	
	DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name, 'Error en procedimiento principal ' || v_proc_name || ' - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'')
																											|| '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, v_log_count, v_idproceso, 'error');
																											
		RESIGNAL;
	END;
	
	CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name, 'Procedure starting for: ' || v_proc_name, v_log_count, v_idproceso,'info');
	

    CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Inicio Borrado de la tabla SMM_USUARIOS_ROLES.', v_log_count, v_idproceso,'info');                                                                                                                                                                 
    DELETE FROM EXT.SMM_USUARIOS_ROLES WHERE ID_USUARIO <> 'A000000' AND ID_USUARIO <> 'COD_UTENTE';                                                                                                                                         
                                                                                                                                                                                                                                   
    CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Fin Borrado de la tabla SMM_USUARIOS_ROLES.', v_log_count, v_idproceso,'info');                                                                                                                                                                    
                                                                                                                                                                                                                                                
    CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Cargando tabla SMM_USUARIOS_ROLES. TenantId: '||v_tenantid , v_log_count, v_idproceso,'info');                                                                                                                                            
                                                                                                                                                                                                                                                
                                                                                                                                                                                                                                                
                                                                                                                                                                                                                                                
                                                                                                                                                                                                                                                
                                                                                                                                                                                                                                                
    INSERT INTO EXT.SMM_USUARIOS_ROLES ( ID_USUARIO, NOMBRE_USUARIO, NOMBRE_ROL, DESCRIPCION_ROL, TIPO_RECORD,                                                                                                                               
                                            NOMBRE_APLICACION, ESTADO_USUARIO, ASIGNADOR_ROLES, COD_ROL )                                                                                                                                       
    SELECT                                                                                                                                                                                                                                      
        U.USERID,                                                                                                                                                                                                                               
        U.FIRSTNAME ||' ' || U.LASTNAME AS NOMBRE_USUARIO,                                                                                                                                                                                      
        R.NAME,                                                                                                                                                                                                                                 
        R.DESCRIPTION,                                                                                                                                                                                                                          
        'B',                                                                                                                                                                                                                                    
        'Commissions',                                                                                                                                                                                                                          
        'U',                                                                                                                                                                                                                                    
        'PortalAdmin',                                                                                                                                                                                                                          
        'A'                                                                                                                                                                                                                                     
                                                                                                                                                                                                                                                
    FROM CSI_USER U                                                                                                                                                                                                                             
    INNER JOIN CSI_PRINCIPALROLE PR ON U.USERSEQ = PR.PRINCIPALSEQ                                                                                                                                                                              
    AND PR.TENANTID = U.TENANTID                                                                                                                                                                                                                
    INNER JOIN CSI_ROLE R ON PR.ROLESEQ = R.ROLESEQ                                                                                                                                                                                             
    AND R.TENANTID = PR.TENANTID                                                                                                                                                                                                                
                                                                                                                                                                                                                                                
    WHERE U.TENANTID = v_tenantid                                                                                                                                                                                                                
    and UPPER(u.userid) not like 'PURGED%';                                                                                                                                                                                                     
    --Condición que afecta solo a DEV                                                                                                                                                                                                           
    --AND LENGTH(U.FIRSTNAME ||' ' || U.LASTNAME) <= 50;                                                                                                                                                                                        
    
    UPDATE EXT.SMM_USUARIOS_ROLES SET TOTAL_USUARIOS = (SELECT COUNT(*) FROM EXT.SMM_USUARIOS_ROLES WHERE ID_USUARIO <> 'A000000' AND ID_USUARIO <> 'COD_UTENTE')                                                                             
    WHERE ID_USUARIO = 'A000000';                                                                                                                                                                                                               
        -- commit;                                                                                                                                                                                                                                 
                                                                                                                                                                                                                                                
                                                                                                                                                                                                                                                
 /*   INSERT INTO EXT.CS_USUARIOS_ROLES ( ID_USUARIO, NOMBRE_USUARIO, NOMBRE_ROL, DESCRIPCION_ROL, TIPO_RECORD,                                                                                                                             
                                            NOMBRE_APLICACION, ESTADO_USUARIO, ASIGNADOR_ROLES, COD_ROL )                                                                                                                                       
    SELECT distinct                                                                                                                                                                                                                             
        par.USERID,                                                                                                                                                                                                                             
        par.LASTNAME AS NOMBRE_USUARIO,                                                                                                                                                                                                         
        'Participant',                                                                                                                                                                                                                          
        'Participant Role for Portal',                                                                                                                                                                                                          
        'B',                                                                                                                                                                                                                                    
        'Commissions',                                                                                                                                                                                                                          
        'U',                                                                                                                                                                                                                                    
        'PortalAdmin',                                                                                                                                                                                                                          
        'A'                                                                                                                                                                                                                                     
                                                                                                                                                                                                                                                
    FROM cs_participant par                                                                                                                                                                                                                     
                                                                                                                                                                                                                                                
    WHERE par.TENANTID = v_tenantid                                                                                                                                                                                                              
    AND PAR.REMOVEDATE = '01/01/2200'                                                                                                                                                                                                           
     AND (substr(to_char(par.TERMINATIONDATE),7,4) ||substr(to_char(par.TERMINATIONDATE),1,2)||substr(to_char(par.TERMINATIONDATE),4,2)>substr(to_char(CURRENT_DATE),7,4) ||substr(to_char(CURRENT_DATE),1,2)||substr(to_char(CURRENT_DATE),4,2)
   or par.TERMINATIONDATE is null);                                                                                                                                                                                                             
                                                                                                                                                                                                                                                
    filas := sql%rowcount;                                                                                                                                                                                                                      
                                                                                                                                                                                                                                                
                                                                                                                                                                                                                                                
                                                                                                                                                                                                                                                
    COMMIT;  */                                                                                                                                                                                                                                 
                                                                                                                                                                                                                                                
                                                                                                                                                                                                                                                
    CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Fin Carga de la tabla SMM_USUARIOS_ROLES: '|| ::ROWCOUNT || ' filas.', v_log_count, v_idproceso,'info');                                                                                                                                       
    CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, v_proc_name, 'Fin procedimiento', v_log_count, v_idproceso, 'info');
    COMMIT;
    -- EXECUTE IMMEDIATE 'ANALYZE TABLE EXT.CS_USUARIOS_ROLES COMPUTE STATISTICS FOR ALL INDEXES';                                                                                                                                             
    -- CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Fin Actualizacion Indices EXT.CS_USUARIOS_ROLES.',v_contador_debug);                                                                                                                                                           
                                                                                                                                                                                                                                          
                                                                                                                                                                                                                                                
END;                                                                                                                                                                                                              
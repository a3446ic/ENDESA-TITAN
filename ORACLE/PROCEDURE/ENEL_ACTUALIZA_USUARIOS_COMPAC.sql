create or replace PACKAGE BODY ENEL_ACTUALIZA_USUARIOS_COMPAC AS
/* *****************************************************************************
   NAME: ENEL_ACTUALIZA_USUARIOS_COMPAC
   PURPOSE:

   REVISIONS:
   Ver        Date        	Author           	Description
   ---------  ----------  	---------------  	------------------------------------
   1.0        27/07/2021	Kassandra Ceña  	Creación procedimiento Usuarios CompAC
***************************************************************************** */

    v_contador_debug	integer; 
    filas 				number; --Para el DEBUG de los INSERT

procedure w_debug ( txt IN VARCHAR2, valor IN Number)
AS
    proc_name VARCHAR2(50 CHAR) := $$PLSQL_UNIT ; -- Nombre del procedimiento para DEBUG
begin
    insert into ENELEXT.ENEL_debug(tenantid, datetime,text,VALUE) VALUES (SUBSTR (USER,1,4),SYSDATE, proc_name || ' ' || txt, valor);
    select v_contador_debug + 1 into v_contador_debug from dual;
    commit;
end;

procedure p_usuarios_compac ( itenantId IN VARCHAR2, salidacontrol out varchar2 )
AS
begin

    w_debug('Inicio Borrado de la tabla CS_USUARIOS_ROLES.', v_contador_debug);
    BEGIN
        LOOP
            DELETE FROM CS_USUARIOS_ROLES WHERE ID_USUARIO <> 'A000000' AND ID_USUARIO <> 'COD_UTENTE';
            EXIT WHEN SQL%ROWCOUNT = 0;
            COMMIT;
        END LOOP;
    END;
    w_debug('Fin Borrado de la tabla CS_USUARIOS_ROLES.', v_contador_debug);

    w_debug('Cargando tabla CS_USUARIOS_ROLES. TenantId: '||itenantId ,  v_contador_debug);
    
    
    
  
      
    INSERT INTO ENELEXT.CS_USUARIOS_ROLES ( ID_USUARIO, NOMBRE_USUARIO, NOMBRE_ROL, DESCRIPCION_ROL, TIPO_RECORD, 
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
    
    WHERE U.TENANTID = itenantId
    and UPPER(u.userid) not like 'PURGED%';
    --Condición que afecta solo a DEV
    --AND LENGTH(U.FIRSTNAME ||' ' || U.LASTNAME) <= 50;
        UPDATE ENELEXT.CS_USUARIOS_ROLES SET TOTAL_USUARIOS = (SELECT COUNT(*) FROM CS_USUARIOS_ROLES WHERE ID_USUARIO <> 'A000000' AND ID_USUARIO <> 'COD_UTENTE')
    WHERE ID_USUARIO = 'A000000';
        commit;
 
    
    INSERT INTO ENELEXT.CS_USUARIOS_ROLES ( ID_USUARIO, NOMBRE_USUARIO, NOMBRE_ROL, DESCRIPCION_ROL, TIPO_RECORD, 
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
        
    WHERE par.TENANTID = itenantId
    AND PAR.REMOVEDATE = '01/01/2200'
     AND (substr(to_char(par.TERMINATIONDATE),7,4) ||substr(to_char(par.TERMINATIONDATE),1,2)||substr(to_char(par.TERMINATIONDATE),4,2)>substr(to_char(CURRENT_DATE),7,4) ||substr(to_char(CURRENT_DATE),1,2)||substr(to_char(CURRENT_DATE),4,2)
   or par.TERMINATIONDATE is null);
        
    filas := sql%rowcount;
    
    
    
    COMMIT;  
    

    w_debug('Fin Carga de la tabla CS_USUARIOS_ROLES: '|| to_char(filas) || ' filas.', v_contador_debug);

    EXECUTE IMMEDIATE 'ANALYZE TABLE ENELEXT.CS_USUARIOS_ROLES COMPUTE STATISTICS FOR ALL INDEXES';
    w_debug('Fin Actualizacion Indices ENELEXT.CS_USUARIOS_ROLES.',v_contador_debug);
end;

END ENEL_ACTUALIZA_USUARIOS_COMPAC;
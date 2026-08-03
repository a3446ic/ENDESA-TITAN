CREATE OR REPLACE FUNCTION EXT.SMM_F_INTERFAZ_ACTIVO(
 i_Interfaz NVARCHAR(25)
)
RETURNS TABLE (
     classifierid VARCHAR(250)
     , DESCRIPTION VARCHAR(250)
     , STAGE VARCHAR(250)
     , SECUENCIA VARCHAR(250)
     , ARGUMENTOS VARCHAR(250)
     , PERIODICIDAD VARCHAR(250)
     , ACTIVO INT
     
) 
LANGUAGE SQLSCRIPT 
AS
BEGIN

	DECLARE v_tenantid NVARCHAR(4) := EXT.LIB_GLOBAL_ENDESA:getTenantID();
	DECLARE v_eot DATE := EXT.LIB_CONSTANTES_ENDESA:v_eot;
	
    RETURN 
    	SELECT
        c.classifierid,                                                                                                                                                                                                                                       
		C.DESCRIPTION,                                                                                                                                                                                                                                              
		gc.Genericattribute1 as STAGE,                                                                                                                                                                                                                              
		gc.Genericattribute2 as SECUENCIA,                                                                                                                                                                                                                          
		gc.Genericattribute3 as ARGUMENTOS,                                                                                                                                                                                                                   
		gc.Genericattribute4 as PERIODICIDAD,                                                                                                                                                                                                                       
		gc.Genericboolean1 as ACTIVO                                                                                                                                                                                                                     
                                                                                                                                                                                                                                        
                                                                                                                                                                                                                                                              
 from CS_CLASSIFIER c                                                                                                                                                                                                                                         
  inner join CS_GENERICCLASSIFIER gc                                                                                                                                                                                                                          
   on C.CLASSIFIERSEQ=GC.CLASSIFIERSEQ                                                                                                                                                                                                                        
   and gc.TENANTID = v_tenantid                                                                                                                                                                                                                                   
   and gc.REMOVEDATE  = v_eot  and gc.islast=1                                                                                                                                                                                                                
  inner join CS_CATEGORY_CLASSIFIERS ccc                                                                                                                                                                                                                      
   on ccc.CLASSIFIERSEQ = c.CLASSIFIERSEQ                                                                                                                                                                                                                     
   and ccc.TENANTID = v_tenantid                                                                                                                                                                                                                            
   and CCC.REMOVEDATE= v_eot and CCC.ISLAST=1                                                                                                                                                                                                                 
  inner join CS_CATEGORYTREE ct                                                                                                                                                                                                                               
   on CCC.CATEGORYTREESEQ=CT.CATEGORYTREESEQ                                                                                                                                                                                                                  
   and ct.TENANTID = v_tenantid                                                                                                                                                                                                                              
   and ct.REMOVEDATE= v_eot and ct.ISLAST=1                                                                                                                                                                                                                   
  INNER JOIN CS_GENERICCLASSIFIERTYPE GCT                                                                                                                                                                                                                     
   ON GCT.GENERICCLASSIFIERTYPESEQ = C.SELECTORID                                                                                                                                                                                                             
   AND C.TENANTID = v_tenantid                                                                                                                                                                                                                                 
   AND C.REMOVEDATE = v_eot                                                                                                                                                                                                                                   
                                                                                                                                                                                                                                                              
 Where       
	CT.NAME='Salida'                                                                                                                                                                                                                                            
  AND GCT.NAME ='Interfaz'                                                                                                                                                                                                                                    
  and GCT.TENANTID = v_tenantid                                                                                                                                                                                                                               
  --and c.classifierid= i_Interfaz                                                                                                                                                                                                                                
  and c.REMOVEDATE= v_eot                                                                                                                                                                                                                                     
  and c.ISLAST=1                                                                                                                                                                                                                                           
 ;   
END;

DO BEGIN
DECLARE V_PRUEBA INT;
	SELECT ACTIVO INTO V_PRUEBA DEFAULT 0 FROM EXT.SMM_F_INTERFAZ_ACTIVO('PRUEBA');
	SELECT V_PRUEBA FROM DUMMY;
END;
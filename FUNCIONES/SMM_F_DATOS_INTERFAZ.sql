CREATE OR REPLACE FUNCTION EXT.SMM_F_DATOS_INTERFAZ(IN i_interfaz NVARCHAR(20))
RETURNS TABLE (
	classifierid VARCHAR(250)
     , DESCRIPTION VARCHAR(250)
     , STAGE VARCHAR(250)
     , SECUENCIA VARCHAR(250)
     , ARGUMENTOS VARCHAR(250)
     , PERIODICIDAD VARCHAR(250)
     , ACTIVO INT
)
AS
    /*---------------------------------------------------------------------
    | Author: Samuel Miralles Manresa
    | Company: Inycom
    | Initial Version Date: XX-XX-2026
    |----------------------------------------------------------------------
    |  
    |
    | Parámetros: i_periodseq
	| Version:	0.1	SMM 2026XXXX	Initial Version.
    -----------------------------------------------------------------------
*/

BEGIN
	DECLARE v_eot DATE := EXT.LIB_CONSTANTES_ENDESA:v_eot;
	
	RETURN
    select
		c.classifierid,
		C.DESCRIPTION,
		gc.Genericattribute1 as STAGE,
		gc.Genericattribute2 as SECUENCIA,
		gc.Genericattribute3 as ARGUMENTOS,
		gc.Genericattribute4 as PERIODICIDAD,
		gc.Genericboolean1 as ACTIVO
    
	from CS_CLASSIFIER c 
    	inner join CS_GENERICCLASSIFIER gc on C.CLASSIFIERSEQ=GC.CLASSIFIERSEQ 
			and gc.TENANTID = 'EXT' 
			and gc.REMOVEDATE = v_eot and gc.islast=1

    	inner join CS_CATEGORY_CLASSIFIERS ccc on  ccc.CLASSIFIERSEQ = c.CLASSIFIERSEQ 
			and ccc.TENANTID = 'EXT' 
			and CCC.REMOVEDATE = v_eot and CCC.ISLAST=1

    	inner join CS_CATEGORYTREE ct on CCC.CATEGORYTREESEQ=CT.CATEGORYTREESEQ 
			and ct.TENANTID = 'EXT' 
			and ct.REMOVEDATE = v_eot and ct.ISLAST=1

    	INNER JOIN CS_GENERICCLASSIFIERTYPE GCT ON GCT.GENERICCLASSIFIERTYPESEQ = C.SELECTORID
			AND C.TENANTID = 'EXT' 
			AND C.REMOVEDATE = v_eot

    Where CT.NAME='Salida' 
		AND GCT.NAME ='Interfaz'
		and GCT.TENANTID = 'EXT' 
		and c.classifierid=i_interfaz 
		and c.REMOVEDATE= v_eot and c.ISLAST=1;

END
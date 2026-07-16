import org.apache.poi.xssf.usermodel.*
import org.apache.poi.ss.usermodel.*
import org.apache.poi.ss.util.CellRangeAddress
import groovy.json.JsonSlurper

// -------------------------------------------------------
// CAPA 1: Configuración (deserializada del JSON una vez)
// -------------------------------------------------------
class ConfigInforme {
    String idInforme
    String nombrePlantilla
    List<ConfigPestana> pestanas
}

class ConfigPestana {
    String nombreHoja
    String modoQuery          // 'UNICA' o 'SEPARADA'
    Map<String, String> queries   // clave: 'unica', 'cabecera', 'detalle'...
    List<ConfigFila> filas
}

class ConfigFila {
    String tipo                // RUPTURA, CABECERA_TABLA, DETALLE, TOTAL, CABECERA_FIJA
    Integer nivel               // solo para RUPTURA
    int filaPlantilla
    String campoRuptura          // solo para RUPTURA
    List<ConfigCampo> campos
    // específico de TOTAL
    String etiqueta
    String campo
    Integer columnaEtiqueta
    Integer columnaValor
}

class ConfigCampo {
    String campo                // nombre en el resultset HANA
    int columna                 // posición en la plantilla Excel
    String tipoDato = 'TEXT'    // TEXT, NUMBER, DATE, CURRENCY, BOOLEAN
    String formato               // patrón opcional, ej '#,##0.00 €'
}
// -------------------------------------------------------
// Helpers comunes [PASAR A LIBRERIA]
// -------------------------------------------------------
def capturarEstilosFila(XSSFSheet sheet, int rowIdx) {
    XSSFRow row = sheet.getRow(rowIdx)
    if (!row) return [:]
    def estilos = [:]
    row.each { XSSFCell cell -> estilos[cell.getColumnIndex()] = cell.getCellStyle() }
    return estilos
}

def copiarFila(XSSFSheet sheet, int rowIdxOrigen, int rowIdxDestino, Map estilosOrigen) {
    if (rowIdxOrigen == rowIdxDestino) return  // ya está en su sitio, nada que copiar

    XSSFWorkbook wb = (XSSFWorkbook) sheet.getWorkbook();

    XSSFRow filaOrigen  = sheet.getRow(rowIdxOrigen)
    XSSFRow filaDestino = sheet.getRow(rowIdxDestino) ?: sheet.createRow(rowIdxDestino)
    filaDestino.setHeightInPoints(filaOrigen?.getHeightInPoints() ?: 15.0f)

    estilosOrigen.each { col, estilo ->
        XSSFCell celdaDest = filaDestino.getCell(col) ?: filaDestino.createCell(col)
        XSSFCellStyle nuevoEstilo = wb.createCellStyle()
        nuevoEstilo.cloneStyleFrom(estilo)
        celdaDest.setCellStyle(nuevoEstilo)
    }

    (0..<sheet.getNumMergedRegions()).each { i ->
        CellRangeAddress merge = sheet.getMergedRegion(i)
        if (merge.firstRow == rowIdxOrigen) {
            int offset = rowIdxDestino - rowIdxOrigen
            sheet.addMergedRegion(new CellRangeAddress(
                merge.firstRow + offset, merge.lastRow + offset,
                merge.firstColumn, merge.lastColumn
            ))
        }
    }
}


def escribirCampos(XSSFSheet sheet, int filaIdx, List campos, Map registro) {
    XSSFRow row = sheet.getRow(filaIdx) ?: sheet.createRow(filaIdx)
   // out << 'escribirCampos :' + filaIdx + ' ' + campos + '\n'
   
    campos.each { c ->
        XSSFCell celda = row.getCell(c.columna) ?: row.createCell(c.columna)
        def valor = registro[c.campo]
       //  out << c.campo + ' ' + valor + '\n'
        switch (c.tipoDato) {
            case 'NUMBER':
            case 'CURRENCY':
                //celda.setCellValue(valor != null ? (valor as double) : 0.0)
                celda.setCellValue(valor?.toString() ?: '')
                break
            case 'DATE':
                if (valor instanceof Date) celda.setCellValue((Date) valor)
                // FALTA FORMATEAR
                break
            case 'BOOLEAN':
                celda.setCellValue(valor as boolean)
                break
            default:
                celda.setCellValue(valor?.toString() ?: '')
        }
    }
}
// -------------------------------------------------------
// Modo SEPARADA — cabecera fija + detalle + totales
// -------------------------------------------------------
def procesarConQuerySeparada = { XSSFSheet sheet, configPestana, List cabecera, List detalle ->

    def filasCabeceraFija = configPestana.filas.findAll { it.tipo == 'CABECERA_FIJA' }
    def filaDetalle        = configPestana.filas.find { it.tipo == 'DETALLE' }
    def filasTotal          = configPestana.filas.findAll { it.tipo == 'TOTAL' }

    def registroCabecera = cabecera[0]  // siempre 1 fila esperada

    out << 'CABECERA:'  + registroCabecera +'\n'
  //    out << filasCabeceraFija

    // Escribir cabecera fija directamente sobre la plantilla
    filasCabeceraFija.each { configFila ->
        escribirCampos(sheet, configFila.filaPlantilla, configFila.campos, registroCabecera)
    }

    // Insertar filas de detalle desplazando los totales
    int numLineas = detalle.size()
    out << 'numLineas: '  + numLineas +'\n'
    if (numLineas > 1) {
        sheet.shiftRows(filasTotal[0].filaPlantilla, sheet.getLastRowNum(), numLineas - 1)
    }

    def estiloDetalle = capturarEstilosFila(sheet, filaDetalle.filaPlantilla)
    detalle.eachWithIndex { registro, idx ->
        int fila = filaDetalle.filaPlantilla + idx
        if (idx > 0) copiarFila( sheet, filaDetalle.filaPlantilla, fila, estiloDetalle)
        escribirCampos(sheet, fila, filaDetalle.campos, registro)
    }

    // Escribir totales en su posición desplazada
    int desplazamiento = numLineas > 1 ? numLineas - 1 : 0
    filasTotal.each { configTotal ->
        int filaDestino = configTotal.filaPlantilla + desplazamiento
        //XSSFRow row = sheet.getRow(filaDestino) ?: sheet.createRow(filaDestino)
        //row.getCell(configTotal.columnaEtiqueta)?.setCellValue(configTotal.etiqueta)
        //row.getCell(configTotal.columnaValor)?.setCellValue(registroCabecera[configTotal.campo] as double)
        escribirCampos(sheet, filaDestino, configTotal.campos, registroCabecera)
    }
    out << '-----------------------------------' +'\n'
}

// =========================================================
// SCRIPT PRINCIPAL — sc_btn_motor_generico
// Parámetros esperados: idInforme, parametros (Map con
// los valores del formulario: idFactura, fechaDesde, etc.)
// =========================================================

// -------------------------------------------------------
// Obtención filtros del formulario
// -------------------------------------------------------

def in_INFORME = form.getValue('au_informe') ?: 'clientes_empresa_prefactura_is'//''
def in_PERIODO = form.getValue('au_periodo')?.capitalize() ?: 'Enero 2026' //''
def in_POSITION = form.getValue('au_mediador') ?: '0002'//''

logger.info('INFORMES EXCEL: in_INFORME:' + in_INFORME + ' in_PERIODO:' +in_PERIODO + ' in_POSITION:' + in_POSITION)

// -------------------------------------------------------
// Conexión BBDD
// -------------------------------------------------------
def db = resp.dbConnect('datasource.0416db')

// -------------------------------------------------------
// PASO 1: Recuperar plantilla y JSON del repositorio SAP
// Se asume convención de nombres: mismo idInforme, distinta extensión
// -------------------------------------------------------

if(in_INFORME && in_PERIODO && in_POSITION){

    def idInforme=''
    if (in_INFORME == 'clientes_empresa_prefactura_is') { 
        idInforme = 'Report_prefactura_ceis_MG'
    } else {
        idInforme = in_INFORME
    }

//ScriptFile plantillaFile = resp.getScriptFile("/app/templates/${idInforme}.xlsx")
//ScriptFile jsonFile       = resp.getScriptFile("/app/json/${idInforme}.json")

    templateFile = resp.storage.getFile("/app/templates/${idInforme}.xlsx");
    out << templateFile.getName() + '\n';
    //jsonFile = resp.storage.getFile("/app/json/${idInforme}.json");
    jsonFile = resp.storage.getFile("/app/json/SMM_Report_prefactura_ceis_MG.json");
    out << jsonFile.getName() + '\n';       
 
        // scriptFile es tu objeto ScriptFile del repositorio SAP
        byte[] fileBytes = templateFile.getBytes()

        if (!fileBytes || fileBytes.length == 0) {
            throw new IllegalStateException(
             "El fichero '${scriptFile.getName()}' está vacío"
            )
        }




String jsonTexto       = jsonFile.getContent()
//out << jsonTexto

if (!fileBytes || fileBytes.length == 0) {
    throw new IllegalStateException("La plantilla del informe ${idInforme} está vacía")
}

out << "Plantilla y JSON recuperados correctamente para informe ${idInforme}"+ '\n'

// -------------------------------------------------------
// PASO 2: Deserializar el JSON a la estructura de configuración
// -------------------------------------------------------
def cargarConfiguracion = { String json ->
    def slurper = new JsonSlurper()
    def parsed  = slurper.parseText(json)

    [
        idInforme       : parsed.idInforme,
        nombrePlantilla : parsed.nombrePlantilla,
        pestanas        : parsed.pestanas.collect { p ->
            [
                nombreHoja : p.nombreHoja,
                modoQuery  : p.modoQuery,
                queries    : p.modoQuery == 'UNICA'
                                ? [unica: p.query.sql]
                                : [cabecera: p.queries.cabecera.sql, detalle: p.queries.detalle.sql],
                filas      : p.filas.collect { f ->
                    [
                        tipo            : f.tipo,
                        nivel           : f.nivel,
                        filaPlantilla   : f.filaPlantilla,
                        campoRuptura    : f.campoRuptura,
                        etiqueta        : f.etiqueta,
                        campo           : f.campo,
                        columnaEtiqueta : f.columnaEtiqueta,
                        columnaValor    : f.columnaValor,
                        campos          : (f.campos ?: []).collect { c ->
                            [
                                campo    : c.campo,
                                columna  : c.columna,
                                tipoDato : c.tipoDato ?: 'TEXT',
                                formato  : c.formato
                            ]
                        }
                    ]
                }
            ]
        }
    ]
}

def config
try {
    config = cargarConfiguracion(jsonTexto)
} catch (Exception e) {
    throw new IllegalStateException("Error parseando el JSON de metadatos del informe ${idInforme}: ${e.message}")
}

out << "Configuración cargada: ${config.pestanas.size()} pestaña(s) definidas" + '\n'

// -------------------------------------------------------
// PASO 3: Abrir el workbook desde la plantilla
// -------------------------------------------------------

    // Convertir a InputStream y abrir como XSSFWorkbook
    XSSFWorkbook wb = (XSSFWorkbook) WorkbookFactory.create(
        new ByteArrayInputStream(fileBytes)
    )
    // Número total de hojas
    int numSheets = wb.getNumberOfSheets()
    out << "Número de pestañas en plantilla: ${numSheets}" + '\n'
    XSSFSheet sheet_ex = wb.getSheetAt(0)
    //out << 'getSheetName ' + sheet_ex.getSheetName() + '\n'
// -------------------------------------------------------
// PASO 4: Bucle por cada pestaña configurada
// -------------------------------------------------------
config.pestanas.each { pestanaConfig ->

    XSSFSheet sheet = wb.getSheet(pestanaConfig.nombreHoja)

    if (!sheet) {
        out << "AVISO: la hoja '${pestanaConfig.nombreHoja}' no existe en la plantilla. Se omite." + '\n'
        return  // continue del each
    }
    try {
        out << 'pestanaConfig.modoQuery: ' + pestanaConfig.modoQuery + '\n'
        if (pestanaConfig.modoQuery == 'UNICA') {
            // procesarConQueryUnica(db, sheet, wb, pestanaConfig, parametros)
        } else if (pestanaConfig.modoQuery == 'SEPARADA') {
            //procesarConQuerySeparada(db, sheet, wb, pestanaConfig, parametros)
             //out << 'pestanaConfig.queries.cabecera: ' + pestanaConfig.queries.cabecera + '\n'
             //out << 'pestanaConfig.queries.detalle: ' + pestanaConfig.queries.detalle + '\n'
            
            //Asigno valor a las variables
            def i_periodo = 'Febrero 2026'
            def i_codigoCliente = '0001'            
            

            def cabecera = db.queryForList(pestanaConfig.queries.cabecera, i_periodo,i_codigoCliente)
            def detalle  = db.queryForList(pestanaConfig.queries.detalle)
           //out << detalle
            procesarConQuerySeparada(sheet, pestanaConfig, cabecera, detalle)
        } else {
            out << "AVISO: modoQuery '${pestanaConfig.modoQuery}' no reconocido en pestaña '${pestanaConfig.nombreHoja}'"
        }
    } catch (Exception e) {
        out << "ERROR procesando pestaña '${pestanaConfig.nombreHoja}': ${e.message}"
        throw e  // decide si quieres abortar todo el informe o continuar con las demás pestañas
    }

}  // bucle pestanas



// -------------------------------------------------------
// 5. SERIALIZAR
// -------------------------------------------------------
    def fileName = idInforme +"_"+in_PERIODO+".xlsx"

    ByteArrayOutputStream byteArrayOutputStream = new ByteArrayOutputStream()
    wb.write(byteArrayOutputStream)
    byte [] fileContent = byteArrayOutputStream.toByteArray()

    def createdFile = resp.newFile(fileName, fileContent)

    //resp.cases.addAttachment( currentCase , createdFile );

    response.write(createdFile)




} // if(in_INFORME && in_PERIODO && in_POSITION)
#!/bin/bash

# Crear directorios
mkdir -p db raw_data exports scripts

# Verificar que sqlite3 esté instalado
if ! command -v sqlite3 &> /dev/null; then
    echo "sqlite3 no está instalado. Instalando..."
    sudo apt update && sudo apt install -y sqlite3
fi

# Crear crear_db.sh con todas las tablas
echo '#!/bin/bash
# Script para crear la base de datos con tablas de productos, clientes, ventas y detalle_ventas

DB_FILE=../db/tienda.db

sqlite3 $DB_FILE "
CREATE TABLE IF NOT EXISTS productos (
  producto_id INTEGER PRIMARY KEY AUTOINCREMENT,
  nombre TEXT NOT NULL,
  categoria TEXT,
  precio_unitario REAL NOT NULL,
  stock INTEGER DEFAULT 0,
  fecha_creacion DATE DEFAULT CURRENT_DATE
);
CREATE TABLE IF NOT EXISTS clientes (
  cliente_id INTEGER PRIMARY KEY AUTOINCREMENT,
  nombre TEXT NOT NULL,
  telefono TEXT,
  correo TEXT,
  direccion TEXT,
  fecha_registro DATE DEFAULT CURRENT_DATE
);
CREATE TABLE IF NOT EXISTS ventas (
  venta_id INTEGER PRIMARY KEY AUTOINCREMENT,
  cliente_id INTEGER,
  fecha_venta DATE DEFAULT CURRENT_DATE,
  total REAL NOT NULL,
  FOREIGN KEY (cliente_id) REFERENCES clientes(cliente_id)
);
CREATE TABLE IF NOT EXISTS detalle_ventas (
  detalle_id INTEGER PRIMARY KEY AUTOINCREMENT,
  venta_id INTEGER,
  producto_id INTEGER,
  cantidad INTEGER NOT NULL,
  precio_unitario REAL NOT NULL,
  subtotal REAL GENERATED ALWAYS AS (cantidad * precio_unitario),
  FOREIGN KEY (venta_id) REFERENCES ventas(venta_id),
  FOREIGN KEY (producto_id) REFERENCES productos(producto_id)
);
"

echo "Base de datos creada correctamente en $DB_FILE"
' > scripts/crear_db.sh

# Crear importar_csv.sh
echo '#!/bin/bash
# Script para insertar productos desde CSV

#!/bin/bash

# Obtener ruta absoluta de la base de datos
DB_FILE="../db/tienda.db"
RAW_DIR="../raw_data"

mkdir -p "$RAW_DIR"

# Mostrar menú de tablas
echo "¿A qué tabla deseas importar datos?"
echo "1) productos"
echo "2) clientes"
echo "3) ventas"
echo "4) detalle_ventas"
read -p "Selecciona una opción (1-4): " opcion

case $opcion in
  1) tabla="productos"; ;;
  2) tabla="clientes"; ;;
  3) tabla="ventas"; ;;
  4) tabla="detalle_ventas"; ;;
  *) echo "Opción inválida."; exit 1; ;;
esac

# Pedir archivo CSV
read -p "Nombre del archivo CSV en raw_data/ (por ejemplo: productos.csv): " archivo_csv
CSV_FILE="$RAW_DIR/$archivo_csv"

# Verificar que el archivo exista
if [[ ! -f "$CSV_FILE" ]]; then
  echo "El archivo '$CSV_FILE' no existe."
  exit 1
fi

# Importar datos
echo "Importando datos desde $CSV_FILE a la tabla..."
sqlite3 "$DB_FILE" <<EOF
.mode csv
.separator ","
.import $CSV_FILE $tabla
EOF

echo "Datos importados correctamente."

' > scripts/importar_csv.sh

# Crear consulta.sh
echo '#!/bin/bash
# Script para generar reportes desde la base de datos

DB_FILE=../db/tienda.db
EXPORT_DIR=../exports

mkdir -p "$EXPORT_DIR"

# Reporte 1: Ventas por producto (CSV)
sqlite3 -csv "$DB_FILE" "
SELECT p.nombre, SUM(d.cantidad) as unidades_vendidas
FROM detalle_ventas d
JOIN productos p ON d.producto_id = p.producto_id
GROUP BY p.nombre;
" > "$EXPORT_DIR/ventas_por_producto.csv"
echo "Reporte 'ventas_por_producto.csv' generado."

# Reporte 2: Clientes con más compras (JSON)
sqlite3 -json "$DB_FILE" "
SELECT c.nombre, COUNT(v.venta_id) as total_compras
FROM ventas v
JOIN clientes c ON v.cliente_id = c.cliente_id
GROUP BY c.nombre
ORDER BY total_compras DESC;
" > "$EXPORT_DIR/top_clientes.json"
echo "Reporte 'top_clientes.json' generado."

' > scripts/consulta.sh

# Crear export_csv.sh (exporta productos a CSV)
echo '#!/bin/bash
# Script para exportar todas las tablas de la base de datos a archivos CSV

DB_FILE="../db/tienda.db"
EXPORT_DIR="../exports"

# Lista de tablas a exportar
tablas=("productos" "clientes" "ventas" "detalle_ventas")

# Exportar cada tabla a un CSV
for tabla in "${tablas[@]}"; do
  salida="$EXPORT_DIR/${tabla}.csv"
  echo "Exportando tabla '$tabla' a '$salida'..."
  sqlite3 -header -csv "$DB_FILE" "SELECT * FROM $tabla;" > "$salida"
done

echo "Todas las tablas fueron exportadas correctamente a $EXPORT_DIR"

' > scripts/export_csv.sh

# Permisos de ejecución
chmod +x scripts/*.sh

echo "Instalación finalizada."
echo "Puedes ejecutar los scripts desde la carpeta /scripts"

read -p "¿Deseas crear la base de datos ahora? (s/n): " RESPUESTA
if [ "$RESPUESTA" == "s" ]; then
    cd scripts
    bash crear_db.sh
fi
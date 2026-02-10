#!/bin/bash

# Verificar que se pasó un archivo
if [ -z "$1" ]; then
  echo "❌ Error: Debes proporcionar la ruta al archivo de backup."
  echo "Uso: $0 ./backups/tu_archivo.sql"
  exit 1
fi

FILENAME=$1

# Verificar que el archivo existe
if [ ! -f "$FILENAME" ]; then
  echo "❌ Error: El archivo '$FILENAME' no existe."
  exit 1
fi

echo "⚠️ PRECAUCIÓN: Esto sobrescribirá los datos actuales en la base de datos."
echo "¿Estás seguro de que deseas continuar? (y/n)"
read -r response
if [[ ! "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
  echo "Operación cancelada."
  exit 1
fi

echo "Iniciando restauración de la base de datos desde $FILENAME..."

# -i para modo interactivo para recibir el stream del archivo
cat "$FILENAME" | docker exec -i lasprendas_db psql -U postgres lasprendas

if [ $? -eq 0 ]; then
  echo "✅ Restauración completada exitosamente."
else
  echo "❌ Error durante la restauración."
  exit 1
fi

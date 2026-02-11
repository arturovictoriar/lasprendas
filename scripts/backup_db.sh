#!/bin/bash
# Crear carpeta de backups si no existe
mkdir -p ./backups

# Generar nombre de archivo con fecha
FILENAME="./backups/lastprendas_backup_$(date +%Y%m%d_%H%M%S).sql"

echo "Iniciando backup de la base de datos..."
# -t para modo terminal, -U para usuario, lasprendas es la DB
docker exec -t lasprendas_db pg_dump -U postgres lasprendas > $FILENAME

if [ $? -eq 0 ]; then
  echo "✅ Backup completado exitosamente: $FILENAME"
  echo "Puedes encontrarlo en la carpeta ./backups/"
else
  echo "❌ Error al realizar el backup"
  exit 1
fi

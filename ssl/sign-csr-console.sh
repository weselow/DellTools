#!/bin/bash

# === Консольная утилита подписи CSR-файлов от локального CA ===

set -e

# Определение путей
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PKI_ROOT="$SCRIPT_DIR"
CA_NAME="trusted.server360.ru"
CA_FOLDER="$PKI_ROOT/ca"
CSR_FOLDER="$PKI_ROOT/csr"
SIGNED_FOLDER="$PKI_ROOT/signed"
PROCESSED_FOLDER="$PKI_ROOT/csr_processed"

# Проверка наличия openssl
if ! command -v openssl &> /dev/null; then
  echo "❌ OpenSSL не установлен или не найден в PATH"
  exit 1
fi

# Создание папок при необходимости
mkdir -p "$CA_FOLDER" "$CSR_FOLDER" "$SIGNED_FOLDER" "$PROCESSED_FOLDER"

# Поиск всех .csr файлов
shopt -s nullglob
CSR_FILES=("$CSR_FOLDER"/*.csr)
shopt -u nullglob

if [ ${#CSR_FILES[@]} -eq 0 ]; then
  echo "⚠️  Нет .csr файлов в папке: $CSR_FOLDER"
  exit 0
fi

echo -e "\n🔍 Найдено ${#CSR_FILES[@]} CSR-файлов. Начинаем подпись..."

for csr_path in "${CSR_FILES[@]}"; do
  filename=$(basename -- "$csr_path")
  base="${filename%.*}"
  crt_out="$SIGNED_FOLDER/$base.crt"
  san_file="$CSR_FOLDER/$base.cnf"

  echo -e "\n📜 Подпись: $filename"

  openssl x509 -req -in "$csr_path" -CA "$CA_FOLDER/$CA_NAME.crt" -CAkey "$CA_FOLDER/$CA_NAME.key" \
    -CAcreateserial -out "$crt_out" -days 730 -sha256 -extfile "$san_file"

  if [ -f "$crt_out" ]; then
    echo "✅ Сертификат создан: $crt_out"
    mv -f "$csr_path" "$PROCESSED_FOLDER/"
    [ -f "$san_file" ] && mv -f "$san_file" "$PROCESSED_FOLDER/"
  else
    echo "❌ Не удалось создать сертификат для $filename"
  fi
done
# === Консольный скрипт подписи CSR с использованием CA ===

# Пути
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$pkiRoot = $scriptDir
$caName = "trusted.server360.ru"
$caFolder = Join-Path $pkiRoot "ca"
$csrFolder = Join-Path $pkiRoot "csr"
$signedFolder = Join-Path $pkiRoot "signed"
$processedCsrFolder = Join-Path $pkiRoot "csr_processed"

# Создание папок при необходимости
$null = New-Item -ItemType Directory -Force -Path $caFolder, $csrFolder, $signedFolder, $processedCsrFolder

# Проверка наличия OpenSSL
$openssl = "openssl"
try {
    & $openssl version > $null
} catch {
    Write-Host "❌ OpenSSL не найден в PATH. Установите и повторите." -ForegroundColor Red
    exit 1
}

# Получение списка CSR-файлов
$csrFiles = Get-ChildItem -Path $csrFolder -Filter *.csr
if ($csrFiles.Count -eq 0) {
    Write-Host "⚠️  Нет CSR-файлов в папке: $csrFolder" -ForegroundColor Yellow
    exit 0
}

Write-Host "`nНайдено $($csrFiles.Count) CSR-файлов. Начинаем подпись..."

foreach ($csrFile in $csrFiles) {
    $baseName = [System.IO.Path]::GetFileNameWithoutExtension($csrFile.Name)
    $csrPath = $csrFile.FullName
    $crtOut = Join-Path $signedFolder "$baseName.crt"
    $caKey = Join-Path $caFolder "$caName.key"
    $caCrt = Join-Path $caFolder "$caName.crt"
    $sanFile = Join-Path $csrFolder "$baseName.cnf"

    Write-Host "`n📜 Подпись: $baseName.csr"
    & $openssl x509 -req -in $csrPath -CA $caCrt -CAkey $caKey -CAcreateserial `
        -out $crtOut -days 730 -sha256 -extfile $sanFile

    if (Test-Path $crtOut) {
        Write-Host "✅ Подписано: $crtOut" -ForegroundColor Green
        Move-Item -Force $csrPath (Join-Path $processedCsrFolder $csrFile.Name)
        if (Test-Path $sanFile) {
            Move-Item -Force $sanFile (Join-Path $processedCsrFolder ([IO.Path]::GetFileName($sanFile)))
        }
    } else {
        Write-Host "❌ Ошибка подписи: $baseName.csr" -ForegroundColor Red
    }
}
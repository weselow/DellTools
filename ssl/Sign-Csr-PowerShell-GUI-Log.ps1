# === GUI-обработка CSR с подписью от CA ===
Add-Type -AssemblyName Microsoft.VisualBasic
Add-Type -AssemblyName System.Windows.Forms

# Определение путей
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$pkiRoot = $scriptDir
$caName = "trusted.server360.ru"
$caFolder = Join-Path $pkiRoot "ca"
$csrFolder = Join-Path $pkiRoot "csr"
$signedFolder = Join-Path $pkiRoot "signed"
$processedCsrFolder = Join-Path $pkiRoot "csr_processed"

# Удостоверимся, что нужные папки есть
$null = New-Item -ItemType Directory -Force -Path $caFolder, $csrFolder, $signedFolder, $processedCsrFolder

# Выбор файла CSR
$openFileDialog = New-Object System.Windows.Forms.OpenFileDialog
$openFileDialog.InitialDirectory = $csrFolder
$openFileDialog.Filter = "CSR Files (*.csr)|*.csr"
$openFileDialog.Title = "Выберите CSR-файл для подписи"

if ($openFileDialog.ShowDialog() -ne "OK") {
    Write-Host "Операция отменена"
    exit
}

$csrPath = $openFileDialog.FileName
$baseName = [System.IO.Path]::GetFileNameWithoutExtension($csrPath)
$crtOut = Join-Path $signedFolder "$baseName.crt"
$caKey = Join-Path $caFolder "$caName.key"
$caCrt = Join-Path $caFolder "$caName.crt"
$sanFile = Join-Path $csrFolder "$baseName.cnf"

# Проверка наличия openssl
$openssl = "openssl"
try {
    & $openssl version > $null
} catch {
    [System.Windows.Forms.MessageBox]::Show("OpenSSL не найден в PATH. Установите OpenSSL и повторите попытку.","Ошибка",0,[System.Windows.Forms.MessageBoxIcon]::Error)
    exit
}

# Подпись
Write-Host "`n📜 Подписываем $baseName.csr..."
& $openssl x509 -req -in $csrPath -CA $caCrt -CAkey $caKey -CAcreateserial `
    -out $crtOut -days 730 -sha256 -extfile $sanFile

if (Test-Path $crtOut) {
    Write-Host "✅ Сертификат создан: $crtOut"

    # Переместим CSR в архив
    $archivedCsr = Join-Path $processedCsrFolder ([IO.Path]::GetFileName($csrPath))
    Move-Item -Force $csrPath $archivedCsr
    if (Test-Path $sanFile) {
        Move-Item -Force $sanFile (Join-Path $processedCsrFolder ([IO.Path]::GetFileName($sanFile)))
    }
} else {
    Write-Host "❌ Не удалось создать сертификат"
}
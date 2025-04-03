# PowerShell-скрипт для подписи CSR от iDRAC8 и генерации SSL-сертификатов
# Требует: установленный OpenSSL доступен в PATH

$caDir = "pki/ca"
$signedDir = "signed"
$null = New-Item -ItemType Directory -Path $caDir -Force
$null = New-Item -ItemType Directory -Path $signedDir -Force

$caKey = $null
$caCert = $null

# Поиск или генерация CA
$existingCa = Get-ChildItem -Path $caDir -Filter "*.crt" | Where-Object { Test-Path (Join-Path $caDir ($_.BaseName + ".key")) }

if ($existingCa.Count -gt 0) {
    $caCert = $existingCa[0].FullName
    $caKey = Join-Path $caDir ($existingCa[0].BaseName + ".key")
    Write-Host "🔍 Найден существующий CA: $caCert"
} else {
    Write-Host "⚠️  CA не найден в '$caDir'."
    $caName = Read-Host "Введите имя для нового CA (например, my-ca)"
    
    $caKey = Join-Path $caDir "$caName.key"
    $caCert = Join-Path $caDir "$caName.crt"
    $caPfx  = Join-Path $caDir "$caName.pfx"

    & openssl genrsa -out $caKey 2048
    & openssl req -x509 -new -nodes -key $caKey -sha256 -days 1825 `
        -subj "/C=RU/ST=Moscow/L=Moscow/O=MyOrg/OU=IT/CN=$caName Root CA" -out $caCert

    & openssl pkcs12 -export -out $caPfx -inkey $caKey -in $caCert -passout pass:

    Write-Host "✅ Новый CA создан: $caCert / $caKey"
    Write-Host "🔐 CA сертификат экспортирован в PKCS#12: $caPfx"
}

# Обработка всех CSR
Get-ChildItem -Filter "csr*.txt" | ForEach-Object {
    $csrFile = $_.FullName
    Write-Host "`n🔧 Обработка CSR: $csrFile"

    $mainSan = Read-Host "Введите основной hostname (например, idrac8)"
    $domain  = Read-Host "Введите домен (например, example.local)"
    $ip      = Read-Host "Введите IP адрес (например, 192.168.1.100)"
    $days    = Read-Host "Введите срок действия (в днях, по умолчанию 1825)"
    if ([string]::IsNullOrWhiteSpace($days)) { $days = 1825 }

    $sanList = @("DNS:$mainSan", "DNS:$mainSan.$domain")
    if (-not [string]::IsNullOrWhiteSpace($ip)) {
        $sanList += "IP:$ip"
    }
    $sanCombined = $sanList -join ", "

    $name = $mainSan
    $outDir = Join-Path $signedDir $name
    $null = New-Item -ItemType Directory -Path $outDir -Force

    $extFile = Join-Path $outDir "extfile.cnf"
    "subjectAltName=$sanCombined" | Out-File -Encoding ascii $extFile

    $crtPath = Join-Path $outDir "$name.crt"
    $pemPath = Join-Path $outDir "$name.full.pem"
    $pfxPath = Join-Path $outDir "$name.pfx"

    # Подпись сертификата
    & openssl x509 -req -in $csrFile -CA $caCert -CAkey $caKey `
        -CAcreateserial -out $crtPath -days $days -extfile $extFile

    # Формирование PEM
    Get-Content $crtPath, $caCert | Set-Content -Encoding ascii $pemPath

    # Формирование PFX
    & openssl pkcs12 -export -inkey $caKey -in $crtPath -certfile $caCert `
        -out $pfxPath -passout pass:

    Write-Host "✅ Сертификат создан: $crtPath"
    Write-Host "📦 Полный PEM: $pemPath"
    Write-Host "🔐 Итоговый PFX: $pfxPath"

    Remove-Item $csrFile
    Write-Host "🗑️ Удалён CSR: $csrFile"
}

Write-Host "`n🎉 Все CSR обработаны. Сертификаты в папке '$signedDir/'"

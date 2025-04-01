
# === iDRAC Certificate Generator (относительные пути + OpenSSL check) ===

# Получение пути к скрипту
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$pkiRoot = Join-Path $ScriptDir "pki"

# Путь к OpenSSL
$openssl = "C:\Program Files\OpenSSL-Win64\bin\openssl.exe"

# Проверка наличия OpenSSL
if (!(Test-Path $openssl)) {
    Write-Host "❌ OpenSSL не найден по пути: $openssl" -ForegroundColor Red
    Write-Host "🔧 Пожалуйста, установите OpenSSL отсюда: https://slproweb.com/products/Win32OpenSSL.html" -ForegroundColor Yellow
    exit 1
}

# Запрос параметров у пользователя
$hostnameShort = Read-Host "Введите короткое имя хоста (например: idrac-castle)"
$domain = Read-Host "Введите домен (например: jabc.loc)"
$ipAddr = Read-Host "Введите IP-адрес iDRAC (например: 10.20.0.140)"

$hostnameFqdn = "$hostnameShort.$domain"
$caName = "trusted.server360.ru"
$device = "$hostnameShort"

# Пути
$caKey = Join-Path $pkiRoot "ca\$caName.key"
$caCrt = Join-Path $pkiRoot "ca\$caName.crt"
$devDir = Join-Path $pkiRoot $device

# Создаём папки
New-Item -ItemType Directory -Path (Join-Path $pkiRoot "ca") -Force | Out-Null
New-Item -ItemType Directory -Path $devDir -Force | Out-Null

# === 1. Если CA ещё не существует — создать ===
if (!(Test-Path $caKey)) {
    & $openssl genrsa -out $caKey 4096
    & $openssl req -x509 -new -nodes -key $caKey `
        -sha256 -days 3650 -out $caCrt `
        -subj "/CN=Trusted Internal CA/O=server360.ru/OU=IT/C=RU"
}

# === 2. Генерация приватного ключа устройства ===
$keyPath = Join-Path $devDir "$device.key"
& $openssl genrsa -out $keyPath 2048

# === 3. Создание CSR ===
$csrPath = Join-Path $devDir "$device.csr"
& $openssl req -new -key $keyPath `
    -out $csrPath `
    -subj "/C=RU/ST=DO/L=IT Department/O=server360.ru/OU=DevOps/CN=$hostnameFqdn/emailAddress=mail@server360.ru"

# === 4. Создание конфигурации SAN ===
$sanPath = Join-Path $devDir "san.cnf"
@"
subjectAltName = DNS:$hostnameFqdn, DNS:$hostnameShort, IP:$ipAddr
"@ | Set-Content $sanPath

# === 5. Подпись сертификата CA ===
$crtPath = Join-Path $devDir "$device.crt"
& $openssl x509 -req -in $csrPath `
    -CA $caCrt `
    -CAkey $caKey `
    -CAcreateserial `
    -out $crtPath `
    -days 730 -sha256 `
    -extfile $sanPath

# === 6. Объединение PEM для загрузки в iDRAC (если нужно)
$pemPath = Join-Path $devDir "$device.pem"
Get-Content $keyPath, $crtPath | Set-Content $pemPath -Encoding ascii

Write-Host "`n✅ Сертификат для iDRAC создан:"
Write-Host "   - Сертификат: $crtPath"
Write-Host "   - Приватный ключ: $keyPath"
Write-Host "   - Объединённый PEM (для загрузки): $pemPath"
Write-Host "   - CA: $caCrt"

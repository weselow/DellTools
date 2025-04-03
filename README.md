# DellTools
Скрипты и инструменты для работы с серверами Dell

## Как установить свой SSL-сертификат в iDRAC 8

В Idrac8 есть особенности установки самоподписанных ssl. Особенно, если есть желание еще и по ip-адресу заходить без красных предупреждений о небезопасном соединении.

## 🧰 Что делает каждый скрипт

| Скрипт                  | ОС                       | Описание                                                      |
|-------------------------|--------------------------|----------------------------------------------------------------|
| `idrac-cert-generator.ps1` | 🪟 Windows PowerShell     | Генерирует CA, ключ, сертификат, `.pem` — всё с нуля           |
| `Sign-Csr-GUI-Log.ps1`     | 🪟 Windows PowerShell (GUI) | Подписывает CSR через окно выбора файла                        |
| `Sign-Csr-Console.ps1`     | 🪟 Windows PowerShell (CLI) | Подписывает все CSR из папки `csr/`                            |
| `sign-csr-console.sh`      | 🐧 Linux (bash)            | Аналог консольного скрипта для Linux-серверов                 |


Инструкция, как пользоваться этими скриптами, тут: 

https://server360.ru/kak-ustanovit-ssl-sertifikat-na-dell-idrac8-realnyj-opyt-oshibki-i-gotovoe-reshenie/

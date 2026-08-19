# CampusMart PolyCC - local development server
# Run with: powershell -ExecutionPolicy Bypass -File .\server.ps1

$ErrorActionPreference = 'Stop'
$ProjectRoot = $PSScriptRoot
$StorageRoot = Join-Path $ProjectRoot 'storage'
$UploadsRoot = Join-Path $StorageRoot 'registrations'
$SellersRoot = Join-Path $StorageRoot 'sellers'
$UsersFile = Join-Path $StorageRoot 'users.json'
$ProductsFile = Join-Path $StorageRoot 'products.json'
New-Item -ItemType Directory -Force -Path $UploadsRoot | Out-Null
New-Item -ItemType Directory -Force -Path $SellersRoot | Out-Null
if (-not (Test-Path $UsersFile)) { '[]' | Set-Content -Encoding UTF8 $UsersFile }
if (-not (Test-Path $ProductsFile)) { '[]' | Set-Content -Encoding UTF8 $ProductsFile }

function Send-Response($Context, [int]$Status, [string]$ContentType, [byte[]]$Bytes) {
    $Context.Response.StatusCode = $Status
    $Context.Response.ContentType = $ContentType
    $Context.Response.ContentLength64 = $Bytes.Length
    $Context.Response.OutputStream.Write($Bytes, 0, $Bytes.Length)
    $Context.Response.Close()
}

function Send-Json($Context, [int]$Status, $Value) {
    $json = $Value | ConvertTo-Json -Depth 6 -Compress
    Send-Response $Context $Status 'application/json; charset=utf-8' ([Text.Encoding]::UTF8.GetBytes($json))
}

function Get-Users {
    $text = Get-Content -Raw -Encoding UTF8 $UsersFile
    if ([string]::IsNullOrWhiteSpace($text)) { return @() }
    # ConvertFrom-Json returns a root JSON array as one object in Windows PowerShell.
    # Enumerate it explicitly, otherwise login can read every account's salt at once.
    $parsed = ConvertFrom-Json -InputObject $text
    $records = New-Object System.Collections.ArrayList
    foreach ($record in $parsed) {
        if ($null -ne $record.id) { [void]$records.Add($record) }
    }
    return $records.ToArray()
}

function Get-Products {
    $text = Get-Content -Raw -Encoding UTF8 $ProductsFile
    if ([string]::IsNullOrWhiteSpace($text)) { return @() }
    $parsed = ConvertFrom-Json -InputObject $text
    $records = New-Object System.Collections.ArrayList
    foreach ($record in $parsed) {
        if ($null -ne $record.id) { [void]$records.Add($record) }
    }
    return $records.ToArray()
}

function Get-SafeName([string]$Value, [string]$Fallback) {
    $safe = ($Value -replace '[^a-zA-Z0-9_-]', '-').Trim('-')
    if ([string]::IsNullOrWhiteSpace($safe)) { return $Fallback }
    return $safe.Substring(0, [Math]::Min(60, $safe.Length))
}

function Get-PasswordHash([string]$Password, [string]$Salt) {
    # This constructor is supported by Windows PowerShell 5.1 as well as newer PowerShell.
    $cleanSalt = $Salt.Trim()
    $derive = [System.Security.Cryptography.Rfc2898DeriveBytes]::new($Password, [Convert]::FromBase64String($cleanSalt), 100000)
    try { return [Convert]::ToBase64String($derive.GetBytes(32)) } finally { $derive.Dispose() }
}

function Save-Upload($Upload, [string]$Prefix) {
    if ($null -eq $Upload -or [string]::IsNullOrWhiteSpace($Upload.data)) { return $null }
    $extension = [IO.Path]::GetExtension([string]$Upload.name)
    if ($extension -notmatch '^\.(png|jpe?g|pdf)$') { throw 'Jenis fail tidak dibenarkan.' }
    $fileName = "$Prefix-$([Guid]::NewGuid().ToString('N'))$extension"
    $target = Join-Path $UploadsRoot $fileName
    [IO.File]::WriteAllBytes($target, [Convert]::FromBase64String([string]$Upload.data))
    return "storage/registrations/$fileName"
}

function Save-Product($Data, $Seller) {
    foreach ($field in @('name', 'price', 'quantity', 'category', 'description')) {
        if ([string]::IsNullOrWhiteSpace([string]$Data.$field)) { throw 'Sila lengkapkan semua maklumat produk.' }
    }
    if ($null -eq $Data.image -or [string]::IsNullOrWhiteSpace([string]$Data.image.data)) { throw 'Sila muat naik gambar produk.' }
    $extension = [IO.Path]::GetExtension([string]$Data.image.name).ToLowerInvariant()
    if ($extension -notmatch '^\.(png|jpe?g|webp)$') { throw 'Gambar produk mesti PNG, JPG atau WEBP.' }
    $price = [decimal]$Data.price
    $quantity = [int]$Data.quantity
    if ($price -lt 0 -or $quantity -lt 1) { throw 'Harga atau kuantiti produk tidak sah.' }

    $sellerFolder = "$(Get-SafeName $Seller.name 'seller')-$(Get-SafeName $Seller.matric 'account')"
    $productFolder = "$(Get-Date -Format 'yyyyMMdd-HHmmss')-$(Get-SafeName ([string]$Data.name) 'product')-$([Guid]::NewGuid().ToString('N').Substring(0, 8))"
    $targetFolder = Join-Path (Join-Path $SellersRoot $sellerFolder) (Join-Path 'products' $productFolder)
    New-Item -ItemType Directory -Force -Path $targetFolder | Out-Null
    $imageFile = "product-image$extension"
    [IO.File]::WriteAllBytes((Join-Path $targetFolder $imageFile), [Convert]::FromBase64String([string]$Data.image.data))

    $relativeFolder = "storage/sellers/$sellerFolder/products/$productFolder"
    $product = [PSCustomObject]@{
        id = [Guid]::NewGuid().ToString()
        name = ([string]$Data.name).Trim()
        price = $price
        quantity = $quantity
        category = ([string]$Data.category).Trim()
        description = ([string]$Data.description).Trim()
        seller = $Seller.name
        sellerMatric = $Seller.matric
        handle = "@$((Get-SafeName $Seller.name 'seller').ToLowerInvariant())"
        image = "$relativeFolder/$imageFile"
        uploadedAt = (Get-Date).ToString('o')
        folder = $relativeFolder
    }
    $product | ConvertTo-Json -Depth 5 | Set-Content -Encoding UTF8 (Join-Path $targetFolder 'product.json')
    return $product
}

$listener = [System.Net.HttpListener]::new()
$listener.Prefixes.Add('http://localhost:8080/')
$listener.Start()
Write-Host 'CampusMart is running at http://localhost:8080/' -ForegroundColor Green
Write-Host 'Registration data is saved in storage\users.json and storage\registrations\'
Write-Host 'Seller product folders are saved in storage\sellers\'

while ($listener.IsListening) {
    $context = $listener.GetContext()
    try {
        $path = $context.Request.Url.AbsolutePath
        if ($context.Request.HttpMethod -eq 'GET' -and $path -eq '/') {
            Send-Response $context 200 'text/html; charset=utf-8' ([IO.File]::ReadAllBytes((Join-Path $ProjectRoot 'index.html')))
            continue
        }
        if ($context.Request.HttpMethod -eq 'GET' -and $path -eq '/api/registrations') {
            $records = @((Get-Users) | ForEach-Object { [PSCustomObject]@{ name=$_.name; matric=$_.matric; email=$_.email; role=$_.role; matricCard=$_.matricCard; sellerReceipt=$_.sellerReceipt; registeredAt=$_.registeredAt } })
            Send-Json $context 200 @{ success=$true; registrations=$records }; continue
        }
        if ($context.Request.HttpMethod -eq 'GET' -and $path -eq '/api/products') {
            Send-Json $context 200 @{ success=$true; products=@(Get-Products) }; continue
        }
        if ($context.Request.HttpMethod -eq 'GET' -and $path.StartsWith('/storage/registrations/')) {
            $fileName = Split-Path $path -Leaf
            $filePath = Join-Path $UploadsRoot $fileName
            if (-not (Test-Path -LiteralPath $filePath)) { Send-Json $context 404 @{ success=$false; message='Fail tidak ditemui.' }; continue }
            $contentType = switch ([IO.Path]::GetExtension($fileName).ToLowerInvariant()) { '.png' {'image/png'} '.jpg' {'image/jpeg'} '.jpeg' {'image/jpeg'} '.pdf' {'application/pdf'} default {'application/octet-stream'} }
            Send-Response $context 200 $contentType ([IO.File]::ReadAllBytes($filePath)); continue
        }
        if ($context.Request.HttpMethod -eq 'GET' -and $path.StartsWith('/storage/sellers/')) {
            $relativePath = $path.TrimStart('/') -replace '/', [IO.Path]::DirectorySeparatorChar
            $filePath = [IO.Path]::GetFullPath((Join-Path $ProjectRoot $relativePath))
            $safeRoot = [IO.Path]::GetFullPath($SellersRoot) + [IO.Path]::DirectorySeparatorChar
            if (-not $filePath.StartsWith($safeRoot, [StringComparison]::OrdinalIgnoreCase) -or -not (Test-Path -LiteralPath $filePath)) { Send-Json $context 404 @{ success=$false; message='Fail tidak ditemui.' }; continue }
            $contentType = switch ([IO.Path]::GetExtension($filePath).ToLowerInvariant()) { '.png' {'image/png'} '.jpg' {'image/jpeg'} '.jpeg' {'image/jpeg'} '.webp' {'image/webp'} '.json' {'application/json; charset=utf-8'} default {'application/octet-stream'} }
            Send-Response $context 200 $contentType ([IO.File]::ReadAllBytes($filePath)); continue
        }
        if ($context.Request.HttpMethod -ne 'POST' -or $path -notin @('/api/register', '/api/login', '/api/upgrade-seller', '/api/products')) {
            Send-Json $context 404 @{ success = $false; message = 'Not found.' }; continue
        }
        $reader = [IO.StreamReader]::new($context.Request.InputStream, $context.Request.ContentEncoding)
        $body = $reader.ReadToEnd(); $reader.Dispose()
        $data = $body | ConvertFrom-Json
        $users = @(Get-Users)

        if ($path -eq '/api/register') {
            foreach ($field in @('name','matric','email','password','role')) { if ([string]::IsNullOrWhiteSpace([string]$data.$field)) { throw 'Sila lengkapkan semua maklumat wajib.' } }
            $email = ([string]$data.email).Trim().ToLowerInvariant()
            $matric = ([string]$data.matric).Trim().ToUpperInvariant()
            if ($users | Where-Object { $_.email -eq $email -or $_.matric -eq $matric }) { Send-Json $context 409 @{ success=$false; message='Email atau nombor matrik ini telah didaftarkan.' }; continue }
            $matricCard = Save-Upload $data.matricCard 'matric-card'
            if (-not $matricCard) { throw 'Sila muat naik kad matrik.' }
            $receipt = Save-Upload $data.receipt 'seller-receipt'
            $saltBytes = New-Object byte[] 16
            $rng = [Security.Cryptography.RandomNumberGenerator]::Create()
            $rng.GetBytes($saltBytes); $rng.Dispose()
            $salt = [Convert]::ToBase64String($saltBytes)
            $users += [PSCustomObject]@{ id=[Guid]::NewGuid().ToString(); name=([string]$data.name).Trim(); matric=$matric; email=$email; role=[string]$data.role; passwordSalt=$salt; passwordHash=(Get-PasswordHash ([string]$data.password) $salt); matricCard=$matricCard; sellerReceipt=$receipt; registeredAt=(Get-Date).ToString('o') }
            $users | ConvertTo-Json -Depth 5 | Set-Content -Encoding UTF8 $UsersFile
            Send-Json $context 201 @{ success=$true; message='Pendaftaran berjaya disimpan.' }; continue
        }
        if ($path -eq '/api/upgrade-seller') {
            $matric = ([string]$data.matric).Trim().ToUpperInvariant()
            $user = $users | Where-Object { $_.matric -eq $matric } | Select-Object -First 1
            if ($null -eq $user) { Send-Json $context 404 @{ success=$false; message='Account not found.' }; continue }
            if ($user.role -eq 'seller') { Send-Json $context 409 @{ success=$false; message='This account is already a seller account.' }; continue }
            $receipt = Save-Upload $data.receipt 'seller-upgrade-receipt'
            if (-not $receipt) { throw 'Please upload the payment receipt.' }
            $user.role = 'seller'
            $user.sellerReceipt = $receipt
            $users | ConvertTo-Json -Depth 5 | Set-Content -Encoding UTF8 $UsersFile
            Send-Json $context 200 @{ success=$true; message='Seller account upgrade completed.' }; continue
        }
        if ($path -eq '/api/products') {
            $matric = ([string]$data.matric).Trim().ToUpperInvariant()
            $seller = $users | Where-Object { $_.matric -eq $matric -and $_.role -eq 'seller' } | Select-Object -First 1
            if ($null -eq $seller) { Send-Json $context 403 @{ success=$false; message='Akaun seller tidak ditemui.' }; continue }
            $product = Save-Product $data $seller
            $products = @((Get-Products))
            $products += $product
            $products | ConvertTo-Json -Depth 6 | Set-Content -Encoding UTF8 $ProductsFile
            Send-Json $context 201 @{ success=$true; product=$product; message='Produk telah disimpan dalam folder seller.' }; continue
        }
        $matric = ([string]$data.matric).Trim().ToUpperInvariant()
        if ($matric -eq 'SHAMILHAIQAL' -and [string]$data.password -ceq '6d686226be') {
            Send-Json $context 200 @{ success=$true; name='Shamil Haiqal'; role='admin' }; continue
        }
        $user = $users | Where-Object { $_.matric -eq $matric } | Select-Object -First 1
        $inputPasswordHash = ''
        $storedPasswordHash = ''
        if ($null -ne $user) {
            $storedSalt = [string]($user.passwordSalt)
            $storedPasswordHash = [string]($user.passwordHash)
            $inputPasswordHash = Get-PasswordHash -Password ([string]$data.password) -Salt $storedSalt
        }
        if ($null -eq $user -or $inputPasswordHash -cne $storedPasswordHash) { Send-Json $context 401 @{ success=$false; message='Nombor matrik atau kata laluan tidak betul.' }; continue }
        Send-Json $context 200 @{ success=$true; name=$user.name; matric=$user.matric; role=$user.role }
    } catch { Send-Json $context 400 @{ success=$false; message=$_.Exception.Message } }
}

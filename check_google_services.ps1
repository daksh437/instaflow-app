# Google Services.json Checker Script

Write-Host ""
Write-Host "Checking google-services.json file..." -ForegroundColor Cyan
Write-Host ""

$filePath = "android\app\google-services.json"

if (Test-Path $filePath) {
    Write-Host "File found: $filePath" -ForegroundColor Green
    Write-Host ""
    
    $jsonContent = Get-Content $filePath -Raw
    $content = $jsonContent | ConvertFrom-Json
    
    # Check oauth_client
    $oauthClients = $content.client[0].oauth_client
    
    if ($oauthClients.Count -eq 0) {
        Write-Host "OAuth client is EMPTY!" -ForegroundColor Red
        Write-Host ""
        Write-Host "Solution:" -ForegroundColor Yellow
        Write-Host "1. Go to Firebase Console:" -ForegroundColor White
        Write-Host "   https://console.firebase.google.com/project/insta-flow-7d1a7/settings/general/android:com.Instaflow.app" -ForegroundColor Cyan
        Write-Host "2. Scroll down and click 'Download google-services.json'" -ForegroundColor White
        Write-Host "3. Replace the file in: android\app\google-services.json" -ForegroundColor White
        Write-Host ""
    } else {
        Write-Host "OAuth client configured! Found $($oauthClients.Count) client(s)" -ForegroundColor Green
        Write-Host ""
    }
    
    # Check project info
    Write-Host "Project Info:" -ForegroundColor Cyan
    Write-Host "  Project ID: $($content.project_info.project_id)" -ForegroundColor Gray
    Write-Host "  Package: $($content.client[0].client_info.android_client_info.package_name)" -ForegroundColor Gray
    Write-Host ""
} else {
    Write-Host "File not found: $filePath" -ForegroundColor Red
    Write-Host ""
}

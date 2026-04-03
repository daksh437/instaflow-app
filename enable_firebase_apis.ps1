# Enable Firebase APIs for instaflow-fosao
# Run this script in PowerShell

Write-Host "🔥 Enabling Firebase APIs for instaflow-fosao..." -ForegroundColor Cyan
Write-Host ""

# Set project
$PROJECT_ID = "instaflow-fosao"

# List of APIs to enable
$APIS = @(
    "identitytoolkit.googleapis.com",
    "fcm.googleapis.com",
    "firebaseremoteconfig.googleapis.com",
    "firebasedynamiclinks.googleapis.com",
    "firebaseinappmessaging.googleapis.com",
    "firebaseappcheck.googleapis.com",
    "firebaseml.googleapis.com",
    "analyticsdata.googleapis.com",
    "analyticsadmin.googleapis.com",
    "firestore.googleapis.com",
    "firebasestorage.googleapis.com",
    "generativelanguage.googleapis.com"
)

Write-Host "Setting project to: $PROJECT_ID" -ForegroundColor Yellow
gcloud config set project $PROJECT_ID

Write-Host ""
Write-Host "Enabling APIs..." -ForegroundColor Yellow
Write-Host ""

$successCount = 0
$failCount = 0

foreach ($api in $APIS) {
    Write-Host "Enabling $api..." -ForegroundColor Cyan
    $result = gcloud services enable $api --project=$PROJECT_ID 2>&1
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  ✅ Enabled: $api" -ForegroundColor Green
        $successCount++
    } else {
        Write-Host "  ❌ Failed: $api" -ForegroundColor Red
        Write-Host "  Error: $result" -ForegroundColor Red
        $failCount++
    }
    Write-Host ""
}

Write-Host "═══════════════════════════════════════" -ForegroundColor Cyan
Write-Host "Summary:" -ForegroundColor Yellow
Write-Host "  ✅ Success: $successCount" -ForegroundColor Green
Write-Host "  ❌ Failed: $failCount" -ForegroundColor Red
Write-Host ""

if ($failCount -eq 0) {
    Write-Host "✅ All APIs enabled successfully!" -ForegroundColor Green
} else {
    Write-Host "⚠️ Some APIs failed to enable. Check errors above." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Checking enabled APIs..." -ForegroundColor Yellow
gcloud services list --enabled --project=$PROJECT_ID --format="table(serviceName,serviceState)"


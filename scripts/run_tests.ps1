# Script de Execução da Suíte Completa de Testes e Análise de Código
# Ministério Pessoal

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host " Executando Análise e Testes Automatizados " -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

if ($env:PATH -notlike "*C:\Users\vanes\flutter\bin*") {
    $env:PATH = "C:\Users\vanes\flutter\bin;$env:PATH"
}

Write-Host "`n[1/2] Executando Análise Estática (dart analyze)..." -ForegroundColor Yellow
dart analyze lib test

if ($LASTEXITCODE -ne 0) {
    Write-Host "`n[FALHA] A análise estática encontrou erros ou avisos graves." -ForegroundColor Red
    exit $LASTEXITCODE
}

Write-Host "`n[2/2] Executando Testes Unitários e de Integração (flutter test)..." -ForegroundColor Yellow
flutter test --reporter expanded

if ($LASTEXITCODE -ne 0) {
    Write-Host "`n[FALHA] Um ou mais testes falharam." -ForegroundColor Red
    exit $LASTEXITCODE
}

Write-Host "`n[SUCESSO] Todos os testes passaram e o código está 100% em conformidade!" -ForegroundColor Green

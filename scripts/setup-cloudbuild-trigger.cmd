@echo off
REM Create Cloud Build trigger: auto build + update routing-engine on push to main
REM Prerequisite: connect GitHub repo in Cloud Build Console (one time)
REM   https://console.cloud.google.com/cloud-build/triggers/connect?project=cybertranspay

set PROJECT_ID=cybertranspay
set REGION=europe-west1
set TRIGGER_NAME=routing-engine-main
set REPO_OWNER=tyom2001-cell
set REPO_NAME=cybertranspay

echo === Cloud Build trigger setup ===
echo Project: %PROJECT_ID%
echo Trigger: %TRIGGER_NAME% (branch ^main^)
echo.

echo [1/3] IAM permissions (skip with SKIP_IAM=1 if already granted)...
if /I "%SKIP_IAM%"=="1" (
  echo   Skipped — using existing IAM.
) else (
  call "%~dp0grant-cloudbuild-permissions.cmd"
)

echo.
echo [2/3] Checking existing trigger...
gcloud builds triggers describe %TRIGGER_NAME% --region=%REGION% --project=%PROJECT_ID% >nul 2>&1
if not errorlevel 1 (
  echo Trigger "%TRIGGER_NAME%" already exists.
  goto :list
)

echo [3/3] Creating trigger...
gcloud builds triggers create github ^
  --name=%TRIGGER_NAME% ^
  --repo-name=%REPO_NAME% ^
  --repo-owner=%REPO_OWNER% ^
  --branch-pattern=^main$ ^
  --build-config=cloudbuild.yaml ^
  --region=%REGION% ^
  --project=%PROJECT_ID%
if errorlevel 1 goto :trigger_error

:list
echo.
echo === Triggers ===
gcloud builds triggers list --region=%REGION% --project=%PROJECT_ID%
echo.
echo Done. Push to main will run: build -^> push -^> update Cloud Run.
echo Manual update still works: scripts\update-routing-engine.cmd
goto :eof

:trigger_error
echo.
echo FAILED to create trigger.
echo Connect GitHub first:
echo   https://console.cloud.google.com/cloud-build/triggers/connect?project=%PROJECT_ID%
echo Then run this script again.
exit /b 1

#!/usr/bin/env bash
# =============================================================================
# run_job.sh — Submete o job de RDDs (word count) no EMR Serverless.
#
# O que este script faz:
#   1. Descobre BUCKET, APP_ID e ROLE_ARN a partir dos outputs do Terraform
#      (../infra) OU das variaveis de ambiente BUCKET/APP_ID/ROLE_ARN.
#   2. Envia o script PySpark e o dado de exemplo para o S3.
#   3. Dispara o job (start-job-run) e captura o jobRunId.
#   4. Faz polling do estado ate SUCCESS ou FAILED.
#
# Uso (dentro de aws-lab/scripts):
#   ./run_job.sh
# Ou informando manualmente:
#   BUCKET=meu-bucket APP_ID=xxxx ROLE_ARN=arn:aws:iam::...:role/LabRole ./run_job.sh
#
# Requer: AWS CLI v2 configurado com as credenciais do Learner Lab (us-east-1).
# =============================================================================
set -euo pipefail

# Regiao fixa do Learner Lab.
export AWS_DEFAULT_REGION="${AWS_DEFAULT_REGION:-us-east-1}"

# Diretorios (relativos a este script), independente de onde ele foi chamado.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INFRA_DIR="$SCRIPT_DIR/../infra"
JOB_FILE="$SCRIPT_DIR/../job/rdd_job.py"
DATA_FILE="$SCRIPT_DIR/../data/sample_lines.txt"

# Imprime e executa um comando (prefixo "$ " para ficar visivel nos logs).
run() {
  echo "\$ $*"
  "$@"
}

# ---------------------------------------------------------------------------
# 1. Descobrir BUCKET, APP_ID e ROLE_ARN.
#    Preferimos os outputs do Terraform; se falharem, usamos as env vars.
# ---------------------------------------------------------------------------
BUCKET="${BUCKET:-$(terraform -chdir="$INFRA_DIR" output -raw bucket_nome 2>/dev/null || true)}"
APP_ID="${APP_ID:-$(terraform -chdir="$INFRA_DIR" output -raw emr_app_id 2>/dev/null || true)}"
ROLE_ARN="${ROLE_ARN:-$(terraform -chdir="$INFRA_DIR" output -raw labrole_arn 2>/dev/null || true)}"

if [[ -z "$BUCKET" || -z "$APP_ID" || -z "$ROLE_ARN" ]]; then
  echo "ERRO: nao consegui obter BUCKET/APP_ID/ROLE_ARN." >&2
  echo "      Rode 'terraform apply' em ../infra ou defina as variaveis de ambiente" >&2
  echo "      BUCKET, APP_ID e ROLE_ARN antes de executar este script." >&2
  exit 1
fi

echo "BUCKET   = $BUCKET"
echo "APP_ID   = $APP_ID"
echo "ROLE_ARN = $ROLE_ARN"

# ---------------------------------------------------------------------------
# 2. Enviar o script PySpark e o dado de exemplo para o S3.
# ---------------------------------------------------------------------------
run aws s3 cp "$JOB_FILE" "s3://$BUCKET/scripts/rdd_job.py"
run aws s3 cp "$DATA_FILE" "s3://$BUCKET/input/sample_lines.txt"

# ---------------------------------------------------------------------------
# 3. Disparar o job (start-job-run) e capturar o jobRunId.
# ---------------------------------------------------------------------------
echo "\$ aws emr-serverless start-job-run ..."
JOB_RUN_ID="$(aws emr-serverless start-job-run \
  --application-id "$APP_ID" \
  --execution-role-arn "$ROLE_ARN" \
  --name "aula05-rdd" \
  --job-driver '{"sparkSubmit":{"entryPoint":"s3://'"$BUCKET"'/scripts/rdd_job.py","entryPointArguments":["--input","s3://'"$BUCKET"'/input/sample_lines.txt","--output","s3://'"$BUCKET"'/output/wordcount"]}}' \
  --configuration-overrides '{"monitoringConfiguration":{"s3MonitoringConfiguration":{"logUri":"s3://'"$BUCKET"'/logs/"}}}' \
  --query 'jobRunId' --output text)"

echo "jobRunId = $JOB_RUN_ID"

# ---------------------------------------------------------------------------
# 4. Polling do estado ate SUCCESS ou FAILED.
# ---------------------------------------------------------------------------
echo "Aguardando o job terminar (estados: SUBMITTED -> PENDING -> SCHEDULED -> RUNNING -> SUCCESS/FAILED)..."
while true; do
  ESTADO="$(aws emr-serverless get-job-run \
    --application-id "$APP_ID" \
    --job-run-id "$JOB_RUN_ID" \
    --query 'jobRun.state' --output text)"
  echo "estado: $ESTADO"
  case "$ESTADO" in
    SUCCESS)
      echo "Job concluido com SUCESSO."
      echo "Veja o resultado com: ./ver_resultado.sh"
      exit 0
      ;;
    FAILED|CANCELLED)
      echo "Job terminou com estado: $ESTADO." >&2
      echo "Veja os logs em: s3://$BUCKET/logs/ (ou no console EMR Serverless)." >&2
      exit 1
      ;;
    *)
      sleep 15
      ;;
  esac
done

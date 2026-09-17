# main.tf — aws-lab (aula-05: Spark/RDDs no AWS Glue)
# =============================================================================
# INFRA PRONTA DO LAB — você NÃO precisa alterar este arquivo.
#
# O que este arquivo provisiona:
#   - Um AWS Glue Job (PySpark / glueetl) que roda o word count com RDDs. O
#     Glue é o "Spark gerenciado": a AWS provisiona driver e executors sob
#     demanda quando o job é disparado, sem você ligar/desligar máquinas.
#
# Por que Glue e não EMR Serverless?
#   Neste Learner Lab o EMR Serverless está BLOQUEADO (a LabRole não confia em
#   emr-serverless.amazonaws.com), mas o Glue FUNCIONA (a LabRole confia em
#   glue.amazonaws.com). É o mesmo serviço usado na prova deste repositório.
#
# ⚠️ O bucket S3 do lab NÃO é gerenciado por este Terraform (veja o Passo 2.5
#    do README): o AWS Academy Learner Lab bloqueia por Service Control Policy
#    a chamada s3:GetBucketObjectLockConfiguration, que o provider AWS faz
#    incondicionalmente ao ler QUALQUER `aws_s3_bucket` — isso quebra
#    plan/apply/destroy mesmo para um bucket recém-criado, mesmo com
#    object_lock_enabled = false. O bucket é criado uma única vez via AWS CLI
#    (aws s3api create-bucket) e referenciado aqui só pelo nome
#    (var.bucket_nome), sem o Terraform tentar gerenciá-lo. O upload do script
#    e do dado de entrada também é feito por CLI, no scripts/run_job.sh (Passo
#    5), não por este Terraform.
#
# Regras do Learner Lab (leia antes de aplicar):
#   - Região fixa us-east-1 (via var.regiao).
#   - NÃO criamos roles/policies IAM próprias: o Glue Job usa a LabRole por ARN
#     (var.labrole_arn) como IAM role de execução.
#   - Rode `terraform destroy` ao final para não deixar recursos residuais
#     (e apague o bucket manualmente — veja o Passo 7 do README).
# =============================================================================

# -----------------------------------------------------------------------------
# Provider AWS — PRONTO
# Região fixada em var.regiao (us-east-1) e tags de custo aplicadas
# automaticamente a todos os recursos via default_tags.
# -----------------------------------------------------------------------------
provider "aws" {
  region = var.regiao

  default_tags {
    tags = var.tags
  }
}

# -----------------------------------------------------------------------------
# AWS Glue Job (glueetl) — o motor onde os RDDs vão rodar.
# Não há cluster para ligar/desligar: driver e executors são provisionados
# sob demanda quando o job é disparado (aws glue start-job-run) e liberados no
# fim. NÃO cria IAM role: usa a LabRole por ARN (var.labrole_arn).
#
# Escolhas ECONÔMICAS para o orçamento do Learner Lab:
#   - glue_version 4.0    : runtime Spark atual e estável.
#   - worker_type G.1X    : o menor worker padrão (4 vCPU / 16 GB).
#   - number_of_workers 2 : mínimo para ter 1 driver + 1 executor, suficiente
#                           para o dataset pequeno deste lab.
# -----------------------------------------------------------------------------
resource "aws_glue_job" "wordcount" {
  name     = "job-aula05-wordcount"
  role_arn = var.labrole_arn

  glue_version      = "4.0"
  worker_type       = "G.1X"
  number_of_workers = 2

  # command.name = "glueetl" indica um job PySpark (Spark ETL). O script é lido
  # do S3 (publicado por CLI no scripts/run_job.sh — ver nota da SCP acima).
  command {
    name            = "glueetl"
    python_version  = "3"
    script_location = "s3://${var.bucket_nome}/scripts/rdd_job.py"
  }

  # Argumentos passados ao script (getResolvedOptions os lê como --INPUT etc.).
  default_arguments = {
    "--INPUT"  = "s3://${var.bucket_nome}/input/sample_lines.txt"
    "--OUTPUT" = "s3://${var.bucket_nome}/output/wordcount"
    # Logs contínuos do Spark/driver no CloudWatch (grupo /aws-glue/jobs/output).
    "--enable-continuous-cloudwatch-log" = "true"
    # Diretório temporário exigido pelo Glue (fica dentro do mesmo bucket).
    "--TempDir" = "s3://${var.bucket_nome}/tmp/"
  }
}

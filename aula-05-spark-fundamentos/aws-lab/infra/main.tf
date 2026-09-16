# main.tf — aws-lab (aula-05: Spark/RDDs no EMR Serverless)
# =============================================================================
# INFRA PRONTA DO LAB — você NÃO precisa alterar este arquivo.
#
# O que este arquivo provisiona:
#   - Um bucket S3 PRIVADO (guarda o script PySpark, os dados de entrada, a
#     saída do job e os logs).
#   - Uma aplicação EMR Serverless do tipo Spark (é o "cluster gerenciado":
#     a AWS provisiona driver e executors sob demanda, sem você ligar/desligar
#     máquinas). Ver a aula-05 para a relação driver/executors.
#
# Regras do Learner Lab (leia antes de aplicar):
#   - Região fixa us-east-1 (via var.regiao).
#   - NÃO criamos roles/policies IAM próprias: o EMR Serverless usa a LabRole
#     por ARN (var.labrole_arn) como execution role na hora de rodar o job.
#   - Bucket S3 PRIVADO (public access block com os 4 bloqueios = true).
#   - Rode `terraform destroy` ao final para não deixar recursos residuais.
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
# Bucket S3 do lab — armazenamento distribuído/durável (o "HDFS da nuvem").
# Guarda: scripts/ (o rdd_job.py), input/ (sample_lines.txt), output/ (o
# resultado do wordcount) e logs/ (logs do driver/executors do job).
# -----------------------------------------------------------------------------
resource "aws_s3_bucket" "lab" {
  bucket = var.bucket_nome
}

# Bucket PRIVADO: bloqueia qualquer forma de acesso público (4 bloqueios).
resource "aws_s3_bucket_public_access_block" "lab" {
  bucket                  = aws_s3_bucket.lab.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# -----------------------------------------------------------------------------
# Aplicação EMR Serverless (Spark) — o motor onde os RDDs vão rodar.
# Não há cluster para ligar/desligar: driver e executors são provisionados
# sob demanda quando um job é submetido (start-job-run) e liberados no fim.
#
# NÃO cria IAM role: a execução do job usa a LabRole por ARN (var.labrole_arn),
# informada como --execution-role-arn no start-job-run (ver scripts/run_job.sh).
# -----------------------------------------------------------------------------
resource "aws_emrserverless_application" "spark" {
  name          = "app-aula05-spark"
  release_label = "emr-7.1.0"
  type          = "spark"

  # Capacidade máxima agregada que a aplicação pode alocar (driver + executors).
  # Valores modestos para respeitar o orçamento do Learner Lab.
  maximum_capacity {
    cpu    = "8 vCPU"
    memory = "24 GB"
  }

  # auto_stop: se a aplicação ficar ociosa por 15 min, ela para sozinha.
  # No Learner Lab isso é importante: EMR Serverless PARADO não gera custo,
  # então evitamos gasto ocioso mesmo se você esquecer de destruir.
  auto_stop_configuration {
    enabled              = true
    idle_timeout_minutes = 15
  }
}

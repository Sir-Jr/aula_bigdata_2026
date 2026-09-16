# outputs.tf — aws-lab (aula-05: Spark/RDDs no EMR Serverless)
# Expõe os valores que os scripts em ../scripts consomem via `terraform output`.

output "bucket_nome" {
  description = "Nome do bucket S3 do lab (guarda script, dados de entrada, saída e logs)."
  value       = aws_s3_bucket.lab.bucket
}

output "emr_app_id" {
  description = "ID da aplicação EMR Serverless (Spark). Usado no --application-id do start-job-run."
  value       = aws_emrserverless_application.spark.id
}

output "emr_app_arn" {
  description = "ARN da aplicação EMR Serverless (Spark)."
  value       = aws_emrserverless_application.spark.arn
}

output "labrole_arn" {
  description = "ARN da LabRole usada como --execution-role-arn ao submeter o job no EMR Serverless."
  value       = var.labrole_arn
}

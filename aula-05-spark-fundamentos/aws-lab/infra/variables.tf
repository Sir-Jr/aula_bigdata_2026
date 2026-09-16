# variables.tf — aws-lab (aula-05: Spark/RDDs no EMR Serverless)
# PRONTO — não precisa alterar (preencha os valores em terraform.tfvars).
#
# Variáveis de entrada da infra que o aluno provisiona (S3 + EMR Serverless).

# Região obrigatória do AWS Academy Learner Lab.
variable "regiao" {
  description = "Região AWS obrigatória do lab (Learner Lab)."
  type        = string
  default     = "us-east-1"
}

# ARN da role pré-provisionada LabRole. No Learner Lab NÃO é permitido criar
# roles/policies próprias: o EMR Serverless usa esta role por ARN como
# execution role (é ela quem lê/escreve no S3 durante o job).
variable "labrole_arn" {
  description = "ARN da role LabRole do Learner Lab, usada como execution role do EMR Serverless (sem criar roles/policies próprias)."
  type        = string
}

# Nome global único do bucket S3 do lab (guarda script, dados de entrada,
# saída do wordcount e logs do job).
variable "bucket_nome" {
  description = "Nome global único do bucket S3 do lab (script, dados de entrada, saída e logs)."
  type        = string
}

# Tags de custo padronizadas — aplicadas via default_tags do provider em main.tf.
variable "tags" {
  description = "Tags de custo padronizadas aplicadas a todos os recursos."
  type        = map(string)
  default = {
    Projeto    = "lab-aula-05-spark"
    Disciplina = "Big Data"
    Ambiente   = "LearnerLab"
  }
}

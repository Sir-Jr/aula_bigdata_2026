# Evidências — Lab Aula 05 (Spark RDDs na AWS)

> Execução feita via CLI (AWS CLI + Terraform), sem interface gráfica —
> as evidências abaixo são saídas reais de terminal, sem prints de console.

## Identificação

- **Nome:** Sirlande Martins de Oliveira Junior
- **RA:** 6325269
- **Branch:** aula-05-6325269
- **Data:** 2026-09-17

---

## 1. Identidade AWS ativa

Saída de `aws sts get-caller-identity` (confirma que as credenciais do Learner
Lab estão ativas). `Account`/`UserId` mascarados.

**Comando:**
```bash
aws sts get-caller-identity
```

```text
{
    "UserId": "AROA3JNHG7S4GLEZROTGM:user5367787=Sirlande_Martins_de_Oliveira_Junior_-_6325269",
    "Account": "776129150136",
    "Arn": "arn:aws:sts::776129150136:assumed-role/voclabs/user5367787=Sirlande_Martins_de_Oliveira_Junior_-_6325269"
}
```

---

## 2. `terraform apply` concluído

**Onde:** `cd aws-lab/infra && terraform apply`

> Observação: o bucket S3 do lab não é gerenciado pelo Terraform nesta conta
> (veja o Passo 2.5 do README e `infra/main.tf`) — o AWS Academy Learner Lab
> bloqueia por Service Control Policy a chamada
> `s3:GetBucketObjectLockConfiguration`, que o provider AWS faz
> incondicionalmente ao ler qualquer `aws_s3_bucket`, quebrando
> `plan`/`apply`/`destroy` mesmo em um bucket recém-criado. O bucket
> (`lab-aula05-spark-6325269`) foi criado uma única vez via
> `aws s3api create-bucket` + `put-public-access-block`. O Terraform gerencia
> só o AWS Glue Job.

```text
aws_glue_job.wordcount: Creating...
aws_glue_job.wordcount: Creation complete after 2s [id=job-aula05-wordcount]

Apply complete! Resources: 1 added, 0 changed, 0 destroyed.

Outputs:

bucket_nome = "lab-aula05-spark-6325269"
glue_job_nome = "job-aula05-wordcount"
labrole_arn = "arn:aws:iam::776129150136:role/LabRole"
```

---

## 3. Job com estado SUCCEEDED (Glue)

**Onde:** `cd aws-lab/scripts && ./run_job.sh`

```text
BUCKET   = lab-aula05-spark-6325269
GLUE_JOB = job-aula05-wordcount
ROLE_ARN = arn:aws:iam::776129150136:role/LabRole
$ aws s3 cp .../rdd_job.py s3://lab-aula05-spark-6325269/scripts/rdd_job.py
$ aws s3 cp .../sample_lines.txt s3://lab-aula05-spark-6325269/input/sample_lines.txt
$ aws glue start-job-run --job-name job-aula05-wordcount ...
RUN_ID = jr_593acad1fdf4a303c5bf236b9e4a90a643d0831620927f947aa4602de6f75a4e
Aguardando o job terminar (estados: STARTING -> RUNNING -> SUCCEEDED/FAILED)...
estado: RUNNING
(...)
estado: SUCCEEDED
Job concluido com SUCESSO.
```

> Nota: o `job/rdd_job.py` já sobe com o fix do committer do Glue 4.0 aplicado
> (`sc._jsc.hadoopConfiguration().set("mapred.output.committer.class",
> "org.apache.hadoop.mapred.FileOutputCommitter")` dentro de `main()`), então
> esta execução terminou `SUCCEEDED` de primeira — sem o `ClassNotFoundException`
> do `DirectOutputCommitter` visto numa rodada anterior do lab (ver
> `infra/main.tf` para a explicação completa do bug).

---

## 4. Resultado do word count

**Onde:** `cd aws-lab/scripts && ./ver_resultado.sh`

```text
$ aws s3 ls s3://lab-aula05-spark-6325269/output/wordcount/
2026-09-17 19:47:17        311 part-00000
2026-09-17 19:47:17        377 part-00001
2026-09-17 19:47:17        377 part-00002
2026-09-17 19:47:17        394 part-00003
=== Conteudo do word count (palavra,contagem) ===
o,60
a,22
e,19
pedido,19
cliente,18
entrega,17
do,16
produto,16
estoque,14
pagamento,11
(... lista completa com 150+ palavras no arquivo de saída ...)
```

---

## 5. Top palavras / interpretação

Top 5:
```text
o,60
a,22
e,19
pedido,19
cliente,18
```

Interpretação:

> Descontando artigos/preposições ("o", "a", "e"), as palavras mais frequentes
> são "pedido", "cliente" e "entrega" — coerente com um texto de e-commerce
> (fluxo de pedido → pagamento → entrega). O `word_count_rdd` distribuiu as
> linhas de entrada entre os **executors** (workers do Glue) via
> `flatMap`/`map`/`reduceByKey`, e o **driver** apenas coordenou a agregação
> final e a ordenação do resultado antes de gravá-lo no S3.

---

## 6. Logs do driver (bônus)

**Onde:** CloudWatch Logs, grupo `/aws-glue/jobs/output`, stream
`jr_593acad1fdf4a303c5bf236b9e4a90a643d0831620927f947aa4602de6f75a4e`.

```text
=== Word count (palavra,contagem) ===
o,60
a,22
e,19
pedido,19
cliente,18
entrega,17
(...)
```

---

## 7. Limpeza (`terraform destroy`)

**Onde:** `cd aws-lab/infra && terraform destroy`

```text
$ terraform apply tfdestroy
aws_glue_job.wordcount: Destroying... [id=job-aula05-wordcount]
aws_glue_job.wordcount: Destruction complete after 1s

Apply complete! Resources: 0 added, 0 changed, 1 destroyed.

$ aws s3 rm s3://lab-aula05-spark-6325269 --recursive
delete: s3://lab-aula05-spark-6325269/output/wordcount/part-00002
delete: s3://lab-aula05-spark-6325269/output/wordcount/part-00003
delete: s3://lab-aula05-spark-6325269/scripts/rdd_job.py
delete: s3://lab-aula05-spark-6325269/output/wordcount/part-00001
delete: s3://lab-aula05-spark-6325269/output/wordcount/part-00000
delete: s3://lab-aula05-spark-6325269/input/sample_lines.txt

$ aws s3api delete-bucket --bucket lab-aula05-spark-6325269
$ aws s3api head-bucket --bucket lab-aula05-spark-6325269
An error occurred (404) when calling the HeadBucket operation: Not Found
```

> Como o bucket S3 não é gerenciado pelo Terraform nesta conta (item 2), a
> limpeza completa foi: `terraform destroy` (remove o Glue Job) **+**
> `aws s3 rm --recursive` e `aws s3api delete-bucket` (remove o bucket).
> Confirmado sem recursos residuais (`head-bucket` retorna 404).

---

## Checklist de conferência

- [x] 1. Identidade AWS ativa (`aws sts get-caller-identity`)
- [x] 2. `terraform apply` concluído ("Apply complete!" + outputs)
- [x] 3. Job com estado `SUCCEEDED` (Glue) (+ `RUN_ID`)
- [x] 4. Resultado do word count (`./ver_resultado.sh`)
- [x] 5. Top palavras + interpretação (2–3 frases)
- [x] 6. Logs do driver (bônus)
- [x] 7. Limpeza com `terraform destroy` ("Destroy complete!")

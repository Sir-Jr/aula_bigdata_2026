"""
Aula 05 - Spark/RDDs no AWS EMR Serverless
===========================================

Este script roda no EMR SERVERLESS (Spark gerenciado pela AWS), usando a mesma
API de RDDs da aula-05 local (src/rdd_basics.py). A diferença é ONDE ele roda:
aqui o driver e os executors sao provisionados pela AWS sob demanda, e os dados
vem/vao para o S3 (nao para o disco local).

Fluxo:
  1. Le um arquivo de texto do S3 (argumento --input, ex.:
     s3://SEU_BUCKET/input/sample_lines.txt).
  2. Calcula a contagem de palavras com RDDs (word_count_rdd).
  3. Escreve o resultado (uma linha "palavra,contagem" por registro) no S3
     (argumento --output, ex.: s3://SEU_BUCKET/output/wordcount).
  4. Tambem imprime o resultado no stdout do driver (aparece nos logs do job).

Como o script recebe um SparkContext:
  Aqui criamos a SparkSession/-Context dentro de main() (é assim que rodamos no
  EMR Serverless). As funcoes recebem `sc` como parametro, igual à aula-05.

⚠️ ANTES DE SUBIR: complete os dois TODOs abaixo (word_count_rdd e
   top_n_palavras). Enquanto nao completar, as funcoes levantam
   NotImplementedError (mas o modulo importa/compila normalmente).
"""

import argparse

from pyspark.sql import SparkSession


def word_count_rdd(sc, lines):
    """
    TODO 1 (mesmo contrato da aula-05):
    Receba `sc` (SparkContext) e uma lista de strings `lines` (cada item é uma
    "linha" de texto) e retorne a contagem de palavras usando RDDs:
      1. Crie um RDD a partir de `lines` com `sc.parallelize(lines)`.
      2. Use `flatMap` para quebrar cada linha em palavras (separadas por
         espaco) JA convertidas para minusculas.
      3. Use `map` para transformar cada palavra em (palavra, 1).
      4. Use `reduceByKey` para somar as ocorrencias de cada palavra.
      5. Retorne uma lista de tuplas (palavra, contagem), ORDENADA por contagem
         decrescente e, em empate, por ordem alfabetica crescente da palavra.

    Exemplo:
        word_count_rdd(sc, ["gato rato gato", "rato correu gato"])
        -> [("gato", 3), ("rato", 2), ("correu", 1)]
    """
    raise NotImplementedError("TODO 1: implemente word_count_rdd")


def top_n_palavras(sc, lines, n):
    """
    TODO 2:
    Retorne as `n` palavras mais frequentes de `lines`, como lista de tuplas
    (palavra, contagem), na mesma ordenacao de word_count_rdd (contagem
    decrescente e, em empate, alfabetica crescente).

    Dica: reutilize word_count_rdd(sc, lines) e pegue os `n` primeiros itens.

    Exemplo:
        top_n_palavras(sc, ["gato rato gato", "rato correu gato"], 2)
        -> [("gato", 3), ("rato", 2)]
    """
    raise NotImplementedError("TODO 2: implemente top_n_palavras")


def main():
    """Ponto de entrada executado pelo EMR Serverless (spark-submit)."""
    parser = argparse.ArgumentParser(
        description="Word count com RDDs no EMR Serverless (aula-05)."
    )
    parser.add_argument(
        "--input",
        required=True,
        help="Caminho S3 do arquivo de texto de entrada (ex.: s3://bucket/input/sample_lines.txt).",
    )
    parser.add_argument(
        "--output",
        required=True,
        help="Caminho S3 (prefixo) onde gravar o resultado (ex.: s3://bucket/output/wordcount).",
    )
    args = parser.parse_args()

    # SparkSession/-Context gerenciados pelo EMR Serverless.
    spark = SparkSession.builder.appName("aula05-rdd-wordcount").getOrCreate()
    sc = spark.sparkContext

    try:
        # Le o texto do S3 como uma lista de linhas (strings).
        # Usamos spark.read.text(...).rdd para ler do S3 e trazer as linhas.
        linhas = spark.read.text(args.input).rdd.map(lambda row: row[0]).collect()

        # Calcula a contagem de palavras com a API de RDDs (funcao do aluno).
        resultado = word_count_rdd(sc, linhas)

        # Imprime no stdout do driver (aparece nos logs do job no S3/console).
        print("=== Word count (palavra,contagem) ===")
        for palavra, contagem in resultado:
            print(f"{palavra},{contagem}")

        # Grava o resultado no S3 como texto: uma linha "palavra,contagem".
        # Distribui a escrita entre os executors via RDD.saveAsTextFile.
        sc.parallelize(resultado).map(
            lambda t: f"{t[0]},{t[1]}"
        ).saveAsTextFile(args.output)

        print(f"Resultado gravado em: {args.output}")
    finally:
        spark.stop()


if __name__ == "__main__":
    main()

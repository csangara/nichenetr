Assess how well top-ranked ligands can predict a gene set of interest
================
Robin Browaeys
2019-02-19

<!-- github markdown built using
rmarkdown::render("vignettes/target_prediction_evaluation_geneset.Rmd", output_format = "github_document")
-->

This vignette shows how NicheNet can be used to to predict which ligands
might regulate a given set of genes and how well they do this
prediction. For this analysis, you need to define:

- a set of genes of which expression in a “receiver cell” is possibly
  affected by extracellular protein signals (ligands) (e.g. genes
  differentially expressed upon cell-cell interaction )
- a set of potentially active ligands (e.g. ligands expressed by
  interacting “sender cells”)

Therefore, you often first need to process expression data of
interacting cells to define both.

In this example, we will use data from Puram et al. to explore
intercellular communication in the tumor microenvironment in head and
neck squamous cell carcinoma (HNSCC) (See Puram et al. 2017). More
specifically, we will look at which ligands expressed by
cancer-associated fibroblasts (CAFs) can induce a specific gene program
in neighboring malignant cells. This program, a partial
epithelial-mesenschymal transition (p-EMT) program, could be linked by
Puram et al. to metastasis.

For this analysis, we will first assess the ligand activity of each
ligand, or in other words, we will assess how well each CAF-ligand can
predict the p-EMT gene set compared to the background of expressed
genes. This allows us to prioritize p-EMT-regulating ligands. Then, we
will assess how well the prioritized ligands together can predict
whether genes belong to the gene set of interest or not.

The used ligand-target matrix and example expression data of interacting
cells can be downloaded from Zenodo.
[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.3260758.svg)](https://doi.org/10.5281/zenodo.3260758)

### Load packages required for this vignette

``` r
library(nichenetr)
library(tidyverse)
```

### Read in expression data of interacting cells

First, we will read in the publicly available single-cell data from CAF
and malignant cells from HNSCC tumors.

``` r
hnscc_expression = readRDS(url("https://zenodo.org/record/3260758/files/hnscc_expression.rds"))
expression = hnscc_expression$expression
sample_info = hnscc_expression$sample_info # contains meta-information about the cells
```

Secondly, we will determine which genes are expressed in CAFs and
malignant cells from high quality primary tumors. Therefore, we wil not
consider cells from tumor samples of less quality or from lymph node
metastases. To determine expressed genes, we use the definition used by
of Puram et al.

``` r
tumors_remove = c("HN10","HN","HN12", "HN13", "HN24", "HN7", "HN8","HN23")

CAF_ids = sample_info %>% filter(`Lymph node` == 0 & !(tumor %in% tumors_remove) & `non-cancer cell type` == "CAF") %>% pull(cell)
malignant_ids = sample_info %>% filter(`Lymph node` == 0 & !(tumor %in% tumors_remove) & `classified  as cancer cell` == 1) %>% pull(cell)

expressed_genes_CAFs = expression[CAF_ids,] %>% apply(2,function(x){10*(2**x - 1)}) %>% apply(2,function(x){log2(mean(x) + 1)}) %>% .[. >= 4] %>% names()
expressed_genes_malignant = expression[malignant_ids,] %>% apply(2,function(x){10*(2**x - 1)}) %>% apply(2,function(x){log2(mean(x) + 1)}) %>% .[. >= 4] %>% names()
```

### Load the ligand-target model we want to use

``` r
ligand_target_matrix = readRDS(url("https://zenodo.org/record/7074291/files/ligand_target_matrix_nsga2r_final.rds"))
ligand_target_matrix[1:5,1:5] # target genes in rows, ligands in columns
##                     A2M        AANAT        ABCA1          ACE        ACE2
## A-GAMMA3'E 0.0000000000 0.0000000000 0.0000000000 0.0000000000 0.000000000
## A1BG       0.0018503922 0.0011108718 0.0014225077 0.0028594037 0.001139013
## A1BG-AS1   0.0007400797 0.0004677614 0.0005193137 0.0007836698 0.000375007
## A1CF       0.0024799266 0.0013026348 0.0020420890 0.0047921048 0.003273375
## A2M        0.0084693452 0.0040689323 0.0064256379 0.0105191365 0.005719199
```

### Load the gene set of interest and background of genes

As gene set of interest, we consider the genes of which the expression
is possibly affected due to communication with other cells.

Because we here want to investigate how CAF regulate the expression of
p-EMT genes in malignant cells, we will use the p-EMT gene set defined
by Puram et al. as gene set of interset and use all genes expressed in
malignant cells as background of genes.

``` r
pemt_geneset = readr::read_tsv(url("https://zenodo.org/record/3260758/files/pemt_signature.txt"), col_names = "gene") %>% pull(gene) %>% .[. %in% rownames(ligand_target_matrix)] # only consider genes also present in the NicheNet model - this excludes genes from the gene list for which the official HGNC symbol was not used by Puram et al.
head(pemt_geneset)
## [1] "SERPINE1" "TGFBI"    "MMP10"    "LAMC2"    "P4HA2"    "PDPN"
background_expressed_genes = expressed_genes_malignant %>% .[. %in% rownames(ligand_target_matrix)]
head(background_expressed_genes)
## [1] "RPS11"   "ELMO2"   "PNMA1"   "MMP2"    "TMEM216" "ERCC5"
```

### Perform NicheNet’s ligand activity analysis on the gene set of interest

In a first step, we will define a set of potentially active ligands. As
potentially active ligands, we will use ligands that are 1) expressed by
CAFs and 2) can bind a (putative) receptor expressed by malignant cells.
Putative ligand-receptor links were gathered from NicheNet’s
ligand-receptor data sources.

``` r
lr_network = readRDS(url("https://zenodo.org/record/7074291/files/lr_network_human_21122021.rds"))

ligands = lr_network %>% pull(from) %>% unique()
expressed_ligands = intersect(ligands,expressed_genes_CAFs)

receptors = lr_network %>% pull(to) %>% unique()
expressed_receptors = intersect(receptors,expressed_genes_malignant)

potential_ligands = lr_network %>% filter(from %in% expressed_ligands & to %in% expressed_receptors) %>% pull(from) %>% unique()
head(potential_ligands)
## [1] "A2M"    "ADAM10" "ADAM12" "ADAM15" "ADAM17" "ADAM9"
```

Now perform the ligand activity analysis: infer how well NicheNet’s
ligand-target potential scores can predict whether a gene belongs to the
p-EMT program or not.

``` r
ligand_activities = predict_ligand_activities(geneset = pemt_geneset, background_expressed_genes = background_expressed_genes, ligand_target_matrix = ligand_target_matrix, potential_ligands = potential_ligands)
```

Now, we want to rank the ligands based on their ligand activity. In our
validation study, we showed that the pearson correlation between a
ligand’s target predictions and the observed transcriptional response
was the most informative measure to define ligand activity. Therefore,
we will rank the ligands based on their pearson correlation coefficient.

``` r
ligand_activities %>% arrange(-pearson)
## # A tibble: 203 × 5
##    test_ligand auroc   aupr aupr_corrected pearson
##    <chr>       <dbl>  <dbl>          <dbl>   <dbl>
##  1 TGFB2       0.768 0.123          0.107    0.199
##  2 BMP8A       0.770 0.0880         0.0718   0.177
##  3 LTBP1       0.722 0.0785         0.0622   0.163
##  4 TNXB        0.713 0.0737         0.0574   0.158
##  5 ENG         0.759 0.0732         0.0569   0.157
##  6 BMP5        0.745 0.0715         0.0552   0.150
##  7 VCAM1       0.697 0.0640         0.0477   0.149
##  8 MMP2        0.703 0.0652         0.0489   0.145
##  9 COL3A1      0.742 0.0697         0.0534   0.145
## 10 CXCL12      0.708 0.0884         0.0721   0.144
## # … with 193 more rows
best_upstream_ligands = ligand_activities %>% top_n(20, pearson) %>% arrange(-pearson) %>% pull(test_ligand)
head(best_upstream_ligands)
## [1] "TGFB2" "BMP8A" "LTBP1" "TNXB"  "ENG"   "BMP5"
```

For the top 20 ligands, we will now build a multi-ligand model that uses
all top-ranked ligands to predict whether a gene belongs to the p-EMT
program of not. This classification model will be trained via
cross-validation and returns a probability for every gene.

``` r
# change rounds and folds here, to two rounds to reduce time: normally: do multiple rounds
k = 3 # 3-fold
n = 2 # 2 rounds

pemt_gene_predictions_top20_list = seq(n) %>% lapply(assess_rf_class_probabilities, folds = k, geneset = pemt_geneset, background_expressed_genes = background_expressed_genes, ligands_oi = best_upstream_ligands, ligand_target_matrix = ligand_target_matrix)
```

Evaluate now how well the target gene probabilies accord to the gene set
assignments

``` r
# get performance: auroc-aupr-pearson
target_prediction_performances_cv = pemt_gene_predictions_top20_list %>% lapply(classification_evaluation_continuous_pred_wrapper) %>% bind_rows() %>% mutate(round=seq(1:nrow(.)))
```

What is the AUROC, AUPR and PCC of this model (averaged over
cross-validation rounds)?

``` r
target_prediction_performances_cv$auroc %>% mean()
## [1] 0.7511288
target_prediction_performances_cv$aupr %>% mean()
## [1] 0.09557484
target_prediction_performances_cv$pearson %>% mean()
## [1] 0.1944454
```

Evaluate now whether genes belonging to the gene set are more likely to
be top-predicted. We will look at the top 5% of predicted targets here.

``` r
# get performance: how many p-EMT genes and non-p-EMT-genes among top 5% predicted targets
target_prediction_performances_discrete_cv = pemt_gene_predictions_top20_list %>% lapply(calculate_fraction_top_predicted, quantile_cutoff = 0.95) %>% bind_rows() %>% ungroup() %>% mutate(round=rep(1:length(pemt_gene_predictions_top20_list), each = 2))
```

What is the fraction of p-EMT genes that belongs to the top 5% predicted
targets?

``` r
target_prediction_performances_discrete_cv %>% filter(true_target) %>% .$fraction_positive_predicted %>% mean()
## [1] 0.3541667
```

What is the fraction of non-p-EMT genes that belongs to the top 5%
predicted targets?

``` r
target_prediction_performances_discrete_cv %>% filter(!true_target) %>% .$fraction_positive_predicted %>% mean()
## [1] 0.04538395
```

We see that the p-EMT genes are enriched in the top-predicted target
genes. To test this, we will now apply a Fisher’s exact test for every
cross-validation round and report the average p-value.

``` r
target_prediction_performances_discrete_fisher = pemt_gene_predictions_top20_list %>% lapply(calculate_fraction_top_predicted_fisher, quantile_cutoff = 0.95) 
target_prediction_performances_discrete_fisher %>% unlist() %>% mean()
## [1] 5.000915e-18
```

Finally, we will look at which p-EMT genes are well-predicted in every
cross-validation round.

``` r
# get top predicted genes
top_predicted_genes = seq(length(pemt_gene_predictions_top20_list)) %>% lapply(get_top_predicted_genes,pemt_gene_predictions_top20_list) %>% reduce(full_join, by = c("gene","true_target"))
top_predicted_genes %>% filter(true_target)
## # A tibble: 44 × 4
##    gene     true_target predicted_top_target_round1 predicted_top_target_round2
##    <chr>    <lgl>       <lgl>                       <lgl>                      
##  1 SERPINE1 TRUE        TRUE                        TRUE                       
##  2 MMP1     TRUE        TRUE                        TRUE                       
##  3 FSTL3    TRUE        TRUE                        TRUE                       
##  4 MT2A     TRUE        TRUE                        TRUE                       
##  5 COL1A1   TRUE        TRUE                        TRUE                       
##  6 TAGLN    TRUE        TRUE                        TRUE                       
##  7 TNC      TRUE        TRUE                        NA                         
##  8 LAMC2    TRUE        TRUE                        TRUE                       
##  9 THBS1    TRUE        TRUE                        TRUE                       
## 10 MYH9     TRUE        TRUE                        TRUE                       
## # … with 34 more rows
```

### References

<div id="refs" class="references csl-bib-body hanging-indent">

<div id="ref-puram_single-cell_2017" class="csl-entry">

Puram, Sidharth V., Itay Tirosh, Anuraag S. Parikh, Anoop P. Patel,
Keren Yizhak, Shawn Gillespie, Christopher Rodman, et al. 2017.
“Single-Cell Transcriptomic Analysis of Primary and Metastatic Tumor
Ecosystems in Head and Neck Cancer.” *Cell* 171 (7): 1611–1624.e24.
<https://doi.org/10.1016/j.cell.2017.10.044>.

</div>

</div>

NicheNet’s ligand activity analysis on a gene set of interest: predict
active ligands and their target genes
================
Robin Browaeys
2019-01-17

<!-- github markdown built using 
rmarkdown::render("vignettes/ligand_activity_geneset.Rmd", output_format = "github_document")
-->

In this vignette, you can learn how to perform a basic NicheNet
analysis. A NicheNet analysis can help you to generate hypotheses about
an intercellular communication process of interest for which you have
bulk or single-cell gene expression data. Specifically, NicheNet can
predict 1) which ligands from one cell population (“sender/niche”) are
most likely to affect target gene expression in an interacting cell
population (“receiver/target”) and 2) which specific target genes are
affected by which of these predicted ligands.

Because NicheNet studies how ligands affect gene expression in
neighboring cells, you need to have data about this effect in gene
expression you want to study. So, you need to have a clear set of genes
that are putatively affected by ligands from one of more interacting
cells.

The pipeline of a basic NicheNet analysis consist mainly of the
following steps:

- 1.  Define a “sender/niche” cell population and a “receiver/target”
      cell population present in your expression data and determine
      which genes are expressed in both populations

- 2.  Define a gene set of interest: these are the genes in the
      “receiver/target” cell population that are potentially affected by
      ligands expressed by interacting cells (e.g. genes differentially
      expressed upon cell-cell interaction)

- 3.  Define a set of potential ligands: these are ligands that are
      expressed by the “sender/niche” cell population and bind a
      (putative) receptor expressed by the “receiver/target” population

- 4)  Perform NicheNet ligand activity analysis: rank the potential
      ligands based on the presence of their target genes in the gene
      set of interest (compared to the background set of genes)

- 5)  Infer top-predicted target genes of ligands that are top-ranked in
      the ligand activity analysis

This vignette guides you in detail through all these steps. As example
expression data of interacting cells, we will use data from Puram et
al. to explore intercellular communication in the tumor microenvironment
in head and neck squamous cell carcinoma (HNSCC) (See Puram et al.
2017). More specifically, we will look at which ligands expressed by
cancer-associated fibroblasts (CAFs) can induce a specific gene program
in neighboring malignant cells. This program, a partial
epithelial-mesenschymal transition (p-EMT) program, could be linked to
metastasis by Puram et al. 

The used ligand-target matrix and example expression data of interacting
cells can be downloaded from Zenodo.
[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.3260758.svg)](https://doi.org/10.5281/zenodo.3260758)

## Step 0: Load required packages, NicheNet’s ligand-target prior model and processed expression data of interacting cells

Packages:

``` r
library(nichenetr)
library(tidyverse)
```

Ligand-target model:

This model denotes the prior potential that a particular ligand might
regulate the expression of a specific target gene. The Nichenet v2
networks and matrices for both mouse and human can be downloaded from
Zenodo
[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.7074291.svg)](https://doi.org/10.5281/zenodo.7074291).

``` r
options(timeout = 600)
organism = "human"

if(organism == "human"){
  lr_network = readRDS(url("https://zenodo.org/record/7074291/files/lr_network_human_21122021.rds"))
  ligand_target_matrix = readRDS(url("https://zenodo.org/record/7074291/files/ligand_target_matrix_nsga2r_final.rds"))
} else if(organism == "mouse"){
  lr_network = readRDS(url("https://zenodo.org/record/7074291/files/lr_network_mouse_21122021.rds"))
  ligand_target_matrix = readRDS(url("https://zenodo.org/record/7074291/files/ligand_target_matrix_nsga2r_final_mouse.rds"))

}

lr_network = lr_network %>% distinct(from, to)
ligand_target_matrix[1:5,1:5] # target genes in rows, ligands in columns
##                     A2M        AANAT        ABCA1          ACE        ACE2
## A-GAMMA3'E 0.0000000000 0.0000000000 0.0000000000 0.0000000000 0.000000000
## A1BG       0.0018503922 0.0011108718 0.0014225077 0.0028594037 0.001139013
## A1BG-AS1   0.0007400797 0.0004677614 0.0005193137 0.0007836698 0.000375007
## A1CF       0.0024799266 0.0013026348 0.0020420890 0.0047921048 0.003273375
## A2M        0.0084693452 0.0040689323 0.0064256379 0.0105191365 0.005719199
```

Expression data of interacting cells: publicly available single-cell
data from CAF and malignant cells from HNSCC tumors:

``` r
hnscc_expression = readRDS(url("https://zenodo.org/record/3260758/files/hnscc_expression.rds"))
expression = hnscc_expression$expression
sample_info = hnscc_expression$sample_info # contains meta-information about the cells
```

Because the NicheNet 2.0. networks are in the most recent version of the
official gene symbols, we will make sure that the gene symbols used in
the expression data are also updated (= converted from their “aliases”
to official gene symbols). Afterwards, we will make them again
syntactically valid.

``` r
# If this is not done, there will be 35 genes fewer in lr_network_expressed!
colnames(expression) = convert_alias_to_symbols(colnames(expression), "human", verbose = FALSE)
```

## Step 1: Define expressed genes in sender and receiver cell populations

Our research question is to prioritize which ligands expressed by CAFs
can induce p-EMT in neighboring malignant cells. Therefore, CAFs are the
sender cells in this example and malignant cells are the receiver cells.
This is an example of paracrine signaling. Note that autocrine signaling
can be considered if sender and receiver cell type are the same.

Now, we will determine which genes are expressed in the sender cells
(CAFs) and receiver cells (malignant cells) from high quality primary
tumors. Therefore, we wil not consider cells from tumor samples of less
quality or from lymph node metastases.

To determine expressed genes in this case study, we use the definition
used by Puram et al. (the authors of this dataset), which is: Ea, the
aggregate expression of each gene i across the k cells, calculated as
Ea(i) = log2(average(TPM(i)1…k)+1), should be \>= 4. We recommend users
to define expressed genes in the way that they consider to be most
appropriate for their dataset. For single-cell data generated by the 10x
platform in our lab, we don’t use the definition used here, but we
consider genes to be expressed in a cell type when they have non-zero
values in at least 10% of the cells from that cell type. This is
described as well in the other vignette [Perform NicheNet analysis
starting from a Seurat object: step-by-step
analysis](seurat_steps.md):`vignette("seurat_steps", package="nichenetr")`.

``` r
tumors_remove = c("HN10","HN","HN12", "HN13", "HN24", "HN7", "HN8","HN23")

CAF_ids = sample_info %>% filter(`Lymph node` == 0 & !(tumor %in% tumors_remove) & `non-cancer cell type` == "CAF") %>% pull(cell)
malignant_ids = sample_info %>% filter(`Lymph node` == 0 & !(tumor %in% tumors_remove) & `classified  as cancer cell` == 1) %>% pull(cell)

expressed_genes_sender = expression[CAF_ids,] %>% apply(2,function(x){10*(2**x - 1)}) %>% apply(2,function(x){log2(mean(x) + 1)}) %>% .[. >= 4] %>% names()
expressed_genes_receiver = expression[malignant_ids,] %>% apply(2,function(x){10*(2**x - 1)}) %>% apply(2,function(x){log2(mean(x) + 1)}) %>% .[. >= 4] %>% names()

# Check the number of expressed genes: should be a 'reasonable' number of total expressed genes in a cell type, e.g. between 5000-10000 (and not 500 or 20000)
length(expressed_genes_sender)
## [1] 6706
length(expressed_genes_receiver)
## [1] 6351
```

## Step 2: Define the gene set of interest and a background of genes

As gene set of interest, we consider the genes of which the expression
is possibly affected due to communication with other cells. The
definition of this gene set depends on your research question and is a
crucial step in the use of NicheNet.

Because we here want to investigate how CAFs regulate the expression of
p-EMT genes in malignant cells, we will use the p-EMT gene set defined
by Puram et al. as gene set of interest and use all genes expressed in
malignant cells as background of genes.

``` r
geneset_oi = readr::read_tsv(url("https://zenodo.org/record/3260758/files/pemt_signature.txt"), col_names = "gene") %>% pull(gene) %>% .[. %in% rownames(ligand_target_matrix)] # only consider genes also present in the NicheNet model - this excludes genes from the gene list for which the official HGNC symbol was not used by Puram et al.
head(geneset_oi)
## [1] "SERPINE1" "TGFBI"    "MMP10"    "LAMC2"    "P4HA2"    "PDPN"

background_expressed_genes = expressed_genes_receiver %>% .[. %in% rownames(ligand_target_matrix)]
head(background_expressed_genes)
## [1] "RPS11"   "ELMO2"   "PNMA1"   "MMP2"    "TMEM216" "ERCC5"
```

## Step 3: Define a set of potential ligands

As potentially active ligands, we will use ligands that are 1) expressed
by CAFs and 2) can bind a (putative) receptor expressed by malignant
cells. Putative ligand-receptor links were gathered from NicheNet’s
ligand-receptor data sources.

``` r
# If wanted, users can remove ligand-receptor interactions that were predicted based on protein-protein interactions and only keep ligand-receptor interactions that are described in curated databases. To do this: uncomment following line of code:
# lr_network = lr_network %>% filter(database != "ppi_prediction_go" & database != "ppi_prediction")

ligands = lr_network %>% pull(from) %>% unique()
expressed_ligands = intersect(ligands,expressed_genes_sender)

receptors = lr_network %>% pull(to) %>% unique()
expressed_receptors = intersect(receptors,expressed_genes_receiver)

lr_network_expressed = lr_network %>% filter(from %in% expressed_ligands & to %in% expressed_receptors) 
head(lr_network_expressed)
## # A tibble: 6 × 2
##   from   to     
##   <chr>  <chr>  
## 1 A2M    MMP2   
## 2 A2M    MMP9   
## 3 ADAM10 APP    
## 4 ADAM10 CD44   
## 5 ADAM10 TSPAN5 
## 6 ADAM10 TSPAN15
```

This ligand-receptor network contains the expressed ligand-receptor
interactions. As potentially active ligands for the NicheNet analysis,
we will consider the ligands from this network.

``` r
potential_ligands = lr_network_expressed %>% pull(from) %>% unique()
head(potential_ligands)
## [1] "A2M"    "ADAM10" "ADAM12" "ADAM15" "ADAM17" "ADAM9"
```

## Step 4: Perform NicheNet’s ligand activity analysis on the gene set of interest

Now perform the ligand activity analysis: in this analysis, we will
calculate the ligand activity of each ligand, or in other words, we will
assess how well each CAF-ligand can predict the p-EMT gene set compared
to the background of expressed genes (predict whether a gene belongs to
the p-EMT program or not).

``` r
ligand_activities = predict_ligand_activities(geneset = geneset_oi, background_expressed_genes = background_expressed_genes, ligand_target_matrix = ligand_target_matrix, potential_ligands = potential_ligands)
```

Now, we want to rank the ligands based on their ligand activity. In our
validation study, we showed that the pearson correlation coefficient
(PCC) between a ligand’s target predictions and the observed
transcriptional response was the most informative measure to define
ligand activity. Therefore, we will rank the ligands based on their
pearson correlation coefficient. This allows us to prioritize
p-EMT-regulating ligands.

``` r
ligand_activities %>% arrange(-aupr) 
## # A tibble: 212 × 5
##    test_ligand auroc   aupr aupr_corrected pearson
##    <chr>       <dbl>  <dbl>          <dbl>   <dbl>
##  1 TGFB2       0.772 0.120          0.105    0.195
##  2 BMP8A       0.774 0.0852         0.0699   0.175
##  3 INHBA       0.777 0.0837         0.0685   0.122
##  4 CXCL12      0.714 0.0829         0.0676   0.141
##  5 LTBP1       0.727 0.0762         0.0609   0.160
##  6 CCN2        0.736 0.0734         0.0581   0.141
##  7 TNXB        0.719 0.0717         0.0564   0.157
##  8 ENG         0.764 0.0703         0.0551   0.145
##  9 BMP5        0.750 0.0691         0.0538   0.148
## 10 VCAN        0.720 0.0687         0.0534   0.140
## # … with 202 more rows
best_upstream_ligands = ligand_activities %>% top_n(30, aupr) %>% arrange(-aupr) %>% pull(test_ligand)
head(best_upstream_ligands)
## [1] "TGFB2"  "BMP8A"  "INHBA"  "CXCL12" "LTBP1"  "CCN2"
```

We see here that the performance metrics indicate that the 30 top-ranked
ligands can predict the p-EMT genes reasonably, this implies that
ranking of the ligands might be accurate as shown in our study. However,
it is possible that for some gene sets, the target gene prediction
performance of the top-ranked ligands would not be much better than
random prediction. In that case, prioritization of ligands will be less
trustworthy.

Additional note: we looked at the top 30 ligands here and will continue
the analysis by inferring p-EMT target genes of these 30 ligands.
However, the choice of looking only at the 30 top-ranked ligands for
further biological interpretation is based on biological intuition and
is quite arbitrary. Therefore, users can decide to continue the analysis
with a different number of ligands. We recommend to check the selected
cutoff by looking at the distribution of the ligand activity values.
Here, we show the ligand activity histogram (the score for the 30th
ligand is indicated via the dashed line).

``` r
# show histogram of ligand activity scores
p_hist_lig_activity = ggplot(ligand_activities, aes(x=aupr)) + 
  geom_histogram(color="black", fill="darkorange")  + 
  # geom_density(alpha=.1, fill="orange") +
  geom_vline(aes(xintercept=min(ligand_activities %>% top_n(30, aupr) %>% pull(aupr))), color="red", linetype="dashed", size=1) + 
  labs(x="ligand activity (PCC)", y = "# ligands") +
  theme_classic()
p_hist_lig_activity
```

![](ligand_activity_geneset_files/figure-gfm/unnamed-chunk-11-1.png)<!-- -->

## Step 5: Infer target genes of top-ranked ligands and visualize in a heatmap

Now we will show how you can look at the regulatory potential scores
between ligands and target genes of interest. In this case, we will look
at links between top-ranked p-EMT regulating ligands and p-EMT genes. In
the ligand-target heatmaps, we show here regulatory potential scores for
interactions between the 20 top-ranked ligands and following target
genes: genes that belong to the gene set of interest and to the 250 most
strongly predicted targets of at least one of the 20 top-ranked ligands
(the top 250 targets according to the general prior model, so not the
top 250 targets for this dataset). Consequently, genes of your gene set
that are not a top target gene of one of the prioritized ligands, will
not be shown on the heatmap.

``` r
active_ligand_target_links_df = best_upstream_ligands %>% lapply(get_weighted_ligand_target_links,geneset = geneset_oi, ligand_target_matrix = ligand_target_matrix, n = 250) %>% bind_rows()

nrow(active_ligand_target_links_df)
## [1] 460
head(active_ligand_target_links_df)
## # A tibble: 6 × 3
##   ligand target  weight
##   <chr>  <chr>    <dbl>
## 1 TGFB2  ACTN1   0.0849
## 2 TGFB2  C1S     0.124 
## 3 TGFB2  COL17A1 0.0732
## 4 TGFB2  COL1A1  0.243 
## 5 TGFB2  COL4A2  0.148 
## 6 TGFB2  F3      0.0747
```

For visualization purposes, we adapted the ligand-target regulatory
potential matrix as follows. Regulatory potential scores were set as 0
if their score was below a predefined threshold, which was here the 0.25
quantile of scores of interactions between the 20 top-ranked ligands and
each of their respective top targets (see the ligand-target network
defined in the data frame).

``` r
active_ligand_target_links = prepare_ligand_target_visualization(ligand_target_df = active_ligand_target_links_df, ligand_target_matrix = ligand_target_matrix, cutoff = 0.25)

nrow(active_ligand_target_links_df)
## [1] 460
head(active_ligand_target_links_df)
## # A tibble: 6 × 3
##   ligand target  weight
##   <chr>  <chr>    <dbl>
## 1 TGFB2  ACTN1   0.0849
## 2 TGFB2  C1S     0.124 
## 3 TGFB2  COL17A1 0.0732
## 4 TGFB2  COL1A1  0.243 
## 5 TGFB2  COL4A2  0.148 
## 6 TGFB2  F3      0.0747
```

The putatively active ligand-target links will now be visualized in a
heatmap. The order of the ligands accord to the ranking according to the
ligand activity prediction.

``` r
order_ligands = intersect(best_upstream_ligands, colnames(active_ligand_target_links)) %>% rev()
order_targets = active_ligand_target_links_df$target %>% unique()
vis_ligand_target = active_ligand_target_links[order_targets,order_ligands] %>% t()

p_ligand_target_network = vis_ligand_target %>% make_heatmap_ggplot("Prioritized CAF-ligands","p-EMT genes in malignant cells", color = "purple",legend_position = "top", x_axis_position = "top",legend_title = "Regulatory potential") + scale_fill_gradient2(low = "whitesmoke",  high = "purple", breaks = c(0,0.005,0.01)) + theme(axis.text.x = element_text(face = "italic"))

p_ligand_target_network
```

![](ligand_activity_geneset_files/figure-gfm/unnamed-chunk-14-1.png)<!-- -->

Note that the choice of these cutoffs for visualization is quite
arbitrary. We recommend users to test several cutoff values.

If you would consider more than the top 250 targets based on prior
information, you will infer more, but less confident, ligand-target
links; by considering less than 250 targets, you will be more stringent.

If you would change the quantile cutoff that is used to set scores to 0
(for visualization purposes), lowering this cutoff will result in a more
dense heatmap, whereas highering this cutoff will result in a more
sparse heatmap.

## Follow-up analysis 1: Ligand-receptor network inference for top-ranked ligands

One type of follow-up analysis is looking at which receptors of the
receiver cell population (here: malignant cells) can potentially bind to
the prioritized ligands from the sender cell population (here: CAFs).

So, we will now infer the predicted ligand-receptor interactions of the
top-ranked ligands and visualize these in a heatmap.

``` r
# get the ligand-receptor network of the top-ranked ligands
lr_network_top = lr_network %>% filter(from %in% best_upstream_ligands & to %in% expressed_receptors) %>% distinct(from,to)
best_upstream_receptors = lr_network_top %>% pull(to) %>% unique()

# get the weights of the ligand-receptor interactions as used in the NicheNet model
weighted_networks = readRDS(url("https://zenodo.org/record/7074291/files/weighted_networks_nsga2r_final.rds"))
lr_network_top_df = weighted_networks$lr_sig %>% filter(from %in% best_upstream_ligands & to %in% best_upstream_receptors)

# convert to a matrix
lr_network_top_df = lr_network_top_df %>% spread("from","weight",fill = 0)
lr_network_top_matrix = lr_network_top_df %>% select(-to) %>% as.matrix() %>% magrittr::set_rownames(lr_network_top_df$to)

# perform hierarchical clustering to order the ligands and receptors
dist_receptors = dist(lr_network_top_matrix, method = "binary")
hclust_receptors = hclust(dist_receptors, method = "ward.D2")
order_receptors = hclust_receptors$labels[hclust_receptors$order]

dist_ligands = dist(lr_network_top_matrix %>% t(), method = "binary")
hclust_ligands = hclust(dist_ligands, method = "ward.D2")
order_ligands_receptor = hclust_ligands$labels[hclust_ligands$order]
```

Show a heatmap of the ligand-receptor interactions

``` r
vis_ligand_receptor_network = lr_network_top_matrix[order_receptors, order_ligands_receptor]
p_ligand_receptor_network = vis_ligand_receptor_network %>% t() %>% make_heatmap_ggplot("Prioritized CAF-ligands","Receptors expressed by malignant cells", color = "mediumvioletred", x_axis_position = "top",legend_title = "Prior interaction potential")
p_ligand_receptor_network
```

![](ligand_activity_geneset_files/figure-gfm/unnamed-chunk-16-1.png)<!-- -->

## Follow-up analysis 2: Visualize expression of top-predicted ligands and their target genes in a combined heatmap

NicheNet only considers expressed ligands of sender cells, but does not
take into account their expression for ranking the ligands. The ranking
is purely based on the potential that a ligand might regulate the gene
set of interest, given prior knowledge. Because it is also useful to
further look into expression of ligands and their target genes, we
demonstrate here how you could make a combined figure showing ligand
activity, ligand expression, target gene expression and ligand-target
regulatory potential.

#### Load additional packages required for the visualization:

``` r
library(RColorBrewer)
library(cowplot)
library(ggpubr)
```

#### Prepare the ligand activity matrix

``` r
ligand_aupr_matrix = ligand_activities %>% select(aupr) %>% as.matrix() %>% magrittr::set_rownames(ligand_activities$test_ligand)

vis_ligand_aupr = ligand_aupr_matrix[order_ligands, ] %>% as.matrix(ncol = 1) %>% magrittr::set_colnames("AUPR")
```

``` r
p_ligand_aupr = vis_ligand_aupr %>% make_heatmap_ggplot("Prioritized CAF-ligands","Ligand activity", color = "darkorange",legend_position = "top", x_axis_position = "top", legend_title = "AUPR\n(target gene prediction ability)")
p_ligand_aupr
```

![](ligand_activity_geneset_files/figure-gfm/unnamed-chunk-19-1.png)<!-- -->

#### Prepare expression of ligands in fibroblast per tumor

Because the single-cell data was collected from multiple tumors, we will
show here the average expression of the ligands per tumor.

``` r
expression_df_CAF = expression[CAF_ids,order_ligands] %>% data.frame() %>% rownames_to_column("cell") %>% as_tibble() %>% inner_join(sample_info %>% select(cell,tumor), by =  "cell")

aggregated_expression_CAF = expression_df_CAF %>% group_by(tumor) %>% select(-cell) %>% summarise_all(mean)

aggregated_expression_df_CAF = aggregated_expression_CAF %>% select(-tumor) %>% t() %>% magrittr::set_colnames(aggregated_expression_CAF$tumor) %>% data.frame() %>% rownames_to_column("ligand") %>% as_tibble() 

aggregated_expression_matrix_CAF = aggregated_expression_df_CAF %>% select(-ligand) %>% as.matrix() %>% magrittr::set_rownames(aggregated_expression_df_CAF$ligand)

order_tumors = c("HN6","HN20","HN26","HN28","HN22","HN25","HN5","HN18","HN17","HN16") # this order was determined based on the paper from Puram et al. Tumors are ordered according to p-EMT score.
vis_ligand_tumor_expression = aggregated_expression_matrix_CAF[order_ligands,order_tumors]
```

``` r
library(RColorBrewer)
color = colorRampPalette(rev(brewer.pal(n = 7, name ="RdYlBu")))(100)
p_ligand_tumor_expression = vis_ligand_tumor_expression %>% make_heatmap_ggplot("Prioritized CAF-ligands","Tumor", color = color[100],legend_position = "top", x_axis_position = "top", legend_title = "Expression\n(averaged over\nsingle cells)") + theme(axis.text.y = element_text(face = "italic"))
p_ligand_tumor_expression
```

![](ligand_activity_geneset_files/figure-gfm/unnamed-chunk-21-1.png)<!-- -->

#### Prepare expression of target genes in malignant cells per tumor

``` r
expression_df_target = expression[malignant_ids,geneset_oi] %>% data.frame() %>% rownames_to_column("cell") %>% as_tibble() %>% inner_join(sample_info %>% select(cell,tumor), by =  "cell") 

aggregated_expression_target = expression_df_target %>% group_by(tumor) %>% select(-cell) %>% summarise_all(mean)

aggregated_expression_df_target = aggregated_expression_target %>% select(-tumor) %>% t() %>% magrittr::set_colnames(aggregated_expression_target$tumor) %>% data.frame() %>% rownames_to_column("target") %>% as_tibble() 

aggregated_expression_matrix_target = aggregated_expression_df_target %>% select(-target) %>% as.matrix() %>% magrittr::set_rownames(aggregated_expression_df_target$target)

vis_target_tumor_expression_scaled = aggregated_expression_matrix_target %>% t() %>% scale_quantile() %>% .[order_tumors,order_targets]
```

``` r
p_target_tumor_scaled_expression = vis_target_tumor_expression_scaled  %>% make_threecolor_heatmap_ggplot("Tumor","Target", low_color = color[1],mid_color = color[50], mid = 0.5, high_color = color[100], legend_position = "top", x_axis_position = "top" , legend_title = "Scaled expression\n(averaged over\nsingle cells)") + theme(axis.text.x = element_text(face = "italic"))
p_target_tumor_scaled_expression
```

![](ligand_activity_geneset_files/figure-gfm/unnamed-chunk-23-1.png)<!-- -->

#### Combine the different heatmaps in one overview figure

``` r
figures_without_legend = plot_grid(
  p_ligand_aupr + theme(legend.position = "none", axis.ticks = element_blank()) + theme(axis.title.x = element_text()),
  p_ligand_tumor_expression + theme(legend.position = "none", axis.ticks = element_blank()) + theme(axis.title.x = element_text()) + ylab(""),
  p_ligand_target_network + theme(legend.position = "none", axis.ticks = element_blank()) + ylab(""), 
  NULL,
  NULL,
  p_target_tumor_scaled_expression + theme(legend.position = "none", axis.ticks = element_blank()) + xlab(""), 
  align = "hv",
  nrow = 2,
  rel_widths = c(ncol(vis_ligand_aupr)+ 4.5, ncol(vis_ligand_tumor_expression), ncol(vis_ligand_target)) -2,
  rel_heights = c(nrow(vis_ligand_aupr), nrow(vis_target_tumor_expression_scaled) + 3)) 

legends = plot_grid(
  as_ggplot(get_legend(p_ligand_aupr)),
  as_ggplot(get_legend(p_ligand_tumor_expression)),
  as_ggplot(get_legend(p_ligand_target_network)),
  as_ggplot(get_legend(p_target_tumor_scaled_expression)),
  nrow = 2,
  align = "h")

plot_grid(figures_without_legend, 
          legends, 
          rel_heights = c(10,2), nrow = 2, align = "hv")
```

![](ligand_activity_geneset_files/figure-gfm/unnamed-chunk-24-1.png)<!-- -->

## Other follow-up analyses:

As another follow-up analysis, you can infer possible signaling paths
between ligands and targets of interest. You can read how to do this in
the following vignette [Inferring ligand-to-target signaling
paths](ligand_target_signaling_path.md):`vignette("ligand_target_signaling_path", package="nichenetr")`.

Another follow-up analysis is getting a “tangible” measure of how well
top-ranked ligands predict the gene set of interest and assess which
genes of the gene set can be predicted well. You can read how to do this
in the following vignette [Assess how well top-ranked ligands can
predict a gene set of
interest](target_prediction_evaluation_geneset.md):`vignette("target_prediction_evaluation_geneset", package="nichenetr")`.

In case you want to visualize ligand-target links between multiple
interacting cells, you can make an appealing circos plot as shown in
vignette [Circos plot visualization to show active ligand-target links
between interacting
cells](circos.md):`vignette("circos", package="nichenetr")`.

## References

<div id="refs" class="references csl-bib-body hanging-indent">

<div id="ref-puram_single-cell_2017" class="csl-entry">

Puram, Sidharth V., Itay Tirosh, Anuraag S. Parikh, Anoop P. Patel,
Keren Yizhak, Shawn Gillespie, Christopher Rodman, et al. 2017.
“Single-Cell Transcriptomic Analysis of Primary and Metastatic Tumor
Ecosystems in Head and Neck Cancer.” *Cell* 171 (7): 1611–1624.e24.
<https://doi.org/10.1016/j.cell.2017.10.044>.

</div>

</div>

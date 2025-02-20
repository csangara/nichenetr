<!-- README.md is generated from README.Rmd. Please edit that file -->
<!-- github markdown built using
rmarkdown::render("README.Rmd",output_format = "md_document")
-->

# nichenetr

<!-- badges: start -->

[![R build
status](https://github.com/saeyslab/nichenetr/workflows/R-CMD-check-bioc/badge.svg)](https://github.com/saeyslab/nichenetr/actions)
[![Coverage
Status](https://codecov.io/gh/saeyslab/nichenetr/branch/master/graph/badge.svg)](https://codecov.io/gh/saeyslab/nichenetr)
[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.3260758.svg)](https://doi.org/10.5281/zenodo.3260758)
[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.7074291.svg)](https://doi.org/10.5281/zenodo.7074291)
<!-- badges: end -->

**nichenetr: the R implementation of the NicheNet method.** The goal of
NicheNet is to study intercellular communication from a computational
perspective. NicheNet uses human or mouse gene expression data of
interacting cells as input and combines this with a prior model that
integrates existing knowledge on ligand-to-target signaling paths. This
allows to predict ligand-receptor interactions that might drive gene
expression changes in cells of interest.

We describe the NicheNet algorithm in the following paper: [NicheNet:
modeling intercellular communication by linking ligands to target
genes](https://www.nature.com/articles/s41592-019-0667-5).

Bonnardel, T’Jonck et al. (2019) already used NicheNet to predict
upstream niche signals driving Kupffer cell differentiation [Stellate
Cells, Hepatocytes, and Endothelial Cells Imprint the Kupffer Cell
Identity on Monocytes Colonizing the Liver Macrophage
Niche](https://www.cell.com/immunity/fulltext/S1074-7613(19)30368-1).

### Major updates (16-05-2023)!

-   MultiNicheNet - a multi-sample, multi-condition extension of
    NicheNet - is now available on [biorxiv]() and
    [Github](https://github.com/saeyslab/multinichenetr).
-   MultiNicheNet uses an [updated prior model
    (v2)](https://zenodo.org/record/7074291/) consisting of additional
    ligand-receptor interactions from the [Omnipath
    database](https://omnipathdb.org/) and from [Verschueren et
    al. (2020)](https://www.sciencedirect.com/science/article/pii/S0092867420306942?via%3Dihub).
    We have now also updated the vignettes of NicheNet to use the new
    model instead.
-   New functionality: we have included additional functions to
    prioritize ligands not only based on the ligand activity, but also
    on the ligand and receptor expression, cell type specificity, and
    condition specificity. This is similar to the criteria used in
    Differential NicheNet and MultiNicheNet. See the [Prioritizing
    ligands based on expression]() vignette for more information.
-   We included code for making a ligand-receptor-target circos plot in
    the [Circos plot visualization](vignettes/circos.md) vignette.

## Introduction to NicheNet

The figure below shows a graphical representation of the NicheNet
workflow. Interactions inferred from several complementary
ligand-receptor, signaling and gene regulatory data sources were
aggregated in respective integrated networks from which ligand-target
regulatory potential scores were calculated. This model of prior
information on potential ligand-target links can then be used to infer
active ligand-target links between interacting cells. NicheNet
prioritizes ligands according to their activity (i.e., how well they
predict observed changes in gene expression in the receiver cell) and
looks for affected targets with high potential to be regulated by these
prioritized ligands.

We offer the option to use the prebuilt prior model (such that the
network integration steps should not be repeated), or to create and use
your own prior model (see reference to detailed vignette below).

<br><br> ![](vignettes/workflow_nichenet.jpg) <br><br>

NicheNet strongly differs from most current computational approaches to
study intercellular communication. Current approaches study
intercellular communication from (single-cell) expression data by
linking ligands expressed by sender cells to their corresponding
receptors expressed by receiver cells. However, functional understanding
of a cellular communication process also requires knowing how these
inferred ligand-receptor interactions result in changes in the
expression of downstream target genes within the receiver cells. To
address this need, we developed NicheNet. Contrary to existing
approaches, NicheNet looks at gene regulatory effects of ligands because
the used prior knowledge goes beyond ligand-receptor interactions and
incorporates intracellular signaling and transcriptional regulation as
well. As a result, NicheNet allows to predict which ligands influence
the expression in another cell, which target genes are affected by each
ligand and which signaling mediators may be involved. By generating
these novel types of hypotheses, NicheNet can drive an improved
functional understanding of a cell-cell communication process of
interest. The figure below summarizes the conceptual differences between
most current ligand-receptor network inference approaches (top panel)
and NicheNet (bottom panel) and visualizes the power of NicheNet in
prioritizing ligand-receptor interactions based on gene expression
effects.

<br><br>
<img src="vignettes/comparison_other_approaches_2.jpg" width="450" />
<br><br>

## Main functionalities of nichenetr

Specific functionalities of this package include:

-   assessing how well ligands expressed by a sender cell can predict
    changes in gene expression in the receiver cell
-   prioritizing ligands based on their effect on gene expression
-   inferring putative ligand-target links active in the system under
    study
-   inferring potential signaling paths between ligands and target genes
    of interest: to generate causal hypotheses and check which data
    sources support the predictions
-   validation of the prior ligand-target model
-   construction of user-defined prior ligand-target models

Moreover, we provide instructions on how to make intuitive
visualizations of the main predictions (e.g., via circos plots as shown
here below).

<br><br> ![](vignettes/circos_plot_adapted.jpg)

## Installation of nichenetr

Installation typically takes a few minutes, depending on the number of
dependencies that has already been installed on your pc. You can install
nichenetr (and required dependencies) from github with:

    # install.packages("devtools")
    devtools::install_github("saeyslab/nichenetr")

nichenetr was tested on both Windows and Linux (most recently tested R
version: R 4.0.0)

## Learning to use nichenetr

To learn using nichenetr, read one of the following vignettes explaining
several types of analyses:

Following vignette contains the explanation on how to perform a basic
NicheNet analysis. This includes prioritizing ligands and predicting
target genes of prioritized ligands. This demo analysis takes only a few
minutes to run:

-   [NicheNet’s ligand activity analysis on a gene set of interest:
    predict active ligands and their target
    genes](vignettes/ligand_activity_geneset.md):
    `vignette("ligand_activity_geneset", package="nichenetr")`

To facilitate the use of NicheNet on single-cell data, we demonstrate
the use of NicheNet on a Seurat object in following vignettes. One
demonstrates the use of a single wrapper function, the other
demonstrates what’s behind the wrapper (recommended).

-   [Perform NicheNet analysis starting from a Seurat
    object](vignettes/seurat_wrapper.md):`vignette("seurat_wrapper", package="nichenetr")`
-   [Perform NicheNet analysis starting from a Seurat object:
    step-by-step
    analysis](vignettes/seurat_steps.md):`vignette("seurat_steps", package="nichenetr")`

Following vignettes contain explanation on how to do some follow-up
analyses after performing the most basic analysis:

-   [Inferring ligand-to-target signaling
    paths](vignettes/ligand_target_signaling_path.md):
    `vignette("ligand_target_signaling_path", package="nichenetr")`
-   [Assess how well top-ranked ligands can predict a gene set of
    interest](vignettes/target_prediction_evaluation_geneset.md):
    `vignette("target_prediction_evaluation_geneset", package="nichenetr")`
-   [Single-cell NicheNet’s ligand activity
    analysis](vignettes/ligand_activity_single_cell.md):
    `vignette("ligand_activity_single_cell", package="nichenetr")`

If you want to make a circos plot visualization of the NicheNet output,
you can check following vignettes:

-   [Circos plot visualization to show active ligand-target links
    between interacting
    cells](vignettes/circos.md):`vignette("circos", package="nichenetr")`.
-   [Seurat Wrapper + Circos
    visualization](vignettes/seurat_wrapper_circos.md):`vignette("seurat_wrapper_circos", package="nichenetr")`.

People interested in building own models or benchmark own models against
NicheNet can read one of the following vignettes:

-   [Model construction](vignettes/model_construction.md):
    `vignette("model_construction", package="nichenetr")`
-   [Model evaluation: target gene and ligand activity
    prediction](vignettes/model_evaluation.md):
    `vignette("model_evaluation", package="nichenetr")`
-   [Parameter optimization via
    mlrMBO](vignettes/parameter_optimization.md):
    `vignette("parameter_optimization", package="nichenetr")`

People working with mouse data can see in the following vignette how to
convert NicheNet’s ligand-target model (given in human symbols) to mouse
symbols:

-   [Converting NicheNet’s model from human to mouse
    symbols](vignettes/symbol_conversion.md):
    `vignette("symbol_conversion", package="nichenetr")`

Differential NicheNet vignettes:

-   [Differential NicheNet analysis between niches of
    interest](vignettes/differential_nichenet.md):`vignette("differential_nichenet", package="nichenetr")`
-   [Differential NicheNet analysis between conditions of
    interest](vignettes/differential_nichenet_pEMT.md):`vignette("differential_nichenet_pEMT", package="nichenetr")`

## FAQ

Check the FAQ page at [FAQ NicheNet](vignettes/faq.md):
`vignette("faq", package="nichenetr")`

## Previous updates

12-01-2022: In the Liver Atlas paper from Guilliams et al.: [Spatial
proteogenomics reveals distinct and evolutionarily conserved hepatic
macrophage
niches](https://www.sciencedirect.com/science/article/pii/S0092867421014811),
we used Differential NicheNet, an extension to the default NicheNet
algorithm. **Differential NicheNet** can be used to compare cell-cell
interactions between different niches and better predict niche-specific
ligand-receptor (L-R) pairs. It was used in that paper to predict
ligand-receptor pairs specific for the Kupffer cell niche in mouse and
human.

The main difference between the classic NicheNet pipeline and the
Differential NicheNet pipeline is that Differential NicheNet also uses
the differential expression between the conditions/niches of the
ligand-receptor pairs for prioritization in addition to the ligand
activities. The classic NicheNet pipeline on the contrary uses only
ligand acivity for prioritization (and shows differential expression
only in visualizations).

So if you have data of multiple conditions or niches, and you want to
include differential expression of the ligand-receptor pairs in the
prioritization, we recommend you check out Differential NicheNet (update
nichenetr to the 1.1.0 version). At the bottom of this page, you can
find the links to two vignettes illustrating a Differential NicheNet
analysis. We recommend these vignettes if you want to apply Differential
NicheNet on your own data. If you want to see the code used for the
analyses used in the Guilliams et al. paper, see
<https://github.com/saeyslab/NicheNet_LiverCellAtlas>.

## References

Browaeys, R., Saelens, W. & Saeys, Y. NicheNet: modeling intercellular
communication by linking ligands to target genes. Nat Methods (2019)
<doi:10.1038/s41592-019-0667-5>

Bonnardel et al. Stellate Cells, Hepatocytes, and Endothelial Cells
Imprint the Kupffer Cell Identity on Monocytes Colonizing the Liver
Macrophage Niche. Immunity (2019) <doi:10.1016/j.immuni.2019.08.017>

Guilliams et al. Spatial proteogenomics reveals distinct and
evolutionarily conserved hepatic macrophage niches. Cell (2022)
<doi:10.1016/j.cell.2021.12.018>

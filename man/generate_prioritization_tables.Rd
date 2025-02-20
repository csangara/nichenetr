% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/prioritization.R
\name{generate_prioritization_tables}
\alias{generate_prioritization_tables}
\title{generate_prioritization_tables}
\usage{
generate_prioritization_tables(sender_receiver_info, sender_receiver_de, ligand_activities, prioritizing_weights = c("de_ligand" = 1,"de_receptor" = 1,"activity_scaled" = 2,"exprs_ligand" = 2,"exprs_receptor" = 2,"condition_specificity"=0))
}
\arguments{
\item{sender_receiver_info}{Output of `get_exprs_avg` -> `process_table_to_ic`}

\item{sender_receiver_de}{Output of`calculate_de` -> `process_table_to_ic`}

\item{ligand_activities}{Output of `predict_ligand_activities`}

\item{prioritizing_weights}{Named vector indicating the relative weights of each prioritization criterion}
}
\value{
Data frames of prioritized sender-ligand-receiver-receptor interactions.
}
\description{
\code{generate_prioritization_tables}  Perform a prioritization of cell-cell interactions (similar to MultiNicheNet).
User can choose the importance attached to each of the following prioritization criteria: differential expression of ligand and receptor, cell-type specificity of expression of ligand and receptor, NicheNet ligand activity
}
\examples{
\dontrun{
library(dplyr)
lr_network = readRDS(url("https://zenodo.org/record/3260758/files/lr_network.rds"))
lr_network = lr_network \%>\% dplyr::rename(ligand = from, receptor = to) \%>\% dplyr::distinct(ligand, receptor)
ligand_target_matrix = readRDS(url("https://zenodo.org/record/3260758/files/ligand_target_matrix.rds"))
seurat_obj = readRDS(url("https://zenodo.org/record/3531889/files/seuratObj.rds"))
seurat_obj$celltype <- make.names(seuratObj$celltype)
sender_celltypes = c("CD4.T","Treg", "Mono", "NK", "B", "DC")
receiver = "CD8.T"

# Convert lr_network from mouse to human
lr_network = lr_network \%>\% mutate(from = convert_human_to_mouse_symbols(from), to = convert_human_to_mouse_symbols(to)) \%>\% drop_na()
colnames(ligand_target_matrix) = ligand_target_matrix \%>\% colnames() \%>\% convert_human_to_mouse_symbols()
rownames(ligand_target_matrix) = ligand_target_matrix \%>\% rownames() \%>\% convert_human_to_mouse_symbols()
ligand_target_matrix = ligand_target_matrix \%>\% .[!is.na(rownames(ligand_target_matrix)), !is.na(colnames(ligand_target_matrix))]

# Ligand activity analysis
seurat_obj_receiver = subset(seurat_obj, idents = receiver) \%>\% SetIdent(value = .[["aggregate"]])
geneset_oi = FindMarkers(object = seurat_obj_receiver, ident.1 = "LCMV, ident.2 = "SS, min.pct = 0.10) \%>\% rownames_to_column("gene") \%>\%
     filter(p_val_adj <= 0.05 & abs(avg_log2FC) >= 0.25) \%>\% pull(gene) \%>\% .[. \%in\% rownames(ligand_target_matrix)]
expressed_genes_sender = sender_celltypes \%>\% unique() \%>\% lapply(get_expressed_genes, seurat_obj, 0.10) \%>\% unlist() \%>\% unique()
expressed_genes_receiver = get_expressed_genes(receiver, seurat_obj, pct = 0.10)
expressed_ligands = intersect(lr_network \%>\% pull(ligand) \%>\% unique(), expressed_genes_sender)
expressed_receptors = intersect(lr_network \%>\% pull(receiver) \%>\% unique(), expressed_genes_receiver)
potential_ligands = lr_network \%>\% filter(ligand \%in\% expressed_ligands & receptor \%in\% expressed_receptors) \%>\% pull(from) \%>\% unique()
ligand_activities = predict_ligand_activities(geneset = geneset_oi, background_expressed_genes = expressed_genes_receiver \%>\% .[. \%in\% rownames(ligand_target_matrix)],
                                            ligand_target_matrix = ligand_target_matrix, potential_ligands = potential_ligands)

# Calculate LCMV-specific average expression
expression_info = get_exprs_avg(seurat_obj, "celltype", condition_oi = "LCMV", condition_colname = "aggregate")

# Calculate LCMV-specific cell-type markers
DE_table = calculate_de(seurat_obj, "celltype", condition_oi = "LCMV", condition_colname = "aggregate")

# Calculate condition-specific markers
condition_markers <- FindMarkers(object = seuratObj, ident.1 = "LCMV", ident.2 = "SS",
                                 group.by = "aggregate", min.pct = 0, logfc.threshold = 0) \%>\% rownames_to_column("gene")

# Process tables
processed_expr_info = process_table_to_ic(expression_info, table_type = "expression", lr_network)
processed_DE_table <- process_table_to_ic(DE_table, table_type = "celltype_DE", lr_network,
                                          senders_oi = sender_celltypes, receivers_oi = receiver)
processed_condition_DE_table <- process_table_to_ic(condition_markers, table_type = "group_DE", lr_network)

# Generate prioritization tables
prioritizing_weights = c("de_ligand" = 1, "de_receptor" = 1, "activity_scaled" = 2, "exprs_ligand" = 1, "exprs_receptor" = 1, "ligand_condition_specificity" = 0, "receptor_condition_specificity" = 0)
generate_prioritization_tables(processed_expr_info,
                               processed_DE_table,
                               ligand_activities,
                               processed_condition_DE_table,
                               prioritizing_weights)
}
}

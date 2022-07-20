# This file creates the whole makefile

# Create makeflow file for doublet identification
# makeflow -T slurm -J 200 analysis/empty_droplet_identification/empty_droplet_identification.makeflow


# commands
commands = c()
tab = "\t"

# Read arguments
# Read arguments
args = commandArgs(trailingOnly=TRUE)
result_directory = args[[1]]
input_directory = args[[2]]
code_directory = args[[3]]
reference_azimuth_path = args[[4]]

renv::activate(project = code_directory)

# This script slipts the dataset and creates the list of files in a specific directory
library(tidyverse)
library(glue)
library(here)
library(stringr)
library(Seurat)
library(tidyseurat)

R_code_directory = glue("{code_directory}/R")


# Input demultiplexed THOSE FILES MUST EXIST!
input_directory_demultiplexed = input_directory
input_files_demultiplexed = dir(input_directory_demultiplexed, pattern = ".rds")
input_path_demultiplexed = glue("{input_directory_demultiplexed}/{input_files_demultiplexed}")
samples = input_files_demultiplexed |> str_remove(".rds")



# >>> EMPTY droplets
suffix = "__empty_droplet_identification"

output_directory = glue("{result_directory}/preprocessing_results/empty_droplet_identification")
output_path_empty_droplets =   glue("{output_directory}/{samples}{suffix}_output.rds")
output_path_plot_pdf =  glue("{output_directory}/{samples}{suffix}_plot.pdf")
output_path_plot_rds =  glue("{output_directory}/{samples}{suffix}_plot.rds")

# Create input
commands =
  commands |>
  c(
    "CATEGORY=empty_droplet_identification\nMEMORY=10024\nCORES=1\nWALL_TIME=30000",
    glue("{output_path_empty_droplets} {output_path_plot_pdf} {output_path_plot_rds}:{input_path_demultiplexed}\n{tab}Rscript {R_code_directory}/run{suffix}.R {code_directory} {input_path_demultiplexed} {output_path_empty_droplets} {output_path_plot_pdf} {output_path_plot_rds}")
  )




# >>> ALIVE CELLS
suffix = "__alive_identification"

output_directory = glue("{result_directory}/preprocessing_results/alive_identification")
output_path_alive =   glue("{output_directory}/{samples}{suffix}_output.rds")


# Create input
commands =
  commands |> c(
  "CATEGORY=alive_identification\nMEMORY=10024\nCORES=1\nWALL_TIME=30000",
  glue("{output_path_alive}:{input_path_demultiplexed} {output_path_empty_droplets}\n{tab}Rscript {R_code_directory}/run{suffix}.R {code_directory} {input_path_demultiplexed} {output_path_empty_droplets} {output_path_alive}")
)





# >>> NORMALISATION

suffix = "__non_batch_variation_removal"

output_directory = glue("{result_directory}/preprocessing_results/non_batch_variation_removal")
output_path_non_batch_variation_removal =   glue("{output_directory}/{samples}{suffix}_output.rds")


# Create input
commands =
  commands |> c(
  "CATEGORY=non_batch_variation_removal\nMEMORY=40024\nCORES=1\nWALL_TIME=30000",
  glue("{output_path_non_batch_variation_removal}:{input_path_demultiplexed} {output_path_empty_droplets}\n{tab}Rscript {R_code_directory}/run{suffix}.R {code_directory} {input_path_demultiplexed} {output_path_empty_droplets} {output_path_non_batch_variation_removal}")
)




# >>> AZIMUTH ANNOTATION

suffix = "__annotation_label_transfer"

cores = 4

output_directory = glue("{result_directory}/preprocessing_results/annotation_label_transfer")
output_paths_annotation_label_transfer =   glue("{output_directory}/{samples}{suffix}_output.rds")

# Create input
commands =
  commands |>
  c(
    "CATEGORY=annotation_label_transfer\nMEMORY=30024\nCORES=1\nWALL_TIME=10000",
    output_path_non_batch_variation_removal %>%
      enframe(value = "input_path") %>%
      mutate(input_file =  basename(input_path)) %>%
      extract(input_path,into = c("sample"), "([A-Za-z0-9_-]+)___.+", remove = FALSE) %>%
      mutate(output_path = glue("{output_directory}/{sample}{suffix}.rds")) %>%
      mutate(command = glue(
        "{output_paths_annotation_label_transfer}:{output_path_non_batch_variation_removal}\n{tab}Rscript {R_code_directory}/run{suffix}.R {code_directory} {output_path_non_batch_variation_removal} {reference_azimuth_path} {output_paths_annotation_label_transfer}"
      )) %>%
      pull(command)
  )






# >>> DOUBLET IDENTIFICATION

suffix = "__doublet_identification"

cores = 4

# Output
output_directory = glue("{result_directory}/preprocessing_results/doublet_identification")
output_path_doublet_identification =   glue("{output_directory}/{samples}{suffix}_output.rds")

# Create input
commands =
  commands |> c(
  "CATEGORY=doublet_identification\nMEMORY=10024\nCORES=2\nWALL_TIME=30000",
  glue("{output_path_doublet_identification}:{input_path_demultiplexed} {output_path_empty_droplets} {output_path_alive} {output_paths_annotation_label_transfer}\n{tab}Rscript {R_code_directory}/run{suffix}.R {code_directory} {input_path_demultiplexed} {output_path_empty_droplets} {output_path_alive} {output_paths_annotation_label_transfer} {output_path_doublet_identification}")

)



# >>> WRITE PREPROCESSING RESULT

suffix = "__preprocessing_output"

cores = 4

# Output
output_directory = glue("{result_directory}/preprocessing_results/preprocessing_output")
output_path_preprocessing_results =   glue("{output_directory}/{samples}{suffix}_output.rds")

# Create input
commands =
  commands |> c(
  "CATEGORY=preprocessing_output\nMEMORY=10024\nCORES=2\nWALL_TIME=30000",
  glue("{output_path_preprocessing_results}:{output_path_non_batch_variation_removal} {output_path_alive} {output_paths_annotation_label_transfer} {output_path_doublet_identification}\n{tab}Rscript {R_code_directory}/run{suffix}.R {code_directory} {output_path_non_batch_variation_removal} {output_path_alive} {output_paths_annotation_label_transfer} {output_path_doublet_identification} {output_path_preprocessing_results}")

)





# >>> PSEUDOBULK PREPROCESSING

suffix = "__pseudobulk_preprocessing"

cores = 4

# Output
output_directory = glue("{result_directory}/preprocessing_results/pseudobulk_preprocessing")
output_path_result =   glue("{output_directory}/pseudobulk_preprocessing_output.rds")

# Create input
commands =
  commands |> c(
  "CATEGORY=pseudobulk_preprocessing\nMEMORY=50024\nCORES=11\nWALL_TIME=30000",
  glue("{output_path_result}:{paste(output_path_preprocessing_results, collapse=\" \")}\n{tab}Rscript {R_code_directory}/run{suffix}.R {code_directory} {paste(output_path_preprocessing_results, collapse=\" \")} {output_path_result}")

)


# # >>> COMMUNICATION FAST
#
# # Read arguments
# result_directory = commandArgs(trailingOnly=TRUE)[[1]]
#
# tab = "\t"
# code_directory = "analysis/communication"
# cores = 4
#
# # Output
# output_directory = glue("{result_directory}/fast_pipeline_results/communication")
# output_path_result =   glue("{output_directory}/communication_output.rds")
#
# # Output
# output_directory = glue("{result_directory}/fast_pipeline_results/communication")
# output_path_result =   glue("{output_directory}/{samples}_ligand_receptor_count_output.rds")
#
#
# # Create input
# commands =
#   c(
#     "CATEGORY=communication1\nMEMORY=10024\nCORES=4\nWALL_TIME=9000",
#     glue("{output_path_result}:{output_path_preprocessing_results}\n{tab}Rscript {code_directory}/run__ligand_receptor_count.R {output_path_preprocessing_results} {output_path_result}")
#
#   )
#
# # CellChat results
# output_path_plot_overall =  glue("{output_directory}/plot_communication_overall.pdf")
# output_path_plot_heatmap =  glue("{output_directory}/plot_communication_heatmap.pdf")
# output_path_plot_circle =  glue("{output_directory}/plot_communication_circle.pdf")
# output_path_values_communication =  glue("{output_directory}/values_communication.rds")
#
#
# commands |>
#   c(
#     "CATEGORY=communication2\nMEMORY=50024\nCORES=2\nWALL_TIME=18000",
#     glue("{output_path_plot_overall} {output_path_plot_heatmap} {output_path_plot_circle} {output_path_values_communication}:{paste(output_path_result, collapse=\" \")}\n{tab}Rscript {code_directory}/run__differential_communication.R {paste(output_path_result, collapse=\" \")} {result_directory}/metadata.rds {output_path_plot_overall} {output_path_plot_heatmap} {output_path_plot_circle} {output_path_values_communication}")
#
#   ) %>%

commands |>
  write_lines(glue("{result_directory}/pipeline.makeflow"))


# Validated entry point for the administrative-data pipeline.

source("R/schema_contract.R")
source("R/pipeline.R")

run_validated_pipeline <- function(
  input_dir = "data/raw",
  output_dir = "outputs"
) {
  prepared <- prepare_validated_input(input_dir)
  result <- run_pipeline(
    input_dir = prepared$input_dir,
    output_dir = output_dir
  )
  result$schema_contract <- prepared$participant_id_recovery
  invisible(result)
}

if (sys.nframe() == 0L) {
  run_validated_pipeline()
}

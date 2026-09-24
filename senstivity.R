# 1. Load the package.
# Install the stable version from CRAN
#install.packages("nlrx")

library(lhs)
library(sensitivity)
library(ggplot2)
library(dplyr)
library(future)
library(nlrx)

Sys.setenv(JAVA_HOME = "C:/Program Files/Java/jdk-22")  # Change to your path

# Set paths (modify according to your actual installation location)
# Windows example:
#netlogopath <- file.path("C:/Program Files/NetLogo 6.2.2/app")

netlogopath <- file.path("C:/Program Files/NetLogo 6.2.2")


modelpath <- "C:/Users/sncul/Downloads/working model relative agreement - test 1.nlogo"
outpath <- file.path(getwd(), "morris_results4")  # Results output directory

# Create output directory
if(!dir.exists(outpath)) dir.create(outpath, recursive = TRUE)

# ============================================================
# Phase 1: Preliminary screening (low computational cost)
# ============================================================

# Create nl object
nl <- nl(nlversion = "6.2.2",
         nlpath = netlogopath,
         modelpath = modelpath,
         jvmmem = 3072)  # Increase memory if your model is large

# Define experiment - Phase 1 (preliminary screening, using fewer trajectories)
nl@experiment <- experiment(
  expname = "diet_model_morris_phase3",
  outpath = outpath,
  repetition = 1,
  tickmetrics = "true",
  idsetup = "setup",
  idgo = "go",
  runtime = 500,
  evalticks = seq(400, 500),  # Only analyze the last 100 ticks
  metrics = c("final-meat-eater-count",
              "final-non-eater-count"
              ),
  
  # Parameters to analyze (range definitions)
  variables = list(
    # Social influence parameters
    "exp-rate" = list(min = 0.05, max = 0.35, qfun = "qunif"),
    "inst-rate" = list(min = 0.05, max = 0.35, qfun = "qunif"),
    "inj-rate" = list(min = 0.10, max = 0.50, qfun = "qunif"),
    "learning-rate" = list(min = 0.10, max = 0.60, qfun = "qunif"),
    
    # Diet transition sensitivity parameters
    "sensitivity-none-to-reduced" = list(min = 0.5, max = 5.0, qfun = "qunif"),
    "sensitivity-reduced-to-meat" = list(min = 0.5, max = 5.0, qfun = "qunif"),
    "sensitivity-reduced-to-none" = list(min = 0.5, max = 5.0, qfun = "qunif"),
    "sensitivity-meat-to-reduced" = list(min = 0.5, max = 5.0, qfun = "qunif"),
    
    # Maximum transition probabilities
    "max-prob-none-to-reduced" = list(min = 0.1, max = 0.5, qfun = "qunif"),
    "max-prob-reduced-to-meat" = list(min = 0.05, max = 0.4, qfun = "qunif"),
    "max-prob-reduced-to-none" = list(min = 0.1, max = 0.5, qfun = "qunif"),
    "max-prob-meat-to-reduced" = list(min = 0.05, max = 0.4, qfun = "qunif"),
    
    # Inertia parameters
    "max-inertia-effect" = list(min = 0.3, max = 0.95, qfun = "qunif"),
    "habit-formation-time" = list(min = 20, max = 100, qfun = "qunif"),
    "min-probability" = list(min = 0.001, max = 0.05, qfun = "qunif")
  ),
  
  # Fixed parameters (not included in sensitivity analysis)
  constants = list(
    "no-meat-slider" = 10,   # Adjust according to your actual data
    "less-meat-slider" = 20,
    "meat-slider" = 60
  )
)

# Attach Morris simulation design - Phase 1 (low trajectory count)
nl@simdesign <- simdesign_morris(
  nl = nl,
  morristype = "oat",      # One-At-a-Time
  morrislevels = 4,         # 4 levels per parameter
  morrisr = 30,            # 30 trajectories (preliminary screening), change to 10
  morrisgridjump = 2,       # levels/2
  nseeds = 10               # 3 random seeds per combination, change to 10
)

# View experiment settings
eval_variables_constants(nl)
print(nl)

# ============================================================
# Run simulations (in parallel)
# ============================================================


# Set up parallel computing (use all CPU cores)
plan(multisession, workers = 20)  # Test with 4 cores first
options(future.globals.maxSize = 8000 * 1024^2)  # Increase memory limit


# Run all simulations
results_phase1 <- run_nl_all(nl)


# Attach results to nl object
setsim(nl, "simoutput") <- results_phase1

# Save results
saveRDS(nl, file.path(outpath, "morris_phase4.rds"))

# ============================================================
# Analyze results - identify important parameters
# ============================================================

# Calculate Morris sensitivity indices
morris_indices <- analyze_nl(nl)
# Extract mustar and sigma
mu_star_data <- morris_indices[morris_indices$index == "mustar", ]
sigma_data <- morris_indices[morris_indices$index == "sigma", ]

# Create data frame
morris_df <- data.frame(
  Parameter = mu_star_data$parameter,
  mu_star = mu_star_data$value,
  sigma = sigma_data$value,
  Metric = mu_star_data$metric  # Add metric name
)

# View full results
print(morris_df)

# Sort by mu_star
morris_df <- morris_df[order(-morris_df$mu_star), ]



# Plot bar chart
ggplot(morris_df, aes(x = reorder(Parameter, mu_star), y = mu_star)) +
  geom_bar(stat = "identity", fill = "steelblue") +
  coord_flip() +
  labs(title = "Phase 1: Morris Sensitivity Analysis - Parameter Importance",
       x = "Parameter", y = "mu* (mean absolute elementary effect)") +
  theme_minimal()

# Identify important parameters (mu* > 50% of the mean mu* across all parameters)
threshold <- mean(morris_df$mu_star) * 0.5
important_params <- morris_df[morris_df$mu_star > threshold, "Parameter"]
important_params



# Most complete save (one file containing everything)
saveRDS(list(
  nl = nl,
  results = results_phase1,
  morris_indices = morris_indices,
  important_params = important_params
), file = file.path(outpath, "morris_full_analysis.rds"))



###Stability check code

# 1. Get data
morris_indices <- analyze_nl(nl)

# 2. Extract mustar values (ensure they are numeric)
mu_data <- morris_indices[morris_indices$index == "mustar", ]
mu_values <- as.numeric(mu_data$value)

# 3. Calculate statistics
mu_mean <- mean(mu_values, na.rm = TRUE)
mu_sd <- sd(mu_values, na.rm = TRUE)
cv <- mu_sd / mu_mean

# 4. Print results
cat("========== Parameter uncertainty check ==========\n")
cat(sprintf("mu* mean: %.4f\n", mu_mean))
cat(sprintf("mu* standard deviation: %.4f\n", mu_sd))
cat(sprintf("Coefficient of variation (CV): %.4f\n", cv))

# 5. Interpretation
if(cv > 0.3) {
  cat("Warning: CV > 0.3, results are unstable! Consider increasing nseeds or r\n")
} else if(cv > 0.15) {
  cat("Warning: CV between 0.15-0.3, results are basically stable but can be improved\n")
} else {
  cat("OK: CV < 0.15, results are very stable\n")
}






# ============================================================
# Save all results completely (do it now)
# ============================================================

# 1. Make sure results are attached to nl
if(exists("results_phase1")) {
  setsim(nl, "simoutput") <- results_phase1
  cat("Results have been attached to the nl object\n")
}

# 2. Save the complete workspace (recommended)
saveRDS(list(
  nl = nl,                      # Complete nl object (with results)
  results = results_phase1,     # Raw results data frame
  morris_indices = morris_indices,  # Sensitivity indices (if already calculated)
  important_params = important_params,  # List of important parameters
  session_info = sessionInfo()   # R package version information
), file = file.path(outpath, "morris_analysis_complete.rds"))

# 3. Save key objects separately (for quick loading)
saveRDS(nl, file.path(outpath, "nl_with_results.rds"))  # nl containing results
saveRDS(results_phase1, file.path(outpath, "simulation_results.rds"))  # Raw results
saveRDS(morris_indices, file.path(outpath, "morris_indices.rds"))  # Sensitivity indices

# 4. Export to CSV format (for viewing in other software)
write.csv(results_phase1, file.path(outpath, "simulation_results.csv"), row.names = FALSE)

# 5. Save the list of important parameters
writeLines(as.character(important_params), file.path(outpath, "important_parameters.txt"))

cat("\nAll results have been saved to:", outpath, "\n")
cat("File list:\n")
list.files(outpath)






# Load your results
full <- readRDS("C:/Users/sncul/Downloads/morris_results2/morris_full_analysis.rds")

# View the distribution of mu* values
mu_star <- full$morris_indices[full$morris_indices$index == "mustar", ]

# Calculate coefficient of variation (CV = sd/mean)
# Smaller CV means more stable results
cv_values <- aggregate(value ~ parameter, data = mu_star, 
                       FUN = function(x) sd(x)/mean(x))

cat("Uncertainty in parameter estimates (CV values):\n")
print(cv_values[order(cv_values$value), ])

# If CV > 0.3, results are not very stable and more trajectories are needed



















#####TEST##########

# Test using a built-in NetLogo sample model
modelpath <- file.path(netlogopath, "app/models/Sample Models/Biology/Wolf Sheep Predation.nlogo")
outpath <- tempdir()

# Create nl object
nl <- nl(nlversion = "6.2.2",
         nlpath = netlogopath,
         modelpath = modelpath,
         jvmmem = 1024)

# Correct parameter configuration for the Wolf Sheep model
nl@experiment <- experiment(expname = "wolf_sheep_test",
                            outpath = tempdir(),
                            repetition = 1,
                            tickmetrics = "true",
                            idsetup = "setup",
                            idgo = "go",
                            runtime = 100,
                            metrics = c("count sheep", "count wolves"),
                            variables = list(
                              "initial-number-sheep" = list(min = 50, max = 150, step = 50),
                              "initial-number-wolves" = list(min = 20, max = 80, step = 20),
                              "grass-regrowth-time" = list(values = c(0, 30)),  # Note: this uses values, not min/max
                              "show-energy?" = list(values = c("false", "true"))
                            ),
                            constants = list("model-version" = "\"sheep-wolves-grass\""))

# Attach a simple design
nl@simdesign <- simdesign_simple(nl, nseeds = 1)

# Run
results <- run_nl_all(nl)
print(results)

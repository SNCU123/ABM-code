# 1. Load the package.
# 从 CRAN 安装稳定版
#install.packages("nlrx")

library(lhs)
library(sensitivity)
library(ggplot2)
library(dplyr)
library(future)
library(nlrx)

Sys.setenv(JAVA_HOME = "C:/Program Files/Java/jdk-22")  # 修改为你的路径

# 设置路径（根据你的实际安装位置修改）
# Windows 示例：
#netlogopath <- file.path("C:/Program Files/NetLogo 6.2.2/app")

netlogopath <- file.path("C:/Program Files/NetLogo 6.2.2")


modelpath <- "C:/Users/sncul/Downloads/working model relative agreement - test 1.nlogo"
outpath <- file.path(getwd(), "morris_results4")  # 结果输出目录

# 创建输出目录
if(!dir.exists(outpath)) dir.create(outpath, recursive = TRUE)

# ============================================================
# 阶段 1：初步筛选 (低计算成本)
# ============================================================

# 创建 nl 对象
nl <- nl(nlversion = "6.2.2",
         nlpath = netlogopath,
         modelpath = modelpath,
         jvmmem = 3072)  # 如果你的模型较大，增加内存

# 定义实验 - 阶段 1 (初步筛选，使用较少的轨迹数)
nl@experiment <- experiment(
  expname = "diet_model_morris_phase3",
  outpath = outpath,
  repetition = 1,
  tickmetrics = "true",
  idsetup = "setup",
  idgo = "go",
  runtime = 500,
  evalticks = seq(400, 500),  # 只分析最后 100 ticks
  metrics = c("final-meat-eater-count",
              "final-non-eater-count"
              ),
  
  # 待分析的参数（范围定义）
  variables = list(
    # 社会影响参数
    "exp-rate" = list(min = 0.05, max = 0.35, qfun = "qunif"),
    "inst-rate" = list(min = 0.05, max = 0.35, qfun = "qunif"),
    "inj-rate" = list(min = 0.10, max = 0.50, qfun = "qunif"),
    "learning-rate" = list(min = 0.10, max = 0.60, qfun = "qunif"),
    
    # 饮食转换敏感度参数
    "sensitivity-none-to-reduced" = list(min = 0.5, max = 5.0, qfun = "qunif"),
    "sensitivity-reduced-to-meat" = list(min = 0.5, max = 5.0, qfun = "qunif"),
    "sensitivity-reduced-to-none" = list(min = 0.5, max = 5.0, qfun = "qunif"),
    "sensitivity-meat-to-reduced" = list(min = 0.5, max = 5.0, qfun = "qunif"),
    
    # 最大变化概率
    "max-prob-none-to-reduced" = list(min = 0.1, max = 0.5, qfun = "qunif"),
    "max-prob-reduced-to-meat" = list(min = 0.05, max = 0.4, qfun = "qunif"),
    "max-prob-reduced-to-none" = list(min = 0.1, max = 0.5, qfun = "qunif"),
    "max-prob-meat-to-reduced" = list(min = 0.05, max = 0.4, qfun = "qunif"),
    
    # 惯性参数
    "max-inertia-effect" = list(min = 0.3, max = 0.95, qfun = "qunif"),
    "habit-formation-time" = list(min = 20, max = 100, qfun = "qunif"),
    "min-probability" = list(min = 0.001, max = 0.05, qfun = "qunif")
  ),
  
  # 固定参数（不进行敏感性分析）
  constants = list(
    "no-meat-slider" = 10,   # 根据你的实际数据调整
    "less-meat-slider" = 20,
    "meat-slider" = 60
  )
)

# 附加 Morris 模拟设计 - 阶段 1 (低轨迹数)
nl@simdesign <- simdesign_morris(
  nl = nl,
  morristype = "oat",      # One-At-a-Time
  morrislevels = 4,         # 每个参数 4 个水平
  morrisr = 30,            # 30 条轨迹（初步筛选）改成10
  morrisgridjump = 2,       # levels/2
  nseeds = 10               # 每个组合 3 个随机种子 改成10个
)

# 查看实验设置
eval_variables_constants(nl)
print(nl)

# ============================================================
# 运行模拟（并行）
# ============================================================


# 设置并行计算（使用所有 CPU 核心）
plan(multisession, workers = 20)  # 先用4个核心测试
options(future.globals.maxSize = 8000 * 1024^2)  # 增加内存限制


# 运行所有模拟
results_phase1 <- run_nl_all(nl)


# 将结果附加到 nl 对象
setsim(nl, "simoutput") <- results_phase1

# 保存结果
saveRDS(nl, file.path(outpath, "morris_phase4.rds"))

# ============================================================
# 分析结果 - 识别重要参数
# ============================================================

# 计算 Morris 敏感性指数
morris_indices <- analyze_nl(nl)
# 提取 mustar 和 sigma
mu_star_data <- morris_indices[morris_indices$index == "mustar", ]
sigma_data <- morris_indices[morris_indices$index == "sigma", ]

# 创建数据框
morris_df <- data.frame(
  Parameter = mu_star_data$parameter,
  mu_star = mu_star_data$value,
  sigma = sigma_data$value,
  Metric = mu_star_data$metric  # 添加指标名称
)

# 查看完整结果
print(morris_df)

# 按 mu_star 排序
morris_df <- morris_df[order(-morris_df$mu_star), ]



# 绘制条形图
ggplot(morris_df, aes(x = reorder(Parameter, mu_star), y = mu_star)) +
  geom_bar(stat = "identity", fill = "steelblue") +
  coord_flip() +
  labs(title = "Phase 1: Morris Sensitivity Analysis - Parameter Importance",
       x = "Parameter", y = "mu* (mean absolute elementary effect)") +
  theme_minimal()

# 识别重要参数（mu* > 所有参数 mu* 均值的 50%）
threshold <- mean(morris_df$mu_star) * 0.5
important_params <- morris_df[morris_df$mu_star > threshold, "Parameter"]
important_params



# 最完整的保存（一个文件包含所有）
saveRDS(list(
  nl = nl,
  results = results_phase1,
  morris_indices = morris_indices,
  important_params = important_params
), file = file.path(outpath, "morris_full_analysis.rds"))



###稳定检查代码

# 1. 获取数据
morris_indices <- analyze_nl(nl)

# 2. 提取 mustar 值（确保是数值）
mu_data <- morris_indices[morris_indices$index == "mustar", ]
mu_values <- as.numeric(mu_data$value)

# 3. 计算统计量
mu_mean <- mean(mu_values, na.rm = TRUE)
mu_sd <- sd(mu_values, na.rm = TRUE)
cv <- mu_sd / mu_mean

# 4. 打印结果
cat("========== 参数不确定性检查 ==========\n")
cat(sprintf("μ* 平均值: %.4f\n", mu_mean))
cat(sprintf("μ* 标准差: %.4f\n", mu_sd))
cat(sprintf("变异系数 (CV): %.4f\n", cv))

# 5. 解读
if(cv > 0.3) {
  cat("⚠️ CV > 0.3，结果不稳定！建议增加 nseeds 或 r\n")
} else if(cv > 0.15) {
  cat("⚠️ CV 在 0.15-0.3 之间，结果基本稳定但可改进\n")
} else {
  cat("✅ CV < 0.15，结果非常稳定\n")
}






# ============================================================
# 完整保存所有结果（现在就做）
# ============================================================

# 1. 确保结果已附加到 nl
if(exists("results_phase1")) {
  setsim(nl, "simoutput") <- results_phase1
  cat("✅ 结果已附加到 nl 对象\n")
}

# 2. 保存完整的工作空间（推荐）
saveRDS(list(
  nl = nl,                      # 完整的 nl 对象（含结果）
  results = results_phase1,     # 原始结果数据框
  morris_indices = morris_indices,  # 敏感性指数（如果已计算）
  important_params = important_params,  # 重要参数列表
  session_info = sessionInfo()   # R 包版本信息
), file = file.path(outpath, "morris_analysis_complete.rds"))

# 3. 分别保存关键对象（便于快速加载）
saveRDS(nl, file.path(outpath, "nl_with_results.rds"))  # 包含结果的 nl
saveRDS(results_phase1, file.path(outpath, "simulation_results.rds"))  # 原始结果
saveRDS(morris_indices, file.path(outpath, "morris_indices.rds"))  # 敏感性指数

# 4. 导出 CSV 格式（便于其他软件查看）
write.csv(results_phase1, file.path(outpath, "simulation_results.csv"), row.names = FALSE)

# 5. 保存重要参数列表
writeLines(as.character(important_params), file.path(outpath, "important_parameters.txt"))

cat("\n✅ 所有结果已保存到:", outpath, "\n")
cat("文件列表:\n")
list.files(outpath)






# 加载你的结果
full <- readRDS("C:/Users/sncul/Downloads/morris_results2/morris_full_analysis.rds")

# 查看 mu* 值的分布
mu_star <- full$morris_indices[full$morris_indices$index == "mustar", ]

# 计算变异系数（CV = sd/mean）
# CV 越小说明结果越稳定
cv_values <- aggregate(value ~ parameter, data = mu_star, 
                       FUN = function(x) sd(x)/mean(x))

cat("参数估计的不确定性（CV值）:\n")
print(cv_values[order(cv_values$value), ])

# 如果 CV > 0.3，说明结果不太稳定，需要更多轨迹



















#####TEST##########

# 使用 NetLogo 自带示例模型测试
modelpath <- file.path(netlogopath, "app/models/Sample Models/Biology/Wolf Sheep Predation.nlogo")
outpath <- tempdir()

# 创建 nl 对象
nl <- nl(nlversion = "6.2.2",
         nlpath = netlogopath,
         modelpath = modelpath,
         jvmmem = 1024)

# Wolf Sheep 模型的正确参数配置
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
                              "grass-regrowth-time" = list(values = c(0, 30)),  # 注意这里是 values 不是 min/max
                              "show-energy?" = list(values = c("false", "true"))
                            ),
                            constants = list("model-version" = "\"sheep-wolves-grass\""))

# 附加简单设计
nl@simdesign <- simdesign_simple(nl, nseeds = 1)

# 运行
results <- run_nl_all(nl)
print(results)
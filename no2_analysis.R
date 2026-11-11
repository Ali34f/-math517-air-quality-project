# load required libraries 
library(readr)
library(dplyr)
library(tidyr)
library(lubridate)
library(ggplot2)
library(lme4)
library(emmeans)

dir.create("outputs", showWarnings = FALSE)

# Basic settings 
START_YEAR <- 2019
END_YEAR <- 2025

# Keep site-years with >= 75% valid data capture
CAPTURE_MIN <- 0.75 

# Elevated benchmark (ug/m3) for probability analysis
THRESHOLD <- 40              

# load data 
sites <- read_csv("sites.csv", show_col_types = FALSE)
measurements <- read_csv("measurements.csv", show_col_types = FALSE)

# Confirm datetime is already a date-time (POSIXct) to avoid the midnight bug
stopifnot(inherits(measurements$datetime, "POSIXct"))

cat("Total raw rows:", nrow(measurements), "\n")
print(table(measurements$species))
print(count(measurements, species, unit, data_quality_status))
cat("Date range (UTC):\n"); print(range(measurements$datetime, na.rm = TRUE))

# clean up dates and timezone
no2_raw <- measurements %>%
  filter(species == "NO2") %>%
  mutate(
    datetime_local = with_tz(datetime, tzone = "Europe/London"),
    year = year(datetime_local),
    hour = hour(datetime_local),
    dow = wday(datetime_local, label = TRUE, abbr = TRUE, week_start = 1), # Monday first
    daytype = if_else(wday(datetime_local, week_start = 1) >= 6, "Weekend", "Weekday"),
    band = case_when(
      hour < 6  ~ "Night (00-05)",
      hour < 10 ~ "Morning peak (06-09)",
      hour < 16 ~ "Daytime (10-15)",
      hour < 20 ~ "Evening peak (16-19)",
      TRUE      ~ "Late evening (20-23)"
    ),
    band = factor(band, levels = c("Night (00-05)", "Morning peak (06-09)",
                                   "Daytime (10-15)", "Evening peak (16-19)",
                                   "Late evening (20-23)"))
  ) %>%
  filter(year >= START_YEAR & year <= END_YEAR)

# hour 0 is present 
stopifnot(!anyNA(no2_raw$datetime_local))
cat("Hour distribution (must include 0 to 23):\n")
print(table(no2_raw$hour))

# Join with site info 
no2 <- no2_raw %>% inner_join(sites, by = "site_code")

# data quality checks 
dq_summary <- no2 %>%
  summarise(
    n_rows = n(),
    n_missing = sum(is.na(value)),
    pct_missing = 100 * mean(is.na(value)),
    n_negative = sum(value < 0, na.rm = TRUE),
    n_zero = sum(value == 0, na.rm = TRUE),
    min_value = min(value, na.rm = TRUE),
    max_value = max(value, na.rm = TRUE),
    p99_9 = quantile(value, 0.999, na.rm = TRUE),
    n_over_200 = sum(value > 200, na.rm = TRUE)
  )
print("Data Quality Summary:")
print(dq_summary)

# Inspect top 20 highest readings for potential instrument faults
print("Top 20 highest NO2 readings:")
print(no2 %>% filter(!is.na(value)) %>% arrange(desc(value)) %>%
        select(site_code, datetime_local, value) %>% head(20))

# Data capture per site and year 
coverage <- no2 %>%
  group_by(site_code, site_type, year) %>%
  summarise(capture = mean(!is.na(value)), .groups = "drop")

# Save Coverage Heatmap
p_cov <- ggplot(coverage, aes(factor(year), site_code, fill = capture)) +
  geom_tile(colour = "white") +
  facet_grid(site_type ~ ., scales = "free_y", space = "free_y") +
  scale_fill_viridis_c(labels = scales::percent, limits = c(0, 1)) +
  labs(title = "NO\u2082 Data Capture by Site and Year",
       x = "Year", y = "Site", fill = "Valid Hours") +
  theme_minimal(base_size = 9)
ggsave("outputs/fig_coverage.png", p_cov, width = 8, height = 9, dpi = 300)

# Filter site-years based on 75% capture threshold and remove negative/missing values
good_site_years <- coverage %>% filter(capture >= CAPTURE_MIN) %>% select(site_code, year)

no2_clean <- no2 %>%
  semi_join(good_site_years, by = c("site_code", "year")) %>%
  filter(!is.na(value), value >= 0)

cat("Valid cleaned rows kept:", nrow(no2_clean), "of", nrow(no2), "\n")
cat("Site type breakdown of retained records:\n")
print(no2_clean %>% distinct(site_code, site_type) %>% count(site_type))

# summary descriptive stats
desc_stats <- no2_clean %>%
  group_by(site_type) %>%
  summarise(
    n_sites = n_distinct(site_code),
    n_valid_hours = n(),
    mean = mean(value),
    median = median(value),
    sd = sd(value),
    IQR = IQR(value),
    p95 = quantile(value, 0.95),
    .groups = "drop"
  )
print("Descriptive Statistics:")
print(desc_stats)
write_csv(desc_stats, "outputs/descriptive_stats.csv")

# Exploratory Visualization 

# Site-level profiles first to avoid busy site weighting distortion
site_hour <- no2_clean %>%
  group_by(site_code, site_type, daytype, hour) %>%
  summarise(m = mean(value), .groups = "drop")

hour_profile <- site_hour %>%
  group_by(site_type, daytype, hour) %>%
  summarise(
    mean_no2 = mean(m),
    # Middle 50% of sites lower bound
    q25 = quantile(m, 0.25),  
    # Middle 50% of sites upper bound
    q75 = quantile(m, 0.75),
    .groups = "drop"
  )

# Plot 1 : Hourly Trend with Middle 50% Site Spread Ribbon
p1 <- ggplot(hour_profile, aes(hour, mean_no2, colour = site_type, fill = site_type)) +
  geom_ribbon(aes(ymin = q25, ymax = q75), alpha = 0.15, colour = NA) +
  geom_line(linewidth = 1) +
  facet_wrap(~ daytype) +
  labs(
    title = "Mean NO\u2082 by Hour of Day (London Local Time)",
    subtitle = "Line = Mean of site means; Ribbon = Middle 50% of sites (IQR spread)",
    x = "Hour of Day",
    y = expression(NO[2]~(mu*g/m^3)),
    colour = "Site Type", fill = "Site Type"
  ) +
  theme_minimal()
ggsave("outputs/fig_hourly.png", p1, width = 9, height = 5, dpi = 300)

# Plot 2: Roadside Excess over Urban Background Difference Curve
diff_profile <- hour_profile %>%
  select(site_type, daytype, hour, mean_no2) %>%
  pivot_wider(names_from = site_type, values_from = mean_no2) %>%
  mutate(diff = Roadside - `Urban Background`)

p_diff <- ggplot(diff_profile, aes(hour, diff, colour = daytype)) +
  geom_line(linewidth = 1) +
  geom_point() +
  labs(
    title = "Roadside Excess over Urban Background by Hour",
    x = "Hour of Day",
    y = expression(Roadside - Background~(mu*g/m^3)),
    colour = "Day Type"
  ) +
  theme_minimal()
ggsave("outputs/fig_difference.png", p_diff, width = 8, height = 5, dpi = 300)

# Plot 3: Hour x Day-of-Week Heatmap (Monday at top)
heat <- no2_clean %>%
  group_by(site_code, site_type, dow, hour) %>%
  summarise(m = mean(value), .groups = "drop") %>%     
  group_by(site_type, dow, hour) %>%
  summarise(mean_no2 = mean(m), .groups = "drop")      

p_heat <- ggplot(heat, aes(hour, dow, fill = mean_no2)) +
  geom_tile() +
  scale_y_discrete(limits = rev) +
  scale_fill_viridis_c(option = "magma") +
  facet_wrap(~ site_type) +
  labs(
    title = "Mean NO\u2082 by Hour and Day of Week",
    x = "Hour of Day", y = NULL,
    fill = expression(mu*g/m^3)
  ) +
  theme_minimal()
ggsave("outputs/fig_heatmap.png", p_heat, width = 10, height = 4.5, dpi = 300)

# Plot 4: Distribution of Site-Year Means
site_year <- no2_clean %>%
  group_by(site_code, site_type, year) %>%
  summarise(m = mean(value), .groups = "drop")

p_dist <- ggplot(site_year, aes(site_type, m, fill = site_type)) +
  geom_boxplot(outlier.shape = NA, alpha = 0.5) +
  geom_jitter(width = 0.12, alpha = 0.5) +
  labs(
    title = "Site-Year Mean NO\u2082 by Site Type",
    x = NULL, y = expression(NO[2]~(mu*g/m^3))
  ) +
  theme_minimal() + theme(legend.position = "none")
ggsave("outputs/fig_distribution.png", p_dist, width = 6, height = 5, dpi = 300)

# Plot 5: Multi-Year Trend using Stable Sites (2019-2025 complete records)
stable_sites <- coverage %>% filter(capture >= CAPTURE_MIN) %>%
  count(site_code) %>% filter(n == 7) %>% pull(site_code)

trend <- site_year %>% filter(site_code %in% stable_sites) %>%
  group_by(site_type, year) %>%
  summarise(mean_no2 = mean(m), n_sites = n_distinct(site_code), .groups = "drop")

p_trend <- ggplot(trend, aes(year, mean_no2, colour = site_type)) +
  geom_line(linewidth = 1) + geom_point() +
  scale_x_continuous(breaks = 2019:2025) +
  labs(
    title = "NO\u2082 Trend at Sites with Complete Records (2019-2025)",
    x = "Year", y = expression(NO[2]~(mu*g/m^3)), colour = "Site type"
  ) +
  theme_minimal()
ggsave("outputs/fig_trend.png", p_trend, width = 8, height = 5, dpi = 300)

# Probability: chance that an hour exceeds THRESHOLD, worked out per site then averaged
prob_hour <- no2_clean %>%
  group_by(site_code, site_type, daytype, band) %>%
  summarise(p = mean(value > THRESHOLD), .groups = "drop") %>%
  group_by(site_type, daytype, band) %>%
  summarise(p_exceed = mean(p), n_sites = n(), .groups = "drop")

print(prob_hour, n = 20)
write_csv(prob_hour, "outputs/probability_exceed.csv")

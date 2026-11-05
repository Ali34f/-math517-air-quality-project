# load required libraries 
library(readr)
library(dplyr)
library(lubridate)
library(ggplot2)

# --- Data Loading & Cleaning  ---

# load data
sites <- read_csv("sites.csv")
measurements <- read_csv("measurements.csv") # Make sure measurements is loaded

# filter for NO2 between 2019-2025
no2_filtered <- measurements %>%
  filter(species == "NO2") %>%
  mutate(datetime = ymd_hms(datetime),
         year = year(datetime)) %>%
  filter(year >= 2019 & year <= 2025)

# join measurements with site info 
air_quality_joined <- no2_filtered %>%
  inner_join(sites, by = "site_code")

# extract time variables 
air_quality_time <- air_quality_joined %>%
  mutate(
    hour = hour(datetime),
    day_of_week = wday(datetime, label = TRUE, abbr = TRUE),
    year = as.factor(year)
  )

# --- Exploratory Visualisations ---

# plot 1: hourly trend plot  
hourly_summary <- air_quality_time %>%
  group_by(hour, site_type) %>%
  summarise(mean_no2 = mean(value, na.rm = TRUE), .groups = 'drop')

p1 <- ggplot(hourly_summary, aes(x = hour, y = mean_no2, color = site_type)) +
  geom_line(linewidth = 1.2) +
  geom_point() +
  labs(
    title = "Average NO2 Concentration by Hour of Day",
    subtitle = "Roadside vs. Urban Background Comparison",
    x = "Hour of Day (0 to 23)",
    y = "Mean NO2 Concentration",
    color = "Site Type"
  ) +
  theme_minimal()

print(p1)
ggsave("no2_hourly_trend.png", plot = p1, width = 8, height = 5, dpi = 300)


# plot 2: weekly trend plot 
weekly_summary <- air_quality_time %>%
  group_by(day_of_week, site_type) %>%
  summarise(mean_no2 = mean(value, na.rm = TRUE), .groups = 'drop')

p2 <- ggplot(weekly_summary, aes(x = day_of_week, y = mean_no2, color = site_type, group = site_type)) +
  geom_line(linewidth = 1.2) +
  geom_point() +
  labs(
    title = "Average NO2 Concentration by Day of the Week",
    subtitle = "Roadside vs. Urban Background Comparison",
    x = "Day of the Week",
    y = "Mean NO2 Concentration",
    color = "Site Type"
  ) +
  theme_minimal()

print(p2)
ggsave("no2_weekly_trend.png", plot = p2, width = 8, height = 5, dpi = 300)

# plot 3: distribution plot 
p3 <- ggplot(air_quality_time, aes(x = site_type, y = value, fill = site_type)) +
  geom_boxplot(outlier.alpha = 0.1) + 
  scale_y_log10() + 
  labs(
    title = "Distribution of NO2 Concentrations",
    subtitle = "Comparing Roadside vs. Urban Background Sites (Log Scale)",
    x = "Site Type",
    y = "NO2 Concentration (Log Scale)",
    fill = "Site Type"
  ) +
  theme_minimal() +
  theme(legend.position = "none")

print(p3)
ggsave("no2_distribution_boxplot.png", plot = p3, width = 8, height = 5, dpi = 300)









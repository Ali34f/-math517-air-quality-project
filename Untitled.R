# Load required libraries
library(readr)
library(dplyr)
library(lubridate)
library(ggplot2)

# load sites.csv file
sites <- read_csv("sites.csv")
head(sites)

# inspect the site types (Roadside vs Urban Background)
table(sites$site_type)

install.packages("lubridate")

# measurement filter for NO2 in 2023 
no2_2023 <- measurements %>%
  filter(species == "NO2") %>%
  mutate(datetime = ymd_hms(datetime),
         year = year(datetime)) %>%
  filter(year == 2023)

# join measurements with site info 
air_quality_joined <- no2_2023 %>%
  inner_join(sites, by = "site_code")

# check a summary the joined dataset
head(air_quality_joined)
table(air_quality_joined$site_type)

# extract time variables for trend analysis 
air_quality_time <- air_quality_joined %>%
  mutate(
    hour = hour(datetime),
    day_of_week = wday(datetime, label = TRUE, abbr = TRUE)
  )

# hourly means by site type 
hourly_summary <- air_quality_time %>%
  group_by(hour, site_type) %>%
  summarise(mean_no2 = mean(value, na.rm = TRUE), .groups = 'drop')

# hourly variation plot 
ggplot(hourly_summary, aes(x = hour, y = mean_no2, color = site_type)) +
  geom_line(linewidth = 1.2) +
  geom_point() +
  labs(
    title = "Average NO2 Concentration by Hour of Day (2023)",
    subtitle = "Roadside vs. Urban Background Comparison",
    x = "Hour of Day (0 to 23)",
    y = "Mean NO2 Concentration",
    color = "Site Type"
  ) +
  theme_minimal()
ggsave("no2_hourly_trend.png", width = 8, height = 5, dpi = 300)

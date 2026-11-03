LAQN coursework dataset

Source: London Air Quality Network (LAQN), Imperial College London / ERG.

Data period: 2019-01-01 to 2025-12-31 inclusive.
Temporal resolution: hourly.
Pollutants: NO2 and PM25.
Site types: Roadside and Urban Background.
Number of sites: 57.

Student files
-------------
measurements.csv.gz
    Hourly measurements for the selected LAQN sites and pollutants.

sites.csv
    Static information for the sites represented in measurements.csv.gz.
    This includes the site code, name, site type, borough and coordinates
    (where supplied by LAQN), together with site opening/closing dates
    where available.

README.txt
    This file.

Important
---------
- The measurement values and data-quality/status fields are retained from LAQN.
- No missing-value imputation has been applied.
- No values have been removed because they appear unusual.
- Timestamps are stored as UTC/GMT in the measurement file.
- The sites.csv file is the frozen site list for this coursework dataset.
- Students should document all filtering, exclusions, aggregation,
  transformations and other analytical decisions made after this point.

The student package contains only the files needed for the coursework.
Download logs and intermediate files used to create the package are retained
separately by the module team.

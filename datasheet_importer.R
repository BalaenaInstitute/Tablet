#This script imports xls/ csv field data output files collected during fieldwork 
# from fieldDataEntry matlab program into one table, formats GPS, 
# deduplicates records and renames variables
#Laura Feyrer 2024


#LIBRARIES------------
pacman::p_load(data.table, dplyr, readxl, purrr, readr, tidyr, stringr)

here::here()

# # # Read each file and write it to csv  
#function to translate xlsx to csv, need to specify sheet
csv_maker =function(f) {
  df = read_xlsx(f, sheet = sheet)
  write.csv(df, gsub("xlsx", "csv", f), row.names=FALSE) }

#function to move csvs to new folder in input based on sheet name
move.files <- function(x){
  file.rename( from = file.path(valid_path, x) ,
               to = file.path(paste(here::here(), "/input/",sheet, sep = ""), x) )
}    

#CETACEANS------------
original_path <- (here::here("input/originals"))
sheet = "Cetaceans"
year = 2022
Trip = "Arctic_Leg1"

#read in data files
files.to.read = list.files(original_path, pattern="xlsx", full.names = T)
#write csvs to same folder
lapply(files.to.read, csv_maker)

#Move csvs to new folder
files.csv= list.files(original_path, pattern="csv")
lapply(files.csv, move.files)

# Compile and clean variables from multiple csv data----

csv_path <- file.path(paste(here::here(), "/input/",sheet, sep = ""))

all_tables <- list.files(path = csv_path, pattern = "*.csv", full.names = T)
all_data <- all_tables%>%map(read_csv)%>%bind_rows()

summary(all_data)

# create a tibble for cleaned up validated data 
#note this will warn of NAs for observations without coordinates
all_data<-all_data  %>% # pipe - create a sequence of data cleaning operations 
  mutate(LatD = as.numeric(str_sub(all_data$StartPos,1,2)))%>%
  
  mutate(LatM = as.numeric(str_extract(all_data$StartPos,"(?<=d).+(?=N)"))/60)%>%
  mutate(Latitude = LatD+LatM)%>%
  mutate(LongD = as.numeric(str_extract(all_data$StartPos,"(?<=\\s).+(?=d)")))%>%
  mutate(LongM = as.numeric(str_extract(all_data$StartPos,"[\\d\\.]+(?=W)"))/60)%>%
  mutate(Longitude = (LongD+LongM)*-1)%>%
  mutate(Port_Star = PS)%>%  # change field name to something that is clear
  mutate(Species = ifelse(Species == "nbw", "Northern Bottlenose",
                          ifelse(Species == "northen bottlenose", "Northern Bottlenose",
                                 Species)))
#deduplicate
all_data = all_data[!duplicated(all_data$DateT), ]


#clean working variables out for writing output
Sharedata = all_data%>%
  dplyr::select(DateT, Species, Latitude, Longitude,Min, Best, Max, Dist, Bearing, Port_Star, Behaviour, 
                TimeEnd, Pic_no, Comments)


#write csv
write.csv(Sharedata, file = paste0("output/", sheet, Trip, year, ".csv"), row.names = FALSE)
write_rds(Sharedata, file = paste0("output/", sheet, Trip, year, ".rds"))



#ENVIRONMENT----------------
#uses csv_maker and move.files functions above

sheet = "Environment"
original_path <- (here::here("input/originals"))
year = 2022
Trip = "Arctic_Leg1"

#read in data files
files.to.read = list.files(original_path, pattern="xlsx", full.names = T)
#write csvs to same folder
lapply(files.to.read, csv_maker)

#Move csvs to new folder
files.csv= list.files(original_path, pattern="csv")
lapply(files.csv, move.files)

# Compile and clean variables from multiple csv data----

csv_path <- file.path(paste(here::here(), "/input/",sheet, sep = ""))

all_tables <- list.files(path = csv_path, pattern = "*.csv", full.names = T)
all_data <- all_tables%>%map(read_csv)%>%bind_rows()

summary(all_data)

# create a tibble for cleaned up validated Environment data 
###
all_data<-all_data  %>% # pipe - create a linear sequence of operations 
  mutate(LatD = as.numeric(str_sub(all_data$Pos,1,2)))%>%
  
  mutate(LatM = as.numeric(str_extract(all_data$Pos,"(?<=d).+(?=N)"))/60)%>%
  mutate(Latitude = LatD+LatM)%>%
  mutate(LongD = as.numeric(str_extract(all_data$Pos,"(?<=\\s).+(?=d)")))%>%
  mutate(LongM = as.numeric(str_extract(all_data$Pos,"[\\d\\.]+(?=W)"))/60)%>%
  mutate(Longitude = (LongD+LongM)*-1)

#deduplicate
all_data = all_data[!duplicated(all_data$DateT), ]

Sharedata = all_data%>%dplyr::select(-Pos, -LatD,-LatM, -LongD, - LongM,)

#write csv
write.csv(Sharedata, file = paste0("output/", sheet, Trip, year, ".csv"), row.names = FALSE)
write_rds(Sharedata, file = paste0("output/", sheet, Trip, year, ".rds"))
##########################################################################
# Jose Cajide - @jrcajide
# Master Data Science: Data wrangling with dplyr
##########################################################################

# Me instala los paquetes que no tengo. Los que sí no.

list.of.packages <- c("R.utils", "tidyverse", "doParallel", "foreach", "sqldf", "broom", "DBI", "ggplot2", "tidyr", "lubridate")
new.packages <- list.of.packages[!(list.of.packages %in% installed.packages()[,"Package"])]
if(length(new.packages)) install.packages(new.packages)


flights <- readr::read_csv('data/flights/2008.csv')

# Nombre de las columnas
names(flights)

head(flights)

# Dimensión
dim(flights)

summary(flights)  # Como un describe (nos da datos de la distribución y de NANs)

# DPLYR -------------------------------------------------------------------

# Identify the most important data manipulation tools needed for data analysis and make them easy to use in R.
# Provide blazing fast performance for in-memory data by writing key pieces of code in C++.
# Use the same code interface to work with data no matter where it’s stored, whether in a data frame, a data table or database.

# The 5 verbs of dplyr
# select – removes columns from a dataset
# filter – removes rows from a dataset
# arrange – reorders rows in a dataset
# mutate – uses the data to build new columns and values
# summarize – calculates summary statistics

library(dplyr)
library(tidyverse)
# SELECT() ----------------------------------------------------------------------------

flights[c('ActualElapsedTime','ArrDelay','DepDelay')] # base R

select(flights, ActualElapsedTime, ArrDelay, DepDelay)

# Funciones de ayuda para seleccionar

# starts_with(“X”): every name that starts with “X”
# ends_with(“X”): every name that ends with “X”
# contains(“X”): every name that contains “X”
# matches(“X”): every name that matches “X”, where “X” can be a regular expression
# num_range(“x”, 1:5): the variables named x01, x02, x03, x04 and x05
# one_of(x): every name that appears in x, which should be a character vector

select(flights, Origin:Cancelled)  # Cógeme todas las columnas entre esas dos
select(flights, -(DepTime:AirTime))  # Cógeme todas las columnas menos las que están entre esas dos
select(flights, UniqueCarrier, FlightNum, contains("Tail"), ends_with("Delay"))  # Ambas condiciones (or)

# MUTATE() ----------------------------------------------------------------------------

# Transforma el dataframe añadiendole nuevas columnas

foo <- mutate(flights, ActualGroundTime = ActualElapsedTime - AirTime)  # Creamos la columna ActualGroundTime
foo <- mutate(foo, GroundTime = TaxiIn + TaxiOut)
select(foo, ActualGroundTime, GroundTime)

# Podemos combinar varias operaciones a la vez (crear varios campos a la vez)

foo <- mutate(flights, 
              loss = ArrDelay - DepDelay, 
              loss_percent = (loss/DepDelay) * 100 )  # Incluso aquí puedo usar la variable que he creado justo antes

##########################################################################
# Exercise: 
# Mutate the data frame so that it includes a new variable that contains the average speed, 
#  avg_speed traveled by the plane for each flight (in mph). 
# Hint: Average speed can be calculated as distance divided by number of hours of travel, and note that AirTime is given in minutes
##########################################################################

foo2 <- mutate(flights,
               AirTime_Hours = AirTime / 60,
               Avg_Speed = Distance / AirTime)

# O más fácil

mutate(flights,
       Avg_Speed = Distance / (AirTime / 60))


# FILTER() --------------------------------------------------------------------------

# x < y, TRUE if x is less than y
# x <= y, TRUE if x is less than or equal to y
# x == y, TRUE if x equals y
# x != y, TRUE if x does not equal y
# x >= y, TRUE if x is greater than or equal to y
# x > y, TRUE if x is greater than y
# x %in% c(a, b, c), TRUE if x is in the vector c(a, b, c)

# Print out all flights in hflights that traveled 3000 or more miles
filter(flights, Distance > 3000)

# All flights flown by one of AA or UA
filter(flights, UniqueCarrier %in% c('AA', 'UA'))

# All flights where taxiing took longer than flying
# Taxi-Out Time: The time elapsed between departure from the origin airport gate and wheels off.
# Taxi-In Time: The time elapsed between wheels-on and gate arrival at the destination airport.
filter(flights, TaxiIn + TaxiOut > AirTime)  # No hace falta hacer el mutate

# Combining tests using boolean operators

# All flights that departed late but arrived ahead of schedule
filter(flights, DepDelay > 0 & ArrDelay < 0)

# All flights that were cancelled after being delayed
filter(flights, Cancelled == 1, DepDelay > 0)  # La coma es equivalente al &

?filter



##########################################################################
# Exercise: 
# How many weekend flights to JFK airport flew a distance of more than 1000 miles 
# but had a total taxiing time below 15 minutes?

# 1) Select the flights that had JFK as their destination and assign the result to jfk

jfk <- filter(flights, Dest == 'JFK')

# 2) Combine the Year, Month and DayofMonth variables to create a Date column

jfk <- mutate(jfk, Date = as.Date(paste(Year, Month, DayofMonth, sep = '-')))
class(jfk$Date)

# 3) Result:

jfk <- filter(jfk, DayOfWeek %in% c(6,7), Distance > 1000, TaxiIn + TaxiOut < 15)

nrow(jfk)
ncol(jfk)


# 4) Delete jfk object to free resources 

rm(jfk)

# Nota: para acceder a una columna:

jfk['Year']  # Esto es un dataframe. Si se lo meto a una función me petará

jfk$Year  # Esto es un vector


# ARRANGE() --------------------------------------------------------------------------

# Ordenar. Es un ORDER BY

# Cancelled
( cancelled <- select(flights, UniqueCarrier, Dest, Cancelled, CancellationCode, DepDelay, ArrDelay) )

( cancelled <- filter(cancelled, Cancelled == 1, !is.na(DepDelay)) )  # Cancelados y que no tengan nulos en DepDelay

# Arrange cancelled by departure delays
arrange(cancelled, DepDelay)  # Ordena cancelled por DepDelay

# Arrange cancelled so that cancellation reasons are grouped
arrange(cancelled, CancellationCode)

# Arrange cancelled according to carrier and departure delays
arrange(cancelled, UniqueCarrier, DepDelay)

# Arrange cancelled according to carrier and decreasing departure delays
arrange(cancelled, UniqueCarrier, desc(DepDelay))  # Descending

rm(cancelled)

# Arrange flights by total delay (normal order).
arrange(flights, DepDelay + ArrDelay)  # Podemos hacer operaciones dentro del arrange (como en el filter)

# Keep flights leaving to DFW and arrange according to decreasing AirTime 
arrange(filter(flights, Dest == 'JFK'), desc(AirTime))



# SUMMARISE() -----------------------------------------------------------------------

# No es lo mismo que un GROUP BY. Aplicar un summarise es que me va a dar una sola fila con la media, mediana, etc...
# Esto será útil cuando lo juntemos con un groupby para que me obtenga esas magnitudes para grupos.

# min(x) – minimum value of vector x.
# max(x) – maximum value of vector x.
# mean(x) – mean value of vector x.
# median(x) – median value of vector x.
# quantile(x, p) – pth quantile of vector x.
# sd(x) – standard deviation of vector x.
# var(x) – variance of vector x.
# IQR(x) – Inter Quartile Range (IQR) of vector x.

# Print out a summary with variables min_dist and max_dist
summarize(flights, min_dist = min(Distance), max_dist = max(Distance))

# Remove rows that have NA ArrDelay: temp1
na_array_delay <- filter(flights, !is.na(ArrDelay))

# Generate summary about ArrDelay column of temp1
summarise(na_array_delay, 
          earliest = min(ArrDelay), 
          average = mean(ArrDelay), 
          latest = max(ArrDelay), 
          sd = sd(ArrDelay))

df <- summarise(na_array_delay, 
                earliest = min(ArrDelay), 
                average = mean(ArrDelay), 
                latest = max(ArrDelay), 
                sd = sd(ArrDelay))

# Si hay NANs el summarize me va a dar error. Para eso, na.rm = True

df <- summarise(flights, 
                earliest = min(ArrDelay), 
                average = mean(ArrDelay), 
                latest = max(ArrDelay), 
                sd = sd(ArrDelay),
                na.rm = TRUE)

hist(na_array_delay$ArrDelay)

rm(na_array_delay)

# Keep rows that have no NA TaxiIn and no NA TaxiOut: temp2
taxi <- filter(flights, !is.na(TaxiIn), !is.na(TaxiOut))

##########################################################################
# Exercise: 
# Print the maximum taxiing difference of taxi with summarise()

summarise(taxi,
          max_difference = max(abs(TaxiIn - TaxiOut)))



# dplyr provides several helpful aggregate functions of its own, in addition to the ones that are already defined in R. These include:
# first(x) - The first element of vector x.
# last(x) - The last element of vector x.
# nth(x, n) - The nth element of vector x.
# n() - The number of rows in the data.frame or group of observations that summarise() describes.
# n_distinct(x) - The number of unique values in vector x.




# Filter flights to keep all American Airline flights: aa
aa <- filter(flights, UniqueCarrier == "AA")


##########################################################################
# Exercise: 
# Print out a summary of aa with the following variables:
# n_flights: the total number of flights,
# n_canc: the total number of cancelled flights,
# p_canc: the percentage of cancelled flights,
# avg_delay: the average arrival delay of flights whose delay is not NA.

summarise(aa,
          n_flights = n(),
          n_canc = sum(Cancelled),
          p_canc = sum(Cancelled)/n(),
          avg_delay = mean(ArrDelay, na.rm = TRUE))

# Más eficiente

summarise(aa,
          n_flights = n(),
          n_canc = sum(Cancelled),
          p_canc = n_canc / n_flights,
          avg_delay = mean(ArrDelay, na.rm = TRUE))




# Next to these dplyr-specific functions, you can also turn a logical test into an aggregating function with sum() or mean(). 
# A logical test returns a vector of TRUE’s and FALSE’s. When you apply sum() or mean() to such a vector, R coerces each TRUE to a 1 and each FALSE to a 0. 
# This allows you to find the total number or proportion of observations that passed the test, respectively

set.seed(1973)  # Esto es la semilla para el random
(foo <- sample(1:10, 5, replace=T))
foo > 5
sum(foo > 5) # num. elementos > 5
mean(foo)
mean(foo > 5)  # La media de elementos mayores que 5 (2/5 = 0.4)

##########################################################################
# Exercise: 
# Print out a summary of aa with the following variables:
# n_security: the total number of cancelled flights by security reasons,
# CancellationCode: reason for cancellation (A = carrier, B = weather, C = NAS, D = security)

summarise(aa,
          n_security = sum(CancellationCode == 'D', na.rm = TRUE) )

summar

# %>% OPERATOR ----------------------------------------------------------------------

# Piping

mean(c(1, 2, 3, NA), na.rm = TRUE)

# Vs

c(1, 2, 3, NA) %>% mean(na.rm = TRUE)  # El primer argumento de mean ya no lo tengo que meter, se lo paso con la tubería

# Para meter ese símbolo es %>% Ctrl+shift+M 

summarize(filter(mutate(flights, diff = TaxiOut - TaxiIn),!is.na(diff)), avg = mean(diff))

# Vs

flights %>%
  mutate(diff=(TaxiOut-TaxiIn)) %>%
  filter(!is.na(diff)) %>%
  summarise(avg=mean(diff))


flights %>%
  filter(Month == 5, DayofMonth == 17, UniqueCarrier %in% c('UA', 'WN', 'AA', 'DL')) %>%
  select(UniqueCarrier, DepDelay, AirTime, Distance) %>%
  arrange(UniqueCarrier) %>%
  mutate(air_time_hours = AirTime / 60)

##########################################################################
# Exercise: 
# Use summarise() to create a summary of flioght with a single variable, n, 
# that counts the number of overnight flights. These flights have an arrival 
# time that is earlier than their departure time. Only include flights that have 
# no NA values for both DepTime and ArrTime in your count.

flights %>% 
  mutate(diff_time = ArrTime - DepTime) %>% 
  filter(diff_time < 0, !is.na(ArrTime), !is.na(DepTime)) %>% 
  summarise(n_flights = n())


# GROUP_BY() -------------------------------------------------------------------------

# Agrupa en base a las variables del summarise

flights %>% 
  group_by(UniqueCarrier) %>% 
  summarise(n_flights = n(), 
            n_canc = sum(Cancelled), 
            p_canc = 100*n_canc/n_flights, 
            avg_delay = mean(ArrDelay, na.rm = TRUE)) %>% 
  arrange(avg_delay)


flights %>% 
  group_by(DayOfWeek) %>% 
  summarize(avg_taxi = mean(TaxiIn + TaxiOut, na.rm = TRUE)) %>% 
  arrange(desc(avg_taxi))


# Combine group_by with mutate
rank(c(21, 22, 24, 23))  # Te saca un ranking

flights %>% 
  filter(!is.na(ArrDelay)) %>%  # Quita retrasos
  group_by(UniqueCarrier) %>%  # Agrupa por compañia. EL groupby es lazy como en python
  summarise(p_delay = sum(ArrDelay >0)/n()) %>%  # Este n() es cada n de cada compañía
  mutate(rank = rank(p_delay)) %>% 
  arrange(rank) 

# A un groupby siempre le tengo que pasar un summarize con la función de agregación que yo quiera


##########################################################################
# Exercises: 
# 1) In a similar fashion, keep flights that are delayed (ArrDelay > 0 and not NA). 
# Next, create a by-carrier summary with a single variable: avg, the average delay 
# of the delayed flights. Again add a new variable rank to the summary according to 
# avg. Finally, arrange by this rank variable.

flights %>% 
  filter(ArrDelay > 0, !is.na(ArrDelay)) %>% 
  group_by(UniqueCarrier) %>% 
  summarise(avg = mean(DepDelay)) %>% 
  mutate(rank = rank(avg)) %>% 
  arrange(rank)

x <- flights %>% 
  filter(ArrDelay > 0, !is.na(ArrDelay)) %>% 
  group_by(UniqueCarrier) %>% 
  summarise(avg = mean(ArrDelay)) %>% 
  mutate(rank = rank(avg)) %>% 
  arrange(rank)


# 2) How many airplanes only flew to one destination from JFK? 
# The result contains only a single column named nplanes and a single row.

flights %>% 
  filter(Origin == 'JFK') %>% 
  group_by(TailNum) %>% 
  summarise(n_dest = n_distinct(Dest)) %>% 
  filter(n_dest == 1) %>% 
  summarise(n_planes = n())



# 3) Find the most visited destination for each carrier
# Your solution should contain four columns:
# UniqueCarrier and Dest, n, how often a carrier visited a particular destination,
# rank, how each destination ranks per carrier. rank should be 1 for every row, 
# as you want to find the most visited destination for each carrier.

flights %>% 
  group_by(UniqueCarrier, Dest) %>% 
  summarise(n = n()) %>% 
  mutate(rank = rank(desc(n))) %>% 
  filter(rank == 1)


# Other dplyr functions ---------------------------------------------------

# top_n()

flights %>% 
  group_by(UniqueCarrier) %>% 
  top_n(2, ArrDelay) %>%  # Me coge el top 2 de ArrDelay
  select(UniqueCarrier,Dest, ArrDelay) %>% 
  arrange(desc(UniqueCarrier))


# mutate_if(is.character, str_to_lower) -> si es de tipo char, la pone en minúscula
# mutate_at

flights %>% 
  mutate_if(is.character, str_to_lower)

foo <- flights %>% 
  head %>% 
  select(contains("Delay")) %>%   # Se queda con las columnas que contienen Delay
  mutate_at(vars(ends_with("Delay")), funs(./2))   
# le digo que sobre las variables que terminen en delay y le aplicas funs (divídelas entre dos)
# El . es un comodín.

foo

foo %>% 
  mutate_at(vars(ends_with("Delay")), funs(round)) 

rm(foo)


# Dealing with outliers ---------------------------------------------------

# Gestionaremos los outliers de la variable ActualElapsedTime.
# Vamos a ver cómo tratar outliers en una variable. En más de una lo veremos.

# ActualElapsedTime: Elapsed Time of Flight, in Minutes
summary(flights$ActualElapsedTime)

hist(flights$ActualElapsedTime)  # Vemos en el histograma que hay outliers

library(ggplot2)
ggplot(flights) + 
  geom_histogram(aes(x = ActualElapsedTime))

boxplot(flights$ActualElapsedTime,horizontal = TRUE)

# Esto nos devuelve una lista de outliers en base al criterio del boxplot
outliers <- boxplot.stats(flights$ActualElapsedTime)$out
length(outliers)
outliers

no_outliers <- flights %>% 
  filter(!ActualElapsedTime %in% outliers) 

boxplot(no_outliers$ActualElapsedTime,horizontal = TRUE)

mean(no_outliers$ActualElapsedTime, na.rm = T)
hist(no_outliers$ActualElapsedTime)

rm(outliers)
rm(no_outliers)


barplot(table(flights$UniqueCarrier))



# Missing values ----------------------------------------------------------

NA

flights %>% dim

# Removing all NA's from the whole dataset

# Si yo hago esto, se carga el dataset porque no hay ninguna fila que no tenga al menos un NA en
# alguna variable
flights %>% na.omit %>% dim  # Esto funciona bien cuando tenemos buenos datos

# Otra manera es hacer un filtro llamando a complete.cases (evalúa si un vector tiene todos los
# datos informados)
flights %>% filter(complete.cases(.)) %>% dim

# Tercera manera
library(tidyr) # for drop_na()
flights %>% drop_na() %>% dim

# Removing all NA's from a varible

flights %>% 
  drop_na(ends_with("Delay")) %>% 
  summary()

# Better aproaches

# Sustituir por cero
a <- flights %>% 
  #filter(is.na(DepTime)) %>%  # Cogemos todas las filas que tienen NAs
  mutate(DepTime = coalesce(DepTime, 0L))  # Esto me pone DepTime a 0 en los missings (lo del L es para que sea integer)

# Sustituir por el valor de otra columna en ese mismo registro
flights %>% 
  filter(is.na(DepTime)) %>% 
  mutate(DepTime = coalesce(DepTime, CRSDepTime))  #  Ponle el valor de otra columna

# Sustituir un valor raro por un NA
unique(flights$CancellationCode)
foo <- flights %>% 
  mutate(CancellationCode = na_if(CancellationCode, "A"))
unique(foo$CancellationCode)

# CancellationCode: reason for cancellation (A = carrier, B = weather, C = National Air System, D = security)

# La función recode me sustituye una variable en función de lo que yo le diga (recodifica)
foo <- flights %>% 
  mutate(CancellationCode = recode(CancellationCode, "A"="Carrier", "B"="Weather", "C"="National Air System", 
                                   .missing="Not available", 
                                   .default="Others" ))
rm(foo)
foo


# Tidy Data ---------------------------------------------------------------

# Transformaciones, tablas dinámicas (pivot tables)..
# En R este concepto se llama Tidy Data: normalmente en cada columna tenemos una variable y 
# en las filas tenemos observaciones. Esto se dice que está en formato largo.
# Cuando está "traspuesta", se dice que está en formato ancho.

# Es importante controlar esto de pivotar, transponer tablas ya que a la hora de visualizar
# es importante que los datos estén como tienen que estar.

library(tidyr)

# Wide Vs Long 

# spread: me coge un conjunto de datos en formato largo y me lo pone en formato ancho
# gather: lo contrario: de ancho a largo

flights %>% 
  group_by(Origin, Dest) %>% 
  summarise(n = n()) %>% 
  arrange(-n) %>%   # Ordena descendentemente
  spread(Origin, n) %>%  # Me crea una columna con cada origen
  gather("Origin", "n", 2:ncol(.)) %>%  # Créame una columna Origin y otra n con las columnas que hay desde la posición 2 hasta el final
  arrange(-n) 


##########################################################################
# Run the follow statements step by step and trying to understand what they do

flights %>% 
  group_by(UniqueCarrier, Dest) %>% 
  summarise(n = n()) %>%
  ungroup() %>% 
  group_by(Dest) %>% 
  mutate(total= sum(n), pct=n/total, pct= round(pct,4)) %>% 
  ungroup() %>% 
  select(UniqueCarrier, Dest, pct) %>% 
  spread(UniqueCarrier, pct) %>% 
  replace(is.na(.), 0) %>% 
  mutate(total = rowSums(select(., -1)))

# unite()
# separate()

# Muy útiles para trabajar con textos

##########################################################################
# Run the follow statements step by step and trying to understand what they do

flights %>% 
  head(20) %>% 
  unite("code", UniqueCarrier, TailNum, sep = "-") %>%  # Esto es igual que un paste, solo que el paste he de meterlo en un mutate. El equivalente de paste en tuberías es el unite
  select(code) %>% 
  separate(code, c("code1", "code2")) %>%  # Me lo separa
  separate(code2, c("code3", "code4"), -3)  




# Dplyr: Joins ------------------------------------------------------------

# inner_join(x, y)  SELECT * FROM x INNER JOIN y USING (z)
# left_join(x, y) SELECT * FROM x LEFT OUTER JOIN y USING (z)
# right_join(x, y, by = "z") SELECT * FROM x RIGHT OUTER JOIN y USING (z)
# full_join(x, y, by = "z") SELECT * FROM x FULL OUTER JOIN y USING (z)

# semi_join(x, y)
# anti_join(x, y)


airlines <- readr::read_csv('data/airlines.csv')
airlines

airports <- readr::read_csv('data/airports.csv')
airports

# Before joing dataframes, check for unique keys (mirar duplicados)
airports %>% 
  count(iata) %>% 
  filter(n > 1)
# Nos devuelve 0 -> OK


flights2 <- flights %>% 
  select(Origin, Dest, TailNum, UniqueCarrier, DepDelay)

# Top delayed flight by airline
f3 <- flights2 %>% 
  group_by(UniqueCarrier) %>%
  top_n(1, DepDelay) %>% 
  left_join(airlines, by = c("UniqueCarrier" = "Code"))


##########################################################################
# Exercises:
# Join flights2 with airports dataset

flights2 %>% 
  left_join(airports, by = c("Dest" = "iata"))

# Dates with lubridate ----------------------------------------------------

# Base R

as.POSIXct("2013-09-06", format="%Y-%m-%d")
as.POSIXct("2013-09-06 12:30", format="%Y-%m-%d %H:%M")


flights %>% 
  head %>%
  select(Year:DayofMonth,DepTime,ArrTime) %>% 
  separate(DepTime, into = c("Hour", "Minute"), sep = -3, remove = F)

flights %>% 
  head %>%
  select(Year:DayofMonth,DepTime,ArrTime) %>% 
  separate(DepTime, into = c("Hour", "Minute"), sep = -3) %>% 
  mutate(Date = as.Date(paste(Year, Month, DayofMonth, sep = "-")),
         HourMinute = (paste(Hour, Minute, sep = ":")),
         Departure = as.POSIXct(paste(Date, HourMinute), format="%Y-%m-%d %H:%M"))

# Easier with lubridate
library(lubridate)
today()
now()


(datetime <- ymd_hms(now(), tz = "UTC"))
(datetime <- ymd_hms(now(), tz = 'Europe/Madrid'))

Sys.getlocale("LC_TIME")
Sys.getlocale(category = "LC_ALL")

# Available locales: Run this in your shell: locale -a
(datetime <- ymd_hms(now(), tz = 'Europe/Madrid', locale = Sys.getlocale("LC_TIME")))
month(datetime, label = TRUE, locale = 'fi_FI.ISO8859-15')
wday(datetime, label = TRUE, abbr = FALSE, locale = 'fi_FI.ISO8859-15')

year(datetime)
month(datetime)
mday(datetime)

ymd_hm("2013-09-06 12:3")
ymd_hm("2013-09-06 12:03")

# Esto genera un error
flights %>% 
  head %>%
  select(Year:DayofMonth,DepTime,ArrTime) %>% 
  separate(DepTime, into = c("Hour", "Minute"), sep = -3) %>% 
  mutate(dep = make_datetime(Year, Month, DayofMonth, Hour, Minute))

flights %>% 
  head %>%
  select(Year:DayofMonth,DepTime,ArrTime) %>% 
  separate(DepTime, into = c("Hour", "Minute"), sep = -3) %>% 
  mutate_if(is.character, as.integer) %>% 
  mutate(dep_date = make_datetime(Year, Month, DayofMonth) ,
         dep_datetime = make_datetime(Year, Month, DayofMonth, Hour, Minute))

# Let’s do the same thing for each of the four time columns in flights. 
# The times are represented in a slightly odd format, so we use modulus arithmetic to pull out the hour and minute components

# ?Arithmetic
# %/% := integer division
# %% := modulus

departure_times <- flights %>% 
  head(2) %>% 
  select(DepTime) %>% 
  pull()

# Supongamos la hora: 1232
departure_times %/% 100
departure_times %% 100

make_datetime_100 <- function(year, month, day, time) {
  make_datetime(year, month, day, time %/% 100, time %% 100)
}

flights %>% select(TaxiIn, TaxiOut)

flights_dt <- flights %>%  
  filter(!is.na(DepTime), !is.na(ArrTime), !is.na(CRSDepTime), !is.na(CRSArrTime)) %>% 
  mutate(
    dep_time = make_datetime_100(Year, Month, DayofMonth, DepTime),
    arr_time = make_datetime_100(Year, Month, DayofMonth, ArrTime),
    sched_dep_time = make_datetime_100(Year, Month, DayofMonth, CRSDepTime),
    sched_arr_time = make_datetime_100(Year, Month, DayofMonth, CRSArrTime)
  ) %>% 
  select(Origin, Dest, ends_with("_time"))

# distribution of departure times across the year
flights_dt %>% 
  ggplot(aes(dep_time)) + 
  geom_freqpoly(binwidth = 86400)

# wday()
flights_dt %>% 
  mutate(wday = wday(dep_time, label = TRUE)) %>% 
  ggplot(aes(x = wday)) +
  geom_bar()


# Time periods functions
minutes(10)
days(7)
months(1:6)
weeks(3)

datetime
datetime + days(1)

# Datos incoherentes

flights_dt %>% 
  filter(arr_time < dep_time) %>% 
  select(Origin:arr_time)


flights_dt <- flights_dt %>% 
  mutate(
    overnight = arr_time < dep_time,
    arr_time_ok = arr_time + days(overnight * 1),
    sched_arr_time_ok = sched_arr_time + days(overnight * 1)
  )

# Check
flights_dt %>% 
  filter(overnight == T)

# Time Zones
ymd_hms("2007-01-01 12:32:00")
str(flights_dt$dep_time)

pb.txt <- "2007-01-01 12:32:00"
# Greenwich Mean Time (GMT)
(pb.date <- as.POSIXct(pb.txt, tz="Europe/London"))
# Pacific Time (PT)
format(pb.date, tz="America/Los_Angeles",usetz=TRUE)
# Con lubridate
with_tz(pb.date, tz="America/Los_Angeles")
# Coordinated Universal Time (UTC)
with_tz(pb.date, tz="UTC") 


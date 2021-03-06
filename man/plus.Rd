% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/plus.R
\docType{methods}
\name{+}
\alias{+}
\alias{+,leaflet,ANY-method}
\alias{+,mapview,ANY-method}
\alias{+,mapview,mapview-method}
\title{Add a layer to a mapview or leaflet map}
\usage{
\S4method{+}{mapview,ANY}(e1, e2)

\S4method{+}{leaflet,ANY}(e1, e2)
}
\arguments{
\item{e1}{the map to which the layer should be added}

\item{e2}{(spatial) object to be added}
}
\description{
Add a layer to a mapview or leaflet map
}
\examples{
\dontrun{
### raster data ###
library(sp)
library(raster)

m1 <- mapView(poppendorf[[5]])

### point vector data ###
m2 <- mapView(breweries91)

### add two mapview objects
m1 + m2 # final zoom level based on m2
'+'(m2, m1) # final zoom level based on m1
}

}


if ( !isGeneric('mapView') ) {
  setGeneric('mapView', function(x, ...)
    standardGeneric('mapView'))
}

#' view spatial objects interactively
#'
#' @description
#' this function produces an interactive GIS-like view of the specified
#' spatial object(s) on top of the specified base maps.
#'
#' @param x a \code{\link{raster}}* object
#' @param map an optional existing map to be updated/added to
#' @param maxpixels integer > 0. Maximum number of cells to use for the plot.
#' If maxpixels < \code{ncell(x)}, sampleRegular is used before plotting.
#' @param color color (palette) of the points/polygons/lines/pixels
#' @param na.color color for missing values
#' @param use.layer.names should layer names of the Raster* object be used?
#' @param values a vector of values for the visualisation of the layers.
#' Per default these are calculated based on the supplied raster* object.
#' @param map.types character spcifications for the base maps.
#' see \url{http://leaflet-extras.github.io/leaflet-providers/preview/}
#' for available options.
#' @param layer.opacity opacity of the layers
#' @param legend should a legend be plotted
#' @param legend.opacity opacity of the legend
#' @param trim should the raster be trimmed in case there are NAs on the egdes
#' @param verbose should some details be printed during the process
#' @param ... additional arguments passed on to repective functions.
#' See \code{\link{addRasterImage}}, \code{\link{addCircles}},
#' \code{\link{addPolygons}}, \code{\link{addPolylines}} for details
#'
#' @author
#' Tim Appelhans
#'
#' @examples
#' \dontrun{
#' mapView()
#'
#' ### raster data ###
#' library(sp)
#' library(raster)
#'
#' data(meuse.grid)
#' coordinates(meuse.grid) = ~x+y
#' proj4string(meuse.grid) <- CRS("+init=epsg:28992")
#' gridded(meuse.grid) = TRUE
#' meuse_rst <- stack(meuse.grid)
#'
#' m1 <- mapView(meuse_rst)
#' m1
#'
#' # factorial RasterLayer
#' m2 <- mapView(raster::as.factor(meuse_rst[[4]]))
#' m2
#'
#'
#'
#' ### point vector data ###
#' ## SpatialPointsDataFrame ##
#' data(meuse)
#' coordinates(meuse) <- ~x+y
#' proj4string(meuse) <- CRS("+init=epsg:28992")
#'
#' # all layers of meuse
#' mapView(meuse, burst = TRUE)
#'
#' # only one layer, all info in popups
#' mapView(meuse, burst = FALSE)
#'
#' ## SpatialPoints ##
#' meuse_pts <- as(meuse, "SpatialPoints")
#' mapView(meuse_pts)
#'
#'
#'
#' ### overlay vector on top of raster ###
#' m3 <- mapView(meuse, map = slot(m2, "map"))
#' m3
#'
#' m4 <- mapView(meuse, map = slot(m2, "map"), burst = TRUE)
#' m4 # is the same as
#' m5 <- addMapLayer(meuse, slot(m2, "map"), burst = TRUE)
#' m5
#'
#'
#'
#' ### polygon vector data ###
#' data("DEU_admin2")
#' m <- mapView(DEU_admin2, burst = FALSE)
#' m
#'
#' ## points on polygons ##
#' centres <- data.frame(coordinates(DEU_admin2))
#' names(centres) <- c("x", "y")
#' coordinates(centres) <- ~ x + y
#' projection(centres) <- projection(DEU_admin2)
#' addMapLayer(centres, map = slot(m, "map"))
#'
#'
#'
#' ### lines vector data
#' data("atlStorms2005")
#' mapView(atlStorms2005, burst = FALSE)
#' mapView(atlStorms2005, burst = TRUE)
#' }
#'
#' @export mapView
#' @name mapView
#' @rdname mapView
#' @aliases mapView
NULL

## RasterLayer ============================================================
#' @describeIn mapView \code{\link{raster}}
setMethod('mapView', signature(x = 'RasterLayer'),
          function(x,
                   map = NULL,
                   maxpixels = 500000,
                   color = mapViewPalette(7),
                   na.color = "transparent",
                   use.layer.names = TRUE,
                   values = NULL,
                   map.types = c("OpenStreetMap",
                                 "Esri.WorldImagery"),
                   layer.opacity = 0.8,
                   legend = TRUE,
                   legend.opacity = 1,
                   trim = TRUE,
                   verbose = FALSE,
                   ...) {

            pkgs <- c("leaflet", "raster", "magrittr")
            tst <- sapply(pkgs, "requireNamespace",
                          quietly = TRUE, USE.NAMES = FALSE)

            is.fact <- raster::is.factor(x)

            x <- rasterCheckAdjustProjection(x, maxpixels = maxpixels)

            m <- initMap(map, map.types, proj4string(x))

            if (trim) x <- trim(x)

            if (is.fact) x <- raster::as.factor(x)

            if (is.null(values)) {
              if (is.fact) {
                values <- x@data@attributes[[1]]$ID
              } else {
                offset <- diff(range(x[], na.rm = TRUE)) * 0.05
                top <- max(x[], na.rm = TRUE) + offset
                bot <- min(x[], na.rm = TRUE) - offset
                values <- seq(bot, top, length.out = 10)
                values <- round(values, 5)
              }
            } else {
              values <- round(values, 5)
            }

            if (is.fact) {
              pal <- leaflet::colorFactor(color,
                                          domain = NULL,
                                          na.color = na.color)
            } else {
              pal <- leaflet::colorNumeric(color,
                                           domain = values,
                                           na.color = na.color)
            }

            if (use.layer.names) {
              grp <- names(x)
            } else {
              grp <- layerName()
            }

            ## add layers to base map
            m <- leaflet::addRasterImage(map = m,
                                         x = x,
                                         colors = pal,
                                         project = FALSE,
                                         opacity = layer.opacity,
                                         group = grp,
                                         ...)

            if (legend) {
              ## add legend
              m <- leaflet::addLegend(map = m,
                                      pal = pal,
                                      opacity = legend.opacity,
                                      values = values,
                                      title = grp)
            }

            m <- mapViewLayersControl(map = m,
                                      map.types = map.types,
                                      names = grp)

            out <- new('mapview', object = x, map = m)

            return(out)

          }

)

## Raster Stack ===========================================================
#' @describeIn mapView \code{\link{stack}}

setMethod('mapView', signature(x = 'RasterStack'),
          function(x,
                   map = NULL,
                   maxpixels = 500000,
                   color = mapViewPalette(7),
                   na.color = "transparent",
                   values = NULL,
                   map.types = c("OpenStreetMap",
                                 "Esri.WorldImagery"),
                   layer.opacity = 0.8,
                   legend = TRUE,
                   legend.opacity = 1,
                   trim = TRUE,
                   verbose = FALSE,
                   ...) {

            pkgs <- c("leaflet", "raster", "magrittr")
            tst <- sapply(pkgs, "requireNamespace",
                          quietly = TRUE, USE.NAMES = FALSE)

            m <- initMap(map, map.types, proj4string(x))

            if (nlayers(x) == 1) {
              x <- raster(x, layer = 1)
              m <- mapView(x, map = m, map.types = map.types, ...)
              out <- new('mapview', object = x, map = m@map)
            } else {
              m <- mapView(x[[1]], map = m, map.types = map.types, ...)
              for (i in 2:nlayers(x)) {
                m <- mapView(x[[i]], map = m@map, map.types = map.types, ...)
              }

              if (length(getLayerNamesFromMap(m@map)) > 1) {
                m <- leaflet::hideGroup(map = m@map,
                                        group = layers2bHidden(m@map))
              }
              out <- new('mapview', object = x, map = m)
            }

            return(out)

          }

)


## Raster Brick ===========================================================
#' @describeIn mapView \code{\link{brick}}

setMethod('mapView', signature(x = 'RasterBrick'),
          function(x,
                   map = NULL,
                   maxpixels = 500000,
                   color = mapViewPalette(7),
                   na.color = "transparent",
                   values = NULL,
                   map.types = c("OpenStreetMap",
                                 "Esri.WorldImagery"),
                   layer.opacity = 0.8,
                   legend = TRUE,
                   legend.opacity = 1,
                   trim = TRUE,
                   verbose = FALSE,
                   ...) {

            pkgs <- c("leaflet", "raster", "magrittr")
            tst <- sapply(pkgs, "requireNamespace",
                          quietly = TRUE, USE.NAMES = FALSE)

            m <- initMap(map, map.types, proj4string(x))

            if (nlayers(x) == 1) {
              m <- mapView(x[[1]], map = m, map.types = map.types, ...)
            } else {
              m <- mapView(x[[1]], map = m, map.types = map.types, ...)
              for (i in 2:nlayers(x)) {
                m <- mapView(x[[i]], map = m@map, map.types = map.types, ...)
              }

              if (length(getLayerNamesFromMap(m@map)) > 1) {
                m <- leaflet::hideGroup(map = m@map,
                                        group = layers2bHidden(m@map))
              }

            }

            out <- new('mapview', object = x, map = m)

            return(out)

          }

)



## Satellite object =======================================================
#' @describeIn mapView \code{\link{satellite}}

setMethod('mapView', signature(x = 'Satellite'),
          function(x,
                   ...) {

            pkgs <- c("leaflet", "satellite", "magrittr")
            tst <- sapply(pkgs, "requireNamespace",
                          quietly = TRUE, USE.NAMES = FALSE)

            lyrs <- x@layers

            m <- mapView(lyrs[[1]], ...)

            if (length(lyrs) > 1) {
              for (i in 2:length(lyrs)) {
                m <- mapView(lyrs[[i]], m, ...)
              }
            }

            if (length(getLayerNamesFromMap(m)) > 1) {
              m <- leaflet::hideGroup(map = m, group = layers2bHidden(m))
            }

            out <- new('mapview', object = x, map = m)

            return(out)

          }

)


## SpatialPixelsDataFrame =================================================
#' @describeIn mapView \code{\link{SpatialPixelsDataFrame}}
#'
setMethod('mapView', signature(x = 'SpatialPixelsDataFrame'),
          function(x,
                   zcol = NULL,
                   ...) {

            pkgs <- c("leaflet", "sp", "magrittr")
            tst <- sapply(pkgs, "requireNamespace",
                          quietly = TRUE, USE.NAMES = FALSE)

            if(!is.null(zcol)) x <- x[, zcol]

            stck <- do.call("stack", lapply(seq(ncol(x)), function(i) {
              r <- raster::raster(x[, i])
              if (is.factor(x[, i])) r <- raster::as.factor(r)
              return(r)
            }))

            m <- mapView(stck, ...)

            out <- new('mapview', object = x, map = m@map)

            return(out)

          }

)


## SpatialPointsDataFrame =================================================
#' @describeIn mapView \code{\link{SpatialPointsDataFrame}}
#' @param burst whether to show all (TRUE) or only one (FALSE) layers
#' @param zcol attribute name(s) or column number(s) in attribute table
#' of the column(s) to be rendered
#' @param radius attribute name(s) or column number(s) in attribute table
#' of the column(s) to be used for defining the size of circles

setMethod('mapView', signature(x = 'SpatialPointsDataFrame'),
          function(x,
                   zcol = NULL,
                   map = NULL,
                   burst = FALSE,
                   color = mapViewPalette(7),
                   na.color = "transparent",
                   radius = 10,
                   map.types = c("OpenStreetMap",
                                 "Esri.WorldImagery"),
                   layer.opacity = 0.8,
                   legend = TRUE,
                   legend.opacity = 1,
                   verbose = FALSE,
                   ...) {

            pkgs <- c("leaflet", "sp", "magrittr")
            tst <- sapply(pkgs, "requireNamespace",
                          quietly = TRUE, USE.NAMES = FALSE)

            rad_vals <- circleRadius(x, radius)
            if(!is.null(zcol)) x <- x[, zcol]
            if(!is.null(zcol)) burst <- TRUE

            x <- spCheckAdjustProjection(x, verbose)
            if (is.na(proj4string(x))) {
              slot(x, "coords") <- scaleCoordinates(coordinates(x)[, 1],
                                                    coordinates(x)[, 2])
            }

            m <- initMap(map, map.types, proj4string(x))

            if (burst) {
              lst <- lapply(names(x), function(j) x[j])

              vals <- lapply(seq(lst), function(i) lst[[i]]@data[, 1])

              pal_n <- lapply(seq(lst), function(i) {
                if (is.factor(lst[[i]]@data[, 1])) {
                  leaflet::colorFactor(color, lst[[i]]@data[, 1],
                                       levels = levels(lst[[i]]@data[, 1]))
                } else {
                  leaflet::colorNumeric(color, vals[[i]],
                                        na.color = na.color)
                }
              })

              for (i in seq(lst)) {
                pop <- paste(names(lst[[i]]),
                             as.character(vals[[i]]),
                             sep = ": ")

                txt_x <- paste0("x: ", round(coordinates(lst[[i]])[, 1], 2))
                txt_y <- paste0("y: ", round(coordinates(lst[[i]])[, 2], 2))

                txt <- sapply(seq(pop), function(j) {
                  paste(pop[j], txt_x[j], txt_y[j], sep = "<br/>")
                })

                m <- leaflet::addCircleMarkers(m, lng = coordinates(lst[[i]])[, 1],
                                               lat = coordinates(lst[[i]])[, 2],
                                               group = names(lst[[i]]),
                                               color = pal_n[[i]](vals[[i]]),
                                               popup = txt,
                                               data = x,
                                               radius = rad_vals,
                                               ...)

                m <- leaflet::addLegend(map = m, position = "topright",
                                        pal = pal_n[[i]],
                                        opacity = 1, values = vals[[i]],
                                        title = names(lst[[i]]),
                                        layerId = names(lst[[i]]))

                m <- mapViewLayersControl(map = m,
                                          map.types = map.types,
                                          names = names(lst[[i]]))

              }

              if (length(getLayerNamesFromMap(m)) > 1) {
                m <- leaflet::hideGroup(map = m, group = layers2bHidden(m))
              }

            } else {

              df <- as.data.frame(sapply(x@data, as.character),
                                  stringsAsFactors = FALSE)

              nms <- names(df)
              grp <- layerName()

              txt_x <- paste0("x: ", round(coordinates(x)[, 1], 2))
              txt_y <- paste0("y: ", round(coordinates(x)[, 2], 2))

              txt <- rbind(sapply(seq(nrow(x@data)), function(i) {
                paste(nms, df[i, ], sep = ": ")
              }), txt_x, txt_y)

              txt <- sapply(seq(ncol(txt)), function(j) {
                paste(txt[, j], collapse = " <br/> ")
              })

              m <- leaflet::addCircleMarkers(map = m,
                                             lng = coordinates(x)[, 1],
                                             lat = coordinates(x)[, 2],
                                             group = grp,
                                             color = color[length(color)],
                                             popup = txt,
                                             data = x,
                                             if(!is.null(radius)) {
                                               radius = ~rad_vals
                                             } else radius = 10,
                                             ...)

              m <- mapViewLayersControl(map = m,
                                        map.types = map.types,
                                        names = grp)
            }

            out <- new('mapview', object = x, map = m)

            return(out)

          }

)



## SpatialPoints ==========================================================
#' @describeIn mapView \code{\link{SpatialPoints}}

setMethod('mapView', signature(x = 'SpatialPoints'),
          function(x,
                   map = NULL,
                   na.color = "transparent",
                   map.types = c("OpenStreetMap",
                                 "Esri.WorldImagery"),
                   layer.opacity = 0.8,
                   verbose = FALSE,
                   ...) {

            pkgs <- c("leaflet", "sp", "magrittr")
            tst <- sapply(pkgs, "requireNamespace",
                          quietly = TRUE, USE.NAMES = FALSE)

            x <- spCheckAdjustProjection(x, verbose)

            m <- initMap(map, map.types, proj4string(x))

            txt_x <- paste0("x: ", round(coordinates(x)[, 1], 2))
            txt_y <- paste0("y: ", round(coordinates(x)[, 2], 2))

            txt <- sapply(seq(txt_x), function(j) {
              paste(txt_x[j], txt_y[j], sep = "<br/>")
            })

            grp <- layerName()

            m <- leaflet::addCircleMarkers(m, lng = coordinates(x)[, 1],
                                           lat = coordinates(x)[, 2],
                                           group = grp,
                                           popup = txt,
                                           ...)

            m <- mapViewLayersControl(map = m,
                                      map.types = map.types,
                                      names = grp)

            out <- new('mapview', object = x, map = m)

            return(out)

          }
)




## SpatialPolygonsDataFrame ===============================================
#' @describeIn mapView \code{\link{SpatialPolygonsDataFrame}}
#' @param weight line width (see \code{\link{leaflet}} for details)

setMethod('mapView', signature(x = 'SpatialPolygonsDataFrame'),
          function(x,
                   zcol = NULL,
                   map = NULL,
                   burst = FALSE,
                   color = mapViewPalette(7),
                   na.color = "transparent",
                   values = NULL,
                   map.types = c("OpenStreetMap",
                                 "Esri.WorldImagery"),
                   layer.opacity = 0.8,
                   legend = TRUE,
                   legend.opacity = 1,
                   weight = 2,
                   verbose = FALSE,
                   ...) {

            pkgs <- c("leaflet", "sp", "magrittr")
            tst <- sapply(pkgs, "requireNamespace",
                          quietly = TRUE, USE.NAMES = FALSE)

            if(!is.null(zcol)) x <- x[, zcol]
            if(!is.null(zcol)) burst <- TRUE

            x <- spCheckAdjustProjection(x, verbose)

            m <- initMap(map, map.types, proj4string(x))

            coord_lst <- lapply(slot(x, "polygons"), function(x) {
              lapply(slot(x, "Polygons"), function(y) slot(y, "coords"))
            })

            if (burst) {

              lst <- lapply(names(x), function(j) x[j])

              df_all <- lapply(seq(lst), function(i) {
                dat <- data.frame(lst[[i]], stringsAsFactors = TRUE)
                if (is.character(dat[, 1])) {
                  dat[, 1] <- factor(dat[, 1], levels = unique(dat[, 1]))
                }
                return(dat)
              })

              vals <- lapply(seq(lst), function(i) df_all[[i]][, 1])

              pal_n <- lapply(seq(lst), function(i) {
                if (is.factor(df_all[[i]][, 1])) {
                  leaflet::colorFactor(color, vals[[i]],
                                       levels = levels(vals[[i]]),
                                       na.color = na.color)
                } else {
                  leaflet::colorNumeric(color, vals[[i]],
                                        na.color = na.color)
                }
              })

              for (i in seq(lst)) {

                x <- lst[[i]]

                df <- as.data.frame(sapply(x@data, as.character),
                                    stringsAsFactors = FALSE)

                nms <- names(df)
                grp <- nms

                txt <- sapply(seq(nrow(x@data)), function(i) {
                  paste(nms, df[i, ], sep = ": ")
                })

                len <- length(m$x$calls)

                for (j in seq(coord_lst)) {
                  for (h in seq(coord_lst[[j]])) {
                    if (is.na(proj4string(x))) {
                      x <- scalePolygonsCoordinates(x)
                    }
                    x_coord <- coordinates(x@polygons[[j]]@Polygons[[h]])[, 1]
                    y_coord <- coordinates(x@polygons[[j]]@Polygons[[h]])[, 2]
                    clrs <- pal_n[[i]](vals[[i]])
                    m <- leaflet::addPolygons(m,
                                              lng = x_coord,
                                              lat = y_coord,
                                              weight = weight,
                                              group = grp,
                                              color = clrs[j],
                                              popup = txt[j],
                                              ...)
                  }
                }

                m <- leaflet::addLegend(map = m, position = "topright",
                                        pal = pal_n[[i]], opacity = 1,
                                        values = vals[[i]],
                                        title = grp)

                m <- mapViewLayersControl(map = m,
                                          map.types = map.types,
                                          names = grp)

              }

              if (length(getLayerNamesFromMap(m)) > 1) {
                m <- leaflet::hideGroup(map = m, group = layers2bHidden(m))
              }

            } else {

              df <- as.data.frame(sapply(x@data, as.character),
                                  stringsAsFactors = FALSE)

              nms <- names(df)

              grp <- layerName()

              txt <- as.matrix(sapply(seq(nrow(x@data)), function(i) {
                paste(nms, df[i, ], sep = ": ")
              }))

              if (length(zcol) == 1) txt <- t(txt)

              txt <- sapply(seq(ncol(txt)), function(j) {
                paste(txt[, j], collapse = " <br> ")
              })

              len <- length(m$x$calls)

              for (j in seq(coord_lst)) {
                for (h in seq(coord_lst[[j]])) {
                  if (is.na(proj4string(x))) {
                    x <- scalePolygonsCoordinates(x)
                  }
                  x_coord <- coordinates(x@polygons[[j]]@Polygons[[h]])[, 1]
                  y_coord <- coordinates(x@polygons[[j]]@Polygons[[h]])[, 2]
                  m <- leaflet::addPolygons(m,
                                            lng = x_coord,
                                            lat = y_coord,
                                            weight = weight,
                                            group = grp,
                                            color = color[length(color)],
                                            popup = txt[j],
                                            ...)
                }
              }

              m <- mapViewLayersControl(map = m,
                                        map.types = map.types,
                                        names = grp)
            }

            out <- new('mapview', object = x, map = m)

            return(out)

          }

)



## SpatialPolygons ========================================================
#' @describeIn mapView \code{\link{SpatialPolygons}}

setMethod('mapView', signature(x = 'SpatialPolygons'),
          function(x,
                   map = NULL,
                   na.color = "transparent",
                   map.types = c("OpenStreetMap",
                                 "Esri.WorldImagery"),
                   layer.opacity = 0.8,
                   weight = 2,
                   verbose = FALSE,
                   ...) {

            pkgs <- c("leaflet", "sp", "magrittr")
            tst <- sapply(pkgs, "requireNamespace",
                          quietly = TRUE, USE.NAMES = FALSE)

            x <- spCheckAdjustProjection(x, verbose)

            m <- initMap(map, map.types, proj4string(x))

            grp <- layerName()

            coord_lst <- lapply(slot(x, "polygons"), function(x) {
              lapply(slot(x, "Polygons"), function(y) slot(y, "coords"))
            })

            for (j in seq(coord_lst)) {
              for (h in seq(coord_lst[[j]])) {
                x_coord <- coordinates(x@polygons[[j]]@Polygons[[h]])[, 1]
                y_coord <- coordinates(x@polygons[[j]]@Polygons[[h]])[, 2]
                m <- leaflet::addPolygons(m,
                                          lng = x_coord,
                                          lat = y_coord,
                                          weight = weight,
                                          group = grp,
                                          ...)
              }
            }

            m <- mapViewLayersControl(map = m,
                                      map.types = map.types,
                                      names = grp)

            out <- new('mapview', object = x, map = m)

            return(out)

          }
)


## SpatialLinesDataFrame =================================================
#' @describeIn mapView \code{\link{SpatialLinesDataFrame}}

setMethod('mapView', signature(x = 'SpatialLinesDataFrame'),
          function(x,
                   zcol = NULL,
                   map = NULL,
                   burst = FALSE,
                   color = mapViewPalette(7),
                   na.color = "transparent",
                   values = NULL,
                   map.types = c("OpenStreetMap",
                                 "Esri.WorldImagery"),
                   layer.opacity = 0.8,
                   legend = TRUE,
                   legend.opacity = 1,
                   weight = 2,
                   verbose = FALSE,
                   ...) {

            pkgs <- c("leaflet", "sp", "magrittr")
            tst <- sapply(pkgs, "requireNamespace",
                          quietly = TRUE, USE.NAMES = FALSE)

            if(!is.null(zcol)) x <- x[, zcol]
            if(!is.null(zcol)) burst <- TRUE

            x <- spCheckAdjustProjection(x, verbose)

            m <- initMap(map, map.types, proj4string(x))

            if (burst) {

              lst <- lapply(names(x), function(j) x[j])

              df_all <- lapply(seq(lst), function(i) {
                dat <- data.frame(lst[[i]], stringsAsFactors = TRUE)
                if (any(class(dat[, 1]) == "POSIXt")) {
                  dat[, 1] <- as.character(dat[, 1])
                }
                if (is.character(dat[, 1])) {
                  dat[, 1] <- factor(dat[, 1], levels = unique(dat[, 1]))
                }
                return(dat)
              })

              vals <- lapply(seq(lst), function(i) df_all[[i]][, 1])

              pal_n <- lapply(seq(lst), function(i) {
                if (is.factor(df_all[[i]][, 1])) {
                  leaflet::colorFactor(color, vals[[i]],
                                       levels = levels(vals[[i]]),
                                       na.color = na.color)
                } else {
                  leaflet::colorNumeric(color, vals[[i]],
                                        na.color = na.color)
                }
              })

              for (i in seq(lst)) {

                x <- lst[[i]]

                df <- as.data.frame(sapply(x@data, as.character),
                                    stringsAsFactors = FALSE)

                nms <- names(df)
                grp <- nms

                txt <- sapply(seq(nrow(x@data)), function(i) {
                  paste(nms, df[i, ], sep = ": ")
                })

                len <- length(m$x$calls)

                coord_lst <- lapply(slot(x, "lines"), function(x) {
                  lapply(slot(x, "Lines"), function(y) slot(y, "coords"))
                })

                for (j in seq(coord_lst)) {
                  for (h in seq(coord_lst[[j]])) {
                    if (is.na(proj4string(x))) {
                      x <- scaleLinesCoordinates(x)
                    }
                    x_coord <- coordinates(x@lines[[j]]@Lines[[h]])[, 1]
                    y_coord <- coordinates(x@lines[[j]]@Lines[[h]])[, 2]
                    clrs <- pal_n[[i]](vals[[i]])
                    m <- leaflet::addPolylines(m,
                                               lng = x_coord,
                                               lat = y_coord,
                                               weight = weight,
                                               group = grp,
                                               color = clrs[j],
                                               popup = txt[j],
                                               ...)
                  }
                }

                m <- leaflet::addLegend(map = m, position = "topright",
                                        pal = pal_n[[i]], opacity = 1,
                                        values = vals[[i]], title = grp)

                m <- mapViewLayersControl(map = m,
                                          map.types = map.types,
                                          names = grp)

              }

              if (length(getLayerNamesFromMap(m)) > 1) {
                m <- leaflet::hideGroup(map = m, group = layers2bHidden(m))
              }

            } else {

              df <- as.data.frame(sapply(x@data, as.character),
                                  stringsAsFactors = FALSE)

              nms <- names(df)

              grp <- layerName()

              txt <- sapply(seq(nrow(x@data)), function(i) {
                paste(nms, df[i, ], sep = ": ")
              })

              txt <- sapply(seq(ncol(txt)), function(j) {
                paste(txt[, j], collapse = " <br> ")
              })

              len <- length(m$x$calls)

              coord_lst <- lapply(slot(x, "lines"), function(x) {
                lapply(slot(x, "Lines"), function(y) slot(y, "coords"))
              })

              for (j in seq(coord_lst)) {
                for (h in seq(coord_lst[[j]])) {
                  if (is.na(proj4string(x))) {
                    x <- scaleLinesCoordinates(x)
                  }
                  x_coord <- coordinates(x@lines[[j]]@Lines[[h]])[, 1]
                  y_coord <- coordinates(x@lines[[j]]@Lines[[h]])[, 2]
                  m <- leaflet::addPolylines(m,
                                             lng = x_coord,
                                             lat = y_coord,
                                             weight = weight,
                                             group = grp,
                                             color = color[length(color)],
                                             popup = txt[j],
                                             ...)
                }
              }

              m <- mapViewLayersControl(map = m,
                                        map.types = map.types,
                                        names = grp)
            }

            out <- new('mapview', object = x, map = m)

            return(out)

          }

)




## SpatialLines ===========================================================
#' @describeIn mapView \code{\link{SpatialLines}}

setMethod('mapView', signature(x = 'SpatialLines'),
          function(x,
                   map = NULL,
                   na.color = "transparent",
                   map.types = c("OpenStreetMap",
                                 "Esri.WorldImagery"),
                   layer.opacity = 0.8,
                   weight = 2,
                   verbose = FALSE,
                   ...) {

            pkgs <- c("leaflet", "sp", "magrittr")
            tst <- sapply(pkgs, "requireNamespace",
                          quietly = TRUE, USE.NAMES = FALSE)

            llcrs <- CRS("+init=epsg:4326")@projargs

            x <- spCheckAdjustProjection(x, verbose)

            m <- initMap(map, map.types, proj4string(x))

            grp <- layerName()

            coord_lst <- lapply(slot(x, "lines"), function(x) {
              lapply(slot(x, "Lines"), function(y) slot(y, "coords"))
            })

            for (j in seq(coord_lst)) {
              for (h in seq(coord_lst[[j]])) {
                x_coord <- coordinates(x@lines[[j]]@Lines[[h]])[, 1]
                y_coord <- coordinates(x@lines[[j]]@Lines[[h]])[, 2]
                m <- leaflet::addPolylines(m,
                                           lng = x_coord,
                                           lat = y_coord,
                                           weight = weight,
                                           group = grp,
                                           ...)
              }
            }

            m <- mapViewLayersControl(map = m,
                                      map.types = map.types,
                                      names = grp)

            out <- new('mapview', object = x, map = m)

            return(out)

          }

)


## Missing ================================================================
#' @describeIn mapView initiate a map without an object
#'
#' @param easter.egg well, you might find out if you set this to TRUE
setMethod('mapView', signature(x = 'missing'),
          function(map.types = c("OpenStreetMap",
                                 "Esri.WorldImagery"),
                   easter.egg = FALSE) {

            if(easter.egg) {
              envinMR <- data.frame(x = 8.771676,
                                    y = 50.814891,
                                    envinMR = "envinMR")
              coordinates(envinMR) <- ~x+y
              proj4string(envinMR) <- sp::CRS(llcrs)
              m <- initBaseMaps(map.types)

              pop <- paste("<center>", "<b>", "mapview", "</b>", "<br>", " was created at",
                           "<br>",
                           '<a target="_blank" href="http://environmentalinformatics-marburg.de/">Environmental Informatics Marburg</a>',
                           "<br>", "by ", "<br>",
                           '<a target="_blank" href="http://umweltinformatik-marburg.de/en/staff/tim-appelhans/">Tim Appelhans</a>',
                           "<br>", "and is released under", "<br>",
                           strsplit(utils::packageDescription("mapview", fields = "License"), "\\|")[[1]][1],
                           "<br>", "<br>",
                           '<hr width=50% style="border: none; height: 1px; color: #D8D8D8; background: #D8D8D8;"/>',
                           "<br>",
                           "Please cite as: ", "<br>",
                           attr(unclass(utils::citation("mapview"))[[1]], "textVersion"),
                           "<br>", "<br>",
                           'A BibTeX entry for LaTeX users can be created with',
                           "<br>",
                           '<font face="courier">',
                           'citation("mapview")',
                           '</font face="courier">',
                           "</center>")
              m <- leaflet::addCircles(data = envinMR, map = m,
                                       fillColor = "white",
                                       color = "black",
                                       weight = 6,
                                       opacity = 0.8,
                                       fillOpacity = 0.5,
                                       group = "envinMR",
                                       popup = pop)
              m <- leaflet::addPopups(map = m,
                                      lng = 8.771676,
                                      lat = 50.814891,
                                      popup = pop)
              m <- mapViewLayersControl(map = m, map.types = map.types,
                                        names = "envinMR")
              m <- leaflet::setView(map = m, 8.771676, 50.814891, zoom = 18)
              return(m)
            } else {
              m <- initBaseMaps(map.types)
              m <- leaflet::setView(map = m, 8.770862, 50.814772, zoom = 18)
              m <- leaflet::addLayersControl(map = m, baseGroups = map.types,
                                             position = "bottomleft")
              out <- new('mapview', object = NULL, map = m)
              return(out)
            }
          }
)
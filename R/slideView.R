if ( !isGeneric('slideView') ) {
  setGeneric('slideView', function(img1, img2, ...)
    standardGeneric('slideView'))
}

#' Compare two images trough interactive swiping overlay
#'
#' @title slideView
#'
#' @description
#' Two images are overlaid and a slider is provided to interactively
#' compare the two images in a before-after like fashion. \code{img1} and
#' \code{img2} can either be two RasterLayers, two RasterBricks/Stacks or
#' two character strings. In the latter case it is assumed that these
#' point to .png images on the disk.
#'
#' This is a modified implementation of http://bl.ocks.org/rfriberg/8327361
#'
#' @param img1 a RasterStack/Brick, RasterLayer or path to a .png file
#' @param img2 a RasterStack/Brick, RasterLayer or path to a .png file
#' @param maxpixels integer > 0. Maximum number of cells to use for the plot.
#' If maxpixels < \code{ncell(x)}, sampleRegular is used before plotting.
#' @param colors the color palette to be used for visualising RasterLayers
#' @param na.color the color to be used for NA pixels
#'
#' @author
#' Tim Appelhans
#' Stephan Woellauer
#'
#' @examples
#' ### raster data ###
#' library(sp)
#' library(raster)
#'
#' data(poppendorf)
#'
#' stck1 <- subset(poppendorf, c(3, 4, 5))
#' stck2 <- subset(poppendorf, c(2, 3, 4))
#' slideView(stck1, stck2)
#'
#' \dontrun{
#' ### example taken from
#' http://www.news.com.au/technology/environment/nasa-images-reveal-
#' aral-sea-is-shrinking-before-our-eyes/story-e6frflp0-1227074133835
#' library(jpeg)
#' library(raster)
#'
#' web_img2000 <- "http://cdn.newsapi.com.au/image/v1/68565a36c0fccb1bc43c09d96e8fb029"
#'
#' jpg2000 <- readJPEG(readBin(web_img2000, "raw", 1e6))
#'
#' # Convert imagedata to raster
#' rst_blue2000 <- raster(jpg2000[, , 1])
#' rst_green2000 <- raster(jpg2000[, , 2])
#' rst_red2000 <- raster(jpg2000[, , 3])
#'
#' img2000 <- brick(rst_red2000, rst_green2000, rst_blue2000)
#'
#' web_img2013 <- "http://cdn.newsapi.com.au/image/v1/5707499d769db4b8ec76e8df61933f2a"
#'
#' jpg2013 <- readJPEG(readBin(web_img2013, "raw", 1e6))
#'
#' # Convert imagedata to raster
#' rst_blue2013 <- raster(jpg2013[, , 1])
#' rst_green2013 <- raster(jpg2013[, , 2])
#' rst_red2013 <- raster(jpg2013[, , 3])
#'
#' img2013 <- brick(rst_red2013, rst_green2013, rst_blue2013)
#'
#' slideView(img2000, img2013)
#' }
#'
#' @export
#' @docType methods
#' @name slideView
#' @rdname slideView
#' @aliases slideView,RasterStackBrick,RasterStackBrick-method

setMethod("slideView", signature(img1 = "RasterStackBrick",
                                 img2 = "RasterStackBrick"),
          function(img1, img2, maxpixels = 500000) {

            png1 <- rgbStack2PNG(img1, maxpixels = maxpixels)
            png2 <- rgbStack2PNG(img2, maxpixels = maxpixels)

            ## temp dir
            dir <- tempfile()
            dir.create(dir)
            fl1 <- paste0(dir, "/img1", ".png")
            fl2 <- paste0(dir, "/img2", ".png")

            ## pngs
            png::writePNG(png1, fl1)
            png::writePNG(png2, fl2)

            slideViewInternal(list(a="a", b="b"),
                              filename1 = fl1,
                              filename2 = fl2)
          }

)

## RasterLayers ===========================================================
#' @describeIn slideView for RasterLayers
#'
setMethod("slideView", signature(img1 = "RasterLayer",
                                 img2 = "RasterLayer"),
          function(img1,
                   img2,
                   colors = mapViewPalette(7),
                   na.color = "#00000000",
                   maxpixels = 500000) {

            png1 <- raster2PNG(img1, colors = colors,
                               na.color = na.color,
                               maxpixels = maxpixels)
            png2 <- raster2PNG(img2, colors = colors,
                               na.color = na.color,
                               maxpixels = maxpixels)

            ## temp dir
            dir <- tempfile()
            dir.create(dir)
            fl1 <- paste0(dir, "/img1", ".png")
            fl2 <- paste0(dir, "/img2", ".png")

            ## pngs
            png::writePNG(png1, fl1)
            png::writePNG(png2, fl2)

            slideViewInternal(list(a="a", b="b"),
                              filename1 = fl1,
                              filename2 = fl2)
          }

)


## png files ==============================================================
#' @describeIn slideView for png files

setMethod("slideView", signature(img1 = "character",
                                 img2 = "character"),
          function(img1, img2) {

            png1 <- png::readPNG(img1)
            png2 <- png::readPNG(img2)

            ## temp dir
            dir <- tempfile()
            dir.create(dir)
            fl1 <- paste0(dir, "/img1", ".png")
            fl2 <- paste0(dir, "/img2", ".png")

            ## pngs
            png::writePNG(png1, fl1)
            png::writePNG(png2, fl2)

            slideViewInternal(list(a="a", b="b"),
                              filename1 = fl1,
                              filename2 = fl2)
          }

)


### internal functions

slideViewInternal <- function(message,
                              width = NULL,
                              height = NULL,
                              filename1 = NULL,
                              filename2 = NULL) {

  # forward options using x
  x <- list(
    message = message
  )

  #filename1 and filename2 need to have same directory!
  image_dir <- dirname(filename1)

  image_file1 <- basename(filename1)
  image_file2 <- basename(filename2)

  dep1 <- htmltools::htmlDependency(name = "image",
                                    version = "1",
                                    src = c(file = image_dir),
                                    attachment = list(image_file1,
                                                      image_file2))
  deps <- list(dep1)

  sizing <- htmlwidgets::sizingPolicy(padding = 0, browser.fill = TRUE)

  # create widget
  htmlwidgets::createWidget(
    name = 'slideView',
    x,
    width = width,
    height = height,
    package = 'mapview',
    dependencies = deps,
    sizingPolicy = sizing
  )
}



slideViewOutput <- function(outputId, width = '100%', height = '400px'){
  htmlwidgets::shinyWidgetOutput(outputId, 'slideView',
                                 width, height, package = 'mapview')
}


renderslideView <- function(expr, env = parent.frame(), quoted = FALSE) {
  if (!quoted) { expr <- substitute(expr) } # force quoted
  htmlwidgets::shinyRenderWidget(expr, slideViewOutput, env, quoted = TRUE)
}
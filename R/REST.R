#' Extract header field element from httr response
#' 
#' @importFrom httr headers
.gdc_header_elt <- function(response, field, element) {
    value <- headers(response)[[field]]
    if (is.null(value))
        stop("response header does not contain field '", field, "'")

    value <- strsplit(strsplit(value, "; *")[[1L]], "= *")
    key <- vapply(value, `[[`, character(1), 1L)
    idx <- element == key
    if (sum(idx) != 1L)
        stop("response header field '", field,
             "' does not contain unique element '", element, "'")

    value[[which(idx)]][[2]]
}
    
#' Rename a file 'from' to 'to'
.gdc_file_rename <- function(from, to, overwrite) {
    if (overwrite && file.exists(to))
        unlink(to)

    reason <- NULL
    status <- withCallingHandlers({
        file.rename(from, to)
    }, warning=function(w) {
        reason <<- conditionMessage(w)
        invokeRestart("muffleWarning")
    })
    unlink(from)
    if (!status)
        stop("failed to rename downloaded file:\n",
             "\n  from: '", from, "'",
             "\n  to: '", to, "'",
             "\n  reason:",
             "\n", .wrapstr(reason))
    else if (!is.null(reason))
        warning(reason)        # forward non-fatal file rename warning

    to
}

#' (internal) GET endpoint / uri
#'
#' @importFrom httr GET add_headers stop_for_status
.gdc_get <-
    function(endpoint, parameters=list(), token=NULL, ..., base=.gdc_base)
{
    stopifnot(is.character(endpoint), length(endpoint) == 1L)
    uri <- sprintf("%s/%s%s", base, endpoint, .parameter_string(parameters))
    if(getOption('gdc.verbose',FALSE)) {
      message("GET request uri:\n",uri)
    }
    response <- GET(uri, add_headers(`X-Auth-Token`=token), ...)
    stop_for_status(response)
    response
}

#' (internal) POST endpoint / uri
#' 
#' @importFrom httr POST add_headers write_disk stop_for_status
.gdc_post <-
    function(endpoint, body, token=NULL, ..., base=.gdc_base)
{
    stopifnot(is.character(endpoint), length(endpoint) == 1L)
    uri <- sprintf("%s/%s", base, endpoint)
    if(getOption('gdc.verbose',FALSE)) {
      message("POST request uri:\n",uri)
    }
    response <- POST(
        uri, add_headers(`X-Auth-Token`=token),
        ...,
        body=body, encode="json")
    stop_for_status(response)
    response
}

#' Download one file from GDC, renaming to remote filename
#' 
#' @importFrom httr GET write_disk add_headers stop_for_status
.gdc_download_one <-
    function(uri, destination, overwrite, progress, token=NULL, base=.gdc_base)
{
    uri <- sprintf("%s/%s", base, uri)
    response <- GET(uri, write_disk(destination, overwrite),
                    if (progress) progress() else NULL,
                    add_headers(`X-Auth-Token`=token))
    stop_for_status(response)
    if (progress) cat("\n")

    filename <- .gdc_header_elt(response, "content-disposition", "filename")
    to <- file.path(dirname(destination), filename)
    .gdc_file_rename(destination, to, overwrite)
}

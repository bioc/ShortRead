.report_pdf <- function(src, dest, symbolValues) {
    tmpdir <- tempfile()
    if (!dir.create(tmpdir))
        .throw(SRError("Input/Output",
                       "failed to create temporary directory '%s'",
                       tmpdir))
    cwd <- setwd(tmpdir)
    on.exit(setwd(cwd))

    tmpfile <- file.path(tmpdir, basename(src))
    copySubstitute(src, tmpfile, symbolValues)
    texFile <- Sweave(tmpfile)
    tools::texi2dvi(texFile, pdf=TRUE)
    o_pdfFile <- sub(".tex$", ".pdf", texFile)
    ok <- file.copy(o_pdfFile, dest)
    if (!ok)
        .throw(SRError("Input/Output",
                       "failed to copy '%s'\n  to '%s'\n  reason: %s",
                       o_pdfFile, dest,
                       "file exists / invalid directory?"))
    dest
}

.report <- function(type, src, dest, symbolValues) {
    switch(type,
           pdf=.report_pdf(src=src, dest=dest,
             symbolValues=symbolValues),
           .throw((SRError("UserArgumentMismatch",
                           "report type '", type,
                           "' not supported"))))
}

.report_character <- function(x, ...,
                              dest=paste(tempfile(), "pdf", sep="."),
                              type="pdf")
{
    src <- system.file("template", "qa_solexa.Rnw",
                       package="ShortRead")
    symbolValues <- list(QA_SAVE_FILE=x)
    .report(type, src, dest, symbolValues)
}

setMethod("report", "character", .report_character)
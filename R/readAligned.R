.read_csv_portion <- function(dirPath, pattern, colClasses, sep, header) {
    ## visit several files, then collapse
    files <- .file_names(dirPath, pattern)
    lsts <- lapply(files, read.csv,
                   sep=sep, header=header, colClasses=colClasses)
    cclasses <- colClasses[!sapply(colClasses, is.null)]
    lst <- lapply(seq_along(names(cclasses)),
                  function(idx) unlist(lapply(lsts, "[[", idx)))
    names(lst) <- names(cclasses)
    lst
}

.readAligned_SolexaExport <- function(dirPath, pattern=character(0),
                                      sep="\t", header=FALSE) {
    ## NULL are currently ignored, usually from paired-end reads
    csvClasses <- xstringClasses <-
        list(machine=NULL, run="integer", lane="integer",
             tile="integer", x="integer", y="integer",
             indexString=NULL, pairedReadNumber=NULL,
             sequence="DNAString", quality="BString",
             chromosome="factor", contig=NULL, position="integer",
             strand="factor", descriptor=NULL, alignQuality="integer",
             pairedScore=NULL, partnerCzome=NULL, partnerContig=NULL,
             partnerOffset=NULL, partnerStrand=NULL,
             filtering="factor")

    xstringNames <- c("sequence", "quality")
    csvClasses[xstringNames] <- list(NULL, NULL)
    xstringClasses[!names(xstringClasses) %in% xstringNames] <-
        list(NULL)

    ## CSV portion
    lst <- .read_csv_portion(dirPath, pattern, csvClasses, sep, header)
    df <- with(lst, data.frame(run=run, lane=lane, tile=tile, x=x,
                               y=y, filtering=filtering))
    meta <- data.frame(labelDescription=c(
                         "Analysis pipeline run",
                         "Flow cell lane",
                         "Flow cell tile",
                         "Cluster x-coordinate",
                         "Cluster y-coordinate",
                         "Read successfully passed filtering?"))
    alignData <- AlignedDataFrame(df, meta)

    ## XStringSet classes
    sets <- readXStringColumns(dirPath, pattern, xstringClasses,
                               sep=sep, header=header)

    AlignedRead(sread=sets[["sequence"]],
                id=BStringSet(character(length(sets[["sequence"]]))),
                quality=SFastqQuality(sets[["quality"]]),
                chromosome=lst[["chromosome"]],
                position=lst[["position"]],
                strand=lst[["strand"]],
                alignQuality=NumericQuality(lst[["alignQuality"]]),
                alignData=alignData)
}

.readAligned_Maq_ADF <- function(lst) {
    df <- with(lst, data.frame(nMismatchBestHit=nMismatchBestHit,
                               mismatchQuality=mismatchQuality,
                               nExactMatch24=nExactMatch24,
                               nOneMismatch24=nOneMismatch24))
    meta <- data.frame(labelDescription=c(
                         "Number of mismatches of the best hit",
                         "Sum of mismatched base qualities of the best hit",
                         "Number of 0-mismatch hits of the first 24 bases",
                         "Number of 1-mismatch hits of the first 24 bases"))
    AlignedDataFrame(df, meta)
}

.readAligned_MaqMap <- function(dirPath, pattern=character(0), records=-1L, ...) {
    files <- .file_names(dirPath, pattern)
    if (length(files) > 1)
        .arg_mismatch_type_err("dirPath', 'pattern", "character(1)")
    lst <- .Call(.read_maq_map, files, as.integer(records))
    AlignedRead(sread=lst[["readSequence"]],
                id=lst[["readId"]],
                quality=FastqQuality(lst[["fastqScores"]]),
                chromosome=lst[["chromosome"]],
                position=lst[["position"]],
                strand=lst[["strand"]],
                alignQuality=IntegerQuality(lst[["alignQuality"]]),
                alignData=.readAligned_Maq_ADF(lst))
}

.readAligned_MaqMapview <- function(dirPath, pattern=character(0), 
                                    sep="\t", header=FALSE) {
    colClasses <-
        list(NULL, chromosome="factor", position="integer",
             strand="factor", NULL, NULL, alignQuality="integer", NULL,
             NULL, nMismatchBestHit="integer",
             mismatchQuality="integer", nExactMatch24="integer",
             nOneMismatch24="integer", NULL, NULL, NULL)
    ## CSV portion
    csv <- .read_csv_portion(dirPath, pattern, colClasses, sep,
                             header)
    ## XStringSet components
    colClasses <- list("BString", NULL, NULL, NULL, NULL,
                       NULL, NULL, NULL, NULL, NULL, NULL, NULL,
                       NULL, NULL, "DNAString", "BString")
    sets <- readXStringColumns(dirPath, pattern,
                               colClasses, sep=sep, header=header)

    AlignedRead(sread=sets[[2]], id=sets[[1]],
                quality=FastqQuality(sets[[3]]),
                chromosome=factor(csv[["chromosome"]],
                  levels=.order_chr_levels(levels(csv[["chromosome"]]))),
                position=csv[["position"]],
                strand=csv[["strand"]],
                alignQuality=IntegerQuality(csv[["alignQuality"]]),
                alignData=.readAligned_Maq_ADF(csv))
}

.readAligned_character<- function(dirPath, pattern=character(0),
                                  type=c("SolexaExport", "MAQMap",
                                    "MAQMapview"), ...) {
    if (!is.character(type) || length(type) != 1)
        .arg_mismatch_type_err("type", "character(1)")
    switch(type,
           SolexaExport=.readAligned_SolexaExport(dirPath,
             pattern=pattern, ...),
           MAQMap=.readAligned_MaqMap(dirPath, pattern, ...),
           MAQMapview=.readAligned_MaqMapview(dirPath, pattern=pattern,
             ...),
           .throw(SRError("UserArgumentMismatch",
                          "'%s' unknown; value was '%s'",
                          "type", type)))
}

setMethod("readAligned", "character", .readAligned_character)
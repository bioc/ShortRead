setClass(".QA2",
         representation("VIRTUAL", ".ShortReadBase"))

## data sources

.QAData <-
    setRefClass("QAData",
         fields=list(seq="ShortReadQ", filter="logical"),
         methods=list(show=function() {
             cat(class(.self), " ")
             print(.self$seq)
             cat(sprintf("filter: %d of %d", sum(.self$filter),
                         length(.self$filter)), "\n")
         }))

setClass("QASource",
         representation("VIRTUAL", ".QA2",
                        metadata="DataFrame", data="QAData"))

setClass("QASummary",
         representation("VIRTUAL", ".QA2",
                        addFilter="ScalarLogical",
                        useFilter="ScalarLogical",
                        values="DataFrame",
                        html="ScalarCharacter"),
         prototype=prototype(
           addFilter=mkScalar(TRUE),
           useFilter=mkScalar(TRUE)))

setClass("QAFastqSource",
         representation("QASource", "QASummary",
                        con="character", n="ScalarInteger",
                        readerBlockSize="ScalarInteger"))

## setclass("QABamSource",
##          representation("QASource", "QASummary", src="BamFile"))

## summaries

setClass("QASources", representation("QASummary"))

setClass("QAFiltered", representation("QASummary"))

setClass("QANucleotideUse", representation("QASummary"))

setClass("QAQualityUse", representation("QASummary"))

setClass("QASequenceUse", representation("QASummary"))

setClass("QAReadQuality", representation("QASummary"))

setClass("QAAdapterContamination",
         representation("QASummary",
                        Lpattern="ScalarCharacter",
                        Rpattern="ScalarCharacter",
                        max.Lmismatch="ScalarNumeric",
                        max.Rmismatch="ScalarNumeric",
                        min.trim="ScalarInteger"))

setClass("QAFrequentSequence",
         representation("QASummary",
                        n="ScalarInteger", k="ScalarInteger",
                        reportSequences="ScalarLogical"),
         validity=function(object) {
             msg <- NULL
             if (is.finite(object@n) && is.finite(object@k))
                 msg <- c(msg, "only one of 'n' or 'k' can be defined")
             else if (!is.finite(object@n) && !is.finite(object@k))
                 msg <- c(msg, "one of 'k' or 'n' must be defined")
             if (is.null(msg)) TRUE else paste("\n    ", msg)
         })

setClass("QANucleotideByCycle", representation("QASummary"))

setClass("QAQualityByCycle", representation("QASummary"))

## collation

setClass("QACollate",
         representation(".QA2", "SimpleList", src="QASource"),
         prototype=prototype(elementType="QASummary"))

setClass("QA",
         representation(".QA2", "SimpleList", sources="QASources",
                        filtered="QAFiltered"),
         prototype=prototype(elementType="QASummary"))
/* 
   Code to read in a .map file produced by the alignment program Maq.
   Authr: Simon Anders, EBI, sanders@fs.tum.de
*/

#include <cerrno>
#include <stdio.h>
#include <limits.h>
#include <R.h>
#include <Rinternals.h>
#include <zlib.h>
#include "ShortRead.h"
#include "maqmap_m.h"

#if INT_MAX < 0x7fffffffL
#error This package needs an int type with at least 32 bit.
#endif   

template< int max_readlen > SEXP read_maq_map_B( SEXP filename, SEXP maxreads )
/* Reads in the Maq map file with the given filename. If maxreads == -1, the whole file
   is read, otherwise at most the specified number of reads. The function returns a list 
   (i.e., a VECSXP) with the elements listed below in eltnames, which correspond to the 
   columns of maq mapview. */
{
    gzFile mapfile;   
    maqmap_T<max_readlen> * mapheader;
    SEXP seqnames, seq, start, dir, aq, mm, mm24, errsum, nhits0, 
        nhits1, eltnm, df, klass;
    char readseqbuf[ max_readlen ], fastqbuf[ max_readlen ];
    CharAEAE *readid, *readseq, *fastq;
    int i, actnreads, j;
    maqmap1_T<max_readlen> read;

    char enc[] = { DNAencode('A'), DNAencode('C'), DNAencode('G'),
                   DNAencode('T'), DNAencode('N') };
    static const char *eltnames[] = {
        "chromosome", "position", "strand", "alignQuality",
        "nMismatchBestHit", "nMismatchBestHit24", "mismatchQuality",
        "nExactMatch24", "nOneMismatch24", "readId", "readSequence",
        "fastqScores"
    };
   
    /* Check arguments */
    if( !Rf_isString(filename) || Rf_length(filename) != 1 )
        Rf_error( "First argument invalid: should be the filename." );
    if( !Rf_isInteger(maxreads) || Rf_length(maxreads) != 1 )
        Rf_error( "Second argument invalid: should be the maximum number"
               "of reads, provided as integer(1)." );

    /* Check that file can be opened and is a Maq map file */
    mapfile = gzopen( CHAR(STRING_ELT(filename,0)), "rb" );   
    if( !mapfile ) {
        if( errno ) {
            Rf_error( "Failed to open file '%s': %s (errno=%d)",
                   CHAR(STRING_ELT(filename,0)), strerror(errno), errno );
        } else {
            Rf_error( "Failed to open file '%s':"
                   " zlib out of memory", CHAR(STRING_ELT(filename,0)));
        }
    }	    
    gzread( mapfile, &i, sizeof(int) );
    if( i != MAQMAP_FORMAT_NEW ) {
        gzclose( mapfile );
        Rf_error( "File '%s' is not a MAQ map file", 
               CHAR(STRING_ELT(filename,0)));
    }
    i = gzrewind( mapfile );
    if (i)
        Rf_error("internal Rf_error: gzrewind: '%d'", i);

   
    /* Read in header and map maqfile sequence indices to veclist indices */
    mapheader =  maqmap_read_header<max_readlen>( mapfile );   
    PROTECT( seqnames = Rf_allocVector( STRSXP, mapheader->n_ref ) );
    for( i = 0; i < mapheader->n_ref; i++ ) {
        SET_STRING_ELT( seqnames, i, Rf_mkChar( mapheader->ref_name[i] ) );
    }
    if( INTEGER(maxreads)[0] < 0 || 
        INTEGER(maxreads)[0] >= (int) mapheader->n_mapped_reads )
        actnreads = mapheader->n_mapped_reads;
    else
        actnreads = INTEGER(maxreads)[0];
    maq_delete_maqmap(mapheader);      
   
    /* Allocate memory */
    PROTECT( seq    = Rf_allocVector( INTSXP, actnreads ) );
    PROTECT( start  = Rf_allocVector( INTSXP, actnreads ) );
    PROTECT( dir    = Rf_allocVector( INTSXP, actnreads ) );
    PROTECT( aq     = Rf_allocVector( INTSXP, actnreads ) );
    PROTECT( mm     = Rf_allocVector( INTSXP, actnreads ) );
    PROTECT( mm24   = Rf_allocVector( INTSXP, actnreads ) );
    PROTECT( errsum = Rf_allocVector( INTSXP, actnreads ) );
    PROTECT( nhits0 = Rf_allocVector( INTSXP, actnreads ) );
    PROTECT( nhits1 = Rf_allocVector( INTSXP, actnreads ) );
    readid  = new_CharAEAE( actnreads, 0 );
    readseq = new_CharAEAE( actnreads, 0 );
    fastq   = new_CharAEAE( actnreads, 0 );

    for( i = 0; i < actnreads; i++ ) {
      
        /* Various checks */
        if( gzeof(mapfile) ) {
            Rf_error( "Unexpected end of file." );
            gzclose(mapfile);
        }	 
        maqmap_read1<max_readlen>( mapfile, &read );
        if( read.flag || read.dist ) {
            Rf_error( "Paired read found. This function cannot deal with paired reads (yet)." );
            gzclose(mapfile);
        }
      
        /* Build the read sequence and the FASTQ quality string */
        if( read.size > max_readlen )
          Rf_error( "Read with illegal size encountered." );
        for (j = 0; j < read.size; j++) {
            if (read.seq[j] == 0)
              readseqbuf[j] = enc[ 4 ];
            else 
              readseqbuf[j] = enc[ read.seq[j] >> 6 & 0x03 ];
            fastqbuf[j] = ( read.seq[j] & 0x3f ) + 33;   
        }
        readseqbuf[ read.size ] = 0;
        fastqbuf  [ read.size ] = 0;      
      
        /* Copy the data */
        INTEGER(start)[i] = ( read.pos >> 1 ) + 1;
        INTEGER(dir  )[i] = ( read.pos & 0x01 ) + 1; /* '+': 1, '-': 2 */
        INTEGER(seq   )[i] = read.seqid + 1;
        INTEGER(aq    )[i] = read.map_qual;
        INTEGER(mm    )[i] = read.info1 & 0x0f;
        INTEGER(mm24  )[i] = read.info1 >> 4;
        INTEGER(errsum)[i] = read.info2;
        INTEGER(nhits0)[i] = read.c[0];
        INTEGER(nhits1)[i] = read.c[1];
        CharAEAE_append_string( readid,  read.name );
        CharAEAE_append_string( readseq, readseqbuf );
        CharAEAE_append_string( fastq,   fastqbuf );
    }
   
    /* Build the data frame */
    PROTECT( df = Rf_allocVector( VECSXP, 12 ) );
    SET_VECTOR_ELT( df, 0, seq );
    SET_VECTOR_ELT( df, 1, start );
    SET_VECTOR_ELT( df, 2, dir );    
    SET_VECTOR_ELT( df, 3, aq );
    SET_VECTOR_ELT( df, 4, mm );    
    SET_VECTOR_ELT( df, 5, mm24 );  
    SET_VECTOR_ELT( df, 6, errsum );
    SET_VECTOR_ELT( df, 7, nhits0 );
    SET_VECTOR_ELT( df, 8, nhits1 );
    SET_VECTOR_ELT( df, 9, new_XRawList_from_CharAEAE( "BStringSet",
					"BString", readid, R_NilValue ) );
    SET_VECTOR_ELT( df, 10, new_XRawList_from_CharAEAE( "DNAStringSet",
					"DNAString", readseq, R_NilValue ) );
    SET_VECTOR_ELT( df, 11, new_XRawList_from_CharAEAE( "BStringSet",
					"BString", fastq, R_NilValue ) );

    Rf_setAttrib( seq, Rf_install( "levels" ), seqnames );
    PROTECT( klass = Rf_allocVector( STRSXP, 1 ) );
    SET_STRING_ELT( klass, 0, Rf_mkChar( "factor" ) );
    Rf_setAttrib( seq, Rf_install( "class" ), klass );
    UNPROTECT( 1 );

    SEXP strand_levels = PROTECT(_get_strand_levels());
    _as_factor_SEXP(dir, strand_levels);
    UNPROTECT( 1 );
   
    PROTECT( eltnm = Rf_allocVector( STRSXP, 12 ) );
    for( i = 0; i < 12; i++ )
        SET_STRING_ELT( eltnm, i, Rf_mkChar( eltnames[i] ) );
    Rf_namesgets( df, eltnm );

    UNPROTECT( 12 );
    return df;   
}   

extern "C" SEXP read_maq_map( SEXP filename, SEXP maxreads, SEXP maq_longreads )
{
   if( LOGICAL(maq_longreads)[0] )
      return read_maq_map_B< MAX_READLEN_NEW >( filename, maxreads );
   else
      return read_maq_map_B< MAX_READLEN_OLD >( filename, maxreads );
}

/***             analog 5.32             http://www.analog.cx/             ***/
/*** This program is copyright (c) Stephen R. E. Turner 1995 - 2003 except as
 *** stated otherwise. Distribution, usage and modification of this program is
 *** subject to the conditions of the Licence which you should have received
 *** with it. This program comes with no warranty, expressed or implied.   ***/

/*** output2.c; subsiduary output functions ***/

#include "anlghea3.h"

extern unsigned int *rep2lng, *rep2busystr;
extern choice *rep2type, *rep2reqs, *rep2reqs7, *rep2date, *rep2firstd;
extern char repcodes[], *repname[];
extern htmlstrlenp htmlstrlen;

/* Print "goto"s. Assume outstyle == HTML and want-gotos already tested. */
void gotos(FILE *outf, Outchoices *od, choice rep) {
  extern char *anchorname[];

  choice *reporder = od->reporder;
  char **lngstr = od->lngstr;
  int i;

  fprintf(outf, "<p>(<b>%s</b>", lngstr[goto_]);
  fprintf(outf, ": <a HREF=\"#Top\">%s</a>", lngstr[top_]);
  for (i = 0; reporder[i] != -1; i++) {
    if (reporder[i] == rep)
      fprintf(outf, "%s %s", lngstr[colon_], lngstr[rep2lng[reporder[i]]]);
    else if (od->repq[reporder[i]])
      fprintf(outf, "%s <a HREF=\"#%s\">%s</a>", lngstr[colon_],
	      anchorname[reporder[i]], lngstr[rep2lng[reporder[i]]]);
  }
  fputs(")\n", outf);
}

void report_title(FILE *outf, Outchoices *od, choice rep) {
  extern char *anchorname[];

  char *name = od->lngstr[rep2lng[rep]];
  char *desc = od->descstr[rep];
  choice outstyle = od->outstyle;

  if (outstyle == HTML) {
    fprintf(outf, "<h2><a NAME=\"%s\">%s</a></h2>\n", anchorname[rep], name);
    if (od->gotos == TRUE)
      gotos(outf, od, rep);
  }
  else if (outstyle == ASCII) {
    fprintf(outf, "%s\n", name);
    matchlength(outf, outstyle, name, '-');
    fputc('\n', outf);
  }
  else if (outstyle == LATEX)
    fprintf(outf, "\\section*{%s}\n", name);
  if (od->descriptions && desc != NULL) {
    if (outstyle == HTML)
      fprintf(outf, "<p><em>%s</em>\n", desc);
    else if (outstyle == ASCII) {
      mprintf(outf, od->pagewidth, "%s", desc);
      mprintf(outf, 0, "");
      if (rep != REP_SIZE && rep != REP_PROCTIME)
	putc('\n', outf);
    }  /* These two reports probably have no further header text. If this is
	  wrong, it's corrected in reportspan() below. */
    else if (outstyle == LATEX) {
      fprintf(outf, "{\\em %s}\n\n", desc);
      if (rep != REP_SIZE && rep != REP_PROCTIME)
	fprintf(outf, "\\smallskip\n");
    }
  }
}

/* The period represented by the report. At the moment, this is a function of
   the report, not the underlying item type. Either choice makes some sense,
   though, and it would just be a matter of changing the calculation of maxd &
   min before passing them into this function. */
void reportspan(FILE *outf, Outchoices *od, choice rep, timecode_t maxd,
		timecode_t mind, Dateman *dman) {
  /* Assume od->repspan already tested. */
  choice outstyle = od->outstyle;
  char **lngstr = od->lngstr;
  char *compsep = od->compsep;

  if (maxd == FIRST_TIME || mind == LAST_TIME ||
      (mind - dman->firsttime < od->rsthresh && 
       dman->lasttime - maxd < od->rsthresh))
    return;

  if ((rep == REP_SIZE || rep == REP_PROCTIME) && od->descriptions &&
      od->descstr[rep] != NULL) {
    /* We were wrong when we assumed in report_title() that these reports had
       no further header text. (See comment there). So correct for it now. */
    if (outstyle == ASCII)
      putc('\n', outf);
    else if (outstyle == LATEX)
      fprintf(outf, "\\smallskip\n");
  }

  if (outstyle == HTML)
    fprintf(outf, "<p><em>");
  else if (outstyle == LATEX)
    fprintf(outf, "{\\em ");

  if (outstyle == COMPUTER) {
    fprintf(outf, "%c%s*FR%s%s\n", repcodes[rep], compsep, compsep,
	    timesprintf(od, lngstr[datefmt2_], mind, UNSET));
    fprintf(outf, "%c%s*LR%s%s\n", repcodes[rep], compsep, compsep,
	    timesprintf(od, lngstr[datefmt2_], maxd, UNSET));
  }
  else {
    mprintf(outf, od->pagewidth, "%s %s ", lngstr[repspan_],
	    timesprintf(od, lngstr[datefmt2_], mind, UNSET));
    mprintf(outf, od->pagewidth, "%s %s.", lngstr[to_],
	    timesprintf(od, lngstr[datefmt2_], maxd, UNSET));
    if (outstyle == LATEX)
      putc('}', outf);
    mprintf(outf, 0, NULL);
  }
  if (outstyle == HTML)
    fprintf(outf, "</em>\n");
  else if (outstyle == ASCII && rep != REP_SIZE && rep != REP_PROCTIME)
    putc('\n', outf);  /* These two reports have no further header text */
  else if (outstyle == LATEX) {
    fprintf(outf, "\n");
    if (rep != REP_SIZE && rep != REP_PROCTIME)
      fprintf(outf, "\\smallskip\n");
  }
}

size_t htmlstrlen_normal(char *s, choice outstyle) {
  /* Assume string contains no &'s except as markup; but see below. */
  /* NB This may not always work well for multibyte charsets, but it's hard to
     know whether an & is markup or just a byte of a multibyte character.
     Special cases are given below and selected in init.c. */
  char *t;
  logical f;
  size_t i;

  if (outstyle != HTML)
    return(strlen(s));

  for (t = s, f = TRUE, i = 0; *t != '\0'; t++) {
    if (*t == '&')
      f = FALSE;
    else if (*t == ';')
      f = TRUE;
    if (f)
      i++;
  }
  return(f?i:strlen(s));
  /* If !f, something went wrong (eg multibyte). Maybe the & wasn't markup. */
}

size_t htmlstrlen_utf8(char *s, choice outstyle) {
  /* This only knows about jp chars in the range 1110xxxx 10xxxxxx 10xxxxxx.
     Other languages using UTF-8 would need new code. */
  unsigned char *t;
  size_t i;

  if (outstyle != HTML)
    return(strlen(s));

  for (i = 0, t = (unsigned char *)s; *t != '\0'; t++) {
    if ((*t & 0xf0) == 0xe0 && (*(t + 1) & 0xc0) == 0x80 &&
	(*(t + 2) & 0xc0) == 0x80) {
      t += 2;  /* plus 1 in loop */
      i += 2;
      /* three-character jp sequence = one jp char = length 2 wrt ASCII */
    }
    else
      i++;
  }
  return(i);
}

size_t htmlstrlen_jis(char *s, choice outstyle) {
  size_t i;

  if (outstyle != HTML)
    return(strlen(s));

  for (i = 0; *s != '\0'; s++) {
    if (*s == 0x1B && (*(s + 1) == '$' || *(s + 1) == '(') && *(s + 2) == 'B')
      s += 2; /* plus 1 in loop */   /* ignore ESC $ B and ESC ( B switches */
    else
      i++;
  }
  return(i);  /* returns length in bytes, because one jp char = two bytes and
		 width of one jp char = width of two ASCII chars */
}

void matchlength(FILE *outf, choice outstyle, char *s, char c) {
  size_t i;

  for (i = htmlstrlen(s, outstyle); i > 0; i--)
    myputc(outf, c, outstyle);
}

void myputc(FILE *outf, char c, choice outstyle) {
  /* NB outstyle may not be od->outstyle in this function (see barchart()) */
  if (outstyle == HTML) {
    if (c == '<')
      fputs("&lt;", outf);
    else if (c == '>')
      fputs("&gt;", outf);
    else if (c == '&')
      fputs("&amp;", outf);
    else if (c == '"')
      fputs("&quot;", outf);
    else
      putc(c, outf);
  }
  else if (outstyle == LATEX) {
    if (c == '&' || c == '$' || c == '%' || c == '&' || c == '#' || c == '_')
      fprintf(outf, "\\%c", c);
    else if (c == '|')
      fputs("$|$", outf);
    else if (c == '\\')
      fputs("$\\backslash$", outf);
    else if (c == '{' || c == '}')
      fprintf(outf, "$\\%c$", c);
    else if (c == '^' || c == '~')
      fprintf(outf, "\\%c{}", c);
    else
      putc(c, outf);
  }
  else
    putc(c, outf);
}

/* htmlputs(): print a string with an appropriate amount of HTML encoding.
   Much quicker than using myputc(). */

/* We don't do anything when outstyle != HTML, even when outstyle == LATEX. The
   reason for this is that we are always inside a \verb so it would be wrong to
   do the conversions. If we ever call this not from inside a \verb, we may
   have to change this, and pass in outstyle == ASCII from inside \verb.
   But see also latexfprintf() below. */

/* multibyte is occasionally not od->multibyte here, because sometimes we know
   that the text is in English and we pass in multibyte == FALSE. */

/** What to convert has SECURITY IMPLICATIONS. An attacker must not be allowed
 ** to insert abitrary data in the output.
 **
 ** So data is categorised according to its source, via an enum in anlghea3.h.
 ** In the following descriptions of the security levels, "convert" means
 ** converting e.g. < to &lt; and "escape" means using \< to prevent this
 ** happening. "unprintable" means characters set as unprintable in init.c:
 ** note that this is only known unprintable characters 0x00 - 0x1F, 0x7F,
 ** and in ISO-8859-* also 0x80-0x9F.
 **
 ** 1) TRUSTED: E.g. a string from a language file. Completely trusted. In
 **    single-byte mode, convert characters (for convenience not security), but
 **    allow any of the special characters to be escaped, even \< .
 **    In multibyte mode, output the string as-is.
 ** 2) FROM_CFG: An item read in from configuration. Unless we're in CGI mode,
 **    treat as case 1. In CGI mode, the input could have come from the form,
 **    so be more cautious to avoid cross-site scripting attacks. Specifically,
 **    convert all characters, allow only \& and \\ escapes, and use '?' in
 **    place of unprintable characters.
 ** 3) UNTRUSTED: E.g. data from the logfile. Do all conversions, don't allow
 **    any escapes, and use '?' in place of all unprintable characters.
 ** 4) IN_HREF: Special case for data from the config file which is being put
 **    inside an <a href=""> or <img src="">. As 3), but use %nm in place of
 **    unprintable characters. (NB data from the logfile which is put inside
 **    an href uses escfprintf() instead of this function.)
 **/
void htmlputs(FILE *outf, Outchoices *od, char *s, choice source) {
#ifdef EBCDIC
  extern unsigned char os_toascii[];
#endif
  extern logical cgi;
  extern logical unprintable[256];

  char w1[64];
  char *c;
  char *w = w1;
  int len = 0;

  if (source == FROM_CFG && !cgi)
    source = TRUSTED;

  if (od->outstyle != HTML || (source == TRUSTED && od->multibyte))
    fputs(s, outf);
  else {
    for (c = s; *c != '\0'; c++) {
      if (*c == '<') {
	PUTs(w, "&lt;", 0);
	len += 4;
      }
      else if (*c == '>') {
	PUTs(w, "&gt;", 0);
	len += 4;
      }
      else if (*c == '&') {
	PUTs(w, "&amp;", 0);
	len += 5;
      }
      else if (*c == '"') {
	PUTs(w, "&quot;", 0);
	len += 6;
      }
      else if (*c == '\\' &&  /* escape these chars in these circumstances: */
	       ((source == TRUSTED && (*(c + 1) == '<' || *(c + 1) == '>' ||
				       *(c + 1) == '&' || *(c + 1) == '"' ||
				       *(c + 1) == '\\'))
		|| (source == FROM_CFG && (*(c + 1) == '&' ||
					   *(c + 1) == '\\')))) {
	od->html = FALSE;
	PUTc(w, *(++c));
	len += 1;
      }
      else if (unprintable[(unsigned char)(*c)] && source != TRUSTED) {
	/* unprintable chars */
	if (source == IN_HREF) {
#ifdef EBCDIC
	sprintf(w, "%%%.2X", os_toascii[*c]);
#else
	sprintf(w, "%%%.2X", (unsigned char)(*c));
#endif
	w += 3;
	len += 3;
	}
	else {  /* source == FROM_CFG or UNTRUSTED */
	  PUTc(w, '?');
	  len += 1;
	}
      }
      else {  /* output non-special characters as-is */
	PUTc(w, *c);
	len += 1;
      }
      if (len > 57) {
	*w = '\0';
	fputs(w1, outf);
	w = w1;
	len = 0;
      }
    }
    *w = '\0';
    fputs(w1, outf);
  }
}

void latexfprintf(FILE *outf, char *s) {
  /* Modelled after htmlputs(). But this time assume outstyle == LATEX has
     already been tested. */
  char w1[64];
  char *c;
  char *w = w1;
  int len = 0;

  for (c = s; *c != '\0'; c++) {
    if (*c == '&' || *c == '$' || *c == '%' || *c == '&' || *c == '#' ||
	*c == '_') {
      PUTc(w, '\\');
      PUTc(w, *c);
      len += 2;
    }
    else if (*c == '|') {
      PUTs(w, "$|$", 0);
      len += 3;
    }
    else if (*c == '\\') {
      PUTs(w, "$\\backslash$", 0);
      len += 12;
    }
    else if (*c == '{' || *c == '}') {
      PUTs(w, "$\\", 0);
      PUTc(w, *c);
      PUTc(w, '$');
      len += 4;
    }
    else if (*c == '^' || *c == '~') {
      PUTc(w, '\\');
      PUTc(w, *c);
      PUTs(w, "{}", 0);
      len += 4;
    }
    else {
      PUTc(w, *c);
      len += 1;
    }
    if (len > 50) {
      *w = '\0';
      fputs(w1, outf);
      w = w1;
      len = 0;
    }
  }
  *w = '\0';
  fputs(w1, outf);
}

void escfprintf(FILE *outf, char *name) {
  /* Escape names for use in hyperlinks. As with htmlputs(), don't try and
     print character by character. Assume outstyle == HTML already tested. */
#ifdef EBCDIC
  extern unsigned char os_toascii[];
#endif
  char w1[64];
  char *w = w1;
  int len = 0;

  for ( ; *name != '\0'; name++) {
    if (ISALNUM(*name) || *name == '/' || *name == '.' || *name == ':' ||
	*name == '-' || *name == '~' || *name == '_' || *name == '?' ||
	*name == '%' || *name == '=' || *name == '+' ||
	*name == ';' ||	*name == '@' || *name == '$' || *name == ',') {
      /* All reserved and some unreserved chars from RFC 2396 Sec 2. */
      /* Reserved chars are not escaped because if they are in the logfile they
	 must have their special meanings (path delimiters etc.), and escaping
	 them would change the semantics of the URL. */
      PUTc(w, *name);
      len += 1;
    }
    else if (*name == '&') {
      PUTs(w, "&amp;", 0);
      len += 5;
    }
    else {
#ifdef EBCDIC
      sprintf(w, "%%%.2X", os_toascii[*name]);
#else
      sprintf(w, "%%%.2X", (unsigned char)(*name));
#endif
      w += 3;
      len += 3;
    }
    if (len > 58) {
      *w = '\0';
      fputs(w1, outf);
      w = w1;
      len = 0;
    }
  }
  *w = '\0';
  fputs(w1, outf);
}

void hrule(FILE *outf, Outchoices *od) {
  unsigned int i;

  if (od->outstyle == HTML)
    fputs("<hr>\n", outf);
  else if (od->outstyle == ASCII) {
    for (i = 0; i < od->pagewidth; i++)
      putc('-', outf);
    fputs("\n\n", outf);
  }
  else if (od->outstyle == LATEX)
    fputs("\\medskip\\hrule\n", outf);
}

void include_file(FILE *outf, Outchoices *od, char *name, char type) {
  FILE *inf;
  char buffer[BLOCKSIZE];
  size_t n;

  if ((inf = my_fopen(name, (type == 'h')?"header file":"footer file")) !=
      NULL) {
    od->html = FALSE;
    if (type == 'f' || od->outstyle == HTML) {
      hrule(outf, od);
      if (od->outstyle == LATEX)
	fputs("\\smallskip\n", outf);
    }
    while ((n = fread(buffer, 1, BLOCKSIZE, inf)))  /* single equals */
      fwrite((void *)buffer, 1, n, outf);
    if (type == 'h') {
      hrule(outf, od);
      if (od->outstyle == LATEX)
	fputs("\\smallskip\n", outf);
    }
    (void)my_fclose(inf, name, (type == 'h')?"header file":"footer file");
  }
}

/*** Date printing routine ***/

size_t datefmtlen(Outchoices *od, char *fmt) {
  /* Page width required for formatted date. All dates should be the same,
     so just format an arbitrary one and measure it. */
  return(htmlstrlen(datesprintf(od, fmt, 1, 23, 59, 1, 23, 59, FALSE, UNSET),
		    od->outstyle));
}

char *datesprintf(Outchoices *od, char *fmt, datecode_t date, unsigned int hr,
		  unsigned int min, datecode_t newdate, unsigned int newhr,
		  unsigned int newmin, logical running, choice allowmonth) {
  /* Formats date. Allocates space as necessary, but 2nd call will overwrite */
  /* If od is NULL, must have running == TRUE and allowmonth != UNSET.
     Otherwise, if allowmonth is UNSET, treat as (outstyle == COMPUTER). */
  extern char *engmonths[], *engshortdays[];
  static char *ans = NULL;
  static size_t len = 0;

  choice outstyle;
  char **monthname, **dayname, *compsep;
  size_t monthlen, daylen, ampmlen, plainmonthlen, plaindaylen, plainampmlen;
  size_t current, increment;
  unsigned int d, m, y, d2, m2, y2, n, i;
  char *s, *c, *am, *pm;

  if (od == NULL) {   /* Not in output routine */
    outstyle = OUT_NONE;
    monthname = engmonths;
    dayname = engshortdays;
    compsep = NULL;
    am = "am";
    pm = "pm";
    plainmonthlen = ENGMONTHLEN;
    plaindaylen = ENGSHORTDAYLEN;
    plainampmlen = 2;
  }
  else {
    outstyle = od->outstyle;
    monthname = od->monthname;
    dayname = od->dayname;
    compsep = od->compsep;
    am = od->lngstr[am_];
    pm = od->lngstr[pm_];
    plainmonthlen = od->plainmonthlen;
    plaindaylen = od->plaindaylen;
    plainampmlen = od->plainampmlen;
  }
  if (running) {    /* Running text: no extra spacing to line things up */
    monthlen = 0;
    daylen = 0;
    ampmlen = 0;
  }
  else {
    monthlen = od->monthlen;
    daylen = od->daylen;
    ampmlen = od->ampmlen;
  }
  if (allowmonth == UNSET)
    allowmonth = (outstyle == COMPUTER);
  increment = monthlen + plainmonthlen + daylen + plaindaylen + ampmlen +
    plainampmlen + ((compsep == NULL)?0:strlen(compsep)) + 5;
  /* A (naive) upper bound on the amount by which the length of the answer
     might grow in one step; cf comment under plainmonthlen in init.c. */

  if (date == 0 || date == LAST_DATE) {
    n = chrn(fmt, '\b');
    ENSURE_LEN(ans, len, n * ((compsep == NULL)?0:strlen(compsep)) + 1);
    s = ans;
    if (outstyle == COMPUTER && compsep != NULL) {
      for (i = 0; i < n; i++)
	PUTs(s, compsep, 0);
    }
    *s = '\0';
    return(ans);
  }
  code2date(date, &d, &m, &y);
  code2date(newdate, &d2, &m2, &y2);
  ENSURE_LEN(ans, len, 1);  /* in case fmt is "" */
  for (c = fmt, s = ans; *c != '\0'; c++) {
    current = (ans == NULL)?0:(size_t)(s - ans);
    ENSURE_LEN(ans, len, current + increment);
    s = ans + current;   /* in case ans was moved when realloc'ed */
    if (*c == '%' && *(c + 1) != '\0') {
      c++;
      switch (*c) {
      case '%':
	PUTc(s, '%');
	break;
      case 'd':
	PUT2d(s, d);
	break;
      case 'D':
	PUT02d(s, d);
	break;
      case 'l':
	if (monthname != NULL)
	  PUTs(s, monthname[m2],
	       (int)monthlen - (int)htmlstrlen(monthname[m2], HTML));
	break;
      case 'L':
	if (allowmonth)
	  PUT02d(s, m2 + 1);
	break;
      case 'm':
	if (monthname != NULL)
	  PUTs(s, monthname[m],
	       (int)monthlen - (int)htmlstrlen(monthname[m], HTML));
	break;
      case 'M':
	if (allowmonth)
	  PUT02d(s, m + 1);
	break;
      case 'q':
	PUT1d(s, (m / 3) + 1);
	break;
      case '\b':  /* \b only used internally */
	if (compsep != NULL)
	  PUTs(s, compsep, 0);
	break;
      case 'y':
	PUT02d(s, y % 100);
	break;
      case 'Y':
	PUT04d(s, y);
	break;
      case 'h':
	PUT2d(s, hr);
	break;
      case 'H':
	PUT02d(s, hr);
	break;
      case 'j':
	i = hr % 12;
	if (i == 0)
	  i = 12;
	PUT2d(s, i);
	break;
      case 'a':
	if (hr < 12 || hr == 24)
	  PUTs(s, am, (int)ampmlen - (int)htmlstrlen(am, HTML))
	else       /* no semicolon above because of definition of PUTs */
	  PUTs(s, pm, (int)ampmlen - (int)htmlstrlen(pm, HTML));
	break;
      case 'i':
	PUT2d(s, newhr);
	break;
      case 'I':
	PUT02d(s, newhr);
	break;
      case 'k':
	i = newhr % 12;
	if (i == 0)
	  i = 12;
	PUT2d(s, i);
	break;
      case 'b':
	if (newhr < 12 || newhr == 24)
	  PUTs(s, am, (int)ampmlen - (int)htmlstrlen(am, HTML))
	else       /* no semicolon above because of definition of PUTs */
	  PUTs(s, pm, (int)ampmlen - (int)htmlstrlen(pm, HTML));
	break;
      case 'n':
	PUT02d(s, min);
	break;
      case 'o':
	PUT02d(s, newmin);
	break;
      case 'w':
	if (dayname != NULL)
	  PUTs(s, dayname[DAYOFWEEK(date)],
	       (int)daylen - (int)htmlstrlen(dayname[DAYOFWEEK(date)], HTML));
	break;
      case 'x':
	if (outstyle == LATEX)
	  PUTs(s, "--", 0)  /* no semicolon because of definition of PUTs */
	else
	  PUTc(s, '-');
	/* Should be &ndash; in HTML but not all browsers implement &ndash;
	   yet, and when they do it's usually just a regular dash. (Also, I
	   don't know if it's valid in HTML 2.) */
	break;
      }  /* switch *c */
    }    /* if *c == '%' */
    else
      PUTc(s, *c);
  }  /* for c */
  *s = '\0';
  return(ans);
}

char *timesprintf(Outchoices *od, char *fmt, timecode_t t, choice allowmonth) {
  /* Just a wrapper for the most common case of datesprintf(). */
  return(datesprintf(od, fmt, t / 1440, (t % 1440) / 60, t % 60, 0, 0, 0, TRUE,
		     allowmonth));
}

int f3printf(FILE *outf, choice outstyle, double x, unsigned int width,
	     char sepchar) {
  /* Return number of characters printed, but counting e.g. &amp; as 1. */
  /* NB The sepchar is sometimes repsepchar */
  int ans, i;

  x += EPSILON;   /* just to make sure rounding down works OK */
  if (sepchar == '\0')
    return(fprintf(outf, "%*.0f", width, x));

  for (i = 0; x >= 1000; i++)
    x /= 1000;  /* find out how big x is to get number of leading spaces */
  ans = fprintf(outf, "%*d", MAX((int)width - 4 * i, 0), (int)x);
  ans += 4 * i;
  /* now run down again, printing each clump */
  for ( ; i > 0; i--) {
    myputc(outf, sepchar, outstyle);
    x -= (int)x;
    x *= 1000;
    fprintf(outf, "%03d", (int)x);
  }
  return(ans);
}

void printbytes(FILE *outf, Outchoices *od, double bytes, unsigned int bmult,
		unsigned int width, char sepchar) {

  unsigned int dp = od->bytesdp;

  int by1;
  double by2, rounder;
  unsigned int j;

  if (bmult == 0)
    (void)f3printf(outf, od->outstyle, bytes, width, sepchar);
  else {
    for (j = 0; j < bmult; j++)
      bytes /= 1024; /* divide bytes to get kilobytes, megabytes or whatever */

    /* Add some amount in order to round to the correct number of decimal
       places accurately: 0.5 for 0 d.p.s, 0.05 for 1 d.p. etc. */
    rounder = 0.5;
    for (j = 0; j < dp; j++)
      rounder /= 10.0;
    bytes += rounder;

    if (dp == 0) {  /* fractional part not wanted */
      fprintf(outf, "%*d", width, (int)bytes);
    }
    else {
      by1 = (int)bytes;    /* whole number of kilo/mega/etc. bytes */
      width -= MIN(width, dp + 1);  /* leave room for fractional part */
      fprintf(outf, "%*d", width, by1);
      by2 = (bytes - (double)by1);  /* fractional part */
      for (j = 0; j < dp; j++)
	by2 *= 10;
      myputc(outf, od->decpt, od->outstyle);
      fprintf(outf, "%0*d", dp, (int)by2);
    }
  }
}

void doublemprintf(FILE *outf, choice outstyle, unsigned int pagewidth,
		   double x, char decpt) {
  unsigned int prec;
  double d;

  /* first calculate how many decimal places we need */

  for (prec = 0, d = x - (double)((int)(x));
       d - (double)((int)(d + 0.000005)) > 0.00001; d *= 10)
    prec++;

  /* now print it */

  if (pagewidth == 0 || outstyle == HTML || outstyle == LATEX) {
    /* just fprintf not mprintf */
    if (prec > 0) {
      fprintf(outf, "%d", (int)x);
      myputc(outf, decpt, outstyle);
      fprintf(outf, "%0*d", prec, (int)(d + EPSILON));
    }
    else
      fprintf(outf, "%d", (int)(x + EPSILON));
  }
  else if (prec > 0)
    mprintf(outf, pagewidth, "%d%c%0*d", (int)x, decpt, prec,
	    (int)(d + EPSILON));
  else
    mprintf(outf, pagewidth, "%d", (int)(x + EPSILON));
}


double findunit(Outchoices *od, double n, unsigned int width[], choice *cols) {
  int w;
  double unit;
  int c;
  int i, j;

  w = (int)(od->pagewidth) - (int)width[COL_TITLE] - 2;
  for (c = 0; cols[c] != COL_NUMBER; c++)
    w -= (int)width[cols[c]] + 2;
  w = MAX(w, (int)(od->mingraphwidth));
  /* unit must be nice amount: i.e., {1, 1.5, 2, 2.5, 3, 4, 5, 6, 8} * 10^n */
  unit = ((n - 1) / (double)w);
  j = 0;
  while (unit > 24.) {
    unit /= 10.;
    j++;
  }
  unit = (double)((int)unit);
  if (unit == 6.)
    unit = 7.;
  else if (unit == 8.)
      unit = 9.;
  else if (unit >= 20.)
    unit = 24.;
  else if (unit >= 15.)
    unit = 19.;
  else if (unit >= 10.)
    unit = 14.;
  unit += 1.;
  for (i = 0; i < j; i++) {
    unit *= 10.;
  }
  return(unit);
}

void calcsizes(Outchoices *od, choice rep, unsigned int width[],
	       unsigned int *bmult, unsigned int *bmult7, double *unit,
	       unsigned long maxr, unsigned long maxr7, unsigned long maxp,
	       unsigned long maxp7, double maxb, double maxb7,
	       unsigned long howmany) {
  /* width[COL_TITLE] should be set before calling this function. */
  /* width[COL_TITLE] == 0 signifies that the title is last and this function
     should calculate the remaining width. */
  /* *unit == 0 for timegraphs (and it's then set here); non-zero otherwise. */
  extern unsigned int *col2colhead;

  choice outstyle = od->outstyle;
  char repsepchar = od->repsepchar;
  char graphby = od->graph[rep];
  choice *cols = od->cols[rep];
  char **lngstr = od->lngstr;

  int w;
  unsigned int i;

  if (outstyle == COMPUTER) {
    width[COL_REQS] = 0;
    width[COL_REQS7] = 0;
    width[COL_PAGES] = 0;
    width[COL_PAGES7] = 0;
    width[COL_BYTES] = 0;
    width[COL_BYTES7] = 0;
    width[COL_PREQS] = 0;
    width[COL_PREQS7] = 0;
    width[COL_PPAGES] = 0;
    width[COL_PPAGES7] = 0;
    width[COL_PBYTES] = 0;
    width[COL_PBYTES7] = 0;
    width[COL_DATE] = 0;
    width[COL_TIME] = 0;
    width[COL_FIRSTD] = 0;
    width[COL_FIRSTT] = 0;
    width[COL_INDEX] = 0;
    width[COL_TITLE] = 0;
    *bmult = 0;
    *bmult7 = 0;
  }
  else {
    width[COL_REQS] = MAX(LEN3(log10i(maxr) + 1, repsepchar),
			  htmlstrlen(lngstr[col2colhead[COL_REQS]], outstyle));
    width[COL_REQS7] = MAX(LEN3(log10i(maxr7) + 1, repsepchar),
			   htmlstrlen(lngstr[col2colhead[COL_REQS7]],
				      outstyle));
    width[COL_PAGES] = MAX(LEN3(log10i(maxp) + 1, repsepchar),
			   htmlstrlen(lngstr[col2colhead[COL_PAGES]],
				      outstyle));
    width[COL_PAGES7] = MAX(LEN3(log10i(maxp7) + 1, repsepchar),
			    htmlstrlen(lngstr[col2colhead[COL_PAGES7]],
				       outstyle));
    if (od->rawbytes || maxb < 1024.0) {
      width[COL_BYTES] = MAX(LEN3(log10x(maxb) + 1, repsepchar),
			     htmlstrlen(lngstr[col2colhead[COL_BYTES]],
					outstyle));
      *bmult = 0;
    }
    else {
      *bmult = findbmult(maxb, od->bytesdp);
      width[COL_BYTES] = MAX(3 + od->bytesdp + (od->bytesdp != 0),
			     htmlstrlen(lngstr[col2colhead[COL_BYTES] + 1],
					outstyle)
			     + htmlstrlen(lngstr[byteprefixabbr_ + *bmult],
					  outstyle) - 1);
    }
    /* I have some misgivings about allowing the bmult7 to be different from
       the bmult. It's less immediately readable. But I think it's necessary,
       because maxb and maxb7 are quite often different orders of magnitude. */
    if (od->rawbytes || maxb7 < 1024.0) {
      width[COL_BYTES7] = MAX(LEN3(log10x(maxb7) + 1, repsepchar),
			      htmlstrlen(lngstr[col2colhead[COL_BYTES7]],
					 outstyle));
      *bmult7 = 0;
    }
    else {
      *bmult7 = findbmult(maxb7, od->bytesdp);
      width[COL_BYTES7] = MAX(3 + od->bytesdp + (od->bytesdp != 0),
			      htmlstrlen(lngstr[col2colhead[COL_BYTES7] + 1],
					 outstyle)
			      + htmlstrlen(lngstr[byteprefixabbr_ + *bmult7],
					   outstyle) - 1);
    }
    width[COL_PREQS] = MAX(6, htmlstrlen(lngstr[col2colhead[COL_PREQS]],
					 outstyle));
    width[COL_PREQS7] = MAX(6, htmlstrlen(lngstr[col2colhead[COL_PREQS7]],
					  outstyle));
    width[COL_PPAGES] = MAX(6, htmlstrlen(lngstr[col2colhead[COL_PPAGES]],
					  outstyle));
    width[COL_PPAGES7] = MAX(6, htmlstrlen(lngstr[col2colhead[COL_PPAGES7]],
					   outstyle));
    width[COL_PBYTES] = MAX(6, htmlstrlen(lngstr[col2colhead[COL_PBYTES]],
					  outstyle));
    width[COL_PBYTES7] = MAX(6, htmlstrlen(lngstr[col2colhead[COL_PBYTES7]],
					   outstyle));
    width[COL_DATE] = MAX(datefmtlen(od, lngstr[genrepdate_]),
			  htmlstrlen(lngstr[col2colhead[COL_DATE]], outstyle));
    width[COL_TIME] = MAX(datefmtlen(od, lngstr[genreptime_]),
			  htmlstrlen(lngstr[col2colhead[COL_TIME]], outstyle));
    width[COL_FIRSTD] = MAX(datefmtlen(od, lngstr[genrepdate_]),
			    htmlstrlen(lngstr[col2colhead[COL_FIRSTD]],
				       outstyle));
    width[COL_FIRSTT] = MAX(datefmtlen(od, lngstr[genreptime_]),
			    htmlstrlen(lngstr[col2colhead[COL_FIRSTT]],
				       outstyle));
    width[COL_INDEX] = MAX(LEN3(log10i(howmany) + 1, repsepchar),
			   htmlstrlen(lngstr[col2colhead[COL_INDEX]],
				      outstyle));
    if (*unit == 0) { /* i.e. a timegraph */
      if (graphby == 'R' || graphby == 'r')
	*unit = findunit(od, (double)maxr, width, cols);
      else if (graphby == 'P' || graphby == 'p')
	*unit = findunit(od, (double)maxp, width, cols);
      else {
	for (i = 0; i < *bmult; i++)
	  maxb /= 1024;
	if (*bmult > 0)
	  maxb *= 1000;
	*unit = findunit(od, maxb, width, cols);
	if (*bmult > 0)
	  *unit /= 1000;
      }
    }
    if (width[COL_TITLE] == 0) {
      w = (int)(od->pagewidth);
      for (i = 0; cols[i] != COL_NUMBER; i++)
	w -= (int)width[cols[i]] + 2;
      width[COL_TITLE] = (unsigned int)MAX(0, w);
    }
  }
}

unsigned int alphatreewidth(Outchoices *od, choice rep, Hashtable *tree,
			    unsigned int level, Strlist *partname) {
  /* Calculate width needed for Organisation Report.
     Constructing the name is basically the same code as printtree(). */
  extern char *workspace;

  char *name;
  size_t need = (size_t)level + 3;
  Strlist *pn, s;
  Hashindex *p;
  unsigned int tw = 0, tmp;

  if (tree == NULL || tree->head[0] == NULL)
    return(0);
  for (p = tree->head[0]; p != NULL; TO_NEXT(p)) {
    name = maketreename(partname, p, &pn, &s, need, rep, TRUE);
    if (!STREQ(name, LNGSTR_NODOMAIN) && !STREQ(name, LNGSTR_UNKDOMAIN) &&
	!ISDIGIT(name[strlen(name) - 1])) { /* ignore left-aligned ones */
      strcpy(workspace, name);
      do_aliasx(NULL, NULL, workspace, od->aliashead[G(rep)]);
      tmp = htmlstrlen(workspace, od->outstyle) + 2 * level;
                       /* will be printed with 2 trailing spaces per level */
      tw = MAX(tw, tmp);
      tmp = alphatreewidth(od, rep, (Hashtable *)(p->other), level + 1, pn);
      tw = MAX(tw, tmp);
      /* The second tmp will of course be bigger unless there are aliases
	 (if there are any children at all). */
    }
  }
  return(tw);
}

void declareunit(FILE *outf, Outchoices *od, char graphby, double unit,
		 unsigned int bmult) {
  /* NB Number can still overflow pagewidth, but only if pagewidth is small,
     and will wrap straight after. pagewidth is never guaranteed anyway. */
  extern unsigned int ppcol;

  choice outstyle = od->outstyle;
  char markchar = od->markchar;
  unsigned int pagewidth = od->pagewidth;
  char **lngstr = od->lngstr;

  char *s;

  if (outstyle != COMPUTER) {
    if (outstyle == HTML)
      fputs("<p>\n", outf);
    mprintf(outf, pagewidth, "%s (", lngstr[eachunit_]);
    if (outstyle == ASCII)
      mprintf(outf, pagewidth, "%c", markchar);
    else if (ISLOWER(graphby)) {
      if (outstyle == HTML)
	mprintf(outf, pagewidth, "<tt>%c</tt>", markchar);
      else /* outstyle == LATEX */ if (markchar == '|')
	mprintf(outf, pagewidth, "\\verb+%c+", markchar);
      else
	mprintf(outf, pagewidth, "\\verb|%c|", markchar);
    }
    else if (outstyle == HTML) {
      mprintf(outf, pagewidth, "<img src=\"");
      htmlputs(outf, od, od->imagedir, IN_HREF);
      mprintf(outf, pagewidth, "bar%c1.%s\" alt=\"%c\">", od->barstyle,
	      od->pngimages?"png":"gif", markchar);
      /* Above: '.' not EXTSEP even on RISC OS */
    }
    else /* outstyle == LATEX */
      mprintf(outf, pagewidth, "\\barchart{1}");
    mprintf(outf, pagewidth, ") %s ", lngstr[represents_]);
    if (graphby == 'R' || graphby == 'r') {
      ppcol += f3printf(outf, outstyle, unit, 0, od->sepchar);
      if (unit == 1.)
	mprintf(outf, pagewidth, " %s.", lngstr[request_]);
      else
	mprintf(outf, pagewidth, " %s %s.", lngstr[requests_],
		lngstr[partof_]);
    }
    else if (graphby == 'P' || graphby == 'p') {
      ppcol += f3printf(outf, outstyle, unit, 0, od->sepchar);
      if (unit == 1.)
	mprintf(outf, pagewidth, " %s.", lngstr[pagereq_]);
      else
	mprintf(outf, pagewidth, " %s %s.", lngstr[pagereqs_],
		lngstr[partof_]);
    }
    else {
      if (bmult > 0) {
	doublemprintf(outf, outstyle, pagewidth, unit, od->decpt);
	s = strchr(lngstr[xbytes_], '?');  /* checked in initialisation */
	*s = '\0';
	mprintf(outf, pagewidth, " %s%s%s %s.", lngstr[xbytes_],
		lngstr[byteprefix_ + bmult], s + 1, lngstr[partof_]);
	*s = '?';
      }
      else {
	ppcol += f3printf(outf, outstyle, unit, 0, od->sepchar);
	mprintf(outf, pagewidth, " %s %s.", lngstr[bytes_], lngstr[partof_]);
      }
    }
    mprintf(outf, 0, NULL);
  }
}

void whatincluded(FILE *outf, Outchoices *od, choice rep, unsigned long n,
		  Dateman *dman) {
  extern char *byteprefix;
  extern unsigned int *method2sing, *method2pl, *method2date, *method2pc;
  extern unsigned int *method2relpc, *method2sort;

  choice outstyle = od->outstyle;
  unsigned int pagewidth = od->pagewidth;
  char **lngstr = od->lngstr;
  choice sortby = od->sortby[G(rep)];
  double floormin = od->floor[G(rep)].min;
  char floorqual = od->floor[G(rep)].qual;
  choice floorby = od->floor[G(rep)].floorby;
  char *gens = lngstr[rep2lng[rep] + 1];
  char *genp = lngstr[rep2lng[rep] + 2];
  char gender = lngstr[rep2lng[rep] + 3][0];
  choice requests = rep2reqs[G(rep)];
  choice requests7 = rep2reqs7[G(rep)];
  choice date = rep2date[G(rep)];
  choice firstd = rep2firstd[G(rep)];

  int firsts, firstds, alls, sorted, alphsort, unsort, bmult;
  char *lngs, *c;
  static char *t = NULL;
  static size_t tlen = 0;
  unsigned long temp = 0;
  timecode_t tempd;

  if (outstyle != COMPUTER) {
    if (gender == 'm') {
      firsts = firstsm_;
      firstds = firstdsm_;
      alls = allsm_;
      sorted = sortedm_;
      alphsort = STREQ(gens, lngstr[codegs_])?numsortm_:alphasortm_;
      unsort = unsortedm_;            /* quickest kludge for only one report */
    }
    else if (gender == 'f') {
      firsts = firstsf_;
      firstds = firstdsf_;
      alls = allsf_;
      sorted = sortedf_;
      alphsort = STREQ(gens, lngstr[codegs_])?numsortf_:alphasortf_;
      unsort = unsortedf_;
    }
    else { /* gender == 'n' */
      firsts = firstsn_;
      firstds = firstdsn_;
      alls = allsn_;
      sorted = sortedn_;
      alphsort = STREQ(gens, lngstr[codegs_])?numsortn_:alphasortn_;
      unsort = unsortedn_;
    }

    /* see also report_floor() in settings.c */
    if (outstyle == HTML)
      fputs("<p>\n", outf);
    if (floormin < 0 && n < (unsigned long)(-floormin + EPSILON))
      floormin = 1;  /* not enough items for requested -ve floor */
    /* floormin = 1 will work even for date sort because it will be before
       dman->firsttime. With very high probability. :) */
    if (floormin < 0) {
      temp = (unsigned long)(-floormin + EPSILON);
      if (temp == 1)
	mprintf(outf, pagewidth, lngstr[firsts], gens);
      else
	mprintf(outf, pagewidth, lngstr[firstds], temp, genp);
      mprintf(outf, pagewidth, " %s ", lngstr[floorby_]);
      if (floorby == REQUESTS)
	mprintf(outf, pagewidth, "%s", lngstr[method2sort[requests]]);
      else if (floorby == REQUESTS7)
	mprintf(outf, pagewidth, "%s", lngstr[method2sort[requests7]]);
      else if (floorby == DATESORT)
	mprintf(outf, pagewidth, "%s", lngstr[method2sort[date]]);
      else if (floorby == FIRSTDATE)
	mprintf(outf, pagewidth, "%s", lngstr[method2sort[firstd]]);
      else
	mprintf(outf, pagewidth, "%s", lngstr[method2sort[floorby]]);
    }
    else {   /* floormin >= 0 */
      mprintf(outf, pagewidth, lngstr[alls], genp);
      if (floormin < 2 - EPSILON && floorqual == '\0' && floorby == REQUESTS)
	floormin = 0;  /* Report 1r as 0r */
      if (floorby == DATESORT || floorby == FIRSTDATE) {
	tempd = (timecode_t)(floormin + EPSILON);
	if (tempd > dman->firsttime) {
	  mprintf(outf, pagewidth, " %s ",
		  lngstr[method2date[(floorby == DATESORT)?date:firstd]]);
	  mprintf(outf, pagewidth, "%s",
		  timesprintf(od, lngstr[whatincfmt_], tempd, UNSET));
	}
      }
      else if (floormin > EPSILON) {
	mprintf(outf, pagewidth, " %s ", lngstr[atleast_]);
	if (floorqual == '\0') {
	  temp = (unsigned long)(floormin + EPSILON);
	  mprintf(outf, pagewidth, "%lu ", temp);
	  if (floorby == REQUESTS)
	    mprintf(outf, pagewidth, "%s", (temp == 1)?\
		    lngstr[method2sing[requests]]:lngstr[method2pl[requests]]);
	  else if (floorby == REQUESTS7)
	    mprintf(outf, pagewidth, "%s", (temp == 1)?\
		    lngstr[method2sing[requests7]]:\
		    lngstr[method2pl[requests7]]);
	  else
	    mprintf(outf, pagewidth, "%s", (temp == 1)?\
		    lngstr[method2sing[floorby]]:lngstr[method2pl[floorby]]);
	}
	else {  /* floorqual != '\0' */
	  doublemprintf(outf, outstyle, pagewidth, floormin, od->decpt);
	  if (floorqual == '%') {
	    if (floorby == REQUESTS)
	      c = lngstr[method2pc[requests]];
	    else if (floorby == REQUESTS7)
	      c = lngstr[method2pc[requests7]];
	    else
	      c = lngstr[method2pc[floorby]];
	    if (outstyle == LATEX) { /* then change one % to \% -- yuk. */
	      ENSURE_LEN(t, tlen, strlen(c) + 2);
	      strcpy(t, c);
	      if ((c = strchr(t, '%')) != NULL) {
		memmove(c + 1, c, strlen(c) + 1);
		*c = '\\';
	      }
	      c = t;
	    }
	    mprintf(outf, pagewidth, "%s", c);
	  }
	  else if (floorqual == ':') {
	    if (floorby == REQUESTS)
	      c = lngstr[method2relpc[requests]];
	    else if (floorby == REQUESTS7)
	      c = lngstr[method2relpc[requests7]];
	    else
	      c = lngstr[method2relpc[floorby]];
	    if (outstyle == LATEX) { /* and again, change one % to \%. */
	      ENSURE_LEN(t, tlen, strlen(c) + 2);
	      strcpy(t, c);
	      if ((c = strchr(t, '%')) != NULL) {
		memmove(c + 1, c, strlen(c) + 1);
		*c = '\\';
	      }
	      c = t;
	    }
	    mprintf(outf, pagewidth, "%s", c);
	  }
	  else { /* if qual is anything else, must be (k|M|G|T|etc.)bytes */
	    lngs = (floorby == BYTES)?lngstr[xbytestraffic_]:\
	      lngstr[xbytestraffic7_];
	    if (strchr(byteprefix, floorqual) == NULL)  /* shouldn't happen */
	      bmult = 1;
	    else
	      bmult = strchr(byteprefix, floorqual) - byteprefix;
	    c = strchr(lngs, '?');  /* checked during initialisation */
	    *c = '\0';
	    mprintf(outf, pagewidth, " %s%s%s", lngs,
		    lngstr[byteprefix_ + bmult], c + 1);
	    *c = '?';
	  }
	}   /* end floorqual != '\0' */
      }     /* end floormin > EPSILON */
    }       /* end floormin > 0 */
    /* That completes the floor; now we are just left with the sortby */
    if (floormin >= 0 || temp != 1) { /* else only one item, so no sort */
      if (floormin < 0 && sortby == RANDOM)
	sortby = floorby;
      mprintf(outf, pagewidth, ", ");
      if (sortby == ALPHABETICAL)
	mprintf(outf, pagewidth, "%s", lngstr[alphsort]);
      else if (sortby == RANDOM)
	mprintf(outf, pagewidth, "%s", lngstr[unsort]);
      else {
	mprintf(outf, pagewidth, "%s", lngstr[sorted]);
	mprintf(outf, pagewidth, " ");
	if (sortby == REQUESTS)
	  mprintf(outf, pagewidth, "%s", lngstr[method2sort[requests]]);
	else if (sortby == REQUESTS7)
	  mprintf(outf, pagewidth, "%s", lngstr[method2sort[requests7]]);
	else if (sortby == DATESORT)
	  mprintf(outf, pagewidth, "%s", lngstr[method2sort[date]]);
	else if (sortby == FIRSTDATE)
	  mprintf(outf, pagewidth, "%s", lngstr[method2sort[firstd]]);
	else
	  mprintf(outf, pagewidth, "%s", lngstr[method2sort[sortby]]);
      }
    }
    mprintf(outf, pagewidth, ".");
    mprintf(outf, 0, NULL);
  }
  else {  /* outstyle == COMPUTER */
    fprintf(outf, "%c%s*f%s", repcodes[rep], od->compsep, od->compsep);
    if (floormin < 0)
      fprintf(outf, "-%lu", (unsigned long)(-floormin + EPSILON));
    else if (floorby == DATESORT || floorby == FIRSTDATE) {
      tempd = (timecode_t)(floormin + EPSILON);
      fputs(timesprintf(od, "%Y%M%D:%H%n", tempd, UNSET), outf);
    }
    else if (floorqual == '\0')
      fprintf(outf, "%lu", (unsigned long)(floormin + EPSILON));
    else
      fprintf(outf, "%f", floormin);
    if (floorqual != '\0')
      putc(floorqual, outf);
    if (floorby == REQUESTS)
      putc('R', outf);
    else if (floorby == REQUESTS7)
      putc('S', outf);
    else if (floorby == PAGES)
      putc('P', outf);
    else if (floorby == PAGES7)
      putc('Q', outf);
    else if (floorby == BYTES)
      putc('B', outf);
    else if (floorby == BYTES7)
      putc('C', outf);
    else if (floorby == DATESORT)
      putc('D', outf);
    else /* floorby == FIRSTDATE */
      putc('E', outf);

    /* now the sortby */
    if (floormin < 0 && sortby == RANDOM)
      sortby = floorby;
    fprintf(outf, "%s", od->compsep);
    if (sortby == ALPHABETICAL)
      putc('a', outf);
    else if (sortby == BYTES)
      putc('b', outf);
    else if (sortby == BYTES7)
      putc('c', outf);
    else if (sortby == DATESORT)
      putc('d', outf);
    else if (sortby == FIRSTDATE)
      putc('e', outf);
    else if (sortby == PAGES)
      putc('p', outf);
    else if (sortby == PAGES7)
      putc('q', outf);
    else if (sortby == REQUESTS)
      putc('r', outf);
    else if (sortby == REQUESTS7)
      putc('s', outf);
    else /* sortby == RANDOM */
      putc('x', outf);
    putc('\n', outf);
  }
}

void busyprintf(FILE *outf, Outchoices *od, choice rep, char *datefmt,
		unsigned long reqs, unsigned long pages, double bys,
		datecode_t date, unsigned int hr, unsigned int min,
		datecode_t newdate, unsigned int newhr, unsigned int newmin,
		char graphby) {
  choice outstyle = od->outstyle;
  char **lngstr = od->lngstr;
  char sepchar = od->sepchar;
  char *compsep = od->compsep;
  char *busystr = lngstr[rep2busystr[rep]];

  unsigned int bmult;
  char *s;

  if (outstyle == ASCII)
    putc('\n', outf);
  else if (outstyle == COMPUTER)
    putc(repcodes[rep], outf);
  if (outstyle != COMPUTER)
    fprintf(outf, "%s %s (", busystr,
	    datesprintf(od, datefmt, date, hr, min, newdate, newhr, newmin,
			TRUE, UNSET));
  if (TOLOWER(graphby) == 'r') {
    if (outstyle == COMPUTER)
      fprintf(outf, "%s*BT%sR%s", compsep, compsep, compsep);
    f3printf(outf, outstyle, (double)reqs, 0, sepchar);
    if (outstyle != COMPUTER)
      fprintf(outf, " %s).\n", (reqs == 1)?lngstr[request_]:lngstr[requests_]);
  }
  else if (TOLOWER(graphby) == 'p') {
    if (outstyle == COMPUTER)
      fprintf(outf, "%s*BT%sP%s", compsep, compsep, compsep);
    f3printf(outf, outstyle, (double)pages, 0, sepchar);
    if (outstyle != COMPUTER)
      fprintf(outf, " %s).\n",
	      (pages == 1)?lngstr[pagereq_]:lngstr[pagereqs_]);
  }
  else /* TOLOWER(graphby) == 'b' */ {
    if (od->rawbytes)
      bmult = 0;
    else
      bmult = findbmult(bys, od->bytesdp);
    if (outstyle == COMPUTER)
      fprintf(outf, "%s*BT%sB%s", compsep, compsep, compsep);
    printbytes(outf, od, bys, bmult, 0, sepchar);
    if (outstyle != COMPUTER) {
      putc(' ', outf);
      if (bmult >= 1) {
	s = strchr(lngstr[xbytes_], '?');  /* checked in initialisation */
	*s = '\0';
	fprintf(outf, "%s%s%s).\n", lngstr[xbytes_],
		lngstr[byteprefix_ + bmult], s + 1);
	*s = '?';
      }
      else
	fprintf(outf, "%s).\n", lngstr[bytes_]);
    }
  }
  if (outstyle == COMPUTER)
    fprintf(outf, "%s%s\n", compsep,
	    datesprintf(od, datefmt, date, hr, min, newdate, newhr, newmin,
			TRUE, UNSET));
}

void pccol(FILE *outf, Outchoices *od, double n, double tot,
	   unsigned int width) {
  double pc;
  unsigned int pc1, pc2;
  int i;

  if (od->outstyle == COMPUTER)
    fprintf(outf, "%.3f", (tot == 0)?0.0:(n * 100.0 / tot));
  else {
    for (i = 0; i < (int)width - 6; i++)
      putc(' ', outf);
    if (tot == 0)
      pc = 0.0;
    else
      pc = n * 10000.0 / tot;
    if (pc >= 9999.5)
      fputs("  100%", outf);
    else if (pc < 0.5)
      fputs("      ", outf);
    else {
      pc1 = ((int)(pc + 0.5)) / 100;
      pc2 = ((int)(pc + 0.5)) % 100;
      fprintf(outf, "%2d", pc1);
      myputc(outf, od->decpt, od->outstyle);
      fprintf(outf, "%02d%%", pc2);
    }
  }
}

void barchart(FILE *outf, Outchoices *od, char graphby, unsigned long reqs,
	      unsigned long pages, double bys, double unit) {
  choice outstyle = od->outstyle;

  int i, j;
  double x;
  int y;
  logical first = TRUE;

  if (graphby == 'P' || graphby == 'p')
    x = (double)pages - 0.5;
  else if (graphby == 'R' || graphby == 'r')
    x = (double)reqs - 0.5;
  else
    x = bys;
  x /= unit;
  x += 1;
  y = (int)x;
  if (ISLOWER(graphby) || outstyle == ASCII) {
    for (i = 0; i < y; i++)
      myputc(outf, od->markchar, (choice)((outstyle == LATEX)?ASCII:outstyle));
  }                                                   /* because in \verb */
  else if (outstyle == LATEX)
    fprintf(outf, "\\barchart{%d}", y);
  else if (outstyle == HTML) {
    for (j = 32; j >= 1; j /= 2) {
      while (y >= j) {
	fputs("<img src=\"", outf);
	htmlputs(outf, od, od->imagedir, IN_HREF);
	fprintf(outf, "bar%c%d.%s\" alt=\"", od->barstyle, j,
		od->pngimages?"png":"gif");/* '.' not EXTSEP even on RISC OS */

	if (first) {
	  for (i = 0; i < y; i++)
	    myputc(outf, od->markchar, outstyle);
	  first = FALSE;
	}
	fputs("\">", outf);
	y -= j;
      }
    }
  }
}

void colheads(FILE *outf, Outchoices *od, choice rep, unsigned int width[],
	      unsigned int bmult, unsigned int bmult7, logical name1st) {
  extern unsigned int *col2colhead, *rep2colhead;

  char **lngstr = od->lngstr;
  char *name = lngstr[rep2colhead[rep]];
  choice *cols = od->cols[rep];
  choice outstyle = od->outstyle;

  int len;
  char *lngs, *d, verbchar = '\0'; /* initialise to keep the compiler happy */
  unsigned int c, bm;
  int i;  /* i should stay unsigned automatically, but for safety... */

  if (outstyle != COMPUTER) {
    if (outstyle == LATEX) {
      verbchar = '|';  /* assume this never occurs in a column heading */
      /* Note no multibyte problem with this assignment of verbchar because
	 LATEX output doesn't work in multibyte anyway. */
      fprintf(outf, "\\verb%c", verbchar);
    }
    if (name1st)
      fprintf(outf, "%*s: ", width[COL_TITLE] + strlen(name)
	      - htmlstrlen(name, outstyle), name);
    for (c = 0; cols[c] != COL_NUMBER; c++) {
      if (cols[c] == COL_BYTES || cols[c] == COL_BYTES7) {
	bm = (cols[c] == COL_BYTES)?bmult:bmult7;
	lngs = lngstr[col2colhead[cols[c]] + (int)(bm != 0)];
	len = (int)htmlstrlen(lngs, outstyle);
	if (bm > 0)
	  len += (int)htmlstrlen(lngstr[byteprefixabbr_ + bm], outstyle) - 1;
	for (i = width[cols[c]] - len; i > 0; i--)
	  putc(' ', outf);
	if (bm > 0) {
	  d = strchr(lngs, '?');  /* checked during initialisation */
	  *d = '\0';
	  fprintf(outf, "%s%s%s: ", lngs, lngstr[byteprefixabbr_ + bm],
		  d + 1);
	  *d = '?';
	}
	else
	  fprintf(outf, "%s: ", lngs);
      }
      else
	fprintf(outf, "%*s: ", width[cols[c]]
		+ strlen(lngstr[col2colhead[cols[c]]])
		- htmlstrlen(lngstr[col2colhead[cols[c]]], outstyle),
		lngstr[col2colhead[cols[c]]]);
    }
    if (!name1st)
      fputs(name, outf);
    if (outstyle == LATEX)
      putc(verbchar, outf);
    putc('\n', outf);
    if (outstyle == LATEX)
      fprintf(outf, "\\verb%c", verbchar);
    if (name1st) {
      for (i = 0; i < (int)(width[COL_TITLE]); i++)
	putc('-', outf);
      fputs(": ", outf);
    }
    for (c = 0; cols[c] != COL_NUMBER; c++) {
      for (i = width[cols[c]] ; i > 0; i--)
	putc('-', outf);
      fputs(": ", outf);
    }
    if (!name1st)
      matchlength(outf, outstyle, name, '-');
    if (outstyle == LATEX)
      putc(verbchar, outf);
    fputc('\n', outf);
  }
}

char printcols(FILE *outf, Outchoices *od, choice rep, unsigned long reqs,
	       unsigned long reqs7, unsigned long pages, unsigned long pages7,
	       double bys, double bys7, long index, int level,
	       unsigned long totr, unsigned long totr7, unsigned long totp,
	       unsigned long totp7, double totb, double totb7,
	       unsigned int width[], unsigned int bmult, unsigned int bmult7,
	       double unit, logical name1st, logical rightalign, char *name,
	       logical ispage, unsigned int spaces, Include *linkhead,
	       char *baseurl, char *datefmt, char *timefmt, datecode_t date,
	       unsigned int hr, unsigned int min, datecode_t date2,
	       unsigned int hr2, unsigned int min2) {
  /* 'level' is -1 for time reports, 0 for other non-hierarchical reports,
     and starts at 1 for hierarchical reports. */
  /* For time reps, date2, hr2 & min2 carry the end of the interval; for
     genreps, date2, hr2 & min2 carry the time of first request. */
  /* Returns the chosen verbchar: see below. */

  extern char *workspace;

  choice *cols = od->cols[rep];
  logical timerep = (rep < DATEREP_NUMBER);
  char graphby = timerep?(od->graph[rep]):'\0';
  char repsepchar = od->repsepchar;

  char *datestr;
  /* Choice of a verbchar: can't be number, letter, colon, space, percent
     (LaTeX special characters are OK though); or the markchar, the decpt,
     or any character in a compiled date or in the name. Also we try only to
     use ASCII printable characters (32-127) for legible LaTeX code. That
     leaves the following choices, in order of preference. We return the
     verbchar at the end for the cases in which calling functions need to
     terminate the \verb */
  char *verbchar = "|+/!^#-=?_\\~'$\"()<>[]{}.,&;";
  char lastditch[] = {(char)(0xF7)};   /* the division sign in ISO-8859-[12] */
  choice outstyle, saveoutstyle;
  logical aliased, multibyte = FALSE;
  int c, i;

  saveoutstyle = od->outstyle;
  if (od->outstyle == LATEX) {
    while ((*verbchar == od->markchar || *verbchar == od->decpt ||
	    (name != NULL && strchr(name, *verbchar) != NULL) ||
	    (datefmt != NULL && strchr(datefmt, *verbchar) != NULL) ||
	    (timefmt != NULL && strchr(timefmt, *verbchar) != NULL))
	   && *verbchar != '\0')
      verbchar++;
    if (*verbchar == '\0')   /* no suitable char: last guess */
      verbchar = lastditch;
    fprintf(outf, "\\verb%c", *verbchar);
    od->outstyle = ASCII;    /* in \verb, so pretend it's ASCII temporarily */
  }
  outstyle = od->outstyle;
  if (outstyle == COMPUTER) {
    fprintf(outf, "%c%s", repcodes[rep], od->compsep);
    if (level >= 1)
      putc('l', outf);
    for (c = 0; cols[c] != COL_NUMBER; c++) {
      switch(cols[c]) {
      case COL_REQS:
	putc('R', outf);
	break;
      case COL_REQS7:
	putc('S', outf);
	break;
      case COL_PREQS:
	putc('r', outf);
	break;
      case COL_PREQS7:
	putc('s', outf);
	break;
      case COL_PAGES:
	putc('P', outf);
	break;
      case COL_PAGES7:
	putc('Q', outf);
	break;
      case COL_PPAGES:
	putc('p', outf);
	break;
      case COL_PPAGES7:
	putc('q', outf);
	break;
      case COL_BYTES:
	putc('B', outf);
	break;
      case COL_BYTES7:
	putc('C', outf);
	break;
      case COL_PBYTES:
	putc('b', outf);
	break;
      case COL_PBYTES7:
	putc('c', outf);
	break;
      case COL_DATE:
	putc('d', outf);
	break;
      case COL_TIME:
	putc('D', outf);
	break;
      case COL_FIRSTD:
	putc('e', outf);
	break;
      case COL_FIRSTT:
	putc('E', outf);
	break;
      case COL_INDEX:
	putc('N', outf);
	break;
      }
    }
    fputs(od->compsep, outf);
  }  /* outstyle == COMPUTER */
  else if (name1st) {
    if (timerep)
      name = datesprintf(od, datefmt, date, hr, min, date2, hr2, min2, FALSE,
			 UNSET);
    for (i = (int)width[COL_TITLE] - (int)htmlstrlen(name, outstyle); i > 0;
	 i--)
      putc(' ', outf);
    if (rep == REP_SIZE || rep == REP_PROCTIME) {
      /* Kludge: for these two reports, we know the texts are things like
	 "< 1" and we want to convert > and < */
      multibyte = od->multibyte;
      od->multibyte = FALSE;
    }
    htmlputs(outf, od, name, TRUSTED);
    if (rep == REP_SIZE || rep == REP_PROCTIME)
      od->multibyte = multibyte;
    fputs(": ", outf);
  }

  if (outstyle == COMPUTER && level >= 1)
    fprintf(outf, "%d%s", level, od->compsep);
  for (c = 0; cols[c] != COL_NUMBER; c++) {
    switch(cols[c]) {
    case COL_REQS:
      f3printf(outf, outstyle, (double)reqs, width[cols[c]], repsepchar);
      break;
    case COL_REQS7:
      f3printf(outf, outstyle, (double)reqs7, width[cols[c]], repsepchar);
      break;
    case COL_PREQS:
      pccol(outf, od, (double)reqs, (double)totr, width[cols[c]]);
      break;
    case COL_PREQS7:
      pccol(outf, od, (double)reqs7, (double)totr7, width[cols[c]]);
      break;
    case COL_PAGES:
      f3printf(outf, outstyle, (double)pages, width[cols[c]], repsepchar);
      break;
    case COL_PAGES7:
      f3printf(outf, outstyle, (double)pages7, width[cols[c]], repsepchar);
      break;
    case COL_PPAGES:
      pccol(outf, od, (double)pages, (double)totp, width[cols[c]]);
      break;
    case COL_PPAGES7:
      pccol(outf, od, (double)pages7, (double)totp7, width[cols[c]]);
      break;
    case COL_BYTES:
      printbytes(outf, od, bys, bmult, width[cols[c]], repsepchar);
      break;
    case COL_BYTES7:
      printbytes(outf, od, bys7, bmult7, width[cols[c]], repsepchar);
      break;
    case COL_PBYTES:
      pccol(outf, od, bys, totb, width[cols[c]]);
      break;
    case COL_PBYTES7:
      pccol(outf, od, bys7, totb7, width[cols[c]]);
      break;
    case COL_DATE:
    case COL_TIME:
    case COL_FIRSTD:
    case COL_FIRSTT:
      if (cols[c] == COL_DATE || cols[c] == COL_TIME)
	datestr = datesprintf(od, (cols[c] == COL_DATE)?datefmt:timefmt,
			      date, hr, min, 0, 0, 0, FALSE, UNSET);
      else
	datestr = datesprintf(od, (cols[c] == COL_FIRSTD)?datefmt:timefmt,
			      date2, hr2, min2, 0, 0, 0, FALSE, UNSET);
      for (i = (int)width[cols[c]] - (int)htmlstrlen(datestr, outstyle);
	   i > 0; i--)
	putc(' ', outf);
      fprintf(outf, "%s", datestr);
      break;
    case COL_INDEX:
      if (index > 0)
	f3printf(outf, outstyle, (double)index, width[cols[c]], repsepchar);
      else for (i = (int)width[cols[c]]; i > 0; i--)
	putc(' ', outf);
      break;
    }
    if (outstyle == COMPUTER)
      fputs(od->compsep, outf);
    else
      fputs(": ", outf);
  }
  od->outstyle = saveoutstyle;  /* revert to LATEX if necessary */
  outstyle = od->outstyle;

  if (timerep && (outstyle != COMPUTER)) {
      for (i = 0; i < (int)bmult; i++)
	bys /= 1024;
      if (outstyle == LATEX && !ISLOWER(graphby))
	fputc(*verbchar, outf);
      barchart(outf, od, graphby, reqs, pages, bys, unit);
  }
  else if (!name1st) {
    if (name == NULL)
      return(*verbchar);   /* calling function supplies name and newline */
    aliased = TRUE;  /* see aliased = do_aliasx() comment below */
    if (outstyle != COMPUTER) {
      if (rightalign) {
	strcpy(workspace, name);
	aliased = do_aliasx(NULL, NULL, workspace, od->aliashead[G(rep)]);
	/* In this case we have to do the alias twice, once into a string to
	   calculate the number of spaces required, and once to actually print
	   it. But at least we remember if an alias wasn't required, so that we
	   don't need to do it again. */
	i = (int)width[COL_TITLE] - (int)htmlstrlen(workspace, outstyle) -
	  (int)spaces;
      }
      else
	i = (int)spaces;
      for ( ; i > 0; i--)
	putc(' ', outf);
    }
    if (linkhead != NULL && outstyle == HTML &&
	included(name, ispage, linkhead)) {
      /* We link to the unaliased name, because the OUTPUTALIAS is usually in
	 the nature of an annotation. */
      fputs("<a href=\"", outf);
      if (baseurl != NULL)
	htmlputs(outf, od, baseurl, IN_HREF);
      escfprintf(outf, name);
      fputs("\">", outf);
      if (aliased)
	do_aliasx(outf, od, name, od->aliashead[G(rep)]);  /* alias & print */
      else
	htmlputs(outf, od, name, UNTRUSTED);
      fputs("</a>", outf);
    }
    else if (aliased)
      do_aliasx(outf, od, name, od->aliashead[G(rep)]);    /* alias & print */
    else
      htmlputs(outf, od, name, UNTRUSTED);
  }
  /* The previous htmlputs's have userinput = TRUE because of aliases,
     particularly accents in domains: cf do_aliasr(). Note also that for
     multibyte charsets, some necessary conversions may not take place.
     There's not much we can do about this because the source of the name may
     be a URL etc. which we should convert, but may be a lngstr, OUTPUTALIAS
     etc. which we shouldn't. We play conservative, not converting entities,
     and setting html == FALSE (in finalinit(), init.c). */
  else if (outstyle == COMPUTER) {
    if (timerep)
      name = datesprintf(od, datefmt, date, hr, min, date2, hr2, min2, FALSE,
			 UNSET);
    fprintf(outf, "%s", name);
  }
  if (outstyle == LATEX && (!timerep || ISLOWER(graphby)))
      /* if timerep, or u.c. graphby, closed \verb earlier */
    fputc(*verbchar, outf);
  fputc('\n', outf);
  return(*verbchar);
}

void lastseven(FILE *outf, Outchoices *od, timecode_t last7to) {
  char **lngstr = od->lngstr;

  if (od->outstyle == HTML)
    fputs("<p>", outf);
  if (od->outstyle == COMPUTER)
    fprintf(outf, "x%sE7%s%s\n", od->compsep, od->compsep,
	    timesprintf(od, lngstr[datefmt1_], last7to, UNSET));
  else {
    mprintf(outf, od->pagewidth, "(%s %s %s).\n", lngstr[brackets_],
	    lngstr[sevendaysto_],
	    timesprintf(od, lngstr[datefmt1_], last7to, UNSET));
    mprintf(outf, 0, "");
  }
}

/*** Now some stuff for the general summary ***/

void distcount(Hashindex *gooditems, Hashindex *baditems, choice requests,
	       choice requests7, unsigned long *tot, unsigned long *tot7) {
  Hashindex *p;

  for (p = gooditems, *tot = 0, *tot7 = 0; p != NULL; TO_NEXT(p)) {
    if (p->own != NULL) {
      if (p->own->data[requests] > 0)
	(*tot)++;
      if (p->own->data[requests7] > 0)
	(*tot7)++;
    }
  }
  for (p = baditems; p != NULL; TO_NEXT(p)) {
    if (p->own != NULL) {
      if (p->own->data[requests] > 0)
	(*tot)++;
      if (p->own->data[requests7] > 0)
	(*tot7)++;
    }
  }
}

void gensumline(FILE *outf, Outchoices *od, char codeletter, int namecode,
		unsigned long x, unsigned long x7, logical p) {
  choice outstyle = od->outstyle;
  char *name = od->lngstr[namecode];
  char *colon = od->lngstr[colon_];
  char *compsep = od->compsep;

  if (strchr(od->gensumlines, codeletter) == NULL)
    return;
  if ((x > 0 || namecode == succreqs_) && x != (unsigned long)UNSET) {
    if (od->outstyle == HTML) {
      if (p)
	fprintf(outf, "<p><b>%s%s</b> ", name, colon);
      else
	fprintf(outf, "<br><b>%s%s</b> ", name, colon);
    }
    else if (outstyle == ASCII)
      fprintf(outf, "%s%s ", name, colon);
    else if (outstyle == LATEX)
      fprintf(outf, "{\\bf %s%s} ", name, colon);
    else /* outstyle == COMPUTER */
      fprintf(outf, "x%s%c%c%s", compsep, name[0], name[1], compsep);
    f3printf(outf, outstyle, (double)x, 0, od->sepchar);
    if (x7 != (unsigned long)(-1)) {
      if (outstyle == COMPUTER) {
	fprintf(outf, "\nx%s%c%c%s", compsep, name[2], name[3], compsep);
	f3printf(outf, outstyle, (double)x7, 0, od->sepchar);
      }
      else {
	fputs(" (", outf);
	f3printf(outf, outstyle, (double)x7, 0, od->sepchar);
	putc(')', outf);
      }
    }
    putc('\n', outf);
  }
}

void gensumlineb(FILE *outf, Outchoices *od, char codeletter, int namecode,
		 double x, double x7) {
  /* same as gensumline() but for bytes */
  choice outstyle = od->outstyle;
  char **lngstr = od->lngstr;
  char *name = lngstr[namecode];
  char *colon = lngstr[colon_];
  char *compsep = od->compsep;

  char *c;
  unsigned int bm;

  if (strchr(od->gensumlines, codeletter) == NULL)
    return;
  if (x > 0) {
    if (outstyle == HTML)
      fprintf(outf, "<br><b>%s%s</b> ", name, colon);
    else if (outstyle == ASCII)
      fprintf(outf, "%s%s ", name, colon);
    else if (outstyle == LATEX)
      fprintf(outf, "{\\bf %s%s} ", name, colon);
    else /* outstyle == COMPUTER */
      fprintf(outf, "x%s%c%c%s", compsep, name[0], name[1], compsep);
    bm = (od->rawbytes)?0:findbmult(x, od->bytesdp);
    printbytes(outf, od, x, bm, 0, od->sepchar);
    if (outstyle != COMPUTER) {
      if (bm > 0) {
	c = strchr(lngstr[xbytes_], '?');
	*c = '\0';
	fprintf(outf, " %s%s%s", lngstr[xbytes_], lngstr[byteprefix_ + bm],
		c + 1);
	*c = '?';
      }
      else
	fprintf(outf, " %s", lngstr[bytes_]);
    }
    if (x7 != UNSET) {
      if (outstyle == COMPUTER) {
	fprintf(outf, "\nx%s%c%c%s", compsep, name[2], name[3],	compsep);
	f3printf(outf, outstyle, (double)x7, 0, od->sepchar);
      }
      else {
	fputs(" (", outf);
	bm = (od->rawbytes)?0:findbmult(x7, od->bytesdp);
	printbytes(outf, od, x7, bm, 0, od->sepchar);
	if (bm > 0) {
	  c = strchr(lngstr[xbytes_], '?');
	  *c = '\0';
	  fprintf(outf, " %s%s%s)", lngstr[xbytes_], lngstr[byteprefix_ + bm],
		  c + 1);
	  *c = '?';
	}
	else
	  fprintf(outf, " %s)", lngstr[bytes_]);
      }
    }
    putc('\n', outf);
  }
}

logical checkonerep(Outchoices *od, Hashindex *gp, choice rep, choice requests,
		    cutfnp cutfn, dcutfnp dcutfn, void *darg) {
  extern Memman *amemman;

  static char *newname = NULL, *dnewname = NULL;
  static size_t len = 0, dlen = 0;

  char *namestart, *nameend, *name;
  choice rc;

  /* Procedure: go through all the entries. If the report will use that entry
     (it has any requests, and the name is included()) turn the report on.
     To calculate the name, we have to call cutfn if the report is a tree
     report, and/or (dcutfn and alias) if it is a dervrep. */
  for ( ; gp != NULL; TO_NEXT(gp)) {
    if (gp->own != NULL && gp->own->data[requests] > 0) {
      name = gp->name;
      if (cutfn == NULL && dcutfn != NULL) {
	/* The search reports. Here dcutfn can produce zero or multiple answers
	   for each name, and we have to check them all. */
	namestart = NULL;
	for (dcutfn(&namestart, &nameend, name, darg); namestart != NULL;
	     dcutfn(&namestart, &nameend, name, darg)) {
	  ENSURE_LEN(dnewname, dlen, (size_t)(nameend - namestart + 1));
	  memcpy((void *)dnewname, (void *)namestart,
		 (size_t)(nameend - namestart));
	  dnewname[nameend - namestart] = '\0';
	  if ((rc = do_alias(dnewname, amemman, NULL, NULL, 0, FALSE,
			     od->convfloor, od->multibyte, rep)) != ERR) {
	    name = rc?((char *)(amemman->curr_pos)):dnewname;
	    if (included(name, FALSE, od->wanthead[G(rep)]))
	      return(TRUE);
	  }
	}
      }
      else {
	/* otherwise each name produces just one answer to check; the name
	   itself, or if a tree report the name at the top level of the tree */
	if (cutfn != NULL) {  /* if it's a tree report */
	  if (dcutfn != NULL) {  /* if it's also a derv report */
	    /* Here we rely on the fact that if it's both a tree rep and a derv
	       rep, then dcutfn will produce exactly one name. (See comment on
	       dcutfnp in tree.c). */
	    namestart = NULL;
	    dcutfn(&namestart, &nameend, name, darg);
	    ENSURE_LEN(dnewname, dlen, (size_t)(nameend - namestart + 1));
	    memcpy((void *)dnewname, (void *)namestart,
		   (size_t)(nameend - namestart));
	    dnewname[nameend - namestart] = '\0';
	    if ((rc = do_alias(dnewname, amemman, NULL, NULL, 0, FALSE,
			       od->convfloor, od->multibyte, rep)) == ERR)
	      name = NULL;
	    else
	      name = rc?((char *)(amemman->curr_pos)):dnewname;
	  }
	  if (name != NULL) {
	    namestart = NULL;
	    cutfn(&namestart, &nameend, name, FALSE);
	    ENSURE_LEN(newname, len, (size_t)(nameend - namestart + 1));
	    memcpy((void *)newname, (void *)namestart,
		   (size_t)(nameend - namestart));
	    newname[nameend - namestart] = '\0';
	    name = newname;
	  }
	}
	if (name != NULL &&
	    included(name, gp->own->ispage, od->wanthead[G(rep)]))
	  return(TRUE);
      }
    }
  }
  return(FALSE);  /* nothing matched, so turn the report off */
}

logical checktreerep(Outchoices *od, Hashtable *tp, choice rep,
		     choice requests, cutfnp cutfn) {
  unsigned long i;

  for (i = 0; i < tp->size; i++) {
    if (checkonerep(od, tp->head[i], rep, requests, cutfn, NULL, NULL))
      return(TRUE);
  }
  return(FALSE);
}

logical checkarrayrep(Arraydata *array) {
  choice i;

  for (i = 0; ; i++) {
    if (array[i].reqs > 0)
      return(TRUE);
    if (array[i].threshold < -0.5)
      return(FALSE);
  }
}

void checkreps(Outchoices *od, Dateman *dman, Hashindex **gooditems,
	       Arraydata **arraydata,
	       choice data2cols[ITEM_NUMBER][DATA_NUMBER]) {
  extern logical *repistree;

  logical *repq = od->repq;

  cutfnp cutfn;
  dcutfnp dcutfn;
  void *darg;
  choice rep;
  int j;
  choice ok;

  if (dman->currdp == NULL) {
    for (rep = 0; rep < DATEREP_NUMBER; rep++) {
      if (repq[rep]) {
	warn('R', TRUE, "Turning off empty time reports");
	for ( ; rep < DATEREP_NUMBER; rep++)
	  repq[rep] = FALSE;
      }
    }
  }
  for (rep = FIRST_GENREP; rep <= LAST_NORMALREP; rep++) {
    cutfn = repistree[G(rep)]?(od->tree[G(rep)]->cutfn):NULL;
    dcutfn = (rep >= FIRST_DERVREP)?(od->derv[rep - FIRST_DERVREP]->cutfn):\
      NULL;
    darg = (rep >= FIRST_DERVREP)?(od->derv[rep - FIRST_DERVREP]->arg):NULL;
    for (ok = 0, j = 0; od->alltrees[j] != REP_NUMBER; j++) {
      if (rep == od->alltrees[j])
	ok = 1;
    }
    for (j = 0; od->alldervs[j] != REP_NUMBER; j++) {
      if (rep == od->alldervs[j])
	ok = 2;
    }
    if (ok) {
      if (!checktreerep(od, (ok == 1)?(od->tree[G(rep)]->tree):\
			(od->derv[rep - FIRST_DERVREP]->table), rep,
			data2cols[rep2type[rep]][rep2reqs[G(rep)]],
			(ok == 1)?NULL:cutfn)) {
	/* If ok == 1, tree made, so done cutfn already; if ok == 2, made derv
	   but not tree, so still need cutfn. NB i in alltrees or alldervs
	   implies repq so don't have to check that. */
	warn('R', TRUE, "Turning off empty %s", repname[rep]);
	repq[rep] = FALSE;
      }
    }
    else if (repq[rep]) {
      if (!checkonerep(od, gooditems[rep2type[rep]], rep,
		       data2cols[rep2type[rep]][rep2reqs[G(rep)]], cutfn,
		       dcutfn, darg)) {
	warn('R', TRUE, "Turning off empty %s", repname[rep]);
	repq[rep] = FALSE;
      }
    }
  }
  for ( ; rep < REP_NUMBER; rep++) {
    if (repq[rep] && !checkarrayrep(arraydata[rep - FIRST_ARRAYREP])) {
      warn('R', TRUE, "Turning off empty %s", repname[rep]);
      repq[rep] = FALSE;
    }
  }
}

#ifndef NOGRAPHICS
/* Pie charts. First #defines and globals */
#define XSIZE (600)                 /* Size of whole graphic */
#define YSIZE (270)
#define SHORTXSIZE (2 * (XCENTRE))  /* Size if no text on picture */
#define SHORTYSIZE (2 * (YCENTRE))
#define XCENTRE (125)               /* Centre of pie */
#define YCENTRE (125)
#define DIAMETER (200)              /* Diameter of pie */
#define BORDER (4)                  /* Size of border */
#define BOXESLEFT (XCENTRE + DIAMETER / 2 + 25)    /* The coloured boxes */ 
#define BOXESTOP (YCENTRE - DIAMETER / 2 + 16)
#define BOXESSIZE (10)
#define TEXTLEFT ((BOXESLEFT) + 2 * (BOXESSIZE))   /* The labels */
#define TEXTOFFSET (-1)
#define TEXTGAP (16)     /* Vertical period between successive boxes/labels */
#define CAPTIONLEFT (XCENTRE - DIAMETER / 2)       /* Bottom caption */
#define CAPTIONTOP (YCENTRE + DIAMETER / 2 + 12)
#define NO_COLOURS (10)  /* Number of text strings, excluding "Other" */
#define MAXCHARS (54)    /* Max length of a label, INCLUDING \0. */
#define TWOPI (6.283185)
#define MINANGLE (0.01)  /* Min fraction of circle we are prepared to plot */
#define PIE_EPSILON (0.0001)
gdImagePtr im;
gdFontPtr font;
logical normalchart;
int white, black, grey, lightgrey, colours[NO_COLOURS], col, boxesy;
double totangle;

FILE *piechart_init(char *filename) {
  FILE *pieoutf;
  int xsize, ysize, b1, b2;

  if ((pieoutf = FOPENWB(filename)) == NULL) {
    warn('F', TRUE, "Failed to open pie chart file %s for writing: "
	 "ignoring it", filename);
    return(pieoutf);
  }
  debug('F', "Opening %s as pie chart file", filename);
#ifdef RISCOS
  _swix(OS_File, _INR(0,2), 18, filename, 0xb60);  /* set filetype */
#endif

  xsize = normalchart?XSIZE:SHORTXSIZE;
  ysize = normalchart?YSIZE:SHORTYSIZE;
  im = gdImageCreate(xsize, ysize);
  /* The first colour allocated in a new image is the background colour. */
  white = gdImageColorAllocate(im, 255, 255, 255);           /* white */
  black = gdImageColorAllocate(im, 0, 0, 0);                 /* black */
  grey = gdImageColorAllocate(im, 128, 128, 128);            /* grey */
  lightgrey = gdImageColorAllocate(im, 217, 217, 217);       /* light grey */
  col = 0;
  /* Wedge colours. If these change, so must images/sq*. */
  colours[col++] = gdImageColorAllocate(im, 255, 0, 0);      /* red */
  colours[col++] = gdImageColorAllocate(im, 0, 0, 255);      /* mid blue */
  colours[col++] = gdImageColorAllocate(im, 0, 128, 0);      /* green */
  colours[col++] = gdImageColorAllocate(im, 255, 128, 0);    /* orange */
  colours[col++] = gdImageColorAllocate(im, 0, 0, 128);      /* navy blue */
  colours[col++] = gdImageColorAllocate(im, 0, 255, 0);      /* pale green */
  colours[col++] = gdImageColorAllocate(im, 255, 128, 128);  /* pink */
  colours[col++] = gdImageColorAllocate(im, 0, 255, 255);    /* cyan */
  colours[col++] = gdImageColorAllocate(im, 128, 0, 128);    /* purple */
  colours[col++] = gdImageColorAllocate(im, 255, 255, 0);    /* yellow */
  col = 0;
  totangle = 0.75;  /* starting at the top */
  boxesy = BOXESTOP;
  b1 = xsize - 1 - BORDER;
  b2 = ysize - 1 - BORDER;
  /* Plot outline of pie, and border of image */
  gdImageArc(im, XCENTRE, YCENTRE, DIAMETER + 2, DIAMETER + 2, 0, 360, black);
  gdImageRectangle(im, BORDER, BORDER, b1, b2, black);
  gdImageLine(im, xsize - 1, 0, b1, BORDER, black);
  gdImageLine(im, 0, ysize - 1, BORDER, b2, black);
  gdImageFill(im, 0, 0, lightgrey);
  gdImageFill(im, xsize - 1, ysize - 1, grey);
  gdImageLine(im, 0, 0, BORDER, BORDER, black);
  gdImageLine(im, xsize - 1, ysize - 1, b1, b2, black);
  return(pieoutf);
}

void findwedges(Wedge wedge[NO_COLOURS], choice rep, Hashindex *items,
		choice chartby, Strlist *expandlist, unsigned int level,
		Strlist *partname, unsigned long tot, double totb,
		double totb7) {
  /* Calculate which wedges we actually want, i.e. the ten with the biggest
     angles. But we also preserve the sort order of the "items" list. (Be
     careful between > and >= so as to use that order for breaking ties).
     Construction of name same as in printtree(). */
  static double smallestangle;
  static int smallestwedge;

  char *name;
  double angle;
  Strlist *pn, s;
  size_t need = (size_t)level + 3;
  Hashindex *p;
  int i;

  if (level == 0) {  /* not recursing: initialise wedges to 0 */
    for (i = 0; i < NO_COLOURS; i++) {
      wedge[i].angle = 0.0;
      wedge[i].name = NULL;
    }
    smallestangle = 0.0;
    smallestwedge = NO_COLOURS - 1;
  }

  for (pn = partname; pn != NULL; TO_NEXT(pn))
    need += strlen(pn->name);
  for (p = items; p != NULL; TO_NEXT(p)) {
    name = maketreename(partname, p, &pn, &s, need, rep, TRUE);
    if (incstrlist(name, expandlist) && p->other != NULL &&
	((Hashtable *)(p->other))->head[0] != NULL)
      /* then find wedges in lower level of tree instead. ->head[0] != NULL
	 must come after p->other != NULL; o/wise it may not be a treerep */
      findwedges(wedge, rep, ((Hashtable *)(p->other))->head[0], chartby,
		 expandlist, level + 1, pn, tot, totb, totb7);
    else {
      if (chartby == BYTES)
	angle = p->own->bytes / totb;
      else if (chartby == BYTES7)
	angle = p->own->bytes7 / totb7;
      else
	angle = ((double)(p->own->data[chartby])) / ((double)tot);
      if (angle > smallestangle) {/* remove smallest, move along, put p last */
	/* We probably don't do this very often so we don't bother with keeping
	   hold of the memory and reusing it later. */
	free(wedge[smallestwedge].name);
	for (i = smallestwedge; i < NO_COLOURS - 1; i++) {
	  wedge[i].name = wedge[i + 1].name;
	  wedge[i].angle = wedge[i + 1].angle;
	}
	COPYSTR(wedge[NO_COLOURS - 1].name, name);
	/* malloc's necessary space. Needed because next call to maketreename()
	   will overwrite name. */
	wedge[NO_COLOURS - 1].angle = angle;
	smallestangle = wedge[0].angle;  /* Recalculate smallest */
	smallestwedge = 0;
	for (i = 1; i < NO_COLOURS; i++) {
	  if (wedge[i].angle <= smallestangle) {
	    smallestangle = wedge[i].angle;
	    smallestwedge = i;
	  }
	}
      }
    }
  }
}

void piechart_caption(FILE *outf, choice rep, choice chartby, char **lngstr) {
  extern unsigned int *method2sort;
  static char *caption = NULL;
  static size_t len = 0;

  choice requests = rep2reqs[G(rep)];
  choice requests7 = rep2reqs7[G(rep)];

  ENSURE_LEN(caption, len, strlen(lngstr[chartby_]) +
	     strlen(lngstr[method2sort[requests]]) +
	     strlen(lngstr[method2sort[requests7]]) +
	     strlen(lngstr[method2sort[chartby]]) + 3);
  /* More than we need, but that's OK. */
  strcpy(caption, lngstr[chartby_]);
  strcat(caption, " ");
  if (chartby == REQUESTS)
    strcat(caption, lngstr[method2sort[requests]]);
  else if (chartby == REQUESTS7)
    strcat(caption, lngstr[method2sort[requests7]]);
  else
    strcat(caption, lngstr[method2sort[chartby]]);
  strcat(caption, ".");
  if (normalchart) {
#ifdef EBCDIC
    (void)strtoascii(caption);
#endif
    gdImageString(im, font, CAPTIONLEFT, CAPTIONTOP, (unsigned char *)caption,
		  black);
  }
  else
    fprintf(outf, "<p><em>%s</em>\n", caption);
}

int piechart_wedge(FILE *outf, Outchoices *od, double angle, char *s) {
  /* The angle is expressed between 0 and 1. Returns col if wedge was big
     enough to be coloured in, NO_COLOURS for grey, else -1. */
  double x, y, newangle, medangle;
  int colour = black, rc = -1;
  char t[MAXCHARS];
  size_t len;

  if (angle < 0) {
    angle = 1.75 - totangle;  /* rest of the circle because started at 0.75 */
    colour = grey;
  }
  else if (col >= NO_COLOURS)
    angle = 0;  /* As a signal not to make a wedge. Can this happen? */
  else if (angle >= MINANGLE)
    colour = colours[col];

  if (angle >= MINANGLE || (colour == grey && angle > EPSILON)) {
    /* plot one edge of wedge */
    x = (double)XCENTRE + (double)DIAMETER * cos(totangle * TWOPI) / 2. +
      PIE_EPSILON;
    y = (double)YCENTRE + (double)DIAMETER * sin(totangle * TWOPI) / 2. +
      PIE_EPSILON;
    gdImageLine(im, XCENTRE, YCENTRE, (int)x, (int)y, black);

    /* plot other edge of wedge */
    newangle = totangle + angle;
    x = (double)XCENTRE + (double)DIAMETER * cos(newangle * TWOPI) / 2. +
      PIE_EPSILON;
    y = (double)YCENTRE + (double)DIAMETER * sin(newangle * TWOPI) / 2. +
      PIE_EPSILON;
    gdImageLine(im, XCENTRE, YCENTRE, (int)x, (int)y, black);

    /* Fill wedge */
    medangle = totangle + angle / 2.;
    x = (double)XCENTRE + (double)DIAMETER * cos(medangle * TWOPI) / 2.5;
    y = (double)YCENTRE + (double)DIAMETER * sin(medangle * TWOPI) / 2.5;
    if (gdImageGetPixel(im, (int)x, (int)y) == white) {  /* room to colour */
      gdImageFill(im, (int)x, (int)y, colour);
      /* Make label for wedge. If !normalchart, this is done in piechart_key()
	 below instead. (See long comment near bottom of piechart().) */
      if (normalchart) {
	gdImageFilledRectangle(im, BOXESLEFT, boxesy, BOXESLEFT + BOXESSIZE,
			       boxesy + BOXESSIZE, colour);
	if ((len = strlen(s)) <= MAXCHARS - 1)
	  strcpy(t, s);
	else {
	  strncpy(t, s, (MAXCHARS - 3) / 2);
	  strcpy(t + (MAXCHARS - 3) / 2, "...");
	  strncpy(t + (MAXCHARS + 3) / 2, s + len - (MAXCHARS - 4) / 2,
		  (MAXCHARS - 4) / 2);
	  t[MAXCHARS - 1] = '\0';
	}
#ifdef EBCDIC
	strtoascii(t);
#endif
	gdImageString(im, font, TEXTLEFT, boxesy + TEXTOFFSET,
		      (unsigned char *)t, black);
	boxesy += TEXTGAP;
      }
      rc = (colour == grey)?NO_COLOURS:col;
    }   /* end if (room to colour) */
    totangle = newangle;
    col++;
  }
  return(rc);
}

void piechart_key(FILE *outf, Outchoices *od, int col, char *name,
		  char *extension, Alias *aliashead) {
  /* Only called if !normalchart and wedge was included on chart */
  fputs("<br><img src=\"", outf);
  htmlputs(outf, od, od->imagedir, IN_HREF);
  if (col == NO_COLOURS)
    fprintf(outf, "sqg.%s", extension);
  else         /* Above and below: '.' not EXTSEP even on RISC OS */
    fprintf(outf, "sq%d.%s", col, extension);
  fputs("\" alt=\"\"> ", outf);
  do_aliasx(outf, od, name, aliashead);  /* alias and print */
  fputs("\n", outf);
}

void piechart_write(FILE *pieoutf, char *filename, logical jpegcharts) {
#ifdef HAVE_GD
  if (jpegcharts)
    gdImageJpeg(im, pieoutf, 100);
  else
#endif
  gdImagePng(im, pieoutf);
  debug('F', "Closing %s", filename);
  fclose(pieoutf);
  gdImageDestroy(im);
}

void piechart_cleanup(Wedge wedge[NO_COLOURS]) {
  int i;

  /* free the wedge names allocated in findwedges() */
  for (i = 0; i < NO_COLOURS; i++)
    free(wedge[i].name);
}

void piechart(FILE *outf, Outchoices *od, choice rep, Hashindex *items,
	      choice requests, choice requests7, choice pages, choice pages7,
	      unsigned long totr, unsigned long totr7, unsigned long totp,
	      unsigned long totp7, double totb, double totb7) {
  /* Assume outstyle == HTML already tested */
  extern char *workspace;
  extern char *anchorname[];
  static char *filename = NULL;

  char **lngstr = od->lngstr;
  choice chartby = od->chartby[G(rep)];
  Strlist *expandlist = od->expandhead[G(rep)];
  char gender = lngstr[rep2lng[rep] + 3][0];
  char *extension = (od->jpegcharts)?"jpg":"png";

  Wedge wedge[NO_COLOURS];
  FILE *pieoutf;
  int key[NO_COLOURS], keyg;
  double largestangle;
  unsigned long tot = 1;
  char *otherstr;
  int i;

  /* Sort out what the chartby really means */
  if (chartby == CHART_NONE)
    return;  /* We didn't want a pie chart after all */
  if (chartby == REQUESTS) {
    chartby = requests;
    tot = totr;
  }
  else if (chartby == REQUESTS7) {
    chartby = requests7;
    tot = totr7;
  }
  else if (chartby == PAGES) {
    chartby = pages;
    tot = totp;
  }
  else if (chartby == PAGES7) {
    chartby = pages7;
    tot = totp7;
  }
  if (tot == 0 || (chartby == BYTES && totb < 0.5) ||
      (chartby == BYTES7 && totb7 < 0.5)) {
    warn('R', TRUE, "In %s, turning off empty pie chart", repname[rep]);
    return;
  }

  /* Calculate which wedges to include */
  findwedges(wedge, rep, items, chartby, expandlist, 0, NULL, tot, totb,
	     totb7);

  /* Check whether we still want a chart */
  largestangle = wedge[0].angle;
  for (i = 1; i < NO_COLOURS; i++)
    largestangle = MAX(wedge[i].angle, largestangle);
  if (largestangle >= 1 - EPSILON) {
    warn('R', TRUE, "In %s, turning off pie chart of only one wedge",
	 repname[rep]);
    return;
  }
  if (largestangle == 0.) {
    warn('R', TRUE, "In %s, turning off pie chart with no wedges",
	 repname[rep]);
    return;
  }
  if (largestangle < MINANGLE) {
    warn('R', TRUE, "In %s, turning off pie chart because no wedge "
	 "large enough", repname[rep]);
    return;
  }

  /* font and normalchart are the same for every chart, but calculating them
     here allows us to keep the variables only in this file */
  normalchart = TRUE;
  if (strcaseeq(lngstr[charset_], "ISO-8859-2"))
    font = gdFontSmall;
  else {
    font = gdFontFixed;
    if (!strcaseeq(lngstr[charset_], "ISO-8859-1") &&
	!strcaseeq(lngstr[charset_], "US-ASCII"))
      normalchart = FALSE;
  }

  if (filename == NULL)
    filename = (char *)xmalloc(strlen(od->localchartdir) + 13);
  /* max poss length = localchartdir + anchorname ( <= 8 ) + ".png\0" */
  sprintf(filename, "%s%s%c%s", od->localchartdir, anchorname[rep], EXTSEP,
	  extension);
  if ((pieoutf = piechart_init(filename)) == NULL)
    return;  /* Warning message is given in piechart_init() */

  /* Now we can finally get round to plotting the chart */
  for (i = 0; i < NO_COLOURS; i++) {
    key[i] = -1;
    if (wedge[i].name != NULL) {
      strcpy(workspace, wedge[i].name);
      do_aliasx(NULL, NULL, workspace, od->aliashead[G(rep)]);
      key[i] = piechart_wedge(outf, od, wedge[i].angle, workspace);
      /* retain i -> colour mapping for calling piechart_key() below */
    }
  }
  if (normalchart)
    piechart_caption(outf, rep, od->chartby[G(rep)], lngstr);

  /* Plot the catch-all wedge and close the file */
  if (gender == 'm')
    otherstr = lngstr[otherm_];
  else if (gender == 'f')
    otherstr = lngstr[otherf_];
  else
    otherstr = lngstr[othern_];
  keyg = piechart_wedge(outf, od, -1., otherstr);
  piechart_write(pieoutf, filename, od->jpegcharts);

  /* Now the text on the page. In CGI mode, this must be done _after_ the image
     is closed, or the browser may fail to find the image. This is why printing
     the caption and key must be done twice; above here if normalchart, below
     here otherwise. */
  fprintf(outf, "<p><img src=\"%s%s.%s\" alt=\"\">\n", od->chartdir,
	  anchorname[rep], extension);   /* '.' not EXTSEP even on RISC OS */

  if (!normalchart) {
    piechart_caption(outf, rep, od->chartby[G(rep)], lngstr);
    for (i = 0; i < NO_COLOURS; i++) {
      if (key[i] != -1)
	piechart_key(outf, od, key[i], wedge[i].name, extension,
		     od->aliashead[G(rep)]);
    }
    if (keyg != -1)
      piechart_key(outf, od, keyg, otherstr, extension, NULL);
  }

  piechart_cleanup(wedge);
}
#endif  /* NOGRAPHICS */

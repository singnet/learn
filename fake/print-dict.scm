;
; print-dict.scm -- print Link-Grammar dictionary to file.
;
; Copyright (c) 2021 - Linas Vepstas
;
; --------------------------------------------------------
; OVERVIEW:
; Print Link Grammar dictionaries to a file.
;
; Example Usage:
; --------------
; Print dict to stdout.
; (print-LG-flat #t dict)
;
; Print dict to file.
; (define port (open-file "/tmp/4.0.dict" "w"))
; (print-LG-flat port dict)
; (fsync port) (close port)
;

(use-modules (srfi srfi-1))

; --------------------------------------------------------
; Print dictionary.

(define-public (print-LG-flat DEST DICT)
"
  print-LG-flat DEST DICT - print a Link-Grammar style dictionary.

  Prints a flat-file style dictionary.

  The DEST must be the destination file-handle, or #t to print to
  stdout, or #f to print to string.

  The DICT must be a dictionary.
"

	(define (prt-wordlist WL)
		(string-join
			(map (lambda (WORD) (format #f "~A" WORD)) WL)))

	(define (prt-junct CL)
		(string-join
			(map (lambda (CON) (format #f "~A" CON)) CL) " or "))

	(for-each
		(lambda (ENTRY)
			(format DEST "\n~A: ~A;\n"
				(prt-wordlist (first ENTRY))
				(prt-junct (second ENTRY)))
		)
		DICT)
)

; --------------------------------------------------------

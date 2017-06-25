;
; mst-count-en.scm
;
; Run everyting needed for the language-learning disjunct-counting
; pipeline. Starts the REPL server, opens the database, loads the
; database (which can take an hour or more!).
;
(use-modules (system repl common))
(use-modules (system repl server))
(use-modules (opencog) (opencog logger))
(use-modules (opencog persist) (opencog persist-sql))
(use-modules (opencog nlp) (opencog nlp learn))
(use-modules (opencog matrix))

; Write a log-file, just in case...
(cog-logger-set-filename! "/tmp/mst-en.log")
(cog-logger-info "Start MST parsing for English.")

; Start the network REPL server on port 19005
(call-with-new-thread (lambda ()
   (repl-default-option-set! 'prompt "scheme@(en-mst)> ")
   (set-current-error-port (%make-void-port "w"))
   (run-server (make-tcp-server-socket #:port 19005)))
)

; Open the database.
; Edit the below, setting the database name, user and password.
(sql-open "postgres:///en_pairs_rthree_mall?user=ubuntu&password=asdf")

; Load up the words
(display "Fetch all words from database. This may take several minutes.\n")
(fetch-all-words)

; Load up the word-pairs -- this can take over half an hour!
(display "Fetch all word-pairs. This may take well over half-an-hour!\n")

; The object which will be providing pair-counts for us.
; We can also do MST parsing with other kinds of pair-count objects,
; for example, the clique-pairs, or the distance-pairs.
(define pair-obj (make-any-link-api))
(pair-obj 'fetch-pairs)

; Print the sql stats
(sql-stats)

; Clear the sql cache and the stats counters
(sql-clear-cache)
(sql-clear-stats)
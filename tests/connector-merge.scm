;
; connector-merge.scm
;

(use-modules (opencog) (opencog matrix))
(use-modules (opencog nlp))
(use-modules (opencog nlp learn))
(use-modules (opencog persist) (opencog persist-rocks))

(use-modules (opencog test-runner))

(opencog-test-runner)

; ---------------------------------------------------------------
; Database management
(define (setup-database)

	(define dbdir "/tmp/test-merge")
	(cog-atomspace-clear)

	; Create directory if needed.
	(if (not (access? dbdir F_OK)) (mkdir dbdir))
	(define storage-node (RocksStorageNode
		(string-append "rocks://" dbdir)))
	(cog-open storage-node)
)

; ---------------------------------------------------------------
(define t-simple "simplest merge test")
(test-begin t-simple)

; Open the database
(setup-database)

; Load some data
(load "connector-data.scm")
(setup-basic-sections)

; Define matrix API to the data
(define pca (make-pseudo-cset-api))
(define csc (add-covering-sections pca))
(define gsc (add-cluster-gram csc))

; Verify that the data loaded correctly
; We expect 3 sections on "e" and two on "j"
(test-equal 3 (length (gsc 'right-stars (Word "e"))))
(test-equal 2 (length (gsc 'right-stars (Word "j"))))

; Create CrossSections and verify that they got created
(csc 'explode-sections)
(test-equal 15 (length (cog-get-atoms 'CrossSection)))

; Verify that direct-sum object is accessing shapes correctly
; i.e. the 'explode should have created some CrossSections
(test-equal 2 (length (gsc 'right-stars (Word "g"))))
(test-equal 2 (length (gsc 'right-stars (Word "h"))))

; Should not be any CrossSections on e,j; should be same as before.
(test-equal 3 (length (gsc 'right-stars (Word "e"))))
(test-equal 2 (length (gsc 'right-stars (Word "j"))))

; Merge two sections together.
(define disc (make-discrim gsc 0.25 4 4))
(disc 'merge-function (Word "e") (Word "j"))

; We expect just one section left on "e", the klm section.
(test-equal 1 (length (gsc 'right-stars (Word "e"))))

; We expect no sections left on j
(test-equal 0 (length (gsc 'right-stars (Word "j"))))

; We expect three merged sections
(test-equal 3 (length (gsc 'right-stars (WordClassNode "e j"))))

; Of the 3 original Sections, 2 are deleted, and 3 are created,
; leaving a grand total of 4. The 3 new ones are all e-j, the
; remaining old one is a e with a reduced count.  This is just
; the sum of the above.
(test-equal 4 (length (cog-get-atoms 'Section)))

; Validate counts.
(define angl 0.35718064330452926) ; magic value from make-discrim
(test-approximate (* cnt-e-klm (- 1.0 angl))
	(cog-count (car (gsc 'right-stars (Word "e")))) 0.001)

; TODO: validate counts on the other Sections...

; Of the 15 original CrossSections, 12 are deleted outright, and three
; get thier counts reduced (the e-klm crosses). A total of 3x3=9 new
; crosses get created, leaving a grand-total of 12.
(test-equal 12 (length (cog-get-atoms 'CrossSection)))

; TODO: validate counts on the CrossSections...

(test-end t-simple)

; ---------------------------------------------------------------

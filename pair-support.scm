;
; pair-support.scm
;
; Define object-oriented class API's for computing the supporting set
; the the lp-norms for the left and right side of pairs.
;
; Copyright (c) 2017 Linas Vepstas
;
; ---------------------------------------------------------------------
; OVERVIEW
; --------
; See pairobject-api.scm for the overview.
; ---------------------------------------------------------------------

(use-modules (srfi srfi-1))

; ---------------------------------------------------------------------

(define-public (add-pair-support-compute LLOBJ)
"
  add-pair-support-compute LLOBJ - Extend LLOBJ with methods to
  compute wild-card sums, including the support (lp-norm for p=0),
  the count (lp-norm for p=1), the Eucliden length (lp-norm for p=2)
  and the general lp-norm.  These all work with the counts for the
  pairs, and NOT the frequencies!  None of these use cached values,
  instead, they compute these values on the fly.

  Some terminology: Let N(x,y) be the observed count for the pair (x,y).
  The left-support-set consists of all pairs (x,y), for fixed y, for
  which N(x,y) > 0. The right-support-set is the same, for fixed x.

  The support is the size of the support-set.  AKA the l_0 norm.

  The left-count is the wild-card sum_x N(x,y) for fixed y.

  The left-length is sqrt(sum_x N^2(x,y)) for fixed y.

  The left-lp-norm is |sum_x N^p(x,y)|^1/p for fixed y.

  Here, the LLOBJ is expected to be an object, with valid
  counts associated with each pair. LLOBJ is expected to have
  working, functional methods for 'left-type and 'right-type
  on it.
"
	(let ((llobj LLOBJ)
			(star-obj (add-pair-stars LLOBJ)))

		; -------------
		; Given a list of low-level pairs, return list of high-level
		; pairs for which the count is non-zero. Internal use only.
		(define (non-zero-filter LIST)
			(filter-map
				(lambda (lopr)
					; 'item-pair returns the atom holding the count
					; 'pair-count returns the actual count.
					(define hipr (llobj 'item-pair lopr))
					(define cnt (llobj 'pair-count hipr))
					(if (< 0 cnt) hipr #f))
				LIST))

		; Return a list of all pairs (x, y) for y == ITEM for which
		; N(x,y) > 0.  Specifically, this returns the pairs which
		; are hiolding the counts (and not the low-level pairs).
		(define (get-left-support-set ITEM)
			(non-zero-filter (star-obj 'left-stars ITEM)))

		; Same as above, but on the right.
		(define (get-right-support-set ITEM)
			(non-zero-filter (star-obj 'right-stars ITEM)))

		; -------------
		; Return how many non-zero items are in the list.
		(define (get-support-size LIST)
			(fold
				(lambda (lopr cnt)
					; 'item-pair returns the atom holding the count
					; 'pair-count returns the count.
					(+ cnt
						(if (< 0 (llobj 'pair-count (llobj 'item-pair lopr)))
							1 0)))
				0
				LIST))

		; Should return a value exactly equal to
		; (length (get-left-support ITEM))
		; Equivalently to the l_0 norm (l_p norm for p=0)
		(define (get-left-support-size ITEM)
			(get-support-size (star-obj 'left-stars ITEM)))

		(define (get-right-support-size ITEM)
			(get-support-size (star-obj 'right-stars ITEM)))

		; -------------
		; Return the sum of the counts on the list
		(define (sum-count LIST)
			(fold
				(lambda (lopr sum)
					; 'item-pair returns the atom holding the count
					; 'pair-count returns the actual count.
					(define hipr (llobj 'item-pair lopr))
					(define cnt (llobj 'pair-count hipr))
					(+ sum cnt))
				0
				LIST))

		; Should return a value exactly equal to 'left-count
		; Equivalently to the l_1 norm (l_p norm for p=1)
		(define (sum-left-count ITEM)
			(sum-count (star-obj 'left-stars ITEM)))

		(define (sum-right-count ITEM)
			(sum-count (star-obj 'right-stars ITEM)))

		; -------------
		; Return the Euclidean length of the list
		(define (sum-length LIST)
			(define tot
				(fold
					(lambda (lopr sum)
						; 'item-pair returns the atom holding the count
						; 'pair-count returns the actual count.
						(define hipr (llobj 'item-pair lopr))
						(define cnt (llobj 'pair-count hipr))
						(+ sum (* cnt cnt)))
					0
					LIST))
			(sqrt tot))

		; Returns the Eucliden length aka the l_2 norm (l_p norm for p=2)
		(define (sum-left-length ITEM)
			(sum-length (star-obj 'left-stars ITEM)))

		(define (sum-right-length ITEM)
			(sum-length (star-obj 'right-stars ITEM)))

		; -------------
		; Return the lp-norm (Banach-space norm) of the counts
		; on LIST.  Viz sum_k N^p(k) for counted-pairs k in the
		; list
		(define (sum-lp-norm P LIST)
			(define tot
				(fold
					(lambda (lopr sum)
						; 'item-pair returns the atom holding the count
						; 'pair-count returns the actual count.
						(define hipr (llobj 'item-pair lopr))
						(define cnt (llobj 'pair-count hipr))
						(+ sum (expt cnt P)))
					0
					LIST))
			(expt tot (/ 1.0 P)))

		(define (sum-left-lp-norm P ITEM)
			(sum-lp-norm P (star-obj 'left-stars ITEM)))

		(define (sum-right-lp-norm P ITEM)
			(sum-lp-norm P (star-obj 'right-stars ITEM)))

	; Methods on this class.
	(lambda (message . args)
		(case message
			((left-support-set)   (apply get-left-support-set args))
			((right-support-set)  (apply get-right-support-set args))
			((left-support)       (apply get-left-support-size args))
			((right-support)      (apply get-right-support-size args))
			((left-count)         (apply sum-left-count args))
			((right-count)        (apply sum-right-count args))
			((left-length)        (apply sum-left-length args))
			((right-length)       (apply sum-right-length args))
			((left-lp-norm)       (apply sum-left-lp-norm args))
			((right-lp-norm)      (apply sum-right-lp-norm args))
			(else (apply llobj (cons message args))))
		)))

; ---------------------------------------------------------------------

(define-public (add-pair-cosine-compute LLOBJ)
"
  add-pair-cosine-compute LLOBJ - Extend LLOBJ with methods to compute
  vector dot-products and cosine angles.  None of these use cached
  values, instead, they compute these values on the fly.

  Some terminology: Let N(x,y) be the observed count for the pair (x,y).
  There are two ways of computing a dot-product: summing on the left, or
  the right.  Thus we define the left-product as
      left-prod(y,z) = sum_x N(x,y) N(x,z)
  and the right-product as
      right-prod(x,u) = sum_y N(x,y) N(u,y)

  Here, the LLOBJ is expected to be an object, with valid
  counts associated with each pair. LLOBJ is expected to have
  working, functional methods for 'left-type and 'right-type
  on it.
"
	(let ((llobj LLOBJ)
			(star-obj (add-pair-stars LLOBJ)))

		; Given the low-level pair LOPR, return the numeric count for it.
		(define (get-lo-cnt LOPR)
			(llobj 'pair-count (llobj 'item-pair LOPR)))

		; Compute the dot-product, summing over items from the
		; LIST, (which are pairs containing ITEM-A) and using the
		; get-other-lopr function to get the other pair to sum over
		; (i.e. replacing ITEM-A in the list with ITEM-B)
		; With a suitable LIST and get-other-lopr, this can do
		; either the left or the right sums.
		(define (compute-product get-other-lopr ITEM-B LIST)
			; Loop over the the LIST
			(fold
				(lambda (lopr sum)
					(define a-cnt (get-lo-cnt lopr))
					(define b-pr (get-other-lopr lopr ITEM-B))

					(if (null? b-pr)
						sum
						(+ sum (* a-cnt (get-lo-cnt b-pr)))))
				0
				LIST))

		; Return the low-level pair (x,y) if it exists, else
		; return the empty list '()
		(define (have-lopr? X Y)
			(cog-link (llobj 'pair-type) X Y))

		; Get the "other pair", for lefty wild
		(define (get-other-left LOPR OTHER)
			(have-lopr? (gar LOPR) OTHER))

		; Get the "other pair", for righty wild
		(define (get-other-right LOPR OTHER)
			(have-lopr? OTHER (gdr LOPR)))

		(define (compute-left-product ITEM-A ITEM-B)
			(compute-product get-other-left ITEM-B
				(star-obj 'left-stars ITEM-A)))

		(define (compute-right-product ITEM-A ITEM-B)
			(compute-product get-other-right ITEM-B
				(star-obj 'right-stars ITEM-A)))

	; -------------
	; Methods on this class.
	(lambda (message . args)
		(case message
			((left-product)    (apply compute-left-product args))
			((right-product)   (apply compute-right-product args))
			(else (apply llobj (cons message args))))
		)))

; ---------------------------------------------------------------------
